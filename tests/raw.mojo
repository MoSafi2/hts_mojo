from std.sys.info import size_of
from std.testing import TestSuite

from hts_mojo._ffi import hts_free, malloc, sam_hdr_destroy, sam_hdr_parse, sam_hdr_write, sam_write1
from hts_mojo._raw import (
    RawBamRecord,
    RawHtsIndex,
    RawHtsIterator,
    RawSamFile,
    RawSamHeader,
    _check_code,
    _check_not_none,
    _cstr,
)


def _terminated(text: String) -> String:
    return text + "\0"


def test_cstr_helper() raises:
    var text = String("hi")
    var ptr = _cstr(text)
    if ptr[0] != 104 or ptr[1] != 105 or ptr[2] != 0:
        raise Error("_cstr produced unexpected bytes")


def test_check_code() raises:
    _check_code(0, String("ok"))
    try:
        _check_code(1, String("boom"))
    except e:
        return
    raise Error("_check_code should raise on nonzero status")


def test_check_not_none() raises:
    var text: Optional[String] = String("value")
    var copy = _check_not_none(text, String("missing"))
    if copy != "value":
        raise Error("_check_not_none returned wrong value")

    var missing: Optional[String] = None
    try:
        _ = _check_not_none(missing, String("missing"))
    except e:
        return
    raise Error("_check_not_none should raise on None")


def _write_fixture(path: String) raises:
    var header_text = String(
        "@HD\tVN:1.6\tSO:coordinate\n@SQ\tSN:chr1\tLN:1000\n"
    )
    var header_text_c = _terminated(header_text)
    var header = sam_hdr_parse(UInt(header_text.byte_length()), _cstr(header_text_c))
    if not header:
        raise Error("sam_hdr_parse failed")
    var file = RawSamFile(path, _terminated(String("wb")))
    var header_ptr = (
        header.value()
        .unsafe_mut_cast[False]()
        .unsafe_origin_cast[ImmutUntrackedOrigin]()
    )
    var rc = sam_hdr_write(file.ptr(), header_ptr)
    if rc != 0:
        raise Error("sam_hdr_write failed")

    var record = RawBamRecord()
    var seq = String("ACGTN")
    var qual = String('!"#$%')
    var cigar_mem = malloc(UInt(size_of[UInt32]()))
    if not cigar_mem:
        raise Error("malloc failed")
    var cigar_ptr = rebind[Optional[UnsafePointer[UInt32, MutUntrackedOrigin]]](
        cigar_mem
    )
    cigar_ptr.value()[0] = UInt32(UInt(seq.byte_length()) << 4)
    var cigar_arg = (
        cigar_ptr.value()
        .unsafe_mut_cast[False]()
        .unsafe_origin_cast[ImmutUntrackedOrigin]()
    )
    record.set1_sam(
        String("read-1"),
        UInt16(0),
        0,
        0,
        42,
        1,
        cigar_arg,
        -1,
        -1,
        0,
        seq,
        qual,
        0,
    )

    var record_ptr = (
        record.ptr()
        .unsafe_mut_cast[False]()
        .unsafe_origin_cast[ImmutUntrackedOrigin]()
    )
    rc = sam_write1(file.ptr(), header_ptr, record_ptr)
    if rc != 0:
        sam_hdr_destroy(header.value())
        hts_free(cigar_mem.value())
        raise Error("sam_write1 failed")

    file.close()
    sam_hdr_destroy(header.value())
    hts_free(cigar_mem.value())


def test_raw_header_lifecycle() raises:
    var empty = RawSamHeader()
    if empty.n_ref() != 0:
        raise Error("empty header should have zero references")

    var text = _terminated(String("@HD\tVN:1.6\tSO:coordinate\n@SQ\tSN:chr1\tLN:1000\n"))
    var header = RawSamHeader(text)
    if header.n_ref() != 1:
        raise Error("parsed header should have one reference")
    if header.name2tid(_terminated(String("chr1"))) != 0:
        raise Error("name2tid failed")
    if header.tid2len(0) != 1000:
        raise Error("tid2len failed")

    var dup = header.dup()
    if dup.n_ref() != 1:
        raise Error("dup header should preserve references")


def test_raw_header_missing_reference_lookup() raises:
    var text = _terminated(String("@HD\tVN:1.6\tSO:coordinate\n@SQ\tSN:chr1\tLN:1000\n"))
    var header = RawSamHeader(text)
    if header.text_length() <= 0:
        raise Error("header text_length should be positive")
    if header.name2tid(_terminated(String("missing"))) != -1:
        raise Error("missing reference should return -1")
    if header.tid2name(1):
        raise Error("out-of-range tid should not resolve to a name")


def test_raw_file_lifecycle() raises:
    var path = _terminated(String("/tmp/hts_mojo_raw_lifecycle.sam"))
    var file = RawSamFile()
    file.close()

    var writer = RawSamFile(path, _terminated(String("w")))
    writer.close()
    writer.close()


def test_raw_record_lifecycle() raises:
    var record = RawBamRecord()
    var copy = RawBamRecord(copy=record)
    var dup = record.dup()
    record.copy_from(copy)
    _ = dup


def test_raw_record_set1_sam_rejects_length_mismatch() raises:
    var record = RawBamRecord()
    try:
        record.set1_sam(
            String("read-1"),
            UInt16(4),
            -1,
            -1,
            0,
            0,
            None,
            -1,
            -1,
            0,
            String("AC"),
            String("!"),
        )
    except e:
        return
    raise Error("set1_sam should reject mismatched sequence and quality lengths")


def test_raw_record_set1_sam_rejects_non_sam_quality() raises:
    var record = RawBamRecord()
    try:
        record.set1_sam(
            String("read-1"),
            UInt16(4),
            -1,
            -1,
            0,
            0,
            None,
            -1,
            -1,
            0,
            String("A"),
            String(" "),
        )
    except e:
        return
    raise Error("set1_sam should reject quality bytes below ASCII 33")


def test_raw_file_index_and_iterator() raises:
    var path = _terminated(String("/tmp/hts_mojo_raw_test.bam"))
    _write_fixture(path)
    RawHtsIndex.build(path)

    var file = RawSamFile(path, _terminated(String("rb")))
    var header = RawSamHeader(file)
    if header.name2tid(_terminated(String("chr1"))) != 0:
        raise Error("header lookup failed")

    var index = RawHtsIndex(file, path)

    var tid_iter = RawHtsIterator(index, Int32(0), Int64(0), Int64(1000))
    var record = RawBamRecord()
    var rc = tid_iter.next(file, record)
    if rc < 0:
        raise Error("tid iterator should return a record")
    rc = tid_iter.next(file, record)
    if rc != -1:
        raise Error("tid iterator should reach EOF")

    var region_iter = RawHtsIterator(
        index, header, _terminated(String("chr1:1-1000"))
    )
    rc = region_iter.next(file, record)
    if rc < 0:
        raise Error("region iterator should return a record")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
