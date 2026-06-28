from hts_mojo.bam._common import (
    _header_lines,
    _starts_with_ascii,
    _split_tab_fields,
    _field_value,
)
from hts_mojo._ffi import sam_hdr_t, sam_hdr_length, sam_hdr_dup

comptime AlignmenetFileHeader = Header


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


struct Header(Movable, Writable):
    var _raw: RawSamHeader

    def __init__(out self) raises:
        self._raw = RawSamHeader()

    @staticmethod
    def empty() raises -> Self:
        return Self()

    @staticmethod
    def from_text(text: String) raises -> Self:
        var result = Self()
        result._raw = RawSamHeader.parse(text)
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
        self._raw.append_line(
            "@SQ\tSN:" + name + "\tLN:" + String(length) + "\n"
        )

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

    def write_to[w: Writer](self, mut writer: w):
        writer.write(self.text())


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
