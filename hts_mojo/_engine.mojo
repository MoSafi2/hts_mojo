from std.ffi import c_char, CStringSlice
from std.io import Writer as IOWriter
from hts_mojo import _raw
from hts_mojo._ffi import (
    bam_aux2A,
    bam_aux2Z,
    bam_aux2f,
    bam_aux2i,
    bam_auxB2f,
    bam_auxB2i,
    bam_auxB_len,
)



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
struct ReferenceInfo(Copyable, Movable):
    var name: String
    var length: Int64


@fieldwise_init
struct ReadGroupInfo(Copyable, Movable):
    var id: String
    var sample: Optional[String]
    var library: Optional[String]
    var platform: Optional[String]
    var raw_line: String


@fieldwise_init
struct ProgramInfo(Copyable, Movable):
    var id: String
    var program_name: Optional[String]
    var version: Optional[String]
    var command_line: Optional[String]
    var previous_id: Optional[String]
    var raw_line: String




def _split_tab_fields(line: String) -> List[String]:
    var result = List[String]()
    var current = String()
    for cp in line.codepoint_slices():
        var ch = String(cp)
        if ch == "\t":
            result.append(current^)
            current = String()
            continue
        current += ch
    result.append(current^)
    return result^


def _starts_with_ascii(text: String, prefix: String) -> Bool:
    if prefix.byte_length() > text.byte_length():
        return False
    for i in range(prefix.byte_length()):
        if String(text[byte=i]) != String(prefix[byte=i]):
            return False
    return True


def _field_value(field: String, key: String) -> Optional[String]:
    if key.byte_length() != 2 or field.byte_length() < 3:
        return None
    if (
        String(field[byte=0]) != String(key[byte=0])
        or String(field[byte=1]) != String(key[byte=1])
        or String(field[byte=2]) != ":"
    ):
        return None
    var value = String()
    for i in range(3, field.byte_length()):
        value += String(field[byte=i])
    return value


struct Header(Movable, Writable):
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

    def references(self) -> List[ReferenceInfo]:
        var result = List[ReferenceInfo]()
        for tid in range(self.n_references()):
            var name = self.reference_name(Int32(tid))
            var length = self.reference_length(Int32(tid))
            if name and length:
                result.append(ReferenceInfo(name.value(), length.value()))
        return result^

    def add_reference(mut self, name: String, length: Int64) raises:
        if name.byte_length() == 0:
            raise Error("reference name must not be empty")
        if length < 0:
            raise Error("reference length must be non-negative")
        self._raw.append_line("@SQ\tSN:" + name + "\tLN:" + String(length) + "\n")

    def read_groups(self) -> List[ReadGroupInfo]:
        var result = List[ReadGroupInfo]()
        for line in _header_lines(self.text()):
            if not _starts_with_ascii(line, "@RG\t"):
                continue
            var fields = _split_tab_fields(line)
            var id = String()
            var sample: Optional[String] = None
            var library: Optional[String] = None
            var platform: Optional[String] = None
            for field in fields:
                var value = _field_value(field, "ID")
                if value:
                    id = value.value()
                    continue
                value = _field_value(field, "SM")
                if value:
                    sample = value.value()
                    continue
                value = _field_value(field, "LB")
                if value:
                    library = value.value()
                    continue
                value = _field_value(field, "PL")
                if value:
                    platform = value.value()
            result.append(ReadGroupInfo(id, sample, library, platform, line))
        return result^

    def add_read_group(
        mut self,
        id: String,
        sample: Optional[String] = None,
        library: Optional[String] = None,
        platform: Optional[String] = None,
    ) raises:
        if id.byte_length() == 0:
            raise Error("read-group id must not be empty")
        var line = String("@RG\tID:") + id
        if sample:
            line += "\tSM:" + sample.value()
        if library:
            line += "\tLB:" + library.value()
        if platform:
            line += "\tPL:" + platform.value()
        line += "\n"
        self._raw.append_line(line)

    def programs(self) -> List[ProgramInfo]:
        var result = List[ProgramInfo]()
        for line in _header_lines(self.text()):
            if not _starts_with_ascii(line, "@PG\t"):
                continue
            var fields = _split_tab_fields(line)
            var id = String()
            var program_name: Optional[String] = None
            var version: Optional[String] = None
            var command_line: Optional[String] = None
            var previous_id: Optional[String] = None
            for field in fields:
                var value = _field_value(field, "ID")
                if value:
                    id = value.value()
                    continue
                value = _field_value(field, "PN")
                if value:
                    program_name = value.value()
                    continue
                value = _field_value(field, "VN")
                if value:
                    version = value.value()
                    continue
                value = _field_value(field, "CL")
                if value:
                    command_line = value.value()
                    continue
                value = _field_value(field, "PP")
                if value:
                    previous_id = value.value()
            result.append(
                ProgramInfo(
                    id,
                    program_name,
                    version,
                    command_line,
                    previous_id,
                    line,
                )
            )
        return result^

    def add_program(
        mut self,
        id: String,
        program_name: Optional[String] = None,
        version: Optional[String] = None,
        command_line: Optional[String] = None,
        previous_id: Optional[String] = None,
    ) raises:
        if id.byte_length() == 0:
            raise Error("program id must not be empty")
        var line = String("@PG\tID:") + id
        if program_name:
            line += "\tPN:" + program_name.value()
        if version:
            line += "\tVN:" + version.value()
        if command_line:
            line += "\tCL:" + command_line.value()
        if previous_id:
            line += "\tPP:" + previous_id.value()
        line += "\n"
        self._raw.append_line(line)

    def write_to[w: IOWriter](self, mut writer: w):
        writer.write(self.text())



