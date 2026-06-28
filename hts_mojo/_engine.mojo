from std.ffi import c_char, CStringSlice
from hts_mojo import _raw


@fieldwise_init
struct CigarOp(Comparable, TrivialRegisterPassable):
    var value: UInt32

    comptime Match = Self(0)
    comptime Insertion = Self(1)
    comptime Deletion = Self(2)
    comptime ReferenceSkip = Self(3)
    comptime SoftClip = Self(4)
    comptime HardClip = Self(5)
    comptime Padding = Self(6)
    comptime SequenceMatch = Self(7)
    comptime SequenceMismatch = Self(8)
    comptime Back = Self(9)

    def __eq__(self: Self, other: Self) -> Bool:
        return self.value == other.value

    def __lt__(self: Self, other: Self) -> Bool:
        return self.value < other.value


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


@fieldwise_init
struct CigarElement(Copyable, Movable):
    var op: CigarOp
    var length: UInt32


comptime CIGAR_MATCH = CigarOp.Match
comptime CIGAR_INSERTION = CigarOp.Insertion
comptime CIGAR_DELETION = CigarOp.Deletion
comptime CIGAR_REFERENCE_SKIP = CigarOp.ReferenceSkip
comptime CIGAR_SOFT_CLIP = CigarOp.SoftClip
comptime CIGAR_HARD_CLIP = CigarOp.HardClip
comptime CIGAR_PADDING = CigarOp.Padding
comptime CIGAR_SEQUENCE_MATCH = CigarOp.SequenceMatch
comptime CIGAR_SEQUENCE_MISMATCH = CigarOp.SequenceMismatch
comptime CIGAR_BACK = CigarOp.Back


def _cstring_to_string(
    ptr: UnsafePointer[c_char, ImmutUntrackedOrigin]
) -> String:
    var c_str = CStringSlice(unsafe_from_ptr=ptr)
    return String(c_str)


struct Header(Movable):
    var _raw: _raw.RawSamHeader

    def __init__(out self) raises:
        self._raw = _raw.RawSamHeader()

    @staticmethod
    def empty() raises -> Self:
        return Self()

    @staticmethod
    def from_text(text: String) raises -> Self:
        var result = Self()
        result._raw = _raw.RawSamHeader.parse(text)
        return result^

    def clone(self) raises -> Self:
        var result = Self()
        result._raw = self._raw.dup()
        return result^

    def n_references(self) -> Int:
        return self._raw.n_ref()

    def text(self) -> String:
        var ptr = self._raw.borrowed_text_ptr()
        if not ptr:
            return String()
        return _cstring_to_string(ptr.value())

    def reference_name(self, tid: Int32) -> Optional[String]:
        var name = self._raw.tid2name(tid)
        if not name:
            return None
        return _cstring_to_string(name.value())

    def reference_length(self, tid: Int32) -> Optional[Int64]:
        var length = self._raw.tid2len(tid)
        if length < 0:
            return None
        return Int64(length)

    def tid(self, contig: String) raises -> Optional[Int32]:
        var contig_c = contig
        var tid = self._raw.name2tid(contig_c)
        if tid < 0:
            return None
        return tid

    def require_tid(self, contig: String) raises -> Int32:
        var tid = self.tid(contig)
        if not tid:
            raise Error("unknown reference name")
        return tid.value()


struct Record(Movable):
    var _raw: _raw.RawBamRecord

    def __init__(out self) raises:
        self._raw = _raw.RawBamRecord()

    def clone(self) raises -> Self:
        var result = Self()
        result._raw = self._raw.dup()
        return result^

    def flag(self) -> UInt16:
        return self._raw.flag()

    def reference_id(self) -> Int32:
        return self._raw.tid()

    def reference_start(self) -> Int64:
        return self._raw.pos0()

    def reference_end(self) -> Optional[Int64]:
        if self.is_unmapped() or self._raw.n_cigar() == 0:
            return None
        return self._raw.end_pos0()

    def reference_length(self) -> Optional[Int64]:
        var end = self.reference_end()
        if not end:
            return None
        return end.value() - self.reference_start()

    def mapping_quality(self) -> UInt8:
        return self._raw.mapq()

    def next_reference_id(self) -> Int32:
        return self._raw.mate_tid()

    def next_reference_start(self) -> Int64:
        return self._raw.mate_pos0()

    def template_length(self) -> Int64:
        return self._raw.insert_size()

    def query_length(self) -> Int32:
        return Int32(self._raw.l_seq())

    def query_name(self) raises -> String:
        var ptr = self._raw.borrowed_qname_ptr()
        if not ptr:
            raise Error("record has no query name")
        return _cstring_to_string(ptr.value())

    def cigar(self) raises -> List[CigarElement]:
        var result = List[CigarElement]()
        var ptr = self._raw.borrowed_cigar_ptr()
        if not ptr:
            return result^
        for i in range(self._raw.n_cigar()):
            var raw = ptr.value()[i]
            result.append(CigarElement(CigarOp(raw & UInt32(0xF)), raw >> 4))
        return result^

    def cigar_string(self) raises -> Optional[String]:
        if self._raw.n_cigar() == 0:
            return None

        var result = String()
        for item in self.cigar():
            result += String(item.length)
            result += _cigar_op_char(item.op)
        return result

    def query_sequence(self) raises -> String:
        var seq = self._raw.borrowed_seq_ptr()
        if not seq:
            return String()

        var result = String()
        for i in range(self._raw.l_seq()):
            var byte = seq.value()[i >> 1]
            if (i & 1) == 0:
                result += _seq_char(byte >> 4)
            else:
                result += _seq_char(byte & UInt8(0xF))
        return result

    def query_qualities(self) raises -> List[UInt8]:
        var result = List[UInt8]()
        var qual = self._raw.borrowed_qual_ptr()
        if not qual:
            return result^
        for i in range(self._raw.l_seq()):
            result.append(qual.value()[i])
        return result^

    def aux_bytes(self) raises -> List[UInt8]:
        var result = List[UInt8]()
        var aux = self._raw.borrowed_aux_ptr()
        if not aux:
            return result^
        for i in range(self._raw.aux_len()):
            result.append(aux.value()[i])
        return result^

    def is_paired(self) -> Bool:
        return self._has_flag(UInt16(0x1))

    def is_proper_pair(self) -> Bool:
        return self._has_flag(UInt16(0x2))

    def is_unmapped(self) -> Bool:
        return self._has_flag(UInt16(0x4))

    def mate_is_unmapped(self) -> Bool:
        return self._has_flag(UInt16(0x8))

    def is_reverse(self) -> Bool:
        return self._has_flag(UInt16(0x10))

    def mate_is_reverse(self) -> Bool:
        return self._has_flag(UInt16(0x20))

    def is_read1(self) -> Bool:
        return self._has_flag(UInt16(0x40))

    def is_read2(self) -> Bool:
        return self._has_flag(UInt16(0x80))

    def is_secondary(self) -> Bool:
        return self._has_flag(UInt16(0x100))

    def is_qcfail(self) -> Bool:
        return self._has_flag(UInt16(0x200))

    def is_duplicate(self) -> Bool:
        return self._has_flag(UInt16(0x400))

    def is_supplementary(self) -> Bool:
        return self._has_flag(UInt16(0x800))

    def _has_flag(self, flag: UInt16) -> Bool:
        return (self._raw.flag() & flag) != 0


struct ReadOptions(Copyable, Movable):
    var reference_path: Optional[String]
    var threads: Int


struct WriteOptions(Copyable, Movable):
    var reference_path: Optional[String]
    var threads: Int


struct RecordsIter(Movable):
    var _reader: UnsafePointer[Reader, MutUntrackedOrigin]
    var _iter: Optional[_raw.RawHtsIterator]

    def __init__(
        out self,
        reader: UnsafePointer[Reader, MutUntrackedOrigin],
        var iter: Optional[_raw.RawHtsIterator] = None,
    ):
        self._reader = reader
        self._iter = iter^

    def read_into(mut self, mut record: Record) raises -> Bool:
        if self._iter:
            var rc = self._iter.value().next_status(
                self._reader[]._file, record._raw
            )
            if rc >= 0:
                return True
            if rc == -1:
                return False
            raise Error("failed to read indexed alignment record")

        return self._reader[].read_into(record)

    def next(mut self) raises -> Optional[Record]:
        var record = Record()
        if not self.read_into(record):
            return None
        return record^


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

    def header(self) raises -> Header:
        var result = Header()
        result._raw = self._header.dup()
        return result^

    def read_into(mut self, mut record: Record) raises -> Bool:
        var rc = self._file.read1_status(self._header, record._raw)
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

    def records(mut self) -> RecordsIter:
        return RecordsIter(
            UnsafePointer(to=self).unsafe_origin_cast[MutUntrackedOrigin]()
        )

    def set_threads(mut self, n_threads: Int) raises:
        self._file.set_threads(n_threads)

    def set_reference(mut self, reference_path: String) raises:
        self._file.set_reference(reference_path)

    def close(mut self) raises:
        self._file.close()


struct IndexedReader(Movable):
    var _reader: Reader
    var _index: _raw.RawHtsIndex

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
            self._index = _raw.RawHtsIndex.load_at(
                self._reader._file, path, index_path.value()
            )
        else:
            self._index = _raw.RawHtsIndex.load(self._reader._file, path)

    def header(self) raises -> Header:
        return self._reader.header()

    def fetch(mut self, region: Region) raises -> RecordsIter:
        var tid = self.header().require_tid(region.contig)
        return RecordsIter(
            UnsafePointer(to=self._reader).unsafe_origin_cast[
                MutUntrackedOrigin
            ](),
            _raw.RawHtsIterator.queryi(
                self._index, tid, region.start0, region.end0
            ),
        )

    def fetch_string(mut self, region: String) raises -> RecordsIter:
        return RecordsIter(
            UnsafePointer(to=self._reader).unsafe_origin_cast[
                MutUntrackedOrigin
            ](),
            _raw.RawHtsIterator.querys(
                self._index, self._reader._header, region
            ),
        )

    def read_into(mut self, mut record: Record) raises -> Bool:
        return self._reader.read_into(record)

    def next(mut self) raises -> Optional[Record]:
        var record = Record()
        if not self.read_into(record):
            return None
        return record^

    def records(mut self) -> RecordsIter:
        return self._reader.records()

    def set_threads(mut self, n_threads: Int) raises:
        self._reader.set_threads(n_threads)

    def set_reference(mut self, reference_path: String) raises:
        self._reader.set_reference(reference_path)

    def close(mut self) raises:
        self._reader.close()


struct Writer(Movable):
    var _file: _raw.RawAlignmentFile
    var _header: _raw.RawSamHeader

    @staticmethod
    def open(
        path: String,
        header: Header,
        reference_path: Optional[String] = None,
        threads: Int = 0,
    ) raises -> Self:
        return Self(path, header, reference_path, threads)

    def __init__(
        out self,
        path: String,
        header: Header,
        reference_path: Optional[String] = None,
        threads: Int = 0,
    ) raises:
        self._file = _raw.RawAlignmentFile(path, String("w"))
        if reference_path:
            self._file.set_reference(reference_path.value())
        if threads > 0:
            self._file.set_threads(threads)
        self._header = header._raw.dup()
        self._file.write_header(self._header)

    def write(mut self, read record: Record) raises:
        self._file.write1(self._header, record._raw)

    def set_threads(mut self, n_threads: Int) raises:
        self._file.set_threads(n_threads)

    def close(mut self) raises:
        self._file.close()


def _cigar_op_char(op: CigarOp) -> String:
    if op == CigarOp.Match:
        return String("M")
    if op == CigarOp.Insertion:
        return String("I")
    if op == CigarOp.Deletion:
        return String("D")
    if op == CigarOp.ReferenceSkip:
        return String("N")
    if op == CigarOp.SoftClip:
        return String("S")
    if op == CigarOp.HardClip:
        return String("H")
    if op == CigarOp.Padding:
        return String("P")
    if op == CigarOp.SequenceMatch:
        return String("=")
    if op == CigarOp.SequenceMismatch:
        return String("X")
    if op == CigarOp.Back:
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
