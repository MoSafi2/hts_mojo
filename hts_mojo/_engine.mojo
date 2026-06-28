from std.ffi import c_char
from hts_mojo import _raw
from hts_mojo._ffi import (
    bam1_core_t,
    bam1_t,
    bam_endpos,
    sam_hdr_length,
    sam_hdr_dup,
    sam_hdr_name2tid,
    sam_hdr_nref,
    sam_hdr_str,
    sam_hdr_tid2len,
    sam_hdr_tid2name,
    sam_hdr_t,
    sam_hdr_write,
    sam_read1,
    sam_write1,
    uint32_t,
)


@fieldwise_init
struct CIGAR_OP(Comparable, TrivialRegisterPassable):
    var value: UInt32

    comptime CIGAR_MATCH = Self(0)
    comptime CIGAR_INSERTION = Self(1)
    comptime CIGAR_DELETION = Self(2)
    comptime CIGAR_REFERENCE_SKIP = Self(3)
    comptime CIGAR_SOFT_CLIP = Self(4)
    comptime CIGAR_HARD_CLIP = Self(5)
    comptime CIGAR_PADDING = Self(6)
    comptime CIGAR_SEQUENCE_MATCH = Self(7)
    comptime CIGAR_SEQUENCE_MISMATCH = Self(8)
    comptime CIGAR_BACK = Self(9)

    def __eq__(self: Self, other: Self) -> Bool:
        return self.value == other.value

    def __lt__(self: Self, other: Self) -> Bool:
        return self.value < other.value


@fieldwise_init
struct Region(Copyable, Movable):
    var contig: String
    var start: Int64
    var end: Int64


@fieldwise_init
struct CigarElement(Copyable, Movable):
    var op: CIGAR_OP
    var length: UInt32


struct Header(Movable):
    var _raw: _raw.RawSamHeader

    @staticmethod
    def empty() raises -> Self:
        var result = Self()
        result._raw = _raw.RawSamHeader()
        return result^

    @staticmethod
    def from_text(text: String) raises -> Self:
        var result = Self()
        result._raw = _raw.RawSamHeader.parse(text)
        return result^

    @staticmethod
    def from_view(view: HeaderView) raises -> Self:
        var result = Self()
        result._raw = _raw.RawSamHeader.adopt(
            sam_hdr_dup(
                view._require_ptr()
                .unsafe_mut_cast[False]()
                .unsafe_origin_cast[ImmutUntrackedOrigin]()
            )
        )
        return result^

    def __init__(out self) raises:
        self._raw = _raw.RawSamHeader()

    def view(self) -> HeaderView:
        return HeaderView(self._raw.ptr())

    def clone(self) raises -> Self:
        var result = Self()
        result._raw = self._raw.dup()
        return result^

    def n_references(self) -> Int:
        return self._raw.n_ref()

    def text(self) -> String:
        return self.view().text()

    def reference_name(self, tid: Int32) -> Optional[String]:
        return self.view().reference_name(tid)

    def reference_length(self, tid: Int32) -> Optional[Int64]:
        return self.view().reference_length(tid)

    def tid(self, contig: String) -> Int32:
        return self.view().tid(contig)


struct Record(Movable):
    var _raw: _raw.RawBamRecord

    def __init__(out self) raises:
        self._raw = _raw.RawBamRecord()

    def clone(self) raises -> Self:
        var result = Self()
        result._raw = self._raw.dup()
        return result

    def flag(self) -> UInt16:
        return self.view().flag()

    def reference_id(self) -> Int32:
        return self.view().reference_id()

    def reference_start(self) -> Int64:
        return self.view().reference_start()

    def reference_end(self) -> Optional[Int64]:
        return self.view().reference_end()

    def reference_length(self) -> Optional[Int64]:
        return self.view().reference_length()

    def mapping_quality(self) -> UInt8:
        return self.view().mapping_quality()

    def next_reference_id(self) -> Int32:
        return self.view().next_reference_id()

    def next_reference_start(self) -> Int64:
        return self.view().next_reference_start()

    def template_length(self) -> Int64:
        return self.view().template_length()

    def query_length(self) -> Int32:
        return self.view().query_length()

    def query_name(self) raises -> String:
        return self.view().query_name()

    def cigar(self) raises -> List[CigarElement]:
        return self.view().cigar()

    def cigar_string(self) raises -> Optional[String]:
        return self.view().cigar_string()

    def query_sequence(self) raises -> String:
        return self.view().query_sequence()

    def query_qualities(self) raises -> List[UInt8]:
        return self.view().query_qualities()

    def aux_bytes(self) raises -> List[UInt8]:
        return self.view().aux_bytes()

    def is_paired(self) -> Bool:
        return self.view().is_paired()

    def is_proper_pair(self) -> Bool:
        return self.view().is_proper_pair()

    def is_unmapped(self) -> Bool:
        return self.view().is_unmapped()

    def mate_is_unmapped(self) -> Bool:
        return self.view().mate_is_unmapped()

    def is_reverse(self) -> Bool:
        return self.view().is_reverse()

    def mate_is_reverse(self) -> Bool:
        return self.view().mate_is_reverse()

    def is_read1(self) -> Bool:
        return self.view().is_read1()

    def is_read2(self) -> Bool:
        return self.view().is_read2()

    def is_secondary(self) -> Bool:
        return self.view().is_secondary()

    def is_qcfail(self) -> Bool:
        return self.view().is_qcfail()

    def is_duplicate(self) -> Bool:
        return self.view().is_duplicate()

    def is_supplementary(self) -> Bool:
        return self.view().is_supplementary()


struct ReadOptions(Copyable, Movable):
    var reference_path: Optional[String]
    var threads: Int


struct WriteOptions(Copyable, Movable):
    var reference_path: Optional[String]
    var threads: Int


struct Reader(Movable):
    var _file: _raw.RawAlignmentFile
    var _header: _raw.RawSamHeader

    @staticmethod
    def open(
        path: String, reference_path: Optional[String] = None, threads: Int = 0
    ) raises -> Self:
        return Self(path, reference_path, threads)

    def __init__(
        out self,
        path: String,
        reference_path: Optional[String] = None,
        threads: Int = 0,
    ) raises:
        self._file = _raw.RawAlignmentFile(path, String("r"))
        if reference_path:
            self._file.set_reference(reference_path.value())
        if threads > 0:
            self._file.set_threads(threads)
        self._header = self._file.read_header()

    def header(self) -> HeaderView:
        return HeaderView(self._header.ptr())

    def read_into(mut self, mut record: Record) raises -> Bool:
        var rc = Int(
            sam_read1(self._file.ptr(), self._header.ptr(), record._raw.ptr())
        )
        if rc >= 0:
            return True
        if rc == -1:
            return False
        raise Error("failed to read alignment record")

    def read_next(mut self, mut record: Record) raises -> Bool:
        return self.read_into(record)

    def next(mut self) raises -> Optional[Record]:
        var record = Record()
        if not self.read_into(record):
            return None
        return record^

    def set_threads(mut self, n_threads: Int) raises:
        self._file.set_threads(n_threads)

    def set_reference(mut self, reference_path: String) raises:
        self._file.set_reference(reference_path)

    def close(mut self) raises:
        self._file.close()


struct IndexedReader(Movable):
    var _reader: Reader
    var _index: _raw.RawHtsIndex
    var _iter: Optional[_raw.RawHtsIterator]

    @staticmethod
    def open(
        path: String,
        index_path: Optional[String] = None,
        reference_path: Optional[String] = None,
        threads: Int = 0,
    ) raises -> Self:
        return Self(path, index_path, reference_path, threads)

    def __init__(
        out self,
        path: String,
        index_path: Optional[String] = None,
        reference_path: Optional[String] = None,
        threads: Int = 0,
    ) raises:
        self._reader = Reader(path, reference_path, threads)
        if index_path:
            self._index = _raw.RawHtsIndex(
                self._reader._file, path, index_path.value()
            )
        else:
            self._index = _raw.RawHtsIndex(self._reader._file, path)
        self._iter = None

    def header(self) -> HeaderView:
        return self._reader.header()

    def fetch(self, region: Region) raises:
        if self._iter:
            self._iter = None
        var tid = self.header().tid(region.contig)
        if tid < 0:
            raise Error("unknown reference name")
        self._iter = _raw.RawHtsIterator(
            self._index, tid, region.start, region.end
        )

    def fetch_string(self, region: String) raises:
        if self._iter:
            self._iter = None
        self._iter = _raw.RawHtsIterator(
            self._index, self._reader._header, region
        )

    def read_into(mut self, mut record: Record) raises -> Bool:
        if self._iter:
            var rc = self._iter.value().next(self._reader._file, record._raw)
            if rc >= 0:
                return True
            if rc == -1:
                return False
            raise Error("failed to read indexed alignment record")

        return self._reader.read_into(record)

    def next(mut self) raises -> Optional[Record]:
        var record = Record()
        if not self.read_into(record):
            return None
        return record^

    def set_threads(mut self, n_threads: Int) raises:
        self._reader.set_threads(n_threads)

    def set_reference(mut self, reference_path: String) raises:
        self._reader.set_reference(reference_path)

    def close(mut self) raises:
        self._iter = None
        self._reader.close()


struct Writer(Movable):
    var _file: _raw.RawAlignmentFile
    var _header: _raw.RawSamHeader

    @staticmethod
    def open(
        path: String,
        header: HeaderView,
        reference_path: Optional[String] = None,
        threads: Int = 0,
    ) raises -> Self:
        return Self(path, header, reference_path, threads)

    def __init__(
        out self,
        path: String,
        header: HeaderView,
        reference_path: Optional[String] = None,
        threads: Int = 0,
    ) raises:
        self._file = _raw.RawAlignmentFile(path, String("w"))
        if reference_path:
            self._file.set_reference(reference_path.value())
        if threads > 0:
            self._file.set_threads(threads)
        self._header = _raw.RawSamHeader.adopt(
            sam_hdr_dup(
                header._require_ptr()
                .unsafe_mut_cast[False]()
                .unsafe_origin_cast[ImmutUntrackedOrigin]()
            )
        )
        _raw._check_zero(
            Int(
                sam_hdr_write(
                    self._file.ptr(),
                    self._header.ptr()
                    .unsafe_mut_cast[False]()
                    .unsafe_origin_cast[ImmutUntrackedOrigin](),
                )
            ),
            "failed to write header",
        )

    def write(mut self, read record: Record) raises:
        _raw._check_code(
            Int(
                sam_write1(
                    self._file.ptr(),
                    self._header.ptr()
                    .unsafe_mut_cast[False]()
                    .unsafe_origin_cast[ImmutUntrackedOrigin](),
                    record._raw.ptr()
                    .unsafe_mut_cast[False]()
                    .unsafe_origin_cast[ImmutUntrackedOrigin](),
                )
            ),
            "failed to write alignment record",
        )

    def set_threads(mut self, n_threads: Int) raises:
        self._file.set_threads(n_threads)

    def close(mut self) raises:
        self._file.close()


def _cigar_op_char(op: CIGAR_OP) -> String:
    if op == CIGAR_OP.CIGAR_MATCH:
        return String("M")
    if op == CIGAR_OP.CIGAR_INSERTION:
        return String("I")
    if op == CIGAR_OP.CIGAR_DELETION:
        return String("D")
    if op == CIGAR_OP.CIGAR_REFERENCE_SKIP:
        return String("N")
    if op == CIGAR_OP.CIGAR_SOFT_CLIP:
        return String("S")
    if op == CIGAR_OP.CIGAR_HARD_CLIP:
        return String("H")
    if op == CIGAR_OP.CIGAR_PADDING:
        return String("P")
    if op == CIGAR_OP.CIGAR_SEQUENCE_MATCH:
        return String("=")
    if op == CIGAR_OP.CIGAR_SEQUENCE_MISMATCH:
        return String("X")
    if op == CIGAR_OP.CIGAR_BACK:
        return String("B")
    return String("?")


def _seq_char(code: UInt8) -> String:
    if code == 1:
        return String("A")
    if code == 2:
        return String("C")
    if code == 4:
        return String("G")
    if code == 8:
        return String("T")
    if code == 15:
        return String("N")
    if code == 0:
        return String("=")
    if code == 3:
        return String("M")
    if code == 5:
        return String("R")
    if code == 6:
        return String("S")
    if code == 7:
        return String("V")
    if code == 9:
        return String("W")
    if code == 10:
        return String("Y")
    if code == 11:
        return String("H")
    if code == 12:
        return String("K")
    if code == 13:
        return String("D")
    if code == 14:
        return String("B")
    return String("N")
