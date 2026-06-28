from std.ffi import CStringSlice, c_char

from hts_mojo._ffi import (
    bam1_t,
    bam_copy1,
    bam_destroy1,
    bam_dup1,
    bam_init1,
    bam_set1,
    htsFile,
    hts_close,
    hts_free,
    hts_idx_destroy,
    hts_idx_t,
    hts_itr_destroy,
    hts_itr_t,
    hts_get_bgzfp,
    hts_itr_next,
    malloc,
    hts_open,
    hts_set_fai_filename,
    hts_set_threads,
    sam_hdr_destroy,
    sam_hdr_dup,
    sam_hdr_init,
    sam_hdr_length,
    sam_hdr_name2tid,
    sam_hdr_nref,
    sam_hdr_parse,
    sam_hdr_read,
    sam_hdr_str,
    sam_hdr_tid2len,
    sam_hdr_tid2name,
    sam_hdr_t,
    sam_hdr_write,
    sam_index_build3,
    sam_index_load,
    sam_index_load2,
    sam_index_load3,
    sam_itr_queryi,
    sam_itr_querys,
    sam_parse_region,
    sam_read1,
    sam_write1,
    uint8_t,
    uint32_t,
)

# Thin RAII wrappers over the generated HTSlib FFI surface.
#
# These types intentionally stay close to HTSlib semantics:
# - constructors acquire ownership of newly created/read handles
# - destructors release owned HTSlib resources
# - `ptr()` exposes the mutable raw pointer for interop with lower-level calls
# - string inputs passed into HTSlib must already be NUL-terminated
#
# This layer is meant for internal plumbing, not a high-level public API.

def _ensure_nul(mut s: String):
    if s.byte_length() == 0:
        s += "\0"
        return
    if String(s[byte=s.byte_length() - 1]) != "\0":
        s += "\0"


def _cstr(mut s: String) raises -> UnsafePointer[c_char, ImmutUntrackedOrigin]:
    _ensure_nul(s)
    return (
        CStringSlice(s)
        .as_bytes_with_nul()
        .unsafe_ptr()
        .unsafe_origin_cast[ImmutUntrackedOrigin]()
        .bitcast[c_char]()
    )


def _terminated(s: String) -> String:
    var result = s
    _ensure_nul(result)
    return result^


def _bytes_with_nul(mut s: String) raises -> UnsafePointer[UInt8, ImmutUntrackedOrigin]:
    _ensure_nul(s)
    return (
        CStringSlice(s)
        .as_bytes_with_nul()
        .unsafe_ptr()
        .unsafe_origin_cast[ImmutUntrackedOrigin]()
        .bitcast[UInt8]()
    )


struct _OwnedByteBuffer(Movable):
    var _ptr: Optional[UnsafePointer[UInt8, MutUntrackedOrigin]]

    # Temporary malloc-backed storage for arguments that must outlive
    # a single FFI call but still be released deterministically.
    def __init__(out self, size: Int) raises:
        if size <= 0:
            self._ptr = None
            return
        var mem = malloc(UInt(size))
        if not mem:
            raise Error("failed to allocate temporary BAM buffer")
        self._ptr = rebind[Optional[UnsafePointer[UInt8, MutUntrackedOrigin]]](mem)
        for i in range(size):
            self._ptr.value()[i] = UInt8(0)

    def __del__(deinit self):
        if self._ptr:
            hts_free(self._ptr.value().bitcast[NoneType]())

    def ptr(self) -> Optional[UnsafePointer[UInt8, MutUntrackedOrigin]]:
        return self._ptr


def _check_code(code: Int, context: String) raises:
    if code != 0:
        raise Error(context)


def _check_not_none[
    T: Movable & Copyable
](value: Optional[T], context: String) raises -> T:
    if not value:
        raise Error(context)
    return value.value().copy()


struct RawSamFile(Movable):
    """
    RAII wrapper around an `htsFile*`.

    A value created with `RawSamFile(path, mode)` owns the returned HTSlib file
    handle and closes it on destruction. `ptr()` exposes the mutable raw pointer for other
    low-level helpers in this module.
    """
    var _ptr: Optional[UnsafePointer[htsFile, MutUntrackedOrigin]]

    def __init__(out self, path: String, mode: String) raises:
        """Open an alignment file with HTSlib mode semantics such as `rb` or `wb`."""
        var path_c = path
        var mode_c = mode
        self._ptr = hts_open(_cstr(path_c), _cstr(mode_c))
        if not self._ptr:
            raise Error("failed to open alignment file")

    def __del__(deinit self):
        """Release the owned file handle if one is present."""
        if self._ptr:
            _ = hts_close(self._ptr.value())

    def ptr(self) -> UnsafePointer[htsFile, MutUntrackedOrigin]:
        """Return the owned raw file pointer. The caller must not free it."""
        return self._ptr.value()

    def set_threads(mut self, n_threads: Int) raises:
        """Configure HTSlib worker threads for this file handle."""
        _check_code(
            Int(hts_set_threads(self.ptr(), Int32(n_threads))),
            "failed to set alignment threads",
        )

    def set_reference(mut self, reference_path: String) raises:
        """Attach a FASTA reference path for formats and operations that require it."""
        var reference_path_c = reference_path
        _check_code(
            Int(hts_set_fai_filename(self.ptr(), _cstr(reference_path_c))),
            "failed to set reference FASTA",
        )

    def close(mut self) raises:
        """Close the owned file handle. Calling this more than once is a no-op."""
        if self._ptr:
            _check_code(
                Int(hts_close(self._ptr.value())), "failed to close file"
            )
            self._ptr = None


struct RawSamHeader(Movable):
    """
    RAII wrapper around a `sam_hdr_t*`.

    Instances own their header pointer and destroy it automatically. This type
    is intentionally thin and mirrors HTSlib's header-centric operations:
    allocate, read, parse, duplicate, and query references by tid or name.
    """
    var _ptr: Optional[UnsafePointer[sam_hdr_t, MutUntrackedOrigin]]

    def __init__(out self) raises:
        """Allocate an empty mutable SAM header via `sam_hdr_init()`."""
        self._ptr = sam_hdr_init()
        if not self._ptr:
            raise Error("failed to allocate alignment header")

    def __init__(
        out self, ptr: Optional[UnsafePointer[sam_hdr_t, MutUntrackedOrigin]]
    ):
        """Adopt ownership of an existing header pointer returned by HTSlib."""
        self._ptr = ptr

    def __init__(out self, file: RawSamFile) raises:
        """Read and own the header from an open alignment file."""
        self._ptr = sam_hdr_read(file.ptr())
        if not self._ptr:
            raise Error("failed to read alignment header")

    def __init__(out self, text: String) raises:
        """Parse and own a NUL-terminated SAM header text buffer."""
        var text_c = text
        self._ptr = sam_hdr_parse(UInt(text.byte_length()), _cstr(text_c))
        if not self._ptr:
            raise Error("failed to parse alignment header")

    def __del__(deinit self):
        """Destroy the owned header if present."""
        if self._ptr:
            sam_hdr_destroy(self._ptr.value())

    def ptr(self) -> UnsafePointer[sam_hdr_t, MutUntrackedOrigin]:
        """Return the owned raw header pointer. The caller must not free it."""
        return self._ptr.value()

    def dup(self) raises -> Self:
        """Return a deep duplicate that owns its own `sam_hdr_t*`."""
        var result = Self(
            sam_hdr_dup(
                self.ptr()
                .unsafe_mut_cast[False]()
                .unsafe_origin_cast[ImmutUntrackedOrigin]()
            )
        )
        if not result._ptr:
            raise Error("failed to duplicate alignment header")
        return result^

    def text_length(self) -> Int:
        """Return the stored header-text length as reported by HTSlib."""
        return Int(sam_hdr_length(self.ptr()))

    def n_ref(self) -> Int:
        """Return the number of reference sequences recorded in the header."""
        return Int(
            sam_hdr_nref(
                self.ptr()
                .unsafe_mut_cast[False]()
                .unsafe_origin_cast[ImmutUntrackedOrigin]()
            )
        )

    def name2tid(self, reference: String) raises -> Int32:
        """Resolve a NUL-terminated reference name to its numeric tid, or `-1`."""
        var reference_c = reference
        return Int32(sam_hdr_name2tid(self.ptr(), _cstr(reference_c)))

    def tid2name(
        self, tid: Int32
    ) -> Optional[UnsafePointer[c_char, ImmutUntrackedOrigin]]:
        """Return the borrowed HTSlib name pointer for `tid`, or `None` if absent."""
        return sam_hdr_tid2name(
            self.ptr()
            .unsafe_mut_cast[False]()
            .unsafe_origin_cast[ImmutUntrackedOrigin](),
            tid,
        )

    def tid2len(self, tid: Int32) -> Int64:
        """Return the declared reference length for `tid`."""
        return Int64(
            sam_hdr_tid2len(
                self.ptr()
                .unsafe_mut_cast[False]()
                .unsafe_origin_cast[ImmutUntrackedOrigin](),
                tid,
            )
        )


struct RawBamRecord(Movable):
    """
    RAII wrapper around a `bam1_t*`.

    This type owns one mutable BAM record buffer. `set1()` is the strict
    low-level population API that expects HTSlib-ready payload bytes. For test
    setup and simple callers, `set1_sam()` accepts SAM-style sequence and
    quality strings and normalizes the quality bytes before delegating.
    """
    var _ptr: Optional[UnsafePointer[bam1_t, MutUntrackedOrigin]]

    def __init__(out self) raises:
        """Allocate an empty BAM record via `bam_init1()`."""
        self._ptr = bam_init1()
        if not self._ptr:
            raise Error("failed to allocate alignment record")

    def __init__(out self, *, copy: RawBamRecord):
        """Allocate a deep copy of another owned BAM record."""
        self._ptr = bam_dup1(
            copy.ptr()
            .unsafe_mut_cast[False]()
            .unsafe_origin_cast[ImmutUntrackedOrigin]()
        )

    def __del__(deinit self):
        """Destroy the owned BAM record if present."""
        if self._ptr:
            bam_destroy1(self._ptr.value())

    def ptr(self) -> UnsafePointer[bam1_t, MutUntrackedOrigin]:
        """Return the owned raw BAM pointer. The caller must not free it."""
        return self._ptr.value()

    def dup(self) raises -> Self:
        """Return a new record with duplicated underlying BAM storage."""
        return Self(copy=self)

    def copy_from(mut self, read other: RawBamRecord) raises:
        """Copy another record's contents into this record's owned buffer."""
        self._ptr = _check_not_none(
            bam_copy1(
                self.ptr(),
                other.ptr()
                .unsafe_mut_cast[False]()
                .unsafe_origin_cast[ImmutUntrackedOrigin](),
            ),
            "failed to copy alignment record",
        )

    def set1(
        mut self,
        l_qname: UInt,
        qname: UnsafePointer[c_char, ImmutUntrackedOrigin],
        flag: UInt16,
        tid: Int32,
        pos: Int64,
        mapq: UInt8,
        n_cigar: UInt,
        cigar: Optional[UnsafePointer[uint32_t, ImmutUntrackedOrigin]],
        mtid: Int32,
        mpos: Int64,
        isize: Int64,
        l_seq: UInt,
        seq: UnsafePointer[c_char, ImmutUntrackedOrigin],
        qual: UnsafePointer[c_char, ImmutUntrackedOrigin],
        l_aux: UInt,
    ) raises:
        """
        Populate the record by forwarding directly to `bam_set1()`.

        Callers must provide HTSlib-compatible payloads:
        - `qname` must point to a NUL-terminated query name
        - `l_qname` must match HTSlib's length expectation for that name
        - `seq` and `qual` must already be encoded in the byte layout accepted
          by `bam_set1()`
        - this helper performs no normalization beyond error propagation
        """
        _check_code(
            Int(
                bam_set1(
                    self.ptr(),
                    l_qname,
                    qname,
                    flag,
                    tid,
                    pos,
                    mapq,
                    n_cigar,
                    cigar,
                    mtid,
                    mpos,
                    isize,
                    l_seq,
                    seq,
                    qual,
                    l_aux,
                )
            ),
            "failed to populate alignment record",
        )

    def set1_sam(
        mut self,
        qname: String,
        flag: UInt16,
        tid: Int32,
        pos: Int64,
        mapq: UInt8,
        n_cigar: UInt,
        cigar: Optional[UnsafePointer[uint32_t, ImmutUntrackedOrigin]],
        mtid: Int32,
        mpos: Int64,
        isize: Int64,
        seq: String,
        qual: String,
        l_aux: UInt = 0,
    ) raises:
        """
        Populate the record from SAM-style string inputs.

        `seq` is passed to HTSlib as a NUL-terminated sequence string.
        `qual` must contain SAM ASCII qualities with the `+33` offset; this
        method validates the bytes and converts them to raw Phred scores before
        calling `set1()`. Sequence and quality lengths must match exactly.
        """
        if seq.byte_length() != qual.byte_length():
            raise Error("sequence and quality strings must have the same length")

        var seq_len = Int(seq.byte_length())
        var seq_c = _terminated(seq)
        var qual_c = _terminated(qual)
        var qual_bytes = _bytes_with_nul(qual_c)
        var encoded_qual = _OwnedByteBuffer(seq_len)

        for i in range(seq_len):
            var phred_ascii = qual_bytes[i]
            if phred_ascii < UInt8(33):
                raise Error("quality string must use SAM ASCII with +33 offset")
            encoded_qual.ptr().value()[i] = phred_ascii - UInt8(33)

        var qname_c = _terminated(qname)
        self.set1(
            UInt(qname.byte_length()),
            _cstr(qname_c),
            flag,
            tid,
            pos,
            mapq,
            n_cigar,
            cigar,
            mtid,
            mpos,
            isize,
            UInt(seq_len),
            _cstr(seq_c),
            encoded_qual.ptr()
            .value()
            .unsafe_mut_cast[False]()
            .unsafe_origin_cast[ImmutUntrackedOrigin]()
            .bitcast[c_char](),
            l_aux,
        )


struct RawHtsIndex(Movable):
    """
    RAII wrapper around an `hts_idx_t*`.

    Constructors that take a file path load an existing on-disk index and own
    the returned pointer. `build()` is a convenience entry point for index
    creation and does not retain any in-memory index state.
    """
    var _ptr: Optional[UnsafePointer[hts_idx_t, MutUntrackedOrigin]]

    def __init__(
        out self, ptr: Optional[UnsafePointer[hts_idx_t, MutUntrackedOrigin]]
    ):
        """Adopt ownership of an existing HTSlib index pointer."""
        self._ptr = ptr

    def __init__(out self, file: RawSamFile, path: String) raises:
        """Load the default index associated with `path` for `file`."""
        var path_c = path
        self._ptr = sam_index_load(file.ptr(), _cstr(path_c))
        if not self._ptr:
            raise Error("failed to load alignment index")

    def __init__(
        out self, file: RawSamFile, path: String, index_path: String
    ) raises:
        """Load an index from an explicit on-disk index path."""
        var path_c = path
        var index_path_c = index_path
        self._ptr = sam_index_load2(
            file.ptr(), _cstr(path_c), _cstr(index_path_c)
        )
        if not self._ptr:
            raise Error("failed to load alignment index")

    def __init__(
        out self,
        file: RawSamFile,
        path: String,
        index_path: String,
        flags: Int,
    ) raises:
        """Load an index using `sam_index_load3()` with explicit loader flags."""
        var path_c = path
        var index_path_c = index_path
        self._ptr = sam_index_load3(
            file.ptr(), _cstr(path_c), _cstr(index_path_c), Int32(flags)
        )
        if not self._ptr:
            raise Error("failed to load alignment index")

    def __del__(deinit self):
        """Destroy the owned index if present."""
        if self._ptr:
            hts_idx_destroy(self._ptr.value())

    def ptr(self) -> UnsafePointer[hts_idx_t, MutUntrackedOrigin]:
        """Return the owned raw index pointer. The caller must not free it."""
        return self._ptr.value()

    @staticmethod
    def build(
        path: String,
        index_path: Optional[String] = None,
        min_shift: Int = 0,
        threads: Int = 0,
    ) raises:
        """
        Build an index on disk for the alignment file at `path`.

        When `index_path` is omitted HTSlib chooses the default index location.
        `min_shift` and `threads` are forwarded directly to `sam_index_build3()`.
        """
        if index_path:
            var path_c = path
            var index_path_c = index_path.value()
            _check_code(
                Int(
                    sam_index_build3(
                        _cstr(path_c),
                        _cstr(index_path_c),
                        Int32(min_shift),
                        Int32(threads),
                    )
                ),
                "failed to build alignment index",
            )
            return
        var path_c = path
        _check_code(
            Int(
                sam_index_build3(
                    _cstr(path_c), None, Int32(min_shift), Int32(threads)
                )
            ),
            "failed to build alignment index",
        )


struct RawHtsIterator(Movable):
    """
    RAII wrapper around an `hts_itr_t*`.

    Iterators can be constructed either from a numeric `(tid, beg, end)` range
    or from a parsed region string plus header. The iterator owns the HTSlib
    iterator object and exposes `next()` with HTSlib-style status codes.
    """
    var _ptr: Optional[UnsafePointer[hts_itr_t, MutUntrackedOrigin]]

    def __init__(
        out self, ptr: Optional[UnsafePointer[hts_itr_t, MutUntrackedOrigin]]
    ):
        """Adopt ownership of an existing iterator pointer."""
        self._ptr = ptr

    def __init__(
        out self, index: RawHtsIndex, tid: Int32, beg: Int64, end: Int64
    ) raises:
        """Create an iterator over a numeric reference interval."""
        self._ptr = sam_itr_queryi(
            index.ptr()
            .unsafe_mut_cast[False]()
            .unsafe_origin_cast[ImmutUntrackedOrigin](),
            tid,
            beg,
            end,
        )
        if not self._ptr:
            raise Error("failed to create alignment iterator")

    def __init__(
        out self, index: RawHtsIndex, header: RawSamHeader, region: String
    ) raises:
        """Create an iterator from a NUL-terminated region string such as `chr1:1-100`."""
        var region_c = region
        self._ptr = sam_itr_querys(
            index.ptr()
            .unsafe_mut_cast[False]()
            .unsafe_origin_cast[ImmutUntrackedOrigin](),
            header.ptr(),
            _cstr(region_c),
        )
        if not self._ptr:
            raise Error("failed to create alignment iterator")

    def __del__(deinit self):
        """Destroy the owned iterator if present."""
        if self._ptr:
            hts_itr_destroy(self._ptr.value())

    def ptr(self) -> UnsafePointer[hts_itr_t, MutUntrackedOrigin]:
        """Return the owned raw iterator pointer. The caller must not free it."""
        return self._ptr.value()

    def next(self, file: RawSamFile, mut record: RawBamRecord) -> Int:
        """
        Advance the iterator and populate `record` in place.

        Return semantics mirror HTSlib:
        - non-negative: a record was produced
        - `-1`: end of iterator
        - `< -1`: lower-level read or iterator failure
        """
        return Int(
            hts_itr_next(
                hts_get_bgzfp(file.ptr()),
                self.ptr(),
                record.ptr().bitcast[NoneType](),
                file.ptr().bitcast[NoneType](),
            )
        )
