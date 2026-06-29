from hts_mojo._ffi import (
    bam_aux2A,
    bam_aux2Z,
    bam_aux2f,
    bam_aux2i,
    bam_auxB2f,
    bam_auxB2i,
    bam_auxB_len,
)


from std.ffi import c_char

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
    bam_copy1,
    bam_destroy1,
    bam_dup1,
    bam_endpos,
    bam_init1,
    bam_set1,
    c_float,
    hts_mojo_bam_aux_del_by_tag,
    hts_mojo_bam_aux_get,
    hts_mojo_bam_aux_update_float,
    hts_mojo_bam_aux_update_int,
    hts_mojo_bam_aux_update_str,
    uint32_t,
)

from hts_mojo.bam._common import (
    _cstr_ptr,
    _check_sam_text_ascii,
    _check_zero,
    _check_nonnegative,
    _check_ptr,
    _aux_tag_cstr,
    _OwnedByteBuffer,
    _check_i32,
    _bytes_with_nul_ptr,
    _ensure_nul,
    _cstring_to_string,
    _cigar_op_char,
    _seq_char,
    _hex_u16,
    _optional_int64_to_string,
    _raw_bytes_to_hex,
    _aux_value_to_string,
)
from std.io import Writer as IOWriter


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


struct Record(Movable, Writable):
    var _raw: RawBamRecord

    def __init__(out self) raises:
        self._raw = RawBamRecord()

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
                    bytes.append(UInt8(self._raw.aux_array_int(aux.value(), i)))
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
        raise Error(
            "aux mutation is only supported for integer, float, and string"
            " values"
        )

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

    def write_to[w: IOWriter](self, mut writer: w):
        writer.write(
            "Record{qname=",
            self._query_name_or_default(),
            ", flag=",
            _hex_u16(self.flag_bits()),
            ", tid=",
            self.raw_reference_id(),
            ", pos0=",
            self.raw_reference_start(),
            ", end0=",
            _optional_int64_to_string(self.reference_end()),
            ", len=",
            self.query_length(),
            ", mapq=",
            self.mapping_quality(),
            ", mtid=",
            self.raw_next_reference_id(),
            ", mpos0=",
            self.raw_next_reference_start(),
            ", isize=",
            self.template_length(),
            ", aux=",
            self._aux_summary(),
            ", raw=",
            _raw_bytes_to_hex(self._raw_bytes()),
            ", cigar=",
            self._cigar_string_or_default(),
            ", seq=",
            self._query_sequence_or_default(),
            ", qual=",
            self._query_qualities_or_default(),
            "}",
        )

    def _query_name_or_default(self) -> String:
        var ptr = self._raw.borrowed_qname_ptr()
        if not ptr:
            return String("*")
        return _cstring_to_string(ptr.value())

    def _cigar_string_or_default(self) -> String:
        if self._raw.n_cigar() == 0:
            return String("*")
        var ptr = self._raw.borrowed_cigar_ptr()
        if not ptr:
            return String("*")

        var result = String()
        for i in range(self._raw.n_cigar()):
            var raw = ptr.value()[i]
            result += String(raw >> 4)
            result += _cigar_op_char(CigarOp(raw & UInt32(0xF)))
        return result^

    def _query_sequence_or_default(self) -> String:
        var seq = self._raw.borrowed_seq_ptr()
        if not seq:
            return String("*")

        var result = String()
        for i in range(self._raw.l_seq()):
            var byte = seq.value()[i >> 1]
            if (i & 1) == 0:
                result += _seq_char(byte >> 4)
            else:
                result += _seq_char(byte & UInt8(0xF))
        if result.byte_length() == 0:
            return String("*")
        return result^

    def _query_qualities_or_default(self) -> String:
        var qual = self._raw.borrowed_qual_ptr()
        if not qual:
            return String("*")

        var result = String("[")
        for i in range(self._raw.l_seq()):
            if i > 0:
                result += ","
            result += String(qual.value()[i])
        result += "]"
        return result^

    def _raw_bytes(self) -> List[UInt8]:
        var result = List[UInt8]()
        var data = self._raw._data_ptr()
        if not data:
            return result^
        for i in range(self._raw._data_len()):
            result.append(data.value()[i])
        return result^

    def _aux_summary(self) -> String:
        var result = String("[")
        var aux = self._raw.borrowed_aux_ptr()
        if not aux:
            return String("[]")

        var limit = self._raw.aux_len()
        var i = 0
        var first = True
        while i + 2 < limit:
            if not first:
                result += ", "
            first = False

            var tag = String(chr(Int(aux.value()[i])))
            tag += String(chr(Int(aux.value()[i + 1])))
            var aux_field = aux.value() + (i + 2)
            var aux_type = String(chr(Int(aux_field[0])))
            var display_type = aux_type
            if (
                aux_type == "c"
                or aux_type == "C"
                or aux_type == "s"
                or aux_type == "S"
                or aux_type == "i"
                or aux_type == "I"
            ):
                display_type = String("i")
            result += tag
            result += "="
            result += display_type
            result += ":"
            result += _aux_value_to_string(aux_field)

            if aux_type == "Z" or aux_type == "H":
                var j = 1
                while aux_field[j] != 0:
                    j += 1
                i += 2 + 1 + j + 1
                continue
            if aux_type == "B":
                var subtype = String(chr(Int(aux_field[1])))
                var count = Int(
                    UInt32(aux_field[2])
                    | (UInt32(aux_field[3]) << 8)
                    | (UInt32(aux_field[4]) << 16)
                    | (UInt32(aux_field[5]) << 24)
                )
                var element_size = 1
                if subtype == "s" or subtype == "S":
                    element_size = 2
                elif subtype == "i" or subtype == "I" or subtype == "f":
                    element_size = 4
                i += 2 + 1 + 1 + 4 + (count * element_size)
                continue

            if aux_type == "c" or aux_type == "C" or aux_type == "A":
                i += 2 + 1 + 1
            elif aux_type == "s" or aux_type == "S":
                i += 2 + 1 + 2
            elif aux_type == "i" or aux_type == "I" or aux_type == "f":
                i += 2 + 1 + 4
            else:
                break
        result += "]"
        return result^


struct RawBamRecord(Movable):
    var _ptr: Optional[UnsafePointer[bam1_t, MutUntrackedOrigin]]

    def __init__(out self) raises:
        self._ptr = bam_init1()
        if not self._ptr:
            raise Error("failed to allocate alignment record")

    def __del__(deinit self):
        if self._ptr:
            bam_destroy1(self._ptr.value())

    def ptr(self) raises -> UnsafePointer[bam1_t, MutUntrackedOrigin]:
        if not self._ptr:
            raise Error("alignment record is unavailable")
        return self._ptr.value()

    def unsafe_ptr_unchecked(self) -> UnsafePointer[bam1_t, MutUntrackedOrigin]:
        return self._ptr.value()

    def dup(self) raises -> Self:
        return Self._adopt_copy(
            bam_dup1(
                self.ptr()
                .unsafe_mut_cast[False]()
                .unsafe_origin_cast[ImmutUntrackedOrigin]()
            )
        )

    def copy_from(mut self, read other: RawBamRecord) raises:
        self._ptr = _check_ptr(
            bam_copy1(
                self.ptr(),
                other.ptr()
                .unsafe_mut_cast[False]()
                .unsafe_origin_cast[ImmutUntrackedOrigin](),
            ),
            "failed to copy alignment record",
        )

    def set1(
        mut self,
        l_qname: UInt,
        qname: UnsafePointer[c_char, ImmutUntrackedOrigin],
        flag: UInt16,
        tid: Int32,
        pos: Int64,
        mapq: UInt8,
        n_cigar: UInt,
        cigar: Optional[UnsafePointer[uint32_t, ImmutUntrackedOrigin]],
        mtid: Int32,
        mpos: Int64,
        isize: Int64,
        l_seq: UInt,
        seq: UnsafePointer[c_char, ImmutUntrackedOrigin],
        qual: UnsafePointer[c_char, ImmutUntrackedOrigin],
        l_aux: UInt,
    ) raises:
        _ = _check_nonnegative(
            Int(
                bam_set1(
                    self.ptr(),
                    l_qname,
                    qname,
                    flag,
                    tid,
                    pos,
                    mapq,
                    n_cigar,
                    cigar,
                    mtid,
                    mpos,
                    isize,
                    l_seq,
                    seq,
                    qual,
                    l_aux,
                )
            ),
            "failed to populate alignment record",
        )

    def set1_from_sam_fields(
        mut self,
        qname: String,
        flag: UInt16,
        tid: Int32,
        pos: Int64,
        mapq: UInt8,
        n_cigar: UInt,
        cigar: Optional[UnsafePointer[uint32_t, ImmutUntrackedOrigin]],
        mtid: Int32,
        mpos: Int64,
        isize: Int64,
        seq: String,
        qual: String,
        l_aux: UInt = 0,
    ) raises:
        _check_sam_text_ascii(
            qname, "query name must be ASCII SAM text without NUL bytes"
        )
        _check_sam_text_ascii(
            seq, "sequence must be ASCII SAM text without NUL bytes"
        )

        var missing_qual = qual == String("*")
        if not missing_qual:
            _check_sam_text_ascii(
                qual, "quality string must be ASCII SAM text without NUL bytes"
            )

        if not missing_qual and seq.byte_length() != qual.byte_length():
            raise Error(
                "sequence and quality strings must have the same length"
            )

        var seq_len = Int(seq.byte_length())
        var seq_c = seq
        var encoded_qual = _OwnedByteBuffer(seq_len)
        if seq_len > 0 and not encoded_qual.ptr():
            raise Error("failed to allocate temporary quality buffer")

        if seq_len > 0:
            if missing_qual:
                for i in range(seq_len):
                    encoded_qual.ptr().value()[i] = UInt8(0xFF)
            else:
                var qual_c = qual
                var qual_bytes = _bytes_with_nul_ptr(qual_c)
                for i in range(seq_len):
                    var phred_ascii = qual_bytes[i]
                    if phred_ascii < UInt8(33):
                        raise Error(
                            "quality string must use SAM ASCII with +33 offset"
                        )
                    encoded_qual.ptr().value()[i] = phred_ascii - UInt8(33)

        var qname_c = qname
        _ensure_nul(qname_c)
        var qual_ptr = UnsafePointer[
            c_char, ImmutUntrackedOrigin
        ].unsafe_dangling()
        if seq_len > 0:
            qual_ptr = (
                encoded_qual.ptr()
                .value()
                .unsafe_mut_cast[False]()
                .unsafe_origin_cast[ImmutUntrackedOrigin]()
                .bitcast[c_char]()
            )
        self.set1(
            UInt(qname_c.byte_length()),
            _cstr_ptr(qname_c),
            flag,
            tid,
            pos,
            mapq,
            n_cigar,
            cigar,
            mtid,
            mpos,
            isize,
            UInt(seq_len),
            _cstr_ptr(seq_c),
            qual_ptr,
            l_aux,
        )

    def raw_core_ptr(self) -> UnsafePointer[bam1_core_t, MutUntrackedOrigin]:
        return UnsafePointer(
            to=self.unsafe_ptr_unchecked()[].core
        ).unsafe_origin_cast[MutUntrackedOrigin]()

    def tid(self) -> Int32:
        return self.unsafe_ptr_unchecked()[].core.tid

    def pos0(self) -> Int64:
        return self.unsafe_ptr_unchecked()[].core.pos

    def end_pos0(self) -> Int64:
        return Int64(
            bam_endpos(
                self.unsafe_ptr_unchecked()
                .unsafe_mut_cast[False]()
                .unsafe_origin_cast[ImmutUntrackedOrigin]()
            )
        )

    def flag(self) -> UInt16:
        return self.unsafe_ptr_unchecked()[].core.flag

    def mapq(self) -> UInt8:
        return self.unsafe_ptr_unchecked()[].core.qual

    def mate_tid(self) -> Int32:
        return self.unsafe_ptr_unchecked()[].core.mtid

    def mate_pos0(self) -> Int64:
        return self.unsafe_ptr_unchecked()[].core.mpos

    def insert_size(self) -> Int64:
        return self.unsafe_ptr_unchecked()[].core.isize

    def l_seq(self) -> Int:
        return Int(self.unsafe_ptr_unchecked()[].core.l_qseq)

    def n_cigar(self) -> Int:
        return Int(self.unsafe_ptr_unchecked()[].core.n_cigar)

    def borrowed_qname_ptr(
        self,
    ) -> Optional[UnsafePointer[c_char, ImmutUntrackedOrigin]]:
        if not self._data_ptr():
            return None
        return (
            self._data_ptr()
            .value()
            .unsafe_mut_cast[False]()
            .unsafe_origin_cast[ImmutUntrackedOrigin]()
            .bitcast[c_char]()
        )

    def borrowed_cigar_ptr(
        self,
    ) -> Optional[UnsafePointer[uint32_t, ImmutUntrackedOrigin]]:
        if self.n_cigar() == 0 or not self._data_ptr():
            return None
        return self._offset_ptr(self._qname_bytes()).value().bitcast[uint32_t]()

    def borrowed_seq_ptr(
        self,
    ) -> Optional[UnsafePointer[UInt8, ImmutUntrackedOrigin]]:
        if self.l_seq() == 0 or not self._data_ptr():
            return None
        return self._offset_ptr(self._seq_offset())

    def borrowed_qual_ptr(
        self,
    ) -> Optional[UnsafePointer[UInt8, ImmutUntrackedOrigin]]:
        if self.l_seq() == 0 or not self._data_ptr():
            return None
        return self._offset_ptr(self._qual_offset())

    def borrowed_aux_ptr(
        self,
    ) -> Optional[UnsafePointer[UInt8, ImmutUntrackedOrigin]]:
        if self.aux_len() == 0 or not self._data_ptr():
            return None
        return self._offset_ptr(self._aux_offset())

    def aux_len(self) -> Int:
        var length = self._data_len() - self._aux_offset()
        if length < 0:
            return 0
        return length

    def aux_get(
        self, tag: String
    ) raises -> Optional[UnsafePointer[UInt8, ImmutUntrackedOrigin]]:
        var tag_key = _aux_tag_cstr(tag)
        var ptr = hts_mojo_bam_aux_get(
            self.ptr()
            .unsafe_mut_cast[False]()
            .unsafe_origin_cast[ImmutUntrackedOrigin](),
            _cstr_ptr(tag_key),
        )
        if not ptr:
            return None
        return (
            ptr.value()
            .unsafe_mut_cast[False]()
            .unsafe_origin_cast[ImmutUntrackedOrigin]()
        )

    def aux_type(
        self, aux: UnsafePointer[UInt8, ImmutUntrackedOrigin]
    ) -> c_char:
        return c_char(Int(aux[0]))

    def aux_to_int(
        self, aux: UnsafePointer[UInt8, ImmutUntrackedOrigin]
    ) -> Int64:
        return Int64(bam_aux2i(aux))

    def aux_to_float(
        self, aux: UnsafePointer[UInt8, ImmutUntrackedOrigin]
    ) -> Float64:
        return Float64(bam_aux2f(aux))

    def aux_to_char(
        self, aux: UnsafePointer[UInt8, ImmutUntrackedOrigin]
    ) -> c_char:
        return bam_aux2A(aux)

    def aux_to_string(
        self, aux: UnsafePointer[UInt8, ImmutUntrackedOrigin]
    ) -> Optional[UnsafePointer[c_char, ImmutUntrackedOrigin]]:
        var ptr = bam_aux2Z(aux)
        if not ptr:
            return None
        return (
            ptr.value()
            .unsafe_mut_cast[False]()
            .unsafe_origin_cast[ImmutUntrackedOrigin]()
        )

    def aux_array_len(
        self, aux: UnsafePointer[UInt8, ImmutUntrackedOrigin]
    ) -> Int:
        return Int(bam_auxB_len(aux))

    def aux_array_int(
        self, aux: UnsafePointer[UInt8, ImmutUntrackedOrigin], index: Int
    ) raises -> Int64:
        if index < 0:
            raise Error("aux array index out of range")
        return Int64(bam_auxB2i(aux, UInt32(index)))

    def aux_array_float(
        self, aux: UnsafePointer[UInt8, ImmutUntrackedOrigin], index: Int
    ) raises -> Float64:
        if index < 0:
            raise Error("aux array index out of range")
        return Float64(bam_auxB2f(aux, UInt32(index)))

    def set_aux_int(mut self, tag: String, value: Int64) raises:
        var tag_key = _aux_tag_cstr(tag)
        _check_zero(
            Int(
                hts_mojo_bam_aux_update_int(
                    self.ptr(), _cstr_ptr(tag_key), value
                )
            ),
            "failed to update integer aux tag",
        )

    def set_aux_float(mut self, tag: String, value: Float32) raises:
        var tag_key = _aux_tag_cstr(tag)
        _check_zero(
            Int(
                hts_mojo_bam_aux_update_float(
                    self.ptr(), _cstr_ptr(tag_key), c_float(value)
                )
            ),
            "failed to update float aux tag",
        )

    def set_aux_string(mut self, tag: String, value: String) raises:
        _check_sam_text_ascii(
            value, "aux string must be ASCII SAM text without NUL bytes"
        )
        var tag_key = _aux_tag_cstr(tag)
        var value_c = value
        _check_zero(
            Int(
                hts_mojo_bam_aux_update_str(
                    self.ptr(),
                    _cstr_ptr(tag_key),
                    _check_i32(value.byte_length() + 1, "aux string too long"),
                    _cstr_ptr(value_c),
                )
            ),
            "failed to update string aux tag",
        )

    def remove_aux(mut self, tag: String) raises -> Bool:
        var tag_key = _aux_tag_cstr(tag)
        var rc = Int(
            hts_mojo_bam_aux_del_by_tag(self.ptr(), _cstr_ptr(tag_key))
        )
        if rc == 1:
            return False
        _check_zero(rc, "failed to remove aux tag")
        return True

    def get_base4(self, i: Int) raises -> UInt8:
        if i < 0 or i >= self.l_seq():
            raise Error("base index out of range")
        var seq = _check_ptr(self.borrowed_seq_ptr(), "missing sequence data")
        var packed = seq[i >> 1]
        if (i & 1) == 0:
            return (packed >> 4) & UInt8(0xF)
        return packed & UInt8(0xF)

    def get_qual(self, i: Int) raises -> UInt8:
        if i < 0 or i >= self.l_seq():
            raise Error("quality index out of range")
        var qual = _check_ptr(self.borrowed_qual_ptr(), "missing quality data")
        return qual[i]

    @staticmethod
    def _adopt_copy(
        ptr: Optional[UnsafePointer[bam1_t, MutUntrackedOrigin]]
    ) raises -> Self:
        var result = Self()
        if result._ptr:
            bam_destroy1(result._ptr.value())
        result._ptr = _check_ptr(ptr, "failed to duplicate alignment record")
        return result^

    @staticmethod
    def adopt(
        ptr: Optional[UnsafePointer[bam1_t, MutUntrackedOrigin]]
    ) raises -> Self:
        var result = Self()
        if result._ptr:
            bam_destroy1(result._ptr.value())
        result._ptr = _check_ptr(ptr, "failed to adopt alignment record")
        return result^

    def _data_ptr(self) -> Optional[UnsafePointer[UInt8, MutUntrackedOrigin]]:
        return self.unsafe_ptr_unchecked()[].data

    def _data_len(self) -> Int:
        return Int(self.unsafe_ptr_unchecked()[].l_data)

    def _qname_bytes(self) -> Int:
        return Int(self.unsafe_ptr_unchecked()[].core.l_qname)

    def _cigar_bytes(self) -> Int:
        return self.n_cigar() * 4

    def _seq_offset(self) -> Int:
        return self._qname_bytes() + self._cigar_bytes()

    def _seq_bytes(self) -> Int:
        return (self.l_seq() + 1) >> 1

    def _qual_offset(self) -> Int:
        return self._seq_offset() + self._seq_bytes()

    def _aux_offset(self) -> Int:
        return self._qual_offset() + self.l_seq()

    def _offset_ptr(
        self, offset: Int
    ) -> Optional[UnsafePointer[UInt8, ImmutUntrackedOrigin]]:
        if not self._data_ptr():
            return None
        return (
            self._data_ptr()
            .value()
            .unsafe_mut_cast[False]()
            .unsafe_origin_cast[ImmutUntrackedOrigin]()
            + offset
        )


comptime BamRecord = Record
