from std.ffi import CStringSlice, c_char, c_size_t

from hts_mojo import AlignmenetFileHeader, BamReader, BamRecord
from hts_mojo._ffi.hts import hts_expand, hts_free, hts_lib_shutdown
from hts_mojo._ffi.sam import (
    BAM_CSOFT_CLIP,
    BAM_CMATCH,
    BAM_FUNMAP,
    bam_cigar_gen,
    bam_set1,
    sam_close,
    sam_hdr_destroy,
    sam_hdr_parse,
    sam_hdr_write,
    sam_open,
    sam_write1,
)


def _terminated(s: String) -> String:
    return s + "\0"


def _cstr(s: String) raises -> UnsafePointer[c_char, ImmutExternalOrigin]:
    return (
        CStringSlice(s)
        .as_bytes_with_nul()
        .unsafe_ptr()
        .unsafe_origin_cast[ImmutExternalOrigin]()
        .bitcast[c_char]()
    )


def _make_record(
    qname: String,
    tid: Int32,
    pos: Int64,
    mapq: UInt8,
    cigar_len: UInt32,
    cigar_op: UInt32,
    mate_tid: Int32,
    mate_pos: Int64,
    isize: Int64,
    seq: String,
    qual: String,
) raises -> BamRecord:
    var record = BamRecord()
    var cigar_mem: c_size_t = 0
    var seq_len = UInt(seq.byte_length())
    var n_cigar: c_size_t = 0
    var cigar_ptr = UnsafePointer[UInt32, ImmutExternalOrigin].unsafe_dangling()
    if cigar_len > 0:
        var cigar: Optional[UnsafePointer[UInt32, MutExternalOrigin]] = None
        n_cigar = 1
        if seq_len > UInt(cigar_len):
            n_cigar = 2
        cigar_mem = hts_expand[UInt32](
            n_cigar,
            cigar_mem,
            UnsafePointer(to=cigar)
            .unsafe_origin_cast[MutExternalOrigin]()
            .bitcast[UnsafePointer[UInt32, MutExternalOrigin]](),
        )
        cigar.value()[0] = bam_cigar_gen(cigar_len, cigar_op)
        if n_cigar == 2:
            cigar.value()[1] = bam_cigar_gen(
                UInt32(seq_len - UInt(cigar_len)),
                UInt32(BAM_CSOFT_CLIP),
            )
        cigar_ptr = (
            cigar.value()
            .unsafe_mut_cast[False]()
            .unsafe_origin_cast[ImmutExternalOrigin]()
        )

    var qname_c = _terminated(qname)
    var seq_c = _terminated(seq)
    var qual_c = _terminated(qual)
    var rc = bam_set1(
        record._ptr(),
        UInt(qname.byte_length() + 1),
        _cstr(qname_c),
        UInt16(BAM_FUNMAP),
        -1,
        -1,
        0,
        n_cigar,
        cigar_ptr,
        -1,
        -1,
        0,
        seq_len,
        _cstr(seq_c),
        _cstr(qual_c),
        0,
    )
    if cigar_len > 0:
        hts_free(cigar_ptr.unsafe_mut_cast[True]().bitcast[NoneType]())
    if rc < 0:
        raise Error("bam_set1 failed")
    return record^


def _write_fixture(path: String) raises -> None:
    var header_text = String(
        "@HD\tVN:1.6\tSO:coordinate\n@SQ\tSN:chr1\tLN:1000\n"
    )
    var header_text_c = _terminated(header_text)
    var header = sam_hdr_parse(
        UInt(header_text.byte_length()),
        _cstr(header_text_c),
    )
    if not header:
        raise Error("sam_hdr_parse failed")

    var path_c = _terminated(path)
    var mode_c = _terminated(String("wb"))
    var file = sam_open(_cstr(path_c), _cstr(mode_c))
    if not file:
        sam_hdr_destroy(header)
        raise Error("sam_open failed")

    var rc = sam_hdr_write(file, header)
    if rc != 0:
        _ = sam_close(file)
        sam_hdr_destroy(header)
        raise Error("sam_hdr_write failed")

    var first = _make_record(
        String("read-1"),
        0,
        0,
        0,
        0,
        UInt32(0),
        0,
        0,
        0,
        String("ACGTN"),
        String('\x1e\x1f !"'),
    )
    var second = _make_record(
        String("read-2"),
        0,
        0,
        0,
        0,
        UInt32(0),
        0,
        0,
        0,
        String("TTTTT"),
        String('!"#$%'),
    )

    rc = sam_write1(file, header, first._ptr())
    if rc != 0:
        _ = sam_close(file)
        sam_hdr_destroy(header)
        raise Error("sam_write1 first record failed")

    rc = sam_write1(file, header, second._ptr())
    if rc != 0:
        _ = sam_close(file)
        sam_hdr_destroy(header)
        raise Error("sam_write1 second record failed")

    rc = sam_close(file)
    sam_hdr_destroy(header)
    if rc != 0:
        raise Error("sam_close failed")


def test_bam_reader_header_and_records() raises:
    var path = String("/tmp/hts_mojo_bam_reader_test.bam")
    _write_fixture(path)

    var reader = BamReader(path)
    var header = reader.header()
    if header.n_references() != 1:
        raise Error("header reference count mismatch")
    if header.text() != String(
        "@HD\tVN:1.6\tSO:coordinate\n@SQ\tSN:chr1\tLN:1000\n"
    ):
        raise Error("header text mismatch")
    if (
        not header.reference_name(0)
        or header.reference_name(0).value() != "chr1"
    ):
        raise Error("reference_name(0) mismatch")

    var record = BamRecord()
    if not reader.read_next(record):
        raise Error("expected first record")
    if record.query_name() != "read-1":
        raise Error("first record query_name mismatch")
    if not record.is_unmapped():
        raise Error("first record should be unmapped")
    if record.query_sequence() != "ACGTN":
        raise Error("first record query_sequence mismatch")

    var second = reader.next()
    if not second or second.value().query_name() != "read-2":
        raise Error("second record mismatch")
    if not second.value().is_unmapped():
        raise Error("second record should be unmapped")
    if second.value().query_sequence() != "TTTTT":
        raise Error("second record query_sequence mismatch")

    if reader.read_next(record):
        raise Error("expected EOF after second record")
    if reader.next():
        raise Error("next() should return None at EOF")


def main() raises:
    test_bam_reader_header_and_records()
    hts_lib_shutdown()
    print("BamReader smoke test: OK")
