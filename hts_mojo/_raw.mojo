from std.ffi import CStringSlice, c_char
from hts_mojo.bam._common import (
    _cstr_ptr,
    _check_sam_text_ascii,
    _terminated,
    _check_zero,
    _check_nonnegative,
    _check_nonnegative_i32,
    _check_ptr,
    _aux_tag,
    _aux_tag_cstr,
    _OwnedByteBuffer,
    _check_i32,
    _bytes_with_nul_ptr,
    _ensure_nul
)

from hts_mojo._ffi import (
    bam1_core_t,
    bam1_t,
    bam_aux2A,
    bam_aux2f,
    bam_aux2i,
    bam_aux2Z,
    bam_auxB2f,
    bam_auxB2i,
    bam_auxB_len,
    hts_mojo_bam_aux_del_by_tag,
    hts_mojo_bam_aux_get,
    hts_mojo_bam_aux_update_float,
    hts_mojo_bam_aux_update_int,
    hts_mojo_bam_aux_update_str,
    bam_copy1,
    bam_destroy1,
    bam_dup1,
    bam_endpos,
    bam_init1,
    bam_set1,
    c_float,
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
        return Self.adopt(
            sam_hdr_parse(UInt(text.byte_length()), _cstr_ptr(text_c))
        )

    @staticmethod
    def adopt(
        ptr: Optional[UnsafePointer[sam_hdr_t, MutUntrackedOrigin]]
    ) raises -> Self:
        var result = Self(ptr)
        if not result._ptr:
            raise Error("failed to acquire alignment header")
        return result^

    def __del__(deinit self):
        if self._ptr:
            sam_hdr_destroy(self._ptr.value())

    def ptr(self) raises -> UnsafePointer[sam_hdr_t, MutUntrackedOrigin]:
        if not self._ptr:
            raise Error("alignment header is unavailable")
        return self._ptr.value()

    def unsafe_ptr_unchecked(
        self,
    ) -> UnsafePointer[sam_hdr_t, MutUntrackedOrigin]:
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
        return Int(sam_hdr_length(self.unsafe_ptr_unchecked()))

    def borrowed_text_ptr(
        self,
    ) -> Optional[UnsafePointer[c_char, ImmutUntrackedOrigin]]:
        return sam_hdr_str(self.unsafe_ptr_unchecked())

    def n_ref(self) -> Int:
        return Int(
            sam_hdr_nref(
                self.unsafe_ptr_unchecked()
                .unsafe_mut_cast[False]()
                .unsafe_origin_cast[ImmutUntrackedOrigin]()
            )
        )

    def name2tid(self, reference: String) raises -> Int32:
        var reference_c = reference
        return Int32(sam_hdr_name2tid(self.ptr(), _cstr_ptr(reference_c)))

    def tid2name(
        self, tid: Int32
    ) -> Optional[UnsafePointer[c_char, ImmutUntrackedOrigin]]:
        return sam_hdr_tid2name(
            self.unsafe_ptr_unchecked()
            .unsafe_mut_cast[False]()
            .unsafe_origin_cast[ImmutUntrackedOrigin](),
            tid,
        )

    def tid2len(self, tid: Int32) -> Int64:
        return Int64(
            sam_hdr_tid2len(
                self.unsafe_ptr_unchecked()
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
                    _cstr_ptr(line_c),
                    UInt(line.byte_length()),
                )
            ),
            "failed to append header line",
        )
        # TODO: Add program-group helpers once Mojo can bind HTSlib vararg entry
        # points such as sam_hdr_add_pg(...).



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
            sam_index_load(file.ptr(), _cstr_ptr(path_c)),
            "failed to load alignment index",
        )

    @staticmethod
    def load_at(
        file: RawAlignmentFile, path: String, index_path: String
    ) raises -> Self:
        var path_c = path
        var index_path_c = index_path
        return Self._adopt(
            sam_index_load2(
                file.ptr(), _cstr_ptr(path_c), _cstr_ptr(index_path_c)
            ),
            "failed to load alignment index",
        )

    @staticmethod
    def load_with_flags(
        file: RawAlignmentFile, path: String, index_path: String, flags: Int
    ) raises -> Self:
        var path_c = path
        var index_path_c = index_path
        var flags_i32 = _check_i32(flags, "index load flags out of range")
        return Self._adopt(
            sam_index_load3(
                file.ptr(),
                _cstr_ptr(path_c),
                _cstr_ptr(index_path_c),
                flags_i32,
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
        var min_shift_i32 = _check_nonnegative_i32(
            min_shift, "min_shift out of range"
        )
        var threads_i32 = _check_nonnegative_i32(
            threads, "thread count out of range"
        )
        if index_path:
            var index_path_c = index_path.value()
            _check_zero(
                Int(
                    sam_index_build3(
                        _cstr_ptr(path_c),
                        _cstr_ptr(index_path_c),
                        min_shift_i32,
                        threads_i32,
                    )
                ),
                "failed to build alignment index",
            )
            return

        _check_zero(
            Int(
                sam_index_build3(
                    _cstr_ptr(path_c), None, min_shift_i32, threads_i32
                )
            ),
            "failed to build alignment index",
        )

    def __del__(deinit self):
        if self._ptr:
            hts_idx_destroy(self._ptr.value())

    def ptr(self) raises -> UnsafePointer[hts_idx_t, MutUntrackedOrigin]:
        if not self._ptr:
            raise Error("alignment index is unavailable")
        return self._ptr.value()

    def unsafe_ptr_unchecked(
        self,
    ) -> UnsafePointer[hts_idx_t, MutUntrackedOrigin]:
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
        if tid < -1:
            raise Error("reference id out of range")
        if beg0 < 0:
            raise Error("region start must be non-negative")
        if end0 < beg0:
            raise Error("region end must be >= start")
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
                _cstr_ptr(region_c),
            )
        )

    def __del__(deinit self):
        if self._ptr:
            hts_itr_destroy(self._ptr.value())

    def ptr(self) raises -> UnsafePointer[hts_itr_t, MutUntrackedOrigin]:
        if not self._ptr:
            raise Error("alignment iterator is unavailable")
        return self._ptr.value()

    def unsafe_ptr_unchecked(
        self,
    ) -> UnsafePointer[hts_itr_t, MutUntrackedOrigin]:
        return self._ptr.value()

    def next_status(
        mut self, mut file: RawAlignmentFile, mut record: RawBamRecord
    ) raises -> Int:
        return Int(hts_mojo_sam_itr_next(file.ptr(), self.ptr(), record.ptr()))

    @staticmethod
    def _adopt(
        ptr: Optional[UnsafePointer[hts_itr_t, MutUntrackedOrigin]]
    ) raises -> Self:
        var result = Self(ptr)
        if not result._ptr:
            raise Error("failed to create alignment iterator")
        return result^
