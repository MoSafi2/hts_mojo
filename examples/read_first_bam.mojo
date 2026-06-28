from std.sys import argv

from hts_mojo.bam import BamReader, BamRecord


def main() raises:
    var args = argv()
    if len(args) == 0:
        raise Error(
            "usage: mojo run examples/read_first_bam.mojo <input.sam|input.bam>"
        )

    var bam_path = String(args[len(args) - 1])
    var reader = BamReader(bam_path)
    var header = reader.header()

    print("Input path:", bam_path)
    print("References:", header.n_references())

    var record = BamRecord()
    if not reader.read_next(record):
        print("Input contains no records")
        return

    print(record)
    # print("Query name:", record.query_name())
    # print("Flag:", record.flag())
    # print("Reference id:", record.reference_id())
    # print(record)

    # var ref_id = record.reference_id()
    # if ref_id:
    #     var ref_name = header.reference_name(ref_id.value())
    #     if ref_name:
    #         print("Reference name:", ref_name.value())

    # var ref_start = record.reference_start()
    # print("Reference start:", ref_start)

    # var cigar = record.cigar_string()
    # if cigar:
    #     print("CIGAR:", cigar.value())

    # print("Sequence:", record.query_sequence())
