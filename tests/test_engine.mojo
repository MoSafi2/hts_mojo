from std.ffi import c_char
from std.testing import TestSuite

from hts_mojo.bam import (
    AlignmentFormat,
    AuxKind,
    CigarOp,
    Header,
    IndexedReader,
    Pileup,
    ReadOptions,
    Reader,
    Record,
    Region,
    WriteOptions,
    Writer,
)
from hts_mojo._ffi import hts_free, malloc, uint32_t
from hts_mojo.bam.file import RawHtsIndex

comptime _CIGAR_M = UInt32(CigarOp.Match.value)
comptime _CIGAR_I = UInt32(CigarOp.Insertion.value)
comptime _CIGAR_D = UInt32(CigarOp.Deletion.value)
comptime _CIGAR_N = UInt32(CigarOp.ReferenceSkip.value)


def _encode_cigar(length: UInt32, op: UInt32) -> UInt32:
    return (length << 4) | op


def _single_match_cigar(
    length: UInt32,
) raises -> UnsafePointer[uint32_t, ImmutUntrackedOrigin]:
    var mem = malloc(UInt(4))
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


def _cigar_buffer(
    var items: List[UInt32],
) raises -> UnsafePointer[uint32_t, ImmutUntrackedOrigin]:
    var mem = malloc(UInt(len(items) * 4))
    if not mem:
        raise Error("malloc failed")
    var ptr = rebind[Optional[UnsafePointer[UInt32, MutUntrackedOrigin]]](mem)
    for i in range(len(items)):
        ptr.value()[i] = items[i]
    return (
        ptr.value()
        .unsafe_mut_cast[False]()
        .unsafe_origin_cast[ImmutUntrackedOrigin]()
        .bitcast[uint32_t]()
    )


def _make_record(
    qname: String,
    flag: UInt16,
    tid: Int32,
    pos0: Int64,
    mapq: UInt8,
    mtid: Int32,
    mpos0: Int64,
    isize: Int64,
    seq: String,
    qual: String,
) raises -> Record:
    var record = Record()
    var cigar = _single_match_cigar(UInt32(seq.byte_length()))
    record._raw.set1_from_sam_fields(
        qname, flag, tid, pos0, mapq, 1, cigar, mtid, mpos0, isize, seq, qual
    )
    _free_cigar(cigar)
    return record^


def _make_record_with_cigar(
    qname: String,
    flag: UInt16,
    tid: Int32,
    pos0: Int64,
    mapq: UInt8,
    mtid: Int32,
    mpos0: Int64,
    isize: Int64,
    var cigar_ops: List[UInt32],
    seq: String,
    qual: String,
) raises -> Record:
    var record = Record()
    var n_cigar = len(cigar_ops)
    var cigar = _cigar_buffer(cigar_ops^)
    record._raw.set1_from_sam_fields(
        qname,
        flag,
        tid,
        pos0,
        mapq,
        UInt(n_cigar),
        cigar,
        mtid,
        mpos0,
        isize,
        seq,
        qual,
    )
    _free_cigar(cigar)
    return record^


def _write_fixture(path: String) raises:
    var header = Header.empty()
    header.add_reference(String("chr1"), 1000)
    header.add_read_group(String("rg1"), sample=String("sample"))
    header.add_program(
        String("prog1"),
        program_name=String("hts-mojo"),
        version=String("1.0"),
        command_line=String("unit-test"),
    )

    var writer = Writer.open(
        path,
        header,
        format=AlignmentFormat.Bam,
        compression_level=1,
    )
    var first = _make_record(
        String("read-1"),
        UInt16(0),
        0,
        10,
        42,
        -1,
        -1,
        0,
        String("ACGTN"),
        String('!"#$%'),
    )
    first.set_aux_int(String("NM"), 2)
    first.set_aux_float(String("AS"), Float32(3.5))
    first.set_aux_string(String("RG"), String("rg1"))
    writer.write(first)

    var second = _make_record(
        String("read-2"),
        UInt16(0x4),
        -1,
        -1,
        0,
        -1,
        -1,
        0,
        String("TTTTT"),
        String("*****"),
    )
    writer.write(second)
    writer.close()


def _write_indel_fixture(path: String) raises:
    var header = Header.empty()
    header.add_reference(String("chr1"), 1000)
    var writer = Writer.open(
        path,
        header,
        format=AlignmentFormat.Bam,
        compression_level=1,
    )

    var match_read = _make_record(
        String("match-5m"),
        UInt16(0),
        0,
        10,
        60,
        -1,
        -1,
        0,
        String("AACCC"),
        String("!!!!!"),
    )
    writer.write(match_read)

    var deletion_ops = List[UInt32]()
    deletion_ops.append(_encode_cigar(2, _CIGAR_M))
    deletion_ops.append(_encode_cigar(1, _CIGAR_D))
    deletion_ops.append(_encode_cigar(2, _CIGAR_M))
    var deletion_read = _make_record_with_cigar(
        String("with-del"),
        UInt16(0),
        0,
        11,
        60,
        -1,
        -1,
        0,
        deletion_ops^,
        String("GGGG"),
        String("####"),
    )
    writer.write(deletion_read)

    var insertion_ops = List[UInt32]()
    insertion_ops.append(_encode_cigar(2, _CIGAR_M))
    insertion_ops.append(_encode_cigar(1, _CIGAR_I))
    insertion_ops.append(_encode_cigar(2, _CIGAR_M))
    var insertion_read = _make_record_with_cigar(
        String("with-ins"),
        UInt16(0),
        0,
        11,
        60,
        -1,
        -1,
        0,
        insertion_ops^,
        String("TTTTT"),
        String("$$$$$"),
    )
    writer.write(insertion_read)
    writer.close()


def _write_refskip_fixture(path: String) raises:
    var header = Header.empty()
    header.add_reference(String("chr1"), 1000)
    var writer = Writer.open(
        path,
        header,
        format=AlignmentFormat.Bam,
        compression_level=1,
    )

    var skip_ops = List[UInt32]()
    skip_ops.append(_encode_cigar(2, _CIGAR_M))
    skip_ops.append(_encode_cigar(3, _CIGAR_N))
    skip_ops.append(_encode_cigar(2, _CIGAR_M))
    var skip_read = _make_record_with_cigar(
        String("with-skip"),
        UInt16(0),
        0,
        20,
        60,
        -1,
        -1,
        0,
        skip_ops^,
        String("CCCC"),
        String("++++"),
    )
    writer.write(skip_read)

    var overlap_read = _make_record(
        String("cover-skip"),
        UInt16(0),
        0,
        22,
        60,
        -1,
        -1,
        0,
        String("AAAAA"),
        String(",,,,,"),
    )
    writer.write(overlap_read)
    writer.close()


def test_region_validation() raises:
    var region = Region.one_based_closed(String("chr1"), 11, 15)
    if region.contig != "chr1" or region.start0 != 10 or region.end0 != 15:
        raise Error("one_based_closed produced wrong coordinates")

    try:
        _ = Region.one_based_closed(String("chr1"), 0, 1)
    except e:
        pass
    else:
        raise Error("one_based_closed should reject non-positive starts")

    try:
        _ = Region.one_based_closed(String("chr1"), 5, 4)
    except e:
        return
    raise Error("one_based_closed should reject descending ranges")


def test_header_metadata_helpers() raises:
    var header = Header.empty()
    header.add_reference(String("chr1"), 1000)
    header.add_reference(String("chr2"), 250)
    header.add_read_group(
        String("rg1"),
        sample=String("sample-a"),
        library=String("lib-a"),
        platform=String("ILLUMINA"),
    )
    header.add_program(
        String("pg1"),
        program_name=String("aligner"),
        version=String("1.2"),
        command_line=String("aligner --flag"),
    )

    if header.n_references() != 2:
        raise Error("n_references mismatch")
    if not header.tid(String("chr2")) or header.tid(String("chr2")).value() != 1:
        raise Error("tid lookup mismatch")
    if header.require_tid(String("chr1")) != 0:
        raise Error("require_tid mismatch")
    if not header.reference_name(0) or header.reference_name(0).value() != "chr1":
        raise Error("reference_name mismatch")
    if not header.reference_length(1) or header.reference_length(1).value() != 250:
        raise Error("reference_length mismatch")
    if len(header.references()) != 2:
        raise Error("references length mismatch")
    if len(header.read_groups()) != 1:
        raise Error("read_groups length mismatch")
    if not header.read_groups()[0].sample or header.read_groups()[0].sample.value() != "sample-a":
        raise Error("read-group sample mismatch")
    if len(header.programs()) != 1:
        raise Error("programs length mismatch")
    if not header.programs()[0].program_name or header.programs()[0].program_name.value() != "aligner":
        raise Error("program name mismatch")

    var cloned = header.clone()
    if cloned.text() != header.text():
        raise Error("header clone should preserve text")

    var reparsed = Header.from_text(header.text())
    if reparsed.n_references() != 2:
        raise Error("Header.from_text should preserve references")
    if String.write(header) != header.text():
        raise Error("Header should render as its SAM text")


def test_record_accessors_and_aux() raises:
    var record = _make_record(
        String("read-1"),
        UInt16(0x1 | 0x2 | 0x40),
        0,
        10,
        42,
        0,
        30,
        20,
        String("ACGTN"),
        String("!!!!!"),
    )
    record.set_aux_int(String("NM"), 1)
    record.set_aux_float(String("AS"), Float32(2.5))
    record.set_aux_string(String("RG"), String("rg1"))

    if record.flag() != UInt16(0x1 | 0x2 | 0x40):
        raise Error("flag mismatch")
    if not record.flags().is_paired() or not record.is_proper_pair() or not record.is_read1():
        raise Error("flag helper mismatch")
    if record.is_unmapped():
        raise Error("record should be mapped")
    if not record.reference_id() or record.reference_id().value() != 0:
        raise Error("reference_id mismatch")
    if not record.reference_start() or record.reference_start().value() != 10:
        raise Error("reference_start mismatch")
    if not record.reference_end() or record.reference_end().value() != 15:
        raise Error("reference_end mismatch")
    if not record.reference_length() or record.reference_length().value() != 5:
        raise Error("reference_length mismatch")
    if not record.next_reference_id() or record.next_reference_id().value() != 0:
        raise Error("next_reference_id mismatch")
    if not record.next_reference_start() or record.next_reference_start().value() != 30:
        raise Error("next_reference_start mismatch")
    if record.template_length() != 20:
        raise Error("template_length mismatch")
    if record.query_length() != 5:
        raise Error("query_length mismatch")
    if record.query_name() != "read-1":
        raise Error("query_name mismatch")
    if record.query_sequence() != "ACGTN":
        raise Error("query_sequence mismatch")

    var quals = record.query_qualities()
    if len(quals) != 5:
        raise Error("query_qualities mismatch")
    if not record.cigar_string() or record.cigar_string().value() != "5M":
        raise Error("cigar_string mismatch")
    if len(record.cigar()) != 1 or record.cigar()[0].length != 5:
        raise Error("cigar mismatch")

    if not record.has_aux(String("NM")):
        raise Error("expected NM aux tag")
    if not record.get_aux(String("NM")) or record.get_aux(String("NM")).value().kind != AuxKind.Integer:
        raise Error("NM aux kind mismatch")
    if record.get_aux(String("NM")).value().int_value != 1:
        raise Error("NM aux value mismatch")
    if not record.get_aux(String("AS")) or record.get_aux(String("AS")).value().kind != AuxKind.Float:
        raise Error("AS aux kind mismatch")
    if not record.get_aux(String("RG")) or record.get_aux(String("RG")).value().string_value != "rg1":
        raise Error("RG aux string mismatch")
    var rendered = String.write(record)
    if (
        rendered.find("qname=read-1") == -1
        or rendered.find("flag=0x0043") == -1
        or rendered.find("aux=[NM=i:1") == -1
        or rendered.find("AS=f:2.5") == -1
        or rendered.find("RG=Z:rg1") == -1
        or rendered.find("qual=[") == -1
        or rendered.find("cigar=5M") == -1
        or rendered.find("seq=ACGTN") == -1
    ):
        raise Error("Record should render key fields")
    if not record.remove_aux(String("NM")) or record.has_aux(String("NM")):
        raise Error("remove_aux should delete NM")

    var cloned = record.clone()
    if cloned.query_name() != "read-1":
        raise Error("clone should preserve record content")


def _expect_single_alignment(
    pileup: Pileup,
    expected_query_pos: Int32,
    expect_head: Bool,
    expect_tail: Bool,
) raises:
    if pileup.depth() != 1:
        raise Error("pileup depth mismatch")
    var alignments = pileup.alignments()
    var first = alignments.next()
    if not first:
        raise Error("expected one pileup alignment")
    var alignment = first.value()
    if not alignment.query_position():
        raise Error("expected query position")
    if alignment.query_position().value() != expected_query_pos:
        raise Error("pileup query position mismatch")
    if alignment.is_head() != expect_head:
        raise Error("pileup is_head mismatch")
    if alignment.is_tail() != expect_tail:
        raise Error("pileup is_tail mismatch")
    if alignment.is_deletion():
        raise Error("pileup alignment should not be a deletion")
    if alignment.is_refskip():
        raise Error("pileup alignment should not be a refskip")
    if alignment.record().query_name() != "read-1":
        raise Error("pileup alignment record mismatch")
    if alignments.next():
        raise Error("expected exactly one pileup alignment")


def test_writer_and_reader_roundtrip() raises:
    var path = String("/tmp/hts_mojo_engine_roundtrip.bam")
    _write_fixture(path)

    var options = ReadOptions(None, 0, None, False)
    var reader = Reader.open(path, options^)
    var header = reader.header()
    if header.n_references() != 1:
        raise Error("reader header references mismatch")
    if len(header.read_groups()) != 1 or len(header.programs()) != 1:
        raise Error("reader header metadata mismatch")

    var iter = reader.records()
    if not iter.has_next():
        raise Error("records iterator should see first record")
    var first = iter.next()
    if not first or first.value().query_name() != "read-1":
        raise Error("iterator first record mismatch")
    if first.value().query_sequence() != "ACGTN":
        raise Error("iterator sequence mismatch")
    if not first.value().get_aux(String("RG")) or first.value().get_aux(String("RG")).value().string_value != "rg1":
        raise Error("iterator aux mismatch")
    if not iter.has_next():
        raise Error("records iterator should see second record")
    var second = iter.pop_next()
    if not second or second.value().query_name() != "read-2":
        raise Error("iterator second record mismatch")
    if not second.value().is_unmapped():
        raise Error("second record should be unmapped")
    if iter.next():
        raise Error("iterator should be exhausted")

    var direct = Record()
    var second_reader = Reader.open(path)
    if not second_reader.read_next(direct):
        raise Error("read_next should return first record")
    if direct.query_name() != "read-1":
        raise Error("read_next query_name mismatch")
    second_reader.close()
    reader.close()


def test_indexed_reader_fetch() raises:
    var path = String("/tmp/hts_mojo_engine_indexed.bam")
    _write_fixture(path)
    RawHtsIndex.build(path)

    var indexed = IndexedReader.open(path)
    var by_region = indexed.fetch(Region.zero_based(String("chr1"), 0, 100))
    var first = by_region.next()
    if not first or first.value().query_name() != "read-1":
        raise Error("fetch(region) mismatch")
    if by_region.next():
        raise Error("fetch(region) should only return mapped read")

    var by_string = indexed.fetch_string(String("chr1:1-100"))
    var same = by_string.next()
    if not same or same.value().query_name() != "read-1":
        raise Error("fetch_string mismatch")
    indexed.close()


def test_writer_option_validation() raises:
    var header = Header.empty()
    header.add_reference(String("chr1"), 10)
    try:
        _ = Writer.open(
            String("/tmp/hts_mojo_engine_invalid.sam"),
            header,
            format=AlignmentFormat.Sam,
            compression_level=1,
        )
    except e:
        pass
    else:
        raise Error("SAM output should reject compression levels")

    var options = WriteOptions(None, 0, AlignmentFormat.Bam, 1)
    var writer = Writer.open(
        String("/tmp/hts_mojo_engine_options.bam"), header, options^
    )
    writer.close()


def test_reader_pileup() raises:
    var path = String("/tmp/hts_mojo_reader_pileup.bam")
    _write_fixture(path)

    var reader = Reader(path)
    var pileups = reader.pileup()

    for i in range(5):
        var column = pileups.next()
        if not column:
            raise Error("expected pileup column")
        var pileup = column.value()
        if pileup.reference_id() != 0:
            raise Error("pileup tid mismatch")
        if (
            pileup.position0() != Int64(10 + i)
            or pileup.position1() != Int64(11 + i)
        ):
            raise Error("pileup position mismatch")
        _expect_single_alignment(pileup, Int32(i), i == 0, i == 4)

    if pileups.next():
        raise Error("pileup should end after covered positions")
    reader.close()

    var limited_reader = Reader(path)
    var limited = limited_reader.pileup(1)
    if not limited.next():
        raise Error("pileup with max_depth should still yield data")
    limited_reader.close()

    var invalid_reader = Reader(path)
    try:
        _ = invalid_reader.pileup(-1)
    except e:
        invalid_reader.close()
        return
    invalid_reader.close()
    raise Error("pileup should reject negative max_depth")


def test_indexed_reader_pileup_regions() raises:
    var path = String("/tmp/hts_mojo_indexed_reader_pileup.bam")
    _write_fixture(path)
    RawHtsIndex.build(path)

    var reader = IndexedReader(path)
    var region_pileups = reader.pileup_region(
        Region.zero_based(String("chr1"), 10, 15)
    )
    for i in range(5):
        var column = region_pileups.next()
        if not column or column.value().position0() != Int64(10 + i):
            raise Error("region pileup mismatch")
    if region_pileups.next():
        raise Error("region pileup should stop at region end")
    reader.close()

    var string_reader = IndexedReader(path)
    var string_pileups = string_reader.pileup_string(String("chr1:11-15"))
    for i in range(5):
        var column = string_pileups.next()
        if not column or column.value().position0() != Int64(10 + i):
            raise Error("string pileup mismatch")
    if string_pileups.next():
        raise Error("string pileup should stop at region end")
    string_reader.close()


def test_reader_pileup_indels_e2e() raises:
    var path = String("/tmp/hts_mojo_reader_pileup_indels.bam")
    _write_indel_fixture(path)

    var reader = Reader(path)
    var pileups = reader.pileup()

    var column10 = pileups.next()
    if not column10 or column10.value().position0() != 10:
        raise Error("expected pileup at position 10")
    if column10.value().depth() != 1:
        raise Error("position 10 depth mismatch")

    var column11 = pileups.next()
    if not column11 or column11.value().position0() != 11:
        raise Error("expected pileup at position 11")
    if column11.value().depth() != 3:
        raise Error("position 11 depth mismatch")

    var column12 = pileups.next()
    if not column12 or column12.value().position0() != 12:
        raise Error("expected pileup at position 12")
    var found_insertion = False
    var alignments12 = column12.value().alignments()
    while True:
        var alignment = alignments12.next()
        if not alignment:
            break
        if alignment.value().record().query_name() == "with-ins":
            if alignment.value().indel() != 1:
                raise Error("expected insertion marker at position 12")
            found_insertion = True
    if not found_insertion:
        raise Error("missing insertion alignment in pileup")

    var column13 = pileups.next()
    if not column13 or column13.value().position0() != 13:
        raise Error("expected pileup at position 13")
    if column13.value().depth() != 3:
        raise Error("position 13 depth mismatch")
    var saw_deletion = False
    var saw_shifted_query = False
    var alignments13 = column13.value().alignments()
    while True:
        var alignment = alignments13.next()
        if not alignment:
            break
        var qname = alignment.value().record().query_name()
        if qname == "with-del":
            if (
                not alignment.value().is_deletion()
                or alignment.value().query_position()
            ):
                raise Error("expected deletion flag at position 13")
            saw_deletion = True
        if qname == "with-ins":
            if (
                not alignment.value().query_position()
                or alignment.value().query_position().value() != 3
            ):
                raise Error("insertion read should skip inserted base in qpos")
            saw_shifted_query = True
    if not saw_deletion:
        raise Error("missing deletion alignment in pileup")
    if not saw_shifted_query:
        raise Error("missing shifted insertion query position")

    var column14 = pileups.next()
    if not column14 or column14.value().position0() != 14:
        raise Error("expected pileup at position 14")
    if column14.value().depth() != 3:
        raise Error("position 14 depth mismatch")

    var column15 = pileups.next()
    if not column15 or column15.value().position0() != 15:
        raise Error("expected pileup at position 15")
    if column15.value().depth() != 1:
        raise Error("position 15 depth mismatch")
    var alignments15 = column15.value().alignments()
    var only_alignment = alignments15.next()
    if (
        not only_alignment
        or only_alignment.value().record().query_name() != "with-del"
    ):
        raise Error("expected deletion-carrying read at position 15")

    if pileups.next():
        raise Error("indel pileup should end after position 15")
    reader.close()


def test_indexed_reader_pileup_refskip_e2e() raises:
    var path = String("/tmp/hts_mojo_indexed_reader_pileup_refskip.bam")
    _write_refskip_fixture(path)
    RawHtsIndex.build(path)

    var reader = IndexedReader(path)
    var pileups = reader.pileup_string(String("chr1:21-27"))

    var expected_positions = List[Int64]()
    expected_positions.append(20)
    expected_positions.append(21)
    expected_positions.append(22)
    expected_positions.append(23)
    expected_positions.append(24)
    expected_positions.append(25)
    expected_positions.append(26)

    for pos in expected_positions:
        var column = pileups.next()
        if not column or column.value().position0() != pos:
            raise Error("refskip pileup position mismatch")
        var pileup = column.value()
        if pos < 22:
            if pileup.depth() != 1:
                raise Error("leading refskip depth mismatch")
            continue
        if pos <= 24:
            if pileup.depth() != 2:
                raise Error("refskip overlap depth mismatch")
            var saw_refskip = False
            var alignments = pileup.alignments()
            while True:
                var alignment = alignments.next()
                if not alignment:
                    break
                if alignment.value().record().query_name() == "with-skip":
                    if (
                        not alignment.value().is_refskip()
                        or alignment.value().query_position()
                    ):
                        raise Error("expected refskip flag inside skipped region")
                    saw_refskip = True
            if not saw_refskip:
                raise Error("missing refskip alignment in skipped region")
            continue
        if pileup.depth() != 2:
            raise Error("post-refskip overlap depth mismatch")

    if pileups.next():
        raise Error("refskip pileup should end after position 26")
    reader.close()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
