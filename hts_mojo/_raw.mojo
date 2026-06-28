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
    hts_idx_destroy,
    hts_idx_t,
    hts_itr_destroy,
    hts_itr_t,
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
    sam_itr_next,
    sam_itr_queryi,
    sam_itr_querys,
    sam_parse_region,
    sam_read1,
    sam_write1,
    uint8_t,
    uint32_t,
)


def _cstr(s: String) raises -> UnsafePointer[c_char, ImmutUntrackedOrigin]:
    return (
        CStringSlice(s)
        .as_bytes_with_nul()
        .unsafe_ptr()
        .unsafe_origin_cast[ImmutUntrackedOrigin]()
        .bitcast[c_char]()
    )


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
    var _ptr: Optional[UnsafePointer[htsFile, MutUntrackedOrigin]]

    @staticmethod
    def open(path: String, mode: String) raises -> Self:
        var result = Self()
        result._ptr = hts_open(_cstr(path), _cstr(mode))
        if not result._ptr:
            raise Error("failed to open alignment file")
        return result^

    def __init__(out self, path: String, mode: String) raises:
        self._ptr = hts_open(_cstr(path), _cstr(mode))
        if not self._ptr:
            raise Error("failed to open alignment file")

    def __init__(out self):
        self._ptr = None

    def __del__(deinit self):
        if self._ptr:
            _ = hts_close(self._ptr.value())

    def ptr(self) -> UnsafePointer[htsFile, MutUntrackedOrigin]:
        return self._ptr.value()

    def set_threads(mut self, n_threads: Int) raises:
        _check_code(
            Int(hts_set_threads(self.ptr(), Int32(n_threads))),
            "failed to set alignment threads",
        )

    def set_reference(mut self, reference_path: String) raises:
        _check_code(
            Int(hts_set_fai_filename(self.ptr(), _cstr(reference_path))),
            "failed to set reference FASTA",
        )

    def close(mut self) raises:
        if self._ptr:
            _check_code(
                Int(hts_close(self._ptr.value())), "failed to close file"
            )
            self._ptr = None


struct RawSamHeader(Movable):
    var _ptr: Optional[UnsafePointer[sam_hdr_t, MutUntrackedOrigin]]

    def __init__(
        out self, ptr: Optional[UnsafePointer[sam_hdr_t, MutUntrackedOrigin]]
    ):
        self._ptr = ptr

    def __init__(out self, file: RawSamFile) raises:
        self._ptr = sam_hdr_read(file.ptr())
        if not self._ptr:
            raise Error("failed to read alignment header")

    def __init__(out self, text: String) raises:
        self._ptr = sam_hdr_parse(UInt(text.byte_length()), _cstr(text))
        if not self._ptr:
            raise Error("failed to parse alignment header")

    @staticmethod
    def empty() raises -> Self:
        var result = Self(sam_hdr_init())
        if not result._ptr:
            raise Error("failed to allocate alignment header")
        return result^

    def __del__(deinit self):
        if self._ptr:
            sam_hdr_destroy(self._ptr.value())

    def ptr(self) -> UnsafePointer[sam_hdr_t, MutUntrackedOrigin]:
        return self._ptr.value()

    def dup(self) raises -> Self:
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
        return Int(sam_hdr_length(self.ptr()))

    def n_ref(self) -> Int:
        return Int(
            sam_hdr_nref(
                self.ptr()
                .unsafe_mut_cast[False]()
                .unsafe_origin_cast[ImmutUntrackedOrigin]()
            )
        )

    def name2tid(self, reference: String) raises -> Int32:
        return Int32(sam_hdr_name2tid(self.ptr(), _cstr(reference)))

    def tid2name(
        self, tid: Int32
    ) -> Optional[UnsafePointer[c_char, ImmutUntrackedOrigin]]:
        return sam_hdr_tid2name(
            self.ptr()
            .unsafe_mut_cast[False]()
            .unsafe_origin_cast[ImmutUntrackedOrigin](),
            tid,
        )

    def tid2len(self, tid: Int32) -> Int64:
        return Int64(
            sam_hdr_tid2len(
                self.ptr()
                .unsafe_mut_cast[False]()
                .unsafe_origin_cast[ImmutUntrackedOrigin](),
                tid,
            )
        )


struct RawBamRecord(Movable):
    var _ptr: Optional[UnsafePointer[bam1_t, MutUntrackedOrigin]]

    def __init__(out self) raises:
        self._ptr = bam_init1()
        if not self._ptr:
            raise Error("failed to allocate alignment record")

    def __init__(out self, *, copy: RawBamRecord):
        self._ptr = bam_dup1(
            copy.ptr()
            .unsafe_mut_cast[False]()
            .unsafe_origin_cast[ImmutUntrackedOrigin]()
        )

    def __del__(deinit self):
        if self._ptr:
            bam_destroy1(self._ptr.value())

    def ptr(self) -> UnsafePointer[bam1_t, MutUntrackedOrigin]:
        return self._ptr.value()

    def dup(self) raises -> Self:
        return Self(copy=self)^

    def copy_from(mut self, read other: RawBamRecord) raises:
        _check_not_none(
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


struct RawHtsIndex(Movable):
    var _ptr: Optional[UnsafePointer[hts_idx_t, MutUntrackedOrigin]]

    def __init__(
        out self, ptr: Optional[UnsafePointer[hts_idx_t, MutUntrackedOrigin]]
    ):
        self._ptr = ptr

    def __init__(out self, file: RawSamFile, path: String) raises:
        self._ptr = sam_index_load(file.ptr(), _cstr(path))
        if not self._ptr:
            raise Error("failed to load alignment index")

    def __init__(
        out self, file: RawSamFile, path: String, index_path: String
    ) raises:
        self._ptr = sam_index_load2(file.ptr(), _cstr(path), _cstr(index_path))
        if not self._ptr:
            raise Error("failed to load alignment index")

    def __init__(
        out self,
        file: RawSamFile,
        path: String,
        index_path: String,
        flags: Int,
    ) raises:
        self._ptr = sam_index_load3(
            file.ptr(), _cstr(path), _cstr(index_path), flags
        )
        if not self._ptr:
            raise Error("failed to load alignment index")

    def __del__(deinit self):
        if self._ptr:
            hts_idx_destroy(self._ptr.value())

    def ptr(self) -> UnsafePointer[hts_idx_t, MutUntrackedOrigin]:
        return self._ptr.value()

    @staticmethod
    def build(
        path: String,
        index_path: Optional[String] = None,
        min_shift: Int = 0,
        threads: Int = 0,
    ) raises:
        if index_path:
            _check_code(
                Int(
                    sam_index_build3(
                        _cstr(path),
                        _cstr(index_path.value()),
                        min_shift,
                        threads,
                    )
                ),
                "failed to build alignment index",
            )
            return
        _check_code(
            Int(sam_index_build3(_cstr(path), None, min_shift, threads)),
            "failed to build alignment index",
        )


struct RawHtsIterator(Movable):
    var _ptr: Optional[UnsafePointer[hts_itr_t, MutUntrackedOrigin]]

    def __init__(
        out self, ptr: Optional[UnsafePointer[hts_itr_t, MutUntrackedOrigin]]
    ):
        self._ptr = ptr

    def __init__(
        out self, index: RawHtsIndex, tid: Int32, beg: Int64, end: Int64
    ) raises:
        self._ptr = sam_itr_queryi(index.ptr(), tid, beg, end)
        if not self._ptr:
            raise Error("failed to create alignment iterator")

    def __init__(
        out self, index: RawHtsIndex, header: RawSamHeader, region: String
    ) raises:
        self._ptr = sam_itr_querys(index.ptr(), header.ptr(), _cstr(region))
        if not self._ptr:
            raise Error("failed to create alignment iterator")

    def __del__(deinit self):
        if self._ptr:
            hts_itr_destroy(self._ptr.value())

    def ptr(self) -> UnsafePointer[hts_itr_t, MutUntrackedOrigin]:
        return self._ptr.value()

    def next(self, file: RawSamFile, mut record: RawBamRecord) -> Int:
        return Int(sam_itr_next(file.ptr(), self.ptr(), record.ptr()))
