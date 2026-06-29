from std.sys.info import size_of

from hts_mojo._ffi import (
    bam1_t,
    bam_dup1,
    bam_pileup1_t,
    bam_plp_auto,
    bam_plp_destroy,
    bam_plp_set_maxcnt,
    bam_plp_t,
    c_int,
    hts_free,
    hts_mojo_bam_plp_data_t,
    hts_mojo_bam_plp_init,
    malloc,
)
from hts_mojo.bam._common import _check_nonnegative_i32
from hts_mojo.bam.file import RawAlignmentFile, RawHtsIterator
from hts_mojo.bam.header import RawSamHeader
from hts_mojo.bam.record import RawBamRecord, Record


struct PileupAlignment(Copyable, ImplicitlyCopyable, Movable):
    var _ptr: UnsafePointer[bam_pileup1_t, ImmutUntrackedOrigin]

    def __init__(
        out self, ptr: UnsafePointer[bam_pileup1_t, ImmutUntrackedOrigin]
    ):
        self._ptr = ptr

    def query_position(self) -> Optional[Int32]:
        if self.is_deletion() or self.is_refskip():
            return None
        return Int32(self._ptr[].qpos)

    def indel(self) -> Int:
        return Int(self._ptr[].indel)

    def level(self) -> Int:
        return Int(self._ptr[].level)

    def cigar_index(self) -> Int:
        return Int(self._ptr[].cigar_ind)

    def is_deletion(self) -> Bool:
        return self._ptr[].is_del() != 0

    def is_head(self) -> Bool:
        return self._ptr[].is_head() != 0

    def is_tail(self) -> Bool:
        return self._ptr[].is_tail() != 0

    def is_refskip(self) -> Bool:
        return self._ptr[].is_refskip() != 0

    def record(self) raises -> Record:
        var src = self._ptr[].b
        if not src:
            raise Error("pileup alignment record is unavailable")
        var raw = RawBamRecord.adopt(
            bam_dup1(
                src.value()
                .unsafe_mut_cast[False]()
                .unsafe_origin_cast[ImmutUntrackedOrigin]()
            )
        )
        var result = Record()
        result._raw = raw^
        return result^


struct PileupAlignments(Movable):
    var _ptr: UnsafePointer[bam_pileup1_t, ImmutUntrackedOrigin]
    var _count: Int
    var _index: Int

    def __init__(
        out self,
        ptr: UnsafePointer[bam_pileup1_t, ImmutUntrackedOrigin],
        count: Int,
    ):
        self._ptr = ptr
        self._count = count
        self._index = 0

    def next(mut self) -> Optional[PileupAlignment]:
        if self._index >= self._count:
            return None
        var item = PileupAlignment(self._ptr + self._index)
        self._index += 1
        return item

    def pop_next(mut self) -> Optional[PileupAlignment]:
        return self.next()


struct Pileup(Copyable, ImplicitlyCopyable, Movable):
    var _tid: Int32
    var _pos0: Int64
    var _ptr: UnsafePointer[bam_pileup1_t, ImmutUntrackedOrigin]
    var _count: Int

    def __init__(
        out self,
        tid: Int32,
        pos0: Int64,
        ptr: UnsafePointer[bam_pileup1_t, ImmutUntrackedOrigin],
        count: Int,
    ):
        self._tid = tid
        self._pos0 = pos0
        self._ptr = ptr
        self._count = count

    def reference_id(self) -> Int32:
        return self._tid

    def position0(self) -> Int64:
        return self._pos0

    def position1(self) -> Int64:
        return self._pos0 + 1

    def depth(self) -> Int:
        return self._count

    def alignments(self) -> PileupAlignments:
        return PileupAlignments(self._ptr, self._count)


struct Pileups(Movable):
    var _bridge: Optional[UnsafePointer[hts_mojo_bam_plp_data_t, MutUntrackedOrigin]]
    var _iter: Optional[RawHtsIterator]
    var _plp: bam_plp_t
    var _tid: c_int
    var _pos: c_int
    var _count: c_int

    def __init__(
        out self,
        file: RawAlignmentFile,
        header: RawSamHeader,
        max_depth: Optional[Int] = None,
        var iter: Optional[RawHtsIterator] = None,
    ) raises:
        self._iter = iter^
        self._plp = None
        self._tid = c_int(0)
        self._pos = c_int(0)
        self._count = c_int(0)

        var mem = malloc(UInt(size_of[hts_mojo_bam_plp_data_t]()))
        if not mem:
            raise Error("failed to allocate pileup bridge")
        self._bridge = rebind[
            Optional[UnsafePointer[hts_mojo_bam_plp_data_t, MutUntrackedOrigin]]
        ](mem)
        self._bridge.value()[].fp = file.ptr()
        self._bridge.value()[].hdr = header.ptr()
        self._bridge.value()[].itr = None
        self._bridge.value()[].last_status = 0
        if self._iter:
            self._bridge.value()[].itr = self._iter.value().ptr()

        self._plp = hts_mojo_bam_plp_init(self._bridge.value())
        if not self._plp:
            hts_free(mem)
            self._bridge = None
            raise Error("failed to initialize pileup iterator")

        if max_depth:
            var depth = _check_nonnegative_i32(
                max_depth.value(), "max_depth must be non-negative"
            )
            bam_plp_set_maxcnt(self._plp, depth)

    def __del__(deinit self):
        if self._plp:
            bam_plp_destroy(self._plp)
        if self._bridge:
            hts_free(self._bridge.value().bitcast[NoneType]())

    @staticmethod
    def from_reader(
        file: RawAlignmentFile,
        header: RawSamHeader,
        max_depth: Optional[Int] = None,
        var iter: Optional[RawHtsIterator] = None,
    ) raises -> Self:
        return Self(file, header, max_depth, iter^)

    def next(mut self) raises -> Optional[Pileup]:
        if not self._plp:
            raise Error("pileup iterator is unavailable")
        var ptr = bam_plp_auto(
            self._plp,
            UnsafePointer(to=self._tid).unsafe_origin_cast[MutUntrackedOrigin](),
            UnsafePointer(to=self._pos).unsafe_origin_cast[MutUntrackedOrigin](),
            UnsafePointer(to=self._count).unsafe_origin_cast[
                MutUntrackedOrigin
            ](),
        )
        if not ptr:
            if self._bridge and self._bridge.value()[].last_status == -1:
                return None
            raise Error("failed to read alignment record for pileup")
        return Pileup(
            Int32(self._tid), Int64(self._pos), ptr.value(), Int(self._count)
        )

    def pop_next(mut self) raises -> Optional[Pileup]:
        return self.next()
