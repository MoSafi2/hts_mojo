from hts_mojo.bam import AlignmenetFileHeader, BamReader, BamRecord, Writer
from hts_mojo._engine import AlignmentFormat, Record


def _write_fixture(path: String) raises:
    var header = AlignmenetFileHeader.empty()
    header.add_reference(String("chr1"), 1000)
    var writer = Writer.open(path, header, format=AlignmentFormat.Bam)

    var first = Record()
    first._raw.set1_from_sam_fields(
        String("read-1"),
        UInt16(0x4),
        -1,
        -1,
        0,
        0,
        None,
        -1,
        -1,
        0,
        String("ACGTN"),
        String("!!!!!"),
    )
    writer.write(first)

    var second = Record()
    second._raw.set1_from_sam_fields(
        String("read-2"),
        UInt16(0x4),
        -1,
        -1,
        0,
        0,
        None,
        -1,
        -1,
        0,
        String("TTTTT"),
        String("#####"),
    )
    writer.write(second)
    writer.close()


def test_bam_reader_header_and_records() raises:
    var path = String("/tmp/hts_mojo_bam_reader_test.bam")
    _write_fixture(path)

    var reader = BamReader(path)
    var header = reader.header()
    if header.n_references() != 1:
        raise Error("header reference count mismatch")
    if not header.reference_name(0) or header.reference_name(0).value() != "chr1":
        raise Error("reference_name mismatch")

    var record = BamRecord()
    if not reader.read_next(record):
        raise Error("expected first record")
    if record.query_name() != "read-1":
        raise Error("first record query_name mismatch")
    if not record.is_unmapped():
        raise Error("first record should be unmapped")

    var second = reader.next()
    if not second or second.value().query_name() != "read-2":
        raise Error("second record mismatch")
    if reader.next():
        raise Error("next() should return None at EOF")


def main() raises:
    test_bam_reader_header_and_records()
    print("BamReader smoke test: OK")
