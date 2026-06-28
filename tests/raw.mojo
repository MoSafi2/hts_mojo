from std.testing import TestSuite

from hts_mojo._ffi import bam_set1, sam_hdr_write, sam_write1
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


def test_cstr_helper() raises:
    var ptr = _cstr(String("hi"))
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
    var header = RawSamHeader(header_text)
    var file = RawSamFile(path, String("wb"))
    var header_ptr = (
        header.ptr()
        .unsafe_mut_cast[False]()
        .unsafe_origin_cast[ImmutUntrackedOrigin]()
    )
    var rc = sam_hdr_write(file.ptr(), header_ptr)
    if rc != 0:
        raise Error("sam_hdr_write failed")

    var record = RawBamRecord()
    var qname = String("read-1")
    var seq = String("ACGTN")
    var qual = String('!"#$%')
    rc = bam_set1(
        record.ptr(),
        UInt(qname.byte_length() + 1),
        _cstr(qname),
        UInt16(0),
        0,
        0,
        0,
        0,
        None,
        0,
        0,
        0,
        UInt(seq.byte_length()),
        _cstr(seq),
        _cstr(qual),
        0,
    )
    if rc < 0:
        raise Error("bam_set1 failed")

    var record_ptr = (
        record.ptr()
        .unsafe_mut_cast[False]()
        .unsafe_origin_cast[ImmutUntrackedOrigin]()
    )
    rc = sam_write1(file.ptr(), header_ptr, record_ptr)
    if rc != 0:
        raise Error("sam_write1 failed")

    file.close()


def test_raw_header_lifecycle() raises:
    var empty = RawSamHeader()
    if empty.n_ref() != 0:
        raise Error("empty header should have zero references")

    var text = String("@HD\tVN:1.6\tSO:coordinate\n@SQ\tSN:chr1\tLN:1000\n")
    var header = RawSamHeader(text)
    if header.n_ref() != 1:
        raise Error("parsed header should have one reference")
    if header.name2tid(String("chr1")) != 0:
        raise Error("name2tid failed")
    if header.tid2len(0) != 1000:
        raise Error("tid2len failed")

    var dup = header.dup()
    if dup.n_ref() != 1:
        raise Error("dup header should preserve references")


def test_raw_file_lifecycle() raises:
    var path = String("/tmp/hts_mojo_raw_lifecycle.sam")
    var file = RawSamFile()
    file.close()

    var header = RawSamHeader(String("@HD\tVN:1.6\tSO:unsorted\n"))
    var writer = RawSamFile(path, String("w"))
    var header_ptr = (
        header.ptr()
        .unsafe_mut_cast[False]()
        .unsafe_origin_cast[ImmutUntrackedOrigin]()
    )
    var rc = sam_hdr_write(writer.ptr(), header_ptr)
    if rc != 0:
        raise Error("sam_hdr_write failed")
    writer.close()


def test_raw_record_lifecycle() raises:
    var record = RawBamRecord()
    var copy = RawBamRecord(copy=record)
    var dup = record.dup()
    record.copy_from(copy)
    _ = dup


def test_raw_file_index_and_iterator() raises:
    var path = String("/tmp/hts_mojo_raw_test.bam")
    _write_fixture(path)
    RawHtsIndex.build(path)

    var file = RawSamFile(path, String("rb"))
    var header = RawSamHeader(file)
    if header.name2tid(String("chr1")) != 0:
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

    var region_iter = RawHtsIterator(index, header, String("chr1:1-1000"))
    rc = region_iter.next(file, record)
    if rc < 0:
        raise Error("region iterator should return a record")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
