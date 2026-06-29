from std.sys import argv

from hts_mojo._ffi import hts_free, malloc, uint32_t
from hts_mojo.bam._common import _cstr_ptr
from hts_mojo.bam import AlignmentFormat, BamReader, Header, Record, Writer


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
    var qname_c = qname
    var seq_c = seq
    var qual_c = qual
    record._raw.set1(
        UInt(qname_c.byte_length() + 1),
        _cstr_ptr(qname_c),
        flag,
        tid,
        pos0,
        mapq,
        1,
        cigar,
        mtid,
        mpos0,
        isize,
        UInt(seq_c.byte_length()),
        _cstr_ptr(seq_c),
        _cstr_ptr(qual_c),
        0,
    )
    _free_cigar(cigar)
    return record^


def _build_header() raises -> Header:
    var header = Header.empty()
    header.add_reference(String("chr1"), 1000)
    header.add_read_group(String("rg1"), sample=String("synthetic"))
    header.add_program(
        String("hts-mojo-example"),
        program_name=String("write_synthetic_bam"),
        version=String("0.1"),
        command_line=String("mojo run examples/write_synthetic_bam.mojo"),
    )
    return header^


def _write_records(mut writer: Writer) raises:
    var first = _make_record(
        String("synthetic-1"),
        UInt16(0),
        0,
        99,
        60,
        -1,
        -1,
        0,
        String("ACGTN"),
        String('!"#$%'),
    )
    first.set_aux_int(String("NM"), 1)
    first.set_aux_string(String("RG"), String("rg1"))
    writer.write(first)

    var second = _make_record(
        String("synthetic-2"),
        UInt16(0x10),
        0,
        199,
        50,
        -1,
        -1,
        0,
        String("TTGCA"),
        String("#####"),
    )
    second.set_aux_float(String("AS"), Float32(12.5))
    second.set_aux_string(String("RG"), String("rg1"))
    writer.write(second)


def main() raises:
    var args = argv()
    if len(args) < 2:
        raise Error(
            "usage: mojo run examples/write_synthetic_bam.mojo <output.bam>"
        )

    var output_path = String(args[len(args) - 1])
    var header = _build_header()
    var bam_writer = Writer.open(
        output_path,
        header.clone(),
        format=AlignmentFormat.Bam,
        compression_level=1,
    )
    _write_records(bam_writer)
    bam_writer.close()

    print("Wrote 2 synthetic BAM records to ", output_path)

    var sam_path = output_path + String(".sam")
    var sam_writer = Writer.open(
        sam_path,
        header,
        format=AlignmentFormat.Sam,
    )
    _write_records(sam_writer)
    sam_writer.close()

    print("Wrote 2 synthetic SAM records to ", sam_path)

    var bam_reader = BamReader(output_path)
    print(bam_reader.header())
    for record in bam_reader:
        print(record)
    bam_reader.close()
