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


comptime CIGAR_MATCH = UInt32(0)
comptime CIGAR_INSERTION = UInt32(1)
comptime CIGAR_DELETION = UInt32(2)
comptime CIGAR_REFERENCE_SKIP = UInt32(3)
comptime CIGAR_SOFT_CLIP = UInt32(4)
comptime CIGAR_HARD_CLIP = UInt32(5)
comptime CIGAR_PADDING = UInt32(6)
comptime CIGAR_SEQUENCE_MATCH = UInt32(7)
comptime CIGAR_SEQUENCE_MISMATCH = UInt32(8)
comptime CIGAR_BACK = UInt32(9)


@fieldwise_init
struct Region(Copyable, Movable):
    var contig: String
    var start: Int64
    var end: Int64


@fieldwise_init
struct CigarElement(Copyable, Movable):
    var op: UInt32
    var length: UInt32


@fieldwise_init
struct HeaderView(Copyable, Movable):
    var _ptr: Optional[UnsafePointer[sam_hdr_t, MutUntrackedOrigin]]

    def _require_ptr(self) -> UnsafePointer[sam_hdr_t, MutUntrackedOrigin]:
        if not self._ptr:
            raise Error("missing header")
        return self._ptr.value()

    def n_references(self) -> Int:
        return Int(
            sam_hdr_nref(
                self._require_ptr().unsafe_mut_cast[False]().unsafe_origin_cast[
                    ImmutUntrackedOrigin
                ]()
            )
        )

    def text(self) -> String:
        var ptr = sam_hdr_str(self._require_ptr())
        if not ptr:
            return String()

        var result = String()
        var length = Int(sam_hdr_length(self._require_ptr()))
        for i in range(length):
            var ch = ptr.value()[i]
            if ch == 0:
                break
            result += String(chr(Int(ch)))
        return result

    def reference_name(self, tid: Int32) -> Optional[String]:
        var name = sam_hdr_tid2name(
            self._require_ptr().unsafe_mut_cast[False]().unsafe_origin_cast[
                ImmutUntrackedOrigin
            ](),
            tid,
        )
        if not name:
            return None

        var result = String()
        var i = 0
        while True:
            var ch = name.value()[i]
            if ch == 0:
                break
            result += String(chr(Int(ch)))
            i += 1
        return result

    def reference_length(self, tid: Int32) -> Optional[Int64]:
        var length = sam_hdr_tid2len(
            self._require_ptr().unsafe_mut_cast[False]().unsafe_origin_cast[
                ImmutUntrackedOrigin
            ](),
            tid,
        )
        if length < 0:
            return None
        return Int64(length)

    def tid(self, contig: String) -> Int32:
        var contig_c = contig
        return Int32(sam_hdr_name2tid(self._require_ptr(), _raw._cstr(contig_c)))


struct Header(Movable):
    var _raw: _raw.RawSamHeader

    @staticmethod
    def empty() raises -> Self:
        var result = Self()
        result._raw = _raw.RawSamHeader.empty()
        return result

    @staticmethod
    def from_text(text: String) raises -> Self:
        var result = Self()
        result._raw = _raw.RawSamHeader.from_text(text)
        return result

    @staticmethod
    def from_view(view: HeaderView) raises -> Self:
        var result = Self()
        result._raw = _raw.RawSamHeader(
            sam_hdr_dup(
                view._ptr.value().unsafe_mut_cast[False]().unsafe_origin_cast[
                    ImmutUntrackedOrigin
                ]()
            )
        )
        return result

    def __init__(out self) raises:
        self._raw = _raw.RawSamHeader.empty()

    def view(self) -> HeaderView:
        return HeaderView(self._raw.ptr())

    def clone(self) raises -> Self:
        var result = Self()
        result._raw = self._raw.dup()
        return result

    def n_references(self) -> Int:
        return self.view().n_references()

    def text(self) -> String:
        return self.view().text()

    def reference_name(self, tid: Int32) -> Optional[String]:
        return self.view().reference_name(tid)

    def reference_length(self, tid: Int32) -> Optional[Int64]:
        return self.view().reference_length(tid)

    def tid(self, contig: String) -> Int32:
        return self.view().tid(contig)

@fieldwise_init
struct RecordView(Copyable, Movable):
    var _ptr: Optional[UnsafePointer[bam1_t, MutUntrackedOrigin]]

    def _require_ptr(self) -> UnsafePointer[bam1_t, ImmutUntrackedOrigin]:
        if not self._ptr:
            raise Error("missing record")
        return self._ptr.value().unsafe_mut_cast[False]().unsafe_origin_cast[
            ImmutUntrackedOrigin
        ]()

    def _data(self) -> UnsafePointer[uint8_t, MutUntrackedOrigin]:
        var data = self._require_ptr()[].data
        if not data:
            raise Error("missing record data")
        return data.value()

    def _data_len(self) -> Int:
        return Int(self._require_ptr()[].l_data)

    def flag(self) -> UInt16:
        return self._require_ptr()[].core.flag

    def reference_id(self) -> Int32:
        return self._require_ptr()[].core.tid

    def reference_start(self) -> Int64:
        return self._require_ptr()[].core.pos

    def reference_end(self) -> Optional[Int64]:
        if self.is_unmapped() or self._require_ptr()[].core.n_cigar == 0:
            return None
        return Int64(bam_endpos(self._require_ptr()))

    def reference_length(self) -> Optional[Int64]:
        var end = self.reference_end()
        if not end:
            return None
        return end.value() - self.reference_start()

    def mapping_quality(self) -> UInt8:
        return self._require_ptr()[].core.qual

    def next_reference_id(self) -> Int32:
        return self._require_ptr()[].core.mtid

    def next_reference_start(self) -> Int64:
        return self._require_ptr()[].core.mpos

    def template_length(self) -> Int64:
        return self._require_ptr()[].core.isize

    def query_length(self) -> Int32:
        return self._require_ptr()[].core.l_qseq

    def _cigar_word(self, index: Int) -> UInt32:
        var data = self._data()
        var offset = Int(self._require_ptr()[].core.l_qname) + index * 4
        return UInt32(data[offset]) | (UInt32(data[offset + 1]) << 8) | (UInt32(data[offset + 2]) << 16) | (UInt32(data[offset + 3]) << 24)

    def _cigar_count(self) -> Int:
        return Int(self._require_ptr()[].core.n_cigar)

    def _seq_offset(self) -> Int:
        return Int(self._require_ptr()[].core.l_qname) + self._cigar_count() * 4

    def _qual_offset(self) -> Int:
        return self._seq_offset() + ((Int(self._require_ptr()[].core.l_qseq) + 1) >> 1)

    def query_name(self) raises -> String:
        var data = self._data()
        var limit = Int(self._require_ptr()[].core.l_qname)
        var result = String()
        for i in range(limit):
            var ch = data[i]
            if ch == 0:
                break
            result += String(chr(Int(ch)))
        return result

    def cigar(self) raises -> List[CigarElement]:
        var result = List[CigarElement]()
        for i in range(self._cigar_count()):
            var raw = self._cigar_word(i)
            result.append(CigarElement(raw & UInt32(0xF), raw >> 4))
        return result

    def cigar_string(self) raises -> Optional[String]:
        if self._require_ptr()[].core.n_cigar == 0:
            return None

        var result = String()
        for item in self.cigar():
            result += String(item.length)
            result += _cigar_op_char(item.op)
        return result

    def query_sequence(self) raises -> String:
        var data = self._data()
        var result = String()
        var start = self._seq_offset()
        var count = Int(self._require_ptr()[].core.l_qseq)
        for i in range(count):
            var byte = data[start + (i >> 1)]
            if (i & 1) == 0:
                result += _seq_char(byte >> 4)
            else:
                result += _seq_char(byte & UInt8(0xF))
        return result

    def query_qualities(self) raises -> List[UInt8]:
        var data = self._data()
        var result = List[UInt8]()
        var start = self._qual_offset()
        for i in range(Int(self._require_ptr()[].core.l_qseq)):
            result.append(data[start + i])
        return result

    def aux_bytes(self) raises -> List[UInt8]:
        var data = self._data()
        var result = List[UInt8]()
        var start = self._qual_offset() + Int(self._require_ptr()[].core.l_qseq)
        for i in range(self._data_len() - start):
            result.append(data[start + i])
        return result

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
        return (self._require_ptr()[].core.flag & flag) != 0

struct Record(Movable):
    var _raw: _raw.RawBamRecord

    def __init__(out self) raises:
        self._raw = _raw.RawBamRecord()

    def view(self) -> RecordView:
        return RecordView(self._raw.ptr())

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
    var _file: _raw.RawSamFile
    var _header: _raw.RawSamHeader

    @staticmethod
    def open(path: String, reference_path: Optional[String] = None, threads: Int = 0) raises -> Self:
        return Self(path, reference_path, threads)

    def __init__(out self, path: String, reference_path: Optional[String] = None, threads: Int = 0) raises:
        self._file = _raw.RawSamFile.open(path, String("r"))
        if reference_path:
            self._file.set_reference(reference_path.value())
        if threads > 0:
            self._file.set_threads(threads)
        self._header = _raw.RawSamHeader(self._file)

    def header(self) -> HeaderView:
        return HeaderView(self._header.ptr())

    def read_into(mut self, mut record: Record) raises -> Bool:
        var rc = Int(sam_read1(self._file.ptr(), self._header.ptr(), record._raw.ptr()))
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
    def open(path: String, index_path: Optional[String] = None, reference_path: Optional[String] = None, threads: Int = 0) raises -> Self:
        return Self(path, index_path, reference_path, threads)

    def __init__(out self, path: String, index_path: Optional[String] = None, reference_path: Optional[String] = None, threads: Int = 0) raises:
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
    var _file: _raw.RawSamFile
    var _header: _raw.RawSamHeader

    @staticmethod
    def open(path: String, header: HeaderView, reference_path: Optional[String] = None, threads: Int = 0) raises -> Self:
        return Self(path, header, reference_path, threads)

    def __init__(out self, path: String, header: HeaderView, reference_path: Optional[String] = None, threads: Int = 0) raises:
        self._file = _raw.RawSamFile.open(path, String("w"))
        if reference_path:
            self._file.set_reference(reference_path.value())
        if threads > 0:
            self._file.set_threads(threads)
        self._header = _raw.RawSamHeader(
            sam_hdr_dup(
                header._ptr.value().unsafe_mut_cast[False]().unsafe_origin_cast[
                    ImmutUntrackedOrigin
                ]()
            )
        )
        _raw._check_code(
            Int(
                sam_hdr_write(
                    self._file.ptr(),
                    self._header.ptr().unsafe_mut_cast[False]().unsafe_origin_cast[
                        ImmutUntrackedOrigin
                    ](),
                )
            ),
            "failed to write header",
        )

    def write(mut self, read record: Record) raises:
        _raw._check_code(
            Int(
                sam_write1(
                    self._file.ptr(),
                    self._header.ptr().unsafe_mut_cast[False]().unsafe_origin_cast[
                        ImmutUntrackedOrigin
                    ](),
                    record._raw.ptr().unsafe_mut_cast[False]().unsafe_origin_cast[
                        ImmutUntrackedOrigin
                    ](),
                )
            ),
            "failed to write alignment record",
        )

    def set_threads(mut self, n_threads: Int) raises:
        self._file.set_threads(n_threads)

    def close(mut self) raises:
        self._file.close()


def _cigar_op_char(op: UInt32) -> String:
    if op == CIGAR_MATCH:
        return String("M")
    if op == CIGAR_INSERTION:
        return String("I")
    if op == CIGAR_DELETION:
        return String("D")
    if op == CIGAR_REFERENCE_SKIP:
        return String("N")
    if op == CIGAR_SOFT_CLIP:
        return String("S")
    if op == CIGAR_HARD_CLIP:
        return String("H")
    if op == CIGAR_PADDING:
        return String("P")
    if op == CIGAR_SEQUENCE_MATCH:
        return String("=")
    if op == CIGAR_SEQUENCE_MISMATCH:
        return String("X")
    if op == CIGAR_BACK:
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
