from std.ffi import c_char, CStringSlice
from std.io import Writer as IOWriter
from hts_mojo import _raw
from hts_mojo._ffi import (
    bam_aux2A,
    bam_aux2Z,
    bam_aux2f,
    bam_aux2i,
    bam_auxB2f,
    bam_auxB2i,
    bam_auxB_len,
)



@fieldwise_init
struct Region(Copyable, Movable):
    var contig: String
    var start0: Int64
    var end0: Int64

    @staticmethod
    def zero_based(contig: String, start0: Int64, end0: Int64) -> Self:
        return Self(contig, start0, end0)

    @staticmethod
    def one_based_closed(
        contig: String, start1: Int64, end1: Int64
    ) raises -> Self:
        if start1 <= 0:
            raise Error("1-based region start must be positive")
        if end1 < start1:
            raise Error("1-based region end must be >= start")
        return Self(contig, start1 - 1, end1)


