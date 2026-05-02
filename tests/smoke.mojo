from hts_mojo.bam import *
from hts_mojo._ffi.hts import *
from hts_mojo._ffi.sam import (
    BAM_CMATCH,
    BAM_CSOFT_CLIP,
    BAM_FDUP,
    BAM_FMREVERSE,
    BAM_FMUNMAP,
    BAM_FPAIRED,
    BAM_FPROPER_PAIR,
    BAM_FQCFAIL,
    BAM_FREAD1,
    BAM_FREAD2,
    BAM_FREVERSE,
    BAM_FSECONDARY,
    BAM_FSUPPLEMENTARY,
    BAM_FUNMAP,
    bam_set1,
)


def _cstr(
    s: StringLiteral,
) raises -> UnsafePointer[c_char, ImmutExternalOrigin]:
    return (
        CStringSlice(s)
        .as_bytes_with_nul()
        .unsafe_ptr()
        .unsafe_origin_cast[ImmutExternalOrigin]()
        .bitcast[c_char]()
    )


def test_hts_version() raises:
    var version = hts_version()

    var features = hts_features()
    print("HTSlib features bitmask:", features)

    var feature_string = hts_feature_string()

    print("hts_version: OK")
    print("hts_feature_string: OK")


def test_hts_open_close() raises:
    var fp = hts_open(_cstr("/dev/null\0"), _cstr("r\0"))

    var fmt = hts_get_format(fp)
    var rc = hts_close(fp)
    if rc != 0:
        raise Error("hts_close failed")

    print("hts_open/hts_close: OK")


def test_hts_expand() raises:
    var m: c_size_t = 0
    var ptr = UnsafePointer[c_int, MutExternalOrigin]()

    var ptrp = UnsafePointer(to=ptr).unsafe_origin_cast[MutExternalOrigin]()

    m = hts_expand[c_int](8, m, ptrp)

    ptr[0] = 123
    ptr[7] = 456

    if ptr[0] != 123:
        raise Error("ptr[0] mismatch")

    if ptr[7] != 456:
        raise Error("ptr[7] mismatch")

    hts_free(ptr.bitcast[NoneType]())

    print("hts_expand: OK")


def test_hts_expand0() raises:
    var m: c_size_t = 0
    var ptr = UnsafePointer[c_int, MutExternalOrigin]()

    m = hts_expand0[c_int](
        4,
        m,
        UnsafePointer(to=ptr).unsafe_origin_cast[MutExternalOrigin](),
    )

    if m < 4:
        hts_free(ptr.bitcast[NoneType]())
        raise Error("hts_expand0 did not grow capacity")

    # hts_expand0 passes clear=1, so new memory should be zeroed.
    for i in range(4):
        if ptr[i] != 0:
            hts_free(ptr.bitcast[NoneType]())
            raise Error("hts_expand0 did not zero-initialize memory")

    hts_free(ptr.bitcast[NoneType]())

    print("hts_expand0: OK")


def test_bin_helpers() raises:
    if hts_bin_first(0) != 0:
        raise Error("hts_bin_first(0) expected 0")

    if hts_bin_parent(9) != 1:
        raise Error("hts_bin_parent(9) expected 1")

    # var bin = hts_reg2bin(0, 100, 14, 5)
    # if bin < 0:
    #     raise Error("hts_reg2bin returned negative bin")

    print("bin helpers: OK")


def _populate_record(mut record: BamRecord) raises:
    var m: c_size_t = 0
    var cigar = UnsafePointer[UInt32, MutExternalOrigin]()
    m = hts_expand[UInt32](
        2,
        m,
        UnsafePointer(to=cigar).unsafe_origin_cast[MutExternalOrigin](),
    )
    cigar[0] = UInt32(48)
    cigar[1] = UInt32(36)

    var rc = bam_set1(
        record._ptr(),
        6,
        _cstr("read-1\0"),
        0,
        2,
        10,
        42,
        2,
        (
            cigar.unsafe_mut_cast[False]().unsafe_origin_cast[
                ImmutExternalOrigin
            ]()
        ),
        3,
        20,
        100,
        5,
        _cstr("ACGTN\0"),
        _cstr('\x1e\x1f !"\0'),
        0,
    )
    hts_free(cigar.bitcast[NoneType]())
    if rc < 0:
        raise Error("bam_set1 failed")


def test_bam_record_accessors() raises:
    var record = BamRecord()
    _populate_record(record)

    if record.query_name() != "read-1":
        raise Error("query_name mismatch")
    if record.flag() != 0:
        raise Error("flag mismatch")
    if record.reference_id() != 2:
        raise Error("reference_id mismatch")
    if record.reference_start() != 10:
        raise Error("reference_start mismatch")
    if not record.reference_end() or record.reference_end().value() != 13:
        raise Error("reference_end mismatch")
    if not record.reference_length() or record.reference_length().value() != 3:
        raise Error("reference_length mismatch")
    if record.mapping_quality() != 42:
        raise Error("mapping_quality mismatch")
    if record.next_reference_id() != 3:
        raise Error("next_reference_id mismatch")
    if record.next_reference_start() != 20:
        raise Error("next_reference_start mismatch")
    if record.template_length() != 100:
        raise Error("template_length mismatch")
    if record.query_length() != 5:
        raise Error("query_length mismatch")
    if record.query_sequence() != "ACGTN":
        raise Error("query_sequence mismatch")

    var qualities = record.query_qualities()
    if len(qualities) != 5:
        raise Error("query_qualities length mismatch")
    if qualities[0] != 30 or qualities[4] != 34:
        raise Error("query_qualities value mismatch")

    var cigar = record.cigar()
    if len(cigar) != 2:
        raise Error("cigar length mismatch")
    if cigar[0].op != UInt32(BAM_CMATCH) or cigar[0].length != 3:
        raise Error("first cigar element mismatch")
    if cigar[1].op != UInt32(BAM_CSOFT_CLIP) or cigar[1].length != 2:
        raise Error("second cigar element mismatch")
    if not record.cigar_string() or record.cigar_string().value() != "3M2S":
        raise Error("cigar_string mismatch")

    print("BamRecord accessors: OK")


def test_bam_record_optional_coordinates() raises:
    var record = BamRecord()
    _populate_record(record)
    record._ptr()[].core.flag = UInt16(BAM_FUNMAP)
    if record.reference_end():
        raise Error("unmapped reference_end should be None")
    if record.reference_length():
        raise Error("unmapped reference_length should be None")

    var no_cigar = BamRecord()
    var rc = bam_set1(
        no_cigar._ptr(),
        6,
        _cstr("read-2\0"),
        0,
        2,
        10,
        42,
        0,
        UnsafePointer[UInt32, ImmutExternalOrigin].unsafe_dangling(),
        3,
        20,
        100,
        0,
        _cstr("\0"),
        _cstr("\0"),
        0,
    )
    if rc < 0:
        raise Error("bam_set1 no-cigar record failed")
    if no_cigar.reference_end():
        raise Error("no-cigar reference_end should be None")
    if no_cigar.cigar_string():
        raise Error("no-cigar cigar_string should be None")

    print("BamRecord optional coordinates: OK")


def test_bam_record_flags() raises:
    var record = BamRecord()
    record._ptr()[].core.flag = UInt16(
        BAM_FPAIRED
        | BAM_FPROPER_PAIR
        | BAM_FMUNMAP
        | BAM_FREVERSE
        | BAM_FMREVERSE
        | BAM_FREAD1
        | BAM_FREAD2
        | BAM_FSECONDARY
        | BAM_FQCFAIL
        | BAM_FDUP
        | BAM_FSUPPLEMENTARY
    )

    if not record.is_paired():
        raise Error("is_paired mismatch")
    if not record.is_proper_pair():
        raise Error("is_proper_pair mismatch")
    if record.is_unmapped():
        raise Error("is_unmapped mismatch")
    if not record.mate_is_unmapped():
        raise Error("mate_is_unmapped mismatch")
    if not record.is_reverse():
        raise Error("is_reverse mismatch")
    if not record.mate_is_reverse():
        raise Error("mate_is_reverse mismatch")
    if not record.is_read1():
        raise Error("is_read1 mismatch")
    if not record.is_read2():
        raise Error("is_read2 mismatch")
    if not record.is_secondary():
        raise Error("is_secondary mismatch")
    if not record.is_qcfail():
        raise Error("is_qcfail mismatch")
    if not record.is_duplicate():
        raise Error("is_duplicate mismatch")
    if not record.is_supplementary():
        raise Error("is_supplementary mismatch")

    print("BamRecord flags: OK")


def test_bam_record_copy() raises:
    var record = BamRecord()
    _populate_record(record)
    var copied = record.copy()

    var rc = bam_set1(
        record._ptr(),
        7,
        _cstr("changed\0"),
        0,
        2,
        10,
        42,
        0,
        UnsafePointer[UInt32, ImmutExternalOrigin].unsafe_dangling(),
        3,
        20,
        100,
        0,
        _cstr("\0"),
        _cstr("\0"),
        0,
    )
    if rc < 0:
        raise Error("bam_set1 changed record failed")

    if record.query_name() != "changed":
        raise Error("mutated original query_name mismatch")
    if copied.query_name() != "read-1":
        raise Error("copied query_name mismatch")
    if copied.query_sequence() != "ACGTN":
        raise Error("copied query_sequence mismatch")

    print("BamRecord copy: OK")


def main() raises:
    test_hts_version()
    test_hts_open_close()
    test_hts_expand()
    test_hts_expand0()
    test_bin_helpers()
    test_bam_record_accessors()
    test_bam_record_optional_coordinates()
    test_bam_record_flags()
    test_bam_record_copy()

    hts_lib_shutdown()
    print("HTSlib smoke test: OK")
