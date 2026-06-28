from hts_mojo._ffi import (
    htsFile,
    hts_close,
    hts_open,
    hts_set_fai_filename,
    hts_set_threads,
    hts_idx_destroy,
    hts_idx_t,
    hts_itr_destroy,
    hts_itr_t,
    hts_mojo_sam_itr_next,
    sam_hdr_read,
    sam_hdr_write,
    sam_index_build3,
    sam_index_load,
    sam_index_load2,
    sam_index_load3,
    sam_itr_queryi,
    sam_itr_querys,
    sam_read1,
    sam_write1,
)
from hts_mojo.bam._common import (
    _check_i32,
    _check_nonnegative,
    _check_nonnegative_i32,
    _check_zero,
    _cstr_ptr,
)
from hts_mojo.bam.header import RawSamHeader
from hts_mojo.bam.record import RawBamRecord


struct RawAlignmentFile(Movable):
    var _ptr: Optional[UnsafePointer[htsFile, MutUntrackedOrigin]]

    def __init__(out self, path: String, mode: String) raises:
        var path_c = path
        var mode_c = mode
        self._ptr = hts_open(_cstr_ptr(path_c), _cstr_ptr(mode_c))
        if not self._ptr:
            raise Error("failed to open alignment file")

    def __del__(deinit self):
        if self._ptr:
            _ = hts_close(self._ptr.value())

    def ptr(self) raises -> UnsafePointer[htsFile, MutUntrackedOrigin]:
        if not self._ptr:
            raise Error("alignment file is closed")
        return self._ptr.value()

    def unsafe_ptr_unchecked(
        self,
    ) -> UnsafePointer[htsFile, MutUntrackedOrigin]:
        return self._ptr.value()

    def close(mut self) raises:
        if self._ptr:
            _check_zero(
                Int(hts_close(self._ptr.value())), "failed to close file"
            )
            self._ptr = None

    def set_threads(mut self, n_threads: Int) raises:
        var n_threads_i32 = _check_nonnegative_i32(
            n_threads, "thread count out of range"
        )
        _check_zero(
            Int(hts_set_threads(self.ptr(), n_threads_i32)),
            "failed to set alignment threads",
        )

    def set_reference(mut self, reference_path: String) raises:
        var reference_path_c = reference_path
        _check_zero(
            Int(hts_set_fai_filename(self.ptr(), _cstr_ptr(reference_path_c))),
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
    ) raises -> Int:
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


@fieldwise_init
struct Region(Copyable, Movable):
    var contig: String
    var start0: Int64
    var end0: Int64

    @staticmethod
    def zero_based(contig: String, start0: Int64, end0: Int64) -> Self:
        return Self(contig, start0, end0)

    @staticmethod
    def one_based_closed(
        contig: String, start1: Int64, end1: Int64
    ) raises -> Self:
        if start1 <= 0:
            raise Error("1-based region start must be positive")
        if end1 < start1:
            raise Error("1-based region end must be >= start")
        return Self(contig, start1 - 1, end1)


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

    def unsafe_ptr_unchecked(self) -> UnsafePointer[hts_itr_t, MutUntrackedOrigin]:
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
