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


@fieldwise_init
struct SamFlag(Copyable, Movable):
    var bits: UInt16

    def is_paired(self) -> Bool:
        return (self.bits & UInt16(0x1)) != 0

    def is_proper_pair(self) -> Bool:
        return (self.bits & UInt16(0x2)) != 0

    def is_unmapped(self) -> Bool:
        return (self.bits & UInt16(0x4)) != 0

    def mate_is_unmapped(self) -> Bool:
        return (self.bits & UInt16(0x8)) != 0

    def is_reverse(self) -> Bool:
        return (self.bits & UInt16(0x10)) != 0

    def mate_is_reverse(self) -> Bool:
        return (self.bits & UInt16(0x20)) != 0

    def is_read1(self) -> Bool:
        return (self.bits & UInt16(0x40)) != 0

    def is_read2(self) -> Bool:
        return (self.bits & UInt16(0x80)) != 0

    def is_secondary(self) -> Bool:
        return (self.bits & UInt16(0x100)) != 0

    def is_qcfail(self) -> Bool:
        return (self.bits & UInt16(0x200)) != 0

    def is_duplicate(self) -> Bool:
        return (self.bits & UInt16(0x400)) != 0

    def is_supplementary(self) -> Bool:
        return (self.bits & UInt16(0x800)) != 0


@fieldwise_init
struct AuxKind(Comparable, TrivialRegisterPassable):
    var value: UInt8

    comptime Integer = Self(0)
    comptime Float = Self(1)
    comptime Character = Self(2)
    comptime String = Self(3)
    comptime HexString = Self(4)
    comptime ByteArray = Self(5)
    comptime IntegerArray = Self(6)
    comptime FloatArray = Self(7)

    def __eq__(self: Self, other: Self) -> Bool:
        return self.value == other.value

    def __lt__(self: Self, other: Self) -> Bool:
        return self.value < other.value


@fieldwise_init
struct AuxValue(Copyable, Movable):
    var kind: AuxKind
    var int_value: Int64
    var float_value: Float64
    var char_value: String
    var string_value: String
    var byte_array: List[UInt8]
    var int_array: List[Int64]
    var float_array: List[Float64]

    @staticmethod
    def integer(value: Int64) -> Self:
        return Self(
            AuxKind.Integer,
            value,
            0.0,
            String(),
            String(),
            List[UInt8](),
            List[Int64](),
            List[Float64](),
        )

    @staticmethod
    def float(value: Float64) -> Self:
        return Self(
            AuxKind.Float,
            0,
            value,
            String(),
            String(),
            List[UInt8](),
            List[Int64](),
            List[Float64](),
        )

    @staticmethod
    def character(value: String) -> Self:
        return Self(
            AuxKind.Character,
            0,
            0.0,
            value,
            String(),
            List[UInt8](),
            List[Int64](),
            List[Float64](),
        )

    @staticmethod
    def string(value: String) -> Self:
        return Self(
            AuxKind.String,
            0,
            0.0,
            String(),
            value,
            List[UInt8](),
            List[Int64](),
            List[Float64](),
        )

    @staticmethod
    def hex_string(value: String) -> Self:
        return Self(
            AuxKind.HexString,
            0,
            0.0,
            String(),
            value,
            List[UInt8](),
            List[Int64](),
            List[Float64](),
        )

    @staticmethod
    def bytes(var value: List[UInt8]) -> Self:
        return Self(
            AuxKind.ByteArray,
            0,
            0.0,
            String(),
            String(),
            value^,
            List[Int64](),
            List[Float64](),
        )

    @staticmethod
    def integers(var value: List[Int64]) -> Self:
        return Self(
            AuxKind.IntegerArray,
            0,
            0.0,
            String(),
            String(),
            List[UInt8](),
            value^,
            List[Float64](),
        )

    @staticmethod
    def floats(var value: List[Float64]) -> Self:
        return Self(
            AuxKind.FloatArray,
            0,
            0.0,
            String(),
            String(),
            List[UInt8](),
            List[Int64](),
            value^,
        )


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


@fieldwise_init
struct AlignmentFormat(Comparable, TrivialRegisterPassable):
    var value: UInt8

    comptime Sam = Self(0)
    comptime Bam = Self(1)
    comptime Cram = Self(2)

    def __eq__(self: Self, other: Self) -> Bool:
        return self.value == other.value

    def __lt__(self: Self, other: Self) -> Bool:
        return self.value < other.value


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


def _header_lines(text: String) -> List[String]:
    var result = List[String]()
    var current = String()
    for cp in text.codepoint_slices():
        var ch = String(cp)
        if ch == "\n":
            result.append(current^)
            current = String()
            continue
        current += ch
    if current.byte_length() > 0:
        result.append(current^)
    return result^


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


def _writer_mode(
    path: String, options: WriteOptions
) raises -> String:
    var mode = String("w")
    if not options.format:
        if options.compression_level:
            raise Error(
                "compression level requires an explicit BAM or CRAM output format"
            )
        return mode

    var format = options.format.value()
    if format == AlignmentFormat.Sam:
        if options.compression_level:
            raise Error("compression level is not supported for SAM output")
        return mode
    if format == AlignmentFormat.Bam:
        mode += "b"
    elif format == AlignmentFormat.Cram:
        mode += "c"
    else:
        raise Error("unknown alignment output format")

    if options.compression_level:
        var level = options.compression_level.value()
        if level < 0 or level > 9:
            raise Error("compression level must be between 0 and 9")
        mode += String(level)
    return mode


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


struct Record(Movable):
    var _raw: _raw.RawBamRecord

    def __init__(out self) raises:
        self._raw = _raw.RawBamRecord()

    def clone(self) raises -> Self:
        var result = Self()
        result._raw = self._raw.dup()
        return result^

    def flag(self) -> UInt16:
        return self.flag_bits()

    def flag_bits(self) -> UInt16:
        return self._raw.flag()

    def flags(self) -> SamFlag:
        return SamFlag(self.flag_bits())

    def raw_reference_id(self) -> Int32:
        return self._raw.tid()

    def reference_id(self) -> Optional[Int32]:
        var tid = self.raw_reference_id()
        if tid < 0:
            return None
        return tid

    def raw_reference_start(self) -> Int64:
        return self._raw.pos0()

    def reference_start(self) -> Optional[Int64]:
        var start0 = self.raw_reference_start()
        if self.is_unmapped() or start0 < 0:
            return None
        return start0

    def reference_end(self) -> Optional[Int64]:
        if self.is_unmapped() or self._raw.n_cigar() == 0:
            return None
        return self._raw.end_pos0()

    def reference_length(self) -> Optional[Int64]:
        var start = self.reference_start()
        var end = self.reference_end()
        if not start or not end:
            return None
        return end.value() - start.value()

    def mapping_quality(self) -> UInt8:
        return self._raw.mapq()

    def raw_next_reference_id(self) -> Int32:
        return self._raw.mate_tid()

    def next_reference_id(self) -> Optional[Int32]:
        var tid = self.raw_next_reference_id()
        if self.mate_is_unmapped() or tid < 0:
            return None
        return tid

    def raw_next_reference_start(self) -> Int64:
        return self._raw.mate_pos0()

    def next_reference_start(self) -> Optional[Int64]:
        var start0 = self.raw_next_reference_start()
        if self.mate_is_unmapped() or start0 < 0:
            return None
        return start0

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

    def has_aux(self, tag: String) raises -> Bool:
        return self._raw.aux_get(tag) != None

    def get_aux(self, tag: String) raises -> Optional[AuxValue]:
        var aux = self._raw.aux_get(tag)
        if not aux:
            return None

        var aux_type = String(chr(Int(self._raw.aux_type(aux.value()))))
        if (
            aux_type == "c"
            or aux_type == "C"
            or aux_type == "s"
            or aux_type == "S"
            or aux_type == "i"
            or aux_type == "I"
        ):
            return AuxValue.integer(self._raw.aux_to_int(aux.value()))
        if aux_type == "f" or aux_type == "d":
            return AuxValue.float(self._raw.aux_to_float(aux.value()))
        if aux_type == "A":
            return AuxValue.character(
                String(chr(Int(self._raw.aux_to_char(aux.value()))))
            )
        if aux_type == "Z":
            var value = self._raw.aux_to_string(aux.value())
            if not value:
                return AuxValue.string(String())
            return AuxValue.string(_cstring_to_string(value.value()))
        if aux_type == "H":
            var value = self._raw.aux_to_string(aux.value())
            if not value:
                return AuxValue.hex_string(String())
            return AuxValue.hex_string(_cstring_to_string(value.value()))
        if aux_type == "B":
            var subtype = String(chr(Int(aux.value()[1])))
            var length = self._raw.aux_array_len(aux.value())
            if subtype == "c" or subtype == "C":
                var bytes = List[UInt8]()
                for i in range(length):
                    bytes.append(
                        UInt8(self._raw.aux_array_int(aux.value(), i))
                    )
                return AuxValue.bytes(bytes^)
            if (
                subtype == "s"
                or subtype == "S"
                or subtype == "i"
                or subtype == "I"
            ):
                var ints = List[Int64]()
                for i in range(length):
                    ints.append(self._raw.aux_array_int(aux.value(), i))
                return AuxValue.integers(ints^)
            if subtype == "f" or subtype == "d":
                var floats = List[Float64]()
                for i in range(length):
                    floats.append(self._raw.aux_array_float(aux.value(), i))
                return AuxValue.floats(floats^)
        raise Error("unsupported aux tag type")

    def set_aux(mut self, tag: String, value: AuxValue) raises:
        if value.kind == AuxKind.Integer:
            self._raw.set_aux_int(tag, value.int_value)
            return
        if value.kind == AuxKind.Float:
            self._raw.set_aux_float(tag, Float32(value.float_value))
            return
        if value.kind == AuxKind.String or value.kind == AuxKind.HexString:
            self._raw.set_aux_string(tag, value.string_value)
            return
        raise Error("aux mutation is only supported for integer, float, and string values")

    def set_aux_int(mut self, tag: String, value: Int64) raises:
        self._raw.set_aux_int(tag, value)

    def set_aux_float(mut self, tag: String, value: Float32) raises:
        self._raw.set_aux_float(tag, value)

    def set_aux_string(mut self, tag: String, value: String) raises:
        self._raw.set_aux_string(tag, value)

    def remove_aux(mut self, tag: String) raises -> Bool:
        return self._raw.remove_aux(tag)

    def is_paired(self) -> Bool:
        return self.flags().is_paired()

    def is_proper_pair(self) -> Bool:
        return self.flags().is_proper_pair()

    def is_unmapped(self) -> Bool:
        return self.flags().is_unmapped()

    def mate_is_unmapped(self) -> Bool:
        return self.flags().mate_is_unmapped()

    def is_reverse(self) -> Bool:
        return self.flags().is_reverse()

    def mate_is_reverse(self) -> Bool:
        return self.flags().mate_is_reverse()

    def is_read1(self) -> Bool:
        return self.flags().is_read1()

    def is_read2(self) -> Bool:
        return self.flags().is_read2()

    def is_secondary(self) -> Bool:
        return self.flags().is_secondary()

    def is_qcfail(self) -> Bool:
        return self.flags().is_qcfail()

    def is_duplicate(self) -> Bool:
        return self.flags().is_duplicate()

    def is_supplementary(self) -> Bool:
        return self.flags().is_supplementary()


@fieldwise_init
struct ReadOptions(Copyable, Movable):
    var reference_path: Optional[String]
    var threads: Int
    var index_path: Optional[String]
    var require_index: Bool


@fieldwise_init
struct WriteOptions(Copyable, Movable):
    var reference_path: Optional[String]
    var threads: Int
    var format: Optional[AlignmentFormat]
    var compression_level: Optional[Int]


struct RecordsIter(Movable):
    var _reader: UnsafePointer[Reader, MutUntrackedOrigin]
    var _iter: Optional[_raw.RawHtsIterator]
    var _cached: Optional[_raw.RawBamRecord]

    def __init__(
        out self,
        reader: UnsafePointer[Reader, MutUntrackedOrigin],
        var iter: Optional[_raw.RawHtsIterator] = None,
    ):
        self._reader = reader
        self._iter = iter^
        self._cached = None

    def read_into(mut self, mut record: Record) raises -> Bool:
        if self._cached:
            var cached = self._cached^
            self._cached = None
            record._raw.copy_from(cached.value())
            return True
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

    def has_next(mut self) raises -> Bool:
        if self._cached:
            return True
        var raw_record = _raw.RawBamRecord()
        if self._iter:
            var rc = self._iter.value().next_status(
                self._reader[]._file, raw_record
            )
            if rc >= 0:
                self._cached = raw_record^
                return True
            if rc == -1:
                return False
            raise Error("failed to read indexed alignment record")

        var rc = self._reader[]._file.read1_status(
            self._reader[]._header, raw_record
        )
        if rc >= 0:
            self._cached = raw_record^
            return True
        if rc == -1:
            return False
        raise Error("failed to read alignment record")

    def pop_next(mut self) raises -> Optional[Record]:
        return self.next()


struct Reader(Movable):
    var _file: _raw.RawAlignmentFile
    var _header: _raw.RawSamHeader

    @staticmethod
    def open(
        path: String, reference_path: Optional[String] = None, threads: Int = 0
    ) raises -> Self:
        return Self(path, reference_path, threads)

    @staticmethod
    def open(path: String, var options: ReadOptions) raises -> Self:
        return Self(path, options.reference_path^, options.threads)

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
    var _index: Optional[_raw.RawHtsIndex]

    @staticmethod
    def open(
        path: String,
        index_path: Optional[String] = None,
        reference_path: Optional[String] = None,
        threads: Int = 0,
    ) raises -> Self:
        return Self(path, index_path, reference_path, threads)

    @staticmethod
    def open(
        path: String,
        var options: ReadOptions,
        index_path: Optional[String] = None,
    ) raises -> Self:
        if index_path:
            return Self(path, index_path, options.reference_path^, options.threads)
        return Self(
            path,
            options.index_path^,
            options.reference_path^,
            options.threads,
            options.require_index,
        )

    def __init__(
        out self,
        path: String,
        index_path: Optional[String] = None,
        reference_path: Optional[String] = None,
        threads: Int = 0,
        require_index: Bool = True,
    ) raises:
        self._reader = Reader(path, reference_path, threads)
        self._index = None
        if index_path:
            if require_index:
                self._index = _raw.RawHtsIndex.load_at(
                    self._reader._file, path, index_path.value()
                )
            else:
                try:
                    self._index = _raw.RawHtsIndex.load_at(
                        self._reader._file, path, index_path.value()
                    )
                except e:
                    self._index = None
        elif require_index:
            self._index = _raw.RawHtsIndex.load(self._reader._file, path)
        else:
            try:
                self._index = _raw.RawHtsIndex.load(self._reader._file, path)
            except e:
                self._index = None

    def header(self) raises -> Header:
        return self._reader.header()

    def fetch(mut self, region: Region) raises -> RecordsIter:
        if not self._index:
            raise Error("alignment index is unavailable")
        var tid = self.header().require_tid(region.contig)
        return RecordsIter(
            UnsafePointer(to=self._reader).unsafe_origin_cast[
                MutUntrackedOrigin
            ](),
            _raw.RawHtsIterator.queryi(
                self._index.value(), tid, region.start0, region.end0
            ),
        )

    def fetch_string(mut self, region: String) raises -> RecordsIter:
        if not self._index:
            raise Error("alignment index is unavailable")
        return RecordsIter(
            UnsafePointer(to=self._reader).unsafe_origin_cast[
                MutUntrackedOrigin
            ](),
            _raw.RawHtsIterator.querys(
                self._index.value(), self._reader._header, region
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
        format: Optional[AlignmentFormat] = None,
        compression_level: Optional[Int] = None,
    ) raises -> Self:
        return Self(
            path,
            header,
            reference_path,
            threads,
            format,
            compression_level,
        )

    @staticmethod
    def open(path: String, header: Header, var options: WriteOptions) raises -> Self:
        return Self(
            path,
            header,
            options.reference_path^,
            options.threads,
            options.format,
            options.compression_level,
        )

    def __init__(
        out self,
        path: String,
        header: Header,
        reference_path: Optional[String] = None,
        threads: Int = 0,
        format: Optional[AlignmentFormat] = None,
        compression_level: Optional[Int] = None,
    ) raises:
        var mode = _writer_mode(
            path,
            WriteOptions(reference_path, threads, format, compression_level),
        )
        self._file = _raw.RawAlignmentFile(path, mode)
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
