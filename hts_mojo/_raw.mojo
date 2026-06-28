from std.ffi import CStringSlice, c_char

from hts_mojo._ffi import (
    bam1_core_t,
    bam1_t,
    bam_copy1,
    bam_destroy1,
    bam_dup1,
    bam_endpos,
    bam_init1,
    bam_set1,
    htsFile,
    hts_close,
    hts_free,
    hts_idx_destroy,
    hts_idx_t,
    hts_itr_destroy,
    hts_itr_t,
    hts_mojo_sam_itr_next,
    hts_open,
    hts_set_fai_filename,
    hts_set_threads,
    malloc,
    sam_hdr_add_lines,
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
    sam_read1,
    sam_write1,
    uint32_t,
)


def _ensure_nul(mut s: String):
    if s.byte_length() == 0:
        s += "\0"
        return
    if String(s[byte=s.byte_length() - 1]) != "\0":
        s += "\0"


def _terminated(s: String) -> String:
    var result = s
    _ensure_nul(result)
    return result^


def _cstr(mut s: String) raises -> UnsafePointer[c_char, ImmutUntrackedOrigin]:
    _ensure_nul(s)
    return (
        CStringSlice(s)
        .as_bytes_with_nul()
        .unsafe_ptr()
        .unsafe_origin_cast[ImmutUntrackedOrigin]()
        .bitcast[c_char]()
    )


def _bytes_with_nul(
    mut s: String,
) raises -> UnsafePointer[UInt8, ImmutUntrackedOrigin]:
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

    def __init__(out self, size: Int) raises:
        if size <= 0:
            self._ptr = None
            return
        var mem = malloc(UInt(size))
        if not mem:
            raise Error("failed to allocate temporary BAM buffer")
        self._ptr = rebind[Optional[UnsafePointer[UInt8, MutUntrackedOrigin]]](
            mem
        )
        for i in range(size):
            self._ptr.value()[i] = UInt8(0)

    def __del__(deinit self):
        if self._ptr:
            hts_free(self._ptr.value().bitcast[NoneType]())

    def ptr(self) -> Optional[UnsafePointer[UInt8, MutUntrackedOrigin]]:
        return self._ptr


def _check_zero(code: Int, context: String) raises:
    if code != 0:
        raise Error(context)


def _check_nonnegative(code: Int, context: String) raises -> Int:
    if code < 0:
        raise Error(context)
    return code


def _check_ptr[
    T: Movable & Copyable
](value: Optional[T], context: String) raises -> T:
    if not value:
        raise Error(context)
    return value.value().copy()


struct RawAlignmentFile(Movable):
    var _ptr: Optional[UnsafePointer[htsFile, MutUntrackedOrigin]]

    def __init__(out self, path: String, mode: String) raises:
        var path_c = path
        var mode_c = mode
        self._ptr = hts_open(_cstr(path_c), _cstr(mode_c))
        if not self._ptr:
            raise Error("failed to open alignment file")

    def __del__(deinit self):
        if self._ptr:
            _ = hts_close(self._ptr.value())

    def ptr(self) -> UnsafePointer[htsFile, MutUntrackedOrigin]:
        return self._ptr.value()

    def close(mut self) raises:
        if self._ptr:
            _check_zero(Int(hts_close(self._ptr.value())), "failed to close file")
            self._ptr = None

    def set_threads(mut self, n_threads: Int) raises:
        _check_zero(
            Int(hts_set_threads(self.ptr(), Int32(n_threads))),
            "failed to set alignment threads",
        )

    def set_reference(mut self, reference_path: String) raises:
        var reference_path_c = reference_path
        _check_zero(
            Int(hts_set_fai_filename(self.ptr(), _cstr(reference_path_c))),
            "failed to set reference FASTA",
        )
        # TODO: Expose richer file-format option plumbing here when Mojo can call
        # HTSlib vararg APIs such as hts_set_opt(...) safely.

    def read_header(mut self) raises -> RawSamHeader:
        return RawSamHeader.adopt(sam_hdr_read(self.ptr()))

    def write_header(mut self, header: RawSamHeader) raises:
        _check_zero(
            Int(
                sam_hdr_write(
                    self.ptr(),
                    header.ptr()
                    .unsafe_mut_cast[False]()
                    .unsafe_origin_cast[ImmutUntrackedOrigin](),
                )
            ),
            "failed to write alignment header",
        )

    def read1_status(
        mut self, header: RawSamHeader, mut record: RawBamRecord
    ) -> Int:
        return Int(sam_read1(self.ptr(), header.ptr(), record.ptr()))

    def write1(mut self, header: RawSamHeader, record: RawBamRecord) raises:
        _ = _check_nonnegative(
            Int(
                sam_write1(
                    self.ptr(),
                    header.ptr()
                    .unsafe_mut_cast[False]()
                    .unsafe_origin_cast[ImmutUntrackedOrigin](),
                    record.ptr()
                    .unsafe_mut_cast[False]()
                    .unsafe_origin_cast[ImmutUntrackedOrigin](),
                )
            ),
            "failed to write alignment record",
        )


struct RawSamHeader(Movable):
    var _ptr: Optional[UnsafePointer[sam_hdr_t, MutUntrackedOrigin]]

    def __init__(out self) raises:
        self._ptr = sam_hdr_init()
        if not self._ptr:
            raise Error("failed to allocate alignment header")

    def __init__(
        out self, ptr: Optional[UnsafePointer[sam_hdr_t, MutUntrackedOrigin]]
    ):
        self._ptr = ptr

    @staticmethod
    def parse(text: String) raises -> Self:
        var text_c = text
        return Self.adopt(sam_hdr_parse(UInt(text.byte_length()), _cstr(text_c)))

    @staticmethod
    def adopt(ptr: Optional[UnsafePointer[sam_hdr_t, MutUntrackedOrigin]]) raises -> Self:
        var result = Self(ptr)
        if not result._ptr:
            raise Error("failed to acquire alignment header")
        return result^

    def __del__(deinit self):
        if self._ptr:
            sam_hdr_destroy(self._ptr.value())

    def ptr(self) -> UnsafePointer[sam_hdr_t, MutUntrackedOrigin]:
        return self._ptr.value()

    def dup(self) raises -> Self:
        return Self.adopt(
            sam_hdr_dup(
                self.ptr()
                .unsafe_mut_cast[False]()
                .unsafe_origin_cast[ImmutUntrackedOrigin]()
            )
        )

    def text_length(self) -> Int:
        return Int(sam_hdr_length(self.ptr()))

    def borrowed_text_ptr(
        self,
    ) -> Optional[UnsafePointer[c_char, ImmutUntrackedOrigin]]:
        return sam_hdr_str(self.ptr())

    def n_ref(self) -> Int:
        return Int(
            sam_hdr_nref(
                self.ptr()
                .unsafe_mut_cast[False]()
                .unsafe_origin_cast[ImmutUntrackedOrigin]()
            )
        )

    def name2tid(self, reference: String) raises -> Int32:
        var reference_c = reference
        return Int32(sam_hdr_name2tid(self.ptr(), _cstr(reference_c)))

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

    def write_to(mut self, mut file: RawAlignmentFile) raises:
        file.write_header(self)

    def append_line(mut self, line: String) raises:
        var line_c = line
        _check_zero(
            Int(
                sam_hdr_add_lines(
                    self.ptr(),
                    _cstr(line_c),
                    UInt(line.byte_length()),
                )
            ),
            "failed to append header line",
        )
        # TODO: Add program-group helpers once Mojo can bind HTSlib vararg entry
        # points such as sam_hdr_add_pg(...).


struct RawBamRecord(Movable):
    var _ptr: Optional[UnsafePointer[bam1_t, MutUntrackedOrigin]]

    def __init__(out self) raises:
        self._ptr = bam_init1()
        if not self._ptr:
            raise Error("failed to allocate alignment record")

    def __del__(deinit self):
        if self._ptr:
            bam_destroy1(self._ptr.value())

    def ptr(self) -> UnsafePointer[bam1_t, MutUntrackedOrigin]:
        return self._ptr.value()

    def dup(self) raises -> Self:
        return Self._adopt_copy(
            bam_dup1(
                self.ptr()
                .unsafe_mut_cast[False]()
                .unsafe_origin_cast[ImmutUntrackedOrigin]()
            )
        )

    def copy_from(mut self, read other: RawBamRecord) raises:
        self._ptr = _check_ptr(
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
        _ = _check_nonnegative(
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

    def set1_from_sam_fields(
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
            UInt(qname_c.byte_length()),
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

    def raw_core_ptr(self) -> UnsafePointer[bam1_core_t, MutUntrackedOrigin]:
        return UnsafePointer(to=self.ptr()[].core).unsafe_origin_cast[
            MutUntrackedOrigin
        ]()

    def tid(self) -> Int32:
        return self.ptr()[].core.tid

    def pos0(self) -> Int64:
        return self.ptr()[].core.pos

    def end_pos0(self) -> Int64:
        return Int64(
            bam_endpos(
                self.ptr()
                .unsafe_mut_cast[False]()
                .unsafe_origin_cast[ImmutUntrackedOrigin]()
            )
        )

    def flag(self) -> UInt16:
        return self.ptr()[].core.flag

    def mapq(self) -> UInt8:
        return self.ptr()[].core.qual

    def mate_tid(self) -> Int32:
        return self.ptr()[].core.mtid

    def mate_pos0(self) -> Int64:
        return self.ptr()[].core.mpos

    def insert_size(self) -> Int64:
        return self.ptr()[].core.isize

    def l_seq(self) -> Int:
        return Int(self.ptr()[].core.l_qseq)

    def n_cigar(self) -> Int:
        return Int(self.ptr()[].core.n_cigar)

    def borrowed_qname_ptr(self) -> UnsafePointer[c_char, ImmutUntrackedOrigin]:
        return self._data_ptr().value().unsafe_mut_cast[False]().unsafe_origin_cast[
            ImmutUntrackedOrigin
        ]().bitcast[c_char]()

    def borrowed_cigar_ptr(
        self,
    ) -> Optional[UnsafePointer[uint32_t, ImmutUntrackedOrigin]]:
        if self.n_cigar() == 0 or not self._data_ptr():
            return None
        return self._offset_ptr(self._qname_bytes()).value().bitcast[uint32_t]()

    def borrowed_seq_ptr(
        self,
    ) -> Optional[UnsafePointer[UInt8, ImmutUntrackedOrigin]]:
        if self.l_seq() == 0 or not self._data_ptr():
            return None
        return self._offset_ptr(self._seq_offset())

    def borrowed_qual_ptr(
        self,
    ) -> Optional[UnsafePointer[UInt8, ImmutUntrackedOrigin]]:
        if self.l_seq() == 0 or not self._data_ptr():
            return None
        return self._offset_ptr(self._qual_offset())

    def borrowed_aux_ptr(
        self,
    ) -> Optional[UnsafePointer[UInt8, ImmutUntrackedOrigin]]:
        if self.aux_len() == 0 or not self._data_ptr():
            return None
        return self._offset_ptr(self._aux_offset())

    def aux_len(self) -> Int:
        var length = self._data_len() - self._aux_offset()
        if length < 0:
            return 0
        return length

    def get_base4(self, i: Int) raises -> UInt8:
        if i < 0 or i >= self.l_seq():
            raise Error("base index out of range")
        var seq = _check_ptr(self.borrowed_seq_ptr(), "missing sequence data")
        var packed = seq[i >> 1]
        if (i & 1) == 0:
            return (packed >> 4) & UInt8(0xF)
        return packed & UInt8(0xF)

    def get_qual(self, i: Int) raises -> UInt8:
        if i < 0 or i >= self.l_seq():
            raise Error("quality index out of range")
        var qual = _check_ptr(self.borrowed_qual_ptr(), "missing quality data")
        return qual[i]

    @staticmethod
    def _adopt_copy(ptr: Optional[UnsafePointer[bam1_t, MutUntrackedOrigin]]) raises -> Self:
        var result = Self()
        if result._ptr:
            bam_destroy1(result._ptr.value())
        result._ptr = _check_ptr(ptr, "failed to duplicate alignment record")
        return result^

    def _data_ptr(self) -> Optional[UnsafePointer[UInt8, MutUntrackedOrigin]]:
        return self.ptr()[].data

    def _data_len(self) -> Int:
        return Int(self.ptr()[].l_data)

    def _qname_bytes(self) -> Int:
        return Int(self.ptr()[].core.l_qname)

    def _cigar_bytes(self) -> Int:
        return self.n_cigar() * 4

    def _seq_offset(self) -> Int:
        return self._qname_bytes() + self._cigar_bytes()

    def _seq_bytes(self) -> Int:
        return (self.l_seq() + 1) >> 1

    def _qual_offset(self) -> Int:
        return self._seq_offset() + self._seq_bytes()

    def _aux_offset(self) -> Int:
        return self._qual_offset() + self.l_seq()

    def _offset_ptr(
        self, offset: Int
    ) -> Optional[UnsafePointer[UInt8, ImmutUntrackedOrigin]]:
        if not self._data_ptr():
            return None
        return (
            self._data_ptr()
            .value()
            .unsafe_mut_cast[False]()
            .unsafe_origin_cast[ImmutUntrackedOrigin]()
            + offset
        )


struct RawHtsIndex(Movable):
    var _ptr: Optional[UnsafePointer[hts_idx_t, MutUntrackedOrigin]]

    def __init__(
        out self, ptr: Optional[UnsafePointer[hts_idx_t, MutUntrackedOrigin]]
    ):
        self._ptr = ptr

    @staticmethod
    def load(file: RawAlignmentFile, path: String) raises -> Self:
        var path_c = path
        return Self._adopt(
            sam_index_load(file.ptr(), _cstr(path_c)),
            "failed to load alignment index",
        )

    @staticmethod
    def load_at(
        file: RawAlignmentFile, path: String, index_path: String
    ) raises -> Self:
        var path_c = path
        var index_path_c = index_path
        return Self._adopt(
            sam_index_load2(file.ptr(), _cstr(path_c), _cstr(index_path_c)),
            "failed to load alignment index",
        )

    @staticmethod
    def load_with_flags(
        file: RawAlignmentFile, path: String, index_path: String, flags: Int
    ) raises -> Self:
        var path_c = path
        var index_path_c = index_path
        return Self._adopt(
            sam_index_load3(
                file.ptr(), _cstr(path_c), _cstr(index_path_c), Int32(flags)
            ),
            "failed to load alignment index",
        )

    @staticmethod
    def build(
        path: String,
        index_path: Optional[String] = None,
        min_shift: Int = 0,
        threads: Int = 0,
    ) raises:
        var path_c = path
        if index_path:
            var index_path_c = index_path.value()
            _check_zero(
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

        _check_zero(
            Int(
                sam_index_build3(
                    _cstr(path_c), None, Int32(min_shift), Int32(threads)
                )
            ),
            "failed to build alignment index",
        )

    def __del__(deinit self):
        if self._ptr:
            hts_idx_destroy(self._ptr.value())

    def ptr(self) -> UnsafePointer[hts_idx_t, MutUntrackedOrigin]:
        return self._ptr.value()

    @staticmethod
    def _adopt(
        ptr: Optional[UnsafePointer[hts_idx_t, MutUntrackedOrigin]],
        context: String,
    ) raises -> Self:
        var result = Self(ptr)
        if not result._ptr:
            raise Error(context)
        return result^


struct RawHtsIterator(Movable):
    var _ptr: Optional[UnsafePointer[hts_itr_t, MutUntrackedOrigin]]

    def __init__(
        out self, ptr: Optional[UnsafePointer[hts_itr_t, MutUntrackedOrigin]]
    ):
        self._ptr = ptr

    @staticmethod
    def queryi(
        index: RawHtsIndex, tid: Int32, beg0: Int64, end0: Int64
    ) raises -> Self:
        return Self._adopt(
            sam_itr_queryi(
                index.ptr()
                .unsafe_mut_cast[False]()
                .unsafe_origin_cast[ImmutUntrackedOrigin](),
                tid,
                beg0,
                end0,
            )
        )

    @staticmethod
    def querys(
        index: RawHtsIndex, header: RawSamHeader, region: String
    ) raises -> Self:
        var region_c = region
        return Self._adopt(
            sam_itr_querys(
                index.ptr()
                .unsafe_mut_cast[False]()
                .unsafe_origin_cast[ImmutUntrackedOrigin](),
                header.ptr(),
                _cstr(region_c),
            )
        )

    def __del__(deinit self):
        if self._ptr:
            hts_itr_destroy(self._ptr.value())

    def ptr(self) -> UnsafePointer[hts_itr_t, MutUntrackedOrigin]:
        return self._ptr.value()

    def next_status(
        mut self, mut file: RawAlignmentFile, mut record: RawBamRecord
    ) -> Int:
        return Int(hts_mojo_sam_itr_next(file.ptr(), self.ptr(), record.ptr()))

    @staticmethod
    def _adopt(ptr: Optional[UnsafePointer[hts_itr_t, MutUntrackedOrigin]]) raises -> Self:
        var result = Self(ptr)
        if not result._ptr:
            raise Error("failed to create alignment iterator")
        return result^
