from std.ffi import CStringSlice, c_char
from hts_mojo._ffi import malloc, hts_free
from hts_mojo._ffi import (
    bam_aux2A,
    bam_aux2Z,
    bam_aux2f,
    bam_aux2i,
    bam_auxB2f,
    bam_auxB2i,
    bam_auxB_len,
)


comptime _HEX_DIGITS = "0123456789abcdef"


def _ensure_nul(mut s: String):
    if s.byte_length() == 0:
        s += "\0"
        return
    if String(s[byte=s.byte_length() - 1]) != "\0":
        s += "\0"


def _terminated(s: String) -> String:
    var result = s
    _ensure_nul(result)
    return result^


def _check_sam_text_ascii(value: String, context: String) raises:
    for cp in value.codepoint_slices():
        var ch = String(cp)
        if ch == "\0":
            raise Error(context)
        if ch.byte_length() != 1:
            raise Error(context)


def _cstr_ptr(
    var s: String,
) raises -> UnsafePointer[c_char, ImmutUntrackedOrigin]:
    _ensure_nul(s)
    return (
        CStringSlice(s)
        .as_bytes_with_nul()
        .unsafe_ptr()
        .unsafe_origin_cast[ImmutUntrackedOrigin]()
        .bitcast[c_char]()
    )


def _bytes_with_nul_ptr(
    var s: String,
) raises -> UnsafePointer[UInt8, ImmutUntrackedOrigin]:
    _ensure_nul(s)
    return (
        CStringSlice(s)
        .as_bytes_with_nul()
        .unsafe_ptr()
        .unsafe_origin_cast[ImmutUntrackedOrigin]()
        .bitcast[UInt8]()
    )


def _aux_tag(tag: String) raises -> InlineArray[c_char, 2]:
    if tag.byte_length() != 2:
        raise Error("aux tag must be exactly two ASCII characters")
    _check_sam_text_ascii(tag, "aux tag must be exactly two ASCII characters")
    var tag_c = tag
    var tag_bytes = _bytes_with_nul_ptr(tag_c)
    var result = InlineArray[c_char, 2](fill=c_char(0))
    result[0] = c_char(Int(tag_bytes[0]))
    result[1] = c_char(Int(tag_bytes[1]))
    return result^


def _aux_tag_cstr(tag: String) raises -> String:
    if tag.byte_length() != 2:
        raise Error("aux tag must be exactly two ASCII characters")
    _check_sam_text_ascii(tag, "aux tag must be exactly two ASCII characters")
    return _terminated(tag)


struct _OwnedByteBuffer(Movable):
    var _ptr: Optional[UnsafePointer[UInt8, MutUntrackedOrigin]]

    def __init__(out self, size: Int) raises:
        if size <= 0:
            self._ptr = None
            return
        var mem = malloc(UInt(size))
        if not mem:
            raise Error("failed to allocate temporary BAM buffer")
        self._ptr = rebind[Optional[UnsafePointer[UInt8, MutUntrackedOrigin]]](
            mem
        )
        for i in range(size):
            self._ptr.value()[i] = UInt8(0)

    def __del__(deinit self):
        if self._ptr:
            hts_free(self._ptr.value().bitcast[NoneType]())

    def ptr(self) -> Optional[UnsafePointer[UInt8, MutUntrackedOrigin]]:
        return self._ptr


def _check_zero(code: Int, context: String) raises:
    if code != 0:
        raise Error(context)


def _check_nonnegative(code: Int, context: String) raises -> Int:
    if code < 0:
        raise Error(context)
    return code


def _check_i32(value: Int, context: String) raises -> Int32:
    if value < -2147483648 or value > 2147483647:
        raise Error(context)
    return Int32(value)


def _check_nonnegative_i32(value: Int, context: String) raises -> Int32:
    if value < 0:
        raise Error(context)
    return _check_i32(value, context)


def _check_ptr[
    T: Movable & Copyable
](value: Optional[T], context: String) raises -> T:
    if not value:
        raise Error(context)
    return value.value().copy()


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


def _aux_value_to_string(
    aux: UnsafePointer[UInt8, ImmutUntrackedOrigin],
) -> String:
    var aux_type = String(chr(Int(aux[0])))
    if (
        aux_type == "c"
        or aux_type == "C"
        or aux_type == "s"
        or aux_type == "S"
        or aux_type == "i"
        or aux_type == "I"
    ):
        return String(bam_aux2i(aux))
    if aux_type == "f" or aux_type == "d":
        return String(bam_aux2f(aux))
    if aux_type == "A":
        return String(chr(Int(bam_aux2A(aux))))
    if aux_type == "Z" or aux_type == "H":
        var ptr = bam_aux2Z(aux)
        if not ptr:
            return String()
        return _cstring_to_string(ptr.value())
    if aux_type == "B":
        var subtype = String(chr(Int(aux[1])))
        var length = Int(bam_auxB_len(aux))
        var result = String(subtype)
        result += "["
        for i in range(length):
            if i > 0:
                result += ","
            if subtype == "f" or subtype == "d":
                result += String(bam_auxB2f(aux, UInt32(i)))
            else:
                result += String(bam_auxB2i(aux, UInt32(i)))
        result += "]"
        return result
    return String("?")





def _hex_u16(value: UInt16) -> String:
    var result = String("0x")
    result += String(_HEX_DIGITS[byte=Int((value >> 12) & UInt16(0xF))])
    result += String(_HEX_DIGITS[byte=Int((value >> 8) & UInt16(0xF))])
    result += String(_HEX_DIGITS[byte=Int((value >> 4) & UInt16(0xF))])
    result += String(_HEX_DIGITS[byte=Int(value & UInt16(0xF))])
    return result



def _hex_byte(value: UInt8) -> String:
    var result = String("0x")
    result += String(_HEX_DIGITS[byte=Int(value >> 4)])
    result += String(_HEX_DIGITS[byte=Int(value & UInt8(0xF))])
    return result


def _optional_int64_to_string(value: Optional[Int64]) -> String:
    if not value:
        return String("*")
    return String(value.value())


def _raw_bytes_to_hex(bytes: List[UInt8]) -> String:
    var result = String("0x")
    for byte in bytes:
        result += String(_HEX_DIGITS[byte=Int(byte >> 4)])
        result += String(_HEX_DIGITS[byte=Int(byte & UInt8(0xF))])
    return result





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

