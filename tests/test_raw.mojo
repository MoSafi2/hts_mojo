from std.ffi import c_char
from std.sys.info import size_of
from std.testing import TestSuite

from hts_mojo._ffi import hts_free, malloc, sam_hdr_read, uint32_t
from hts_mojo._raw import (
    RawAlignmentFile,
    RawBamRecord,
    RawHtsIndex,
    RawHtsIterator,
    RawSamHeader,
    _bytes_with_nul,
    _check_nonnegative,
    _check_ptr,
    _check_zero,
    _cstr,
    _terminated,
)


def _string_from_cstr(
    ptr: UnsafePointer[c_char, ImmutUntrackedOrigin]
) -> String:
    var result = String()
    var i = 0
    while True:
        var ch = ptr[i]
        if ch == 0:
            break
        result += String(chr(Int(ch)))
        i += 1
    return result


def _string_from_borrowed(
    ptr: UnsafePointer[c_char, ImmutUntrackedOrigin], length: Int
) -> String:
    var result = String()
    for i in range(length):
        var ch = ptr[i]
        if ch == 0:
            break
        result += String(chr(Int(ch)))
    return result


def _single_match_cigar(
    length: UInt32,
) raises -> UnsafePointer[uint32_t, ImmutUntrackedOrigin]:
    var mem = malloc(UInt(size_of[UInt32]()))
    if not mem:
        raise Error("malloc failed")
    var ptr = rebind[Optional[UnsafePointer[UInt32, MutUntrackedOrigin]]](mem)
    ptr.value()[0] = UInt32(length << 4)
    return (
        ptr.value()
        .unsafe_mut_cast[False]()
        .unsafe_origin_cast[ImmutUntrackedOrigin]()
        .bitcast[uint32_t]()
    )


def _free_cigar(cigar: UnsafePointer[uint32_t, ImmutUntrackedOrigin]):
    hts_free(cigar.unsafe_mut_cast[True]().bitcast[NoneType]())


def _write_bam_fixture(path: String) raises:
    var file = RawAlignmentFile(path, String("wb"))
    var header = RawSamHeader()
    header.append_line(String("@HD\tVN:1.6\tSO:coordinate\n"))
    header.append_line(String("@SQ\tSN:chr1\tLN:1000\n"))
    file.write_header(header)

    var cigar = _single_match_cigar(UInt32(5))
    var record = RawBamRecord()
    record.set1_from_sam_fields(
        String("read-1"),
        UInt16(0),
        0,
        10,
        42,
        1,
        cigar,
        -1,
        -1,
        0,
        String("ACGTN"),
        String('!"#$%'),
    )
    file.write1(header, record)
    file.close()
    _free_cigar(cigar)


def test_cstr_helper() raises:
    var text = String("hi")
    var ptr = _cstr(text)
    if ptr[0] != 104 or ptr[1] != 105 or ptr[2] != 0:
        raise Error("_cstr produced unexpected bytes")

    var terminated = _terminated(String("bye"))
    if terminated.byte_length() != 4:
        raise Error("_terminated should append one NUL byte")

    var ok = String("ok")
    var bytes = _bytes_with_nul(ok)
    if bytes[0] != UInt8(111) or bytes[1] != UInt8(107) or bytes[2] != UInt8(0):
        raise Error("_bytes_with_nul produced unexpected bytes")


def test_check_helpers() raises:
    _check_zero(0, String("ok"))
    if _check_nonnegative(3, String("ok")) != 3:
        raise Error("_check_nonnegative returned wrong value")

    var value: Optional[String] = String("value")
    if _check_ptr(value, String("missing")) != "value":
        raise Error("_check_ptr returned wrong value")

    try:
        _check_zero(1, String("boom"))
    except e:
        pass
    else:
        raise Error("_check_zero should raise on nonzero status")

    try:
        _ = _check_nonnegative(-1, String("boom"))
    except e:
        pass
    else:
        raise Error("_check_nonnegative should raise on negative status")

    var missing: Optional[String] = None
    try:
        _ = _check_ptr(missing, String("missing"))
    except e:
        return
    raise Error("_check_ptr should raise on None")


def test_raw_header_parse_and_append() raises:
    var header = RawSamHeader()
    var _ = header.ptr()
    header.append_line(String("@HD\tVN:1.6\tSO:coordinate\n"))
    header.append_line(String("@SQ\tSN:chr1\tLN:1000\n"))

    if header.n_ref() != 1:
        raise Error("header should have one reference")
    if header.name2tid(String("chr1")) != 0:
        raise Error("name2tid failed")
    if header.tid2len(0) != 1000:
        raise Error("tid2len failed")
    if not header.borrowed_text_ptr():
        raise Error("missing borrowed header text")

    var text = _string_from_borrowed(
        header.borrowed_text_ptr().value(), header.text_length()
    )
    if text.byte_length() == 0:
        raise Error("borrowed header text should not be empty")

    var parsed = RawSamHeader.parse(
        String("@HD\tVN:1.6\tSO:coordinate\n@SQ\tSN:chr1\tLN:1000\n")
    )
    if parsed.n_ref() != 1:
        raise Error("parsed header should preserve references")

    var dup = parsed.dup()
    if not dup.tid2name(0):
        raise Error("tid2name failed")


def test_raw_header_adopt_and_write_to() raises:
    var source_path = String("/tmp/hts_mojo_raw_header_source.sam")
    var source_file = RawAlignmentFile(source_path, String("w"))
    var source_header = RawSamHeader()
    source_header.append_line(String("@HD\tVN:1.6\tSO:coordinate\n"))
    source_header.append_line(String("@SQ\tSN:chr2\tLN:200\n"))
    source_header.write_to(source_file)
    source_file.close()

    var reader = RawAlignmentFile(source_path, String("r"))
    var adopted = RawSamHeader.adopt(sam_hdr_read(reader.ptr()))
    reader.close()
    if adopted.n_ref() != 1:
        raise Error("adopted header should preserve references")

    var path = String("/tmp/hts_mojo_raw_header_write.sam")
    var file = RawAlignmentFile(path, String("w"))
    var _ = file.ptr()
    adopted.write_to(file)
    file.close()


def test_raw_header_adopt_rejects_none() raises:
    try:
        _ = RawSamHeader.adopt(None)
    except e:
        return
    raise Error("RawSamHeader.adopt should reject None")


def test_raw_record_accessors() raises:
    var cigar = _single_match_cigar(UInt32(5))
    var record = RawBamRecord()
    var _ = record.ptr()
    record.set1_from_sam_fields(
        String("read-1"),
        UInt16(0),
        0,
        10,
        42,
        1,
        cigar,
        -1,
        -1,
        99,
        String("ACGTN"),
        String('!"#$%'),
    )

    if record.tid() != 0 or record.pos0() != 10:
        _free_cigar(cigar)
        raise Error("record coordinates mismatch")
    if record.end_pos0() != 15:
        _free_cigar(cigar)
        raise Error("record end_pos0 mismatch")
    if record.flag() != 0 or record.mapq() != 42:
        _free_cigar(cigar)
        raise Error("record core fields mismatch")
    if record.mate_tid() != -1 or record.mate_pos0() != -1:
        _free_cigar(cigar)
        raise Error("mate fields mismatch")
    if (
        record.insert_size() != 99
        or record.l_seq() != 5
        or record.n_cigar() != 1
    ):
        _free_cigar(cigar)
        raise Error("record lengths mismatch")
    if record.raw_core_ptr()[].l_qseq != 5:
        _free_cigar(cigar)
        raise Error("raw_core_ptr mismatch")
    if _string_from_cstr(record.borrowed_qname_ptr()) != "read-1":
        _free_cigar(cigar)
        raise Error("borrowed_qname_ptr mismatch")
    if not record.borrowed_cigar_ptr() or record.borrowed_cigar_ptr().value()[
        0
    ] != UInt32(5 << 4):
        _free_cigar(cigar)
        raise Error("borrowed_cigar_ptr mismatch")
    if not record.borrowed_seq_ptr() or not record.borrowed_qual_ptr():
        _free_cigar(cigar)
        raise Error("missing borrowed sequence or quality pointer")
    if record.borrowed_aux_ptr():
        _free_cigar(cigar)
        raise Error("expected no aux payload")
    if record.aux_len() != 0:
        _free_cigar(cigar)
        raise Error("aux_len should be zero")
    if record.get_base4(0) != 1 or record.get_base4(4) != 15:
        _free_cigar(cigar)
        raise Error("get_base4 mismatch")
    _ = record.get_qual(0)
    _ = record.get_qual(4)

    var copy = record.dup()
    if copy.end_pos0() != 15:
        _free_cigar(cigar)
        raise Error("dup mismatch")

    var copied = RawBamRecord()
    copied.copy_from(record)
    if copied.mapq() != 42 or copied.l_seq() != 5:
        _free_cigar(cigar)
        raise Error("copy_from mismatch")

    _free_cigar(cigar)


def test_raw_record_error_paths() raises:
    var record = RawBamRecord()

    try:
        record.set1_from_sam_fields(
            String("read-1"),
            UInt16(0),
            0,
            10,
            42,
            0,
            None,
            -1,
            -1,
            0,
            String("AC"),
            String("!"),
        )
    except e:
        pass
    else:
        raise Error("set1_from_sam_fields should reject mismatched lengths")

    try:
        record.set1_from_sam_fields(
            String("read-1"),
            UInt16(0),
            0,
            10,
            42,
            0,
            None,
            -1,
            -1,
            0,
            String("A"),
            String(" "),
        )
    except e:
        pass
    else:
        raise Error("set1_from_sam_fields should reject non-SAM qualities")

    var cigar = _single_match_cigar(UInt32(1))
    record.set1_from_sam_fields(
        String("read-1"),
        UInt16(0),
        0,
        10,
        42,
        1,
        cigar,
        -1,
        -1,
        0,
        String("A"),
        String("!"),
    )

    try:
        _ = record.get_base4(-1)
    except e:
        pass
    else:
        _free_cigar(cigar)
        raise Error("get_base4 should reject negative indexes")

    try:
        _ = record.get_qual(1)
    except e:
        _free_cigar(cigar)
        return
    _free_cigar(cigar)
    raise Error("get_qual should reject out-of-range indexes")


def test_raw_file_read_write_and_iteration() raises:
    var path = String("/tmp/hts_mojo_raw_test.bam")
    _write_bam_fixture(path)
    RawHtsIndex.build(path)

    var file = RawAlignmentFile(path, String("rb"))
    var header = file.read_header()
    if header.name2tid(String("chr1")) != 0:
        raise Error("header lookup failed")

    var record = RawBamRecord()
    var rc = file.read1_status(header, record)
    if rc < 0:
        raise Error("read1_status should read one record")
    if _string_from_cstr(record.borrowed_qname_ptr()) != "read-1":
        raise Error("read record qname mismatch")
    _ = record.get_qual(0)
    _ = record.get_qual(4)
    rc = file.read1_status(header, record)
    if rc != -1:
        raise Error("expected EOF from read1_status")
    file.close()

    var indexed_file = RawAlignmentFile(path, String("rb"))
    var indexed_header = indexed_file.read_header()
    var index = RawHtsIndex.load(indexed_file, path)

    var tid_iter = RawHtsIterator.queryi(index, 0, 0, 1000)
    var _ = tid_iter.ptr()
    rc = tid_iter.next_status(indexed_file, record)
    if rc < 0 or record.pos0() != 10:
        raise Error("queryi should return the mapped record")
    rc = tid_iter.next_status(indexed_file, record)
    if rc != -1:
        raise Error("queryi should reach EOF")

    var region_iter = RawHtsIterator.querys(
        index, indexed_header, String("chr1:1-1000")
    )
    rc = region_iter.next_status(indexed_file, record)
    if rc < 0 or record.end_pos0() != 15:
        raise Error("querys should return the mapped record")

    indexed_file.close()


def test_raw_index_load_variants() raises:
    var path = String("/tmp/hts_mojo_raw_index_variants.bam")
    _write_bam_fixture(path)
    RawHtsIndex.build(path)

    var file = RawAlignmentFile(path, String("rb"))
    var default_index = RawHtsIndex.load(file, path)
    var explicit_index = RawHtsIndex.load_at(file, path, String(path + ".bai"))
    var flagged_index = RawHtsIndex.load_with_flags(
        file, path, String(path + ".bai"), 0
    )

    var _ = default_index.ptr()
    var __ = explicit_index.ptr()
    var ___ = flagged_index.ptr()
    file.close()


def test_raw_alignment_file_thread_and_reference_methods() raises:
    var path = String("/tmp/hts_mojo_raw_thread_ref.sam")
    var file = RawAlignmentFile(path, String("w"))
    file.set_threads(1)
    try:
        file.set_reference(String("/tmp/nonexistent-reference.fa"))
    except e:
        pass
    file.close()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
