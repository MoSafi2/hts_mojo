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
    print(header)
    var saw_record = False
    for record in reader:
        print(record)
        saw_record = True
    if saw_record:
        return

    var record = BamRecord()
    if not reader.read_next(record):
        print("Input contains no records")
        return

    print(record)
