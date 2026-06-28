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

