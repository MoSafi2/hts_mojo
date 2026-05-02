from std.ffi import CStringSlice, c_char
from std.format import Writable, Writer

from hts_mojo._ffi.sam import (
    BAM_CBACK,
    BAM_CDEL,
    BAM_CDIFF,
    BAM_CEQUAL,
    BAM_CHARD_CLIP,
    BAM_CINS,
    BAM_CMATCH,
    BAM_CPAD,
    BAM_CREF_SKIP,
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
    bam1_t,
    bam_cigar_op,
    bam_cigar_opchr,
    bam_cigar_oplen,
    bam_destroy1,
    bam_dup1,
    bam_endpos,
    bam_get_aux,
    bam_get_cigar,
    bam_get_l_aux,
    bam_get_qname,
    bam_get_qual,
    bam_get_seq,
    bam_init1,
    bam_seqi,
    sam_hdr_t,
    samFile,
    sam_close,
    sam_hdr_destroy,
    sam_hdr_dup,
    sam_hdr_length,
    sam_hdr_nref,
    sam_hdr_read,
    sam_hdr_str,
    sam_hdr_tid2len,
    sam_hdr_tid2name,
    sam_open,
    sam_read1,
)


comptime CIGAR_MATCH = UInt32(BAM_CMATCH)
comptime CIGAR_INSERTION = UInt32(BAM_CINS)
comptime CIGAR_DELETION = UInt32(BAM_CDEL)
comptime CIGAR_REFERENCE_SKIP = UInt32(BAM_CREF_SKIP)
comptime CIGAR_SOFT_CLIP = UInt32(BAM_CSOFT_CLIP)
comptime CIGAR_HARD_CLIP = UInt32(BAM_CHARD_CLIP)
comptime CIGAR_PADDING = UInt32(BAM_CPAD)
comptime CIGAR_SEQUENCE_MATCH = UInt32(BAM_CEQUAL)
comptime CIGAR_SEQUENCE_MISMATCH = UInt32(BAM_CDIFF)
comptime CIGAR_BACK = UInt32(BAM_CBACK)


@fieldwise_init
struct CigarElement(Copyable, Movable):
    var op: UInt32
    var length: UInt32

    def op_char(self) -> UInt8:
        return bam_cigar_opchr(self.op)


struct BamRecord(Copyable, Movable, Writable):
    var _record: Optional[UnsafePointer[bam1_t, MutExternalOrigin]]

    def __init__(out self) raises:
        self._record = bam_init1()
        if not self._record:
            raise Error("bam_init1 failed")

    def __init__(out self, *, copy: Self):
        self._record = bam_dup1(copy._const_ptr())

    def __init__(out self, *, deinit take: Self):
        self._record = take._record^

    def __del__(deinit self):
        if self._record:
            bam_destroy1(self._record.value())

    def _ptr(self) -> UnsafePointer[bam1_t, MutExternalOrigin]:
        return self._record.value()

    def _const_ptr(self) -> UnsafePointer[bam1_t, ImmutExternalOrigin]:
        return (
            self._ptr()
            .unsafe_mut_cast[False]()
            .unsafe_origin_cast[ImmutExternalOrigin]()
        )

    def flag(self) -> UInt16:
        return self._ptr()[].core.flag

    def reference_id(self) -> Int32:
        return self._ptr()[].core.tid

    def reference_start(self) -> Int64:
        return self._ptr()[].core.pos

    def reference_end(self) -> Optional[Int64]:
        if self.is_unmapped() or self._ptr()[].core.n_cigar == 0:
            return None
        return bam_endpos(self._const_ptr())

    def reference_length(self) -> Optional[Int64]:
        var end = self.reference_end()
        if not end:
            return None
        return end.value() - self.reference_start()

    def mapping_quality(self) -> UInt8:
        return self._ptr()[].core.qual

    def next_reference_id(self) -> Int32:
        return self._ptr()[].core.mtid

    def next_reference_start(self) -> Int64:
        return self._ptr()[].core.mpos

    def template_length(self) -> Int64:
        return self._ptr()[].core.isize

    def query_length(self) -> Int32:
        return self._ptr()[].core.l_qseq

    def query_name(self) raises -> String:
        var qname = bam_get_qname(self._ptr())
        var result = String()
        for i in range(Int(self._ptr()[].core.l_qname)):
            var c = qname[i]
            if c == 0:
                break
            result += String(chr(Int(c)))
        return result^

    def cigar(self) raises -> List[CigarElement]:
        var raw_cigar = bam_get_cigar(self._ptr())
        var result = List[CigarElement]()
        for i in range(Int(self._ptr()[].core.n_cigar)):
            var raw = raw_cigar[i]
            result.append(CigarElement(bam_cigar_op(raw), bam_cigar_oplen(raw)))
        return result^

    def cigar_string(self) raises -> Optional[String]:
        if self._ptr()[].core.n_cigar == 0:
            return None

        var raw_cigar = bam_get_cigar(self._ptr())
        var result = String()
        for i in range(Int(self._ptr()[].core.n_cigar)):
            var raw = raw_cigar[i]
            result += String(bam_cigar_oplen(raw))
            result += String(chr(Int(bam_cigar_opchr(raw))))
        return result^

    def query_sequence(self) raises -> String:
        var seq = bam_get_seq(self._ptr())
        var result = String()
        for i in range(Int(self._ptr()[].core.l_qseq)):
            result += _base_char(bam_seqi(seq, i))
        return result^

    def query_qualities(self) raises -> List[UInt8]:
        var qual = bam_get_qual(self._ptr())
        var result = List[UInt8]()
        for i in range(Int(self._ptr()[].core.l_qseq)):
            result.append(qual[i])
        return result^

    def aux_bytes(self) raises -> List[UInt8]:
        var aux = bam_get_aux(self._ptr())
        var result = List[UInt8]()
        for i in range(Int(bam_get_l_aux(self._ptr()))):
            result.append(aux[i])
        return result^

    def is_paired(self) -> Bool:
        return self._has_flag(BAM_FPAIRED)

    def is_proper_pair(self) -> Bool:
        return self._has_flag(BAM_FPROPER_PAIR)

    def is_unmapped(self) -> Bool:
        return self._has_flag(BAM_FUNMAP)

    def mate_is_unmapped(self) -> Bool:
        return self._has_flag(BAM_FMUNMAP)

    def is_reverse(self) -> Bool:
        return self._has_flag(BAM_FREVERSE)

    def mate_is_reverse(self) -> Bool:
        return self._has_flag(BAM_FMREVERSE)

    def is_read1(self) -> Bool:
        return self._has_flag(BAM_FREAD1)

    def is_read2(self) -> Bool:
        return self._has_flag(BAM_FREAD2)

    def is_secondary(self) -> Bool:
        return self._has_flag(BAM_FSECONDARY)

    def is_qcfail(self) -> Bool:
        return self._has_flag(BAM_FQCFAIL)

    def is_duplicate(self) -> Bool:
        return self._has_flag(BAM_FDUP)

    def is_supplementary(self) -> Bool:
        return self._has_flag(BAM_FSUPPLEMENTARY)

    def _has_flag(self, flag: Int32) -> Bool:
        return (Int32(self._ptr()[].core.flag) & flag) != 0

    def write_to(self, mut writer: Some[Writer]):
        writer.write(
            self._query_name_or_star(),
            "\t",
            self.flag(),
            "\t",
            self.reference_id(),
            "\t",
            self._sam_pos(self.reference_start()),
            "\t",
            self.mapping_quality(),
            "\t",
            self._cigar_or_star(),
            "\t",
            self.next_reference_id(),
            "\t",
            self._sam_pos(self.next_reference_start()),
            "\t",
            self.template_length(),
            "\n",
            self._sequence_or_star(),
            "\n",
            self._qualities_or_star(),
        )

    def _query_name_or_star(self) -> String:
        if not self._record:
            return String("*")

        var qname = bam_get_qname(self._ptr())
        var result = String()
        for i in range(Int(self._ptr()[].core.l_qname)):
            var c = qname[i]
            if c == 0:
                break
            result += String(chr(Int(c)))
        if result.byte_length() == 0:
            return String("*")
        return result

    def _cigar_or_star(self) -> String:
        if not self._record or self._ptr()[].core.n_cigar == 0:
            return String("*")

        var raw_cigar = bam_get_cigar(self._ptr())
        var result = String()
        for i in range(Int(self._ptr()[].core.n_cigar)):
            var raw = raw_cigar[i]
            result += String(bam_cigar_oplen(raw))
            result += String(chr(Int(bam_cigar_opchr(raw))))
        return result

    def _sequence_or_star(self) -> String:
        if not self._record or self._ptr()[].core.l_qseq == 0:
            return String("*")

        var seq = bam_get_seq(self._ptr())
        var result = String()
        for i in range(Int(self._ptr()[].core.l_qseq)):
            result += _base_char(bam_seqi(seq, i))
        return result

    def _qualities_or_star(self) -> String:
        if not self._record or self._ptr()[].core.l_qseq == 0:
            return String("*")

        var qual = bam_get_qual(self._ptr())
        var result = String()
        for i in range(Int(self._ptr()[].core.l_qseq)):
            result += String(chr(Int(qual[i] + UInt8(33))))
        return result

    def _sam_pos(self, pos: Int64) -> Int64:
        if pos < 0:
            return 0
        return pos + 1


struct BamHeader(Movable):
    var _header: Optional[UnsafePointer[sam_hdr_t, MutExternalOrigin]]

    def __init__(
        out self, var header: UnsafePointer[sam_hdr_t, MutExternalOrigin]
    ) raises:
        if not header:
            raise Error("sam_hdr_t allocation failed")
        self._header = header

    def __init__(out self, *, deinit take: Self):
        self._header = take._header^

    def __del__(deinit self):
        if self._header:
            sam_hdr_destroy(self._header.value())

    def _ptr(self) -> UnsafePointer[sam_hdr_t, MutExternalOrigin]:
        return self._header.value()

    def _const_ptr(self) -> UnsafePointer[sam_hdr_t, ImmutExternalOrigin]:
        return (
            self._ptr()
            .unsafe_mut_cast[False]()
            .unsafe_origin_cast[ImmutExternalOrigin]()
        )

    def text(self) raises -> String:
        var header = self._ptr()
        var result = String()
        for i in range(Int(sam_hdr_length(header))):
            result += String(chr(Int(sam_hdr_str(header)[i])))
        return result^

    def n_references(self) -> Int:
        return Int(sam_hdr_nref(self._const_ptr()))

    def reference_name(self, tid: Int32) -> Optional[String]:
        if tid < 0 or tid >= Int32(sam_hdr_nref(self._const_ptr())):
            return None

        var name = sam_hdr_tid2name(self._const_ptr(), tid)
        var result = String()
        var i = 0
        while True:
            var c = name[i]
            if c == 0:
                break
            result += String(chr(Int(c)))
            i += 1
        return result^

    def reference_length(self, tid: Int32) -> Optional[Int64]:
        if tid < 0 or tid >= Int32(sam_hdr_nref(self._const_ptr())):
            return None

        var length = sam_hdr_tid2len(self._const_ptr(), tid)
        if length < 0:
            return None
        return Int64(length)


struct BamReader(Movable):
    var _file: Optional[UnsafePointer[samFile, MutExternalOrigin]]
    var _header: Optional[UnsafePointer[sam_hdr_t, MutExternalOrigin]]

    def __init__(out self, path: String) raises:
        self._file = None
        self._header = None

        var path_c = _terminated(path)
        var mode_c = _terminated(String("r"))
        var file = sam_open(_cstr(path_c), _cstr(mode_c))
        if not file:
            raise Error("sam_open failed")

        var header = sam_hdr_read(file)
        if not header:
            sam_close(file)
            raise Error("sam_hdr_read failed")

        self._file = file
        self._header = header

    def __del__(deinit self):
        if self._file:
            sam_close(self._file.value())
        if self._header:
            sam_hdr_destroy(self._header.value())

    def _file_ptr(self) -> UnsafePointer[samFile, MutExternalOrigin]:
        return self._file.value()

    def _header_ptr(self) -> UnsafePointer[sam_hdr_t, MutExternalOrigin]:
        return self._header.value()

    def header(self) raises -> BamHeader:
        var header = sam_hdr_dup(
            self._header_ptr()
            .unsafe_mut_cast[False]()
            .unsafe_origin_cast[ImmutExternalOrigin]()
        )
        if not header:
            raise Error("sam_hdr_dup failed")
        var result = BamHeader(header)
        return result^

    def read_next(mut self, mut record: BamRecord) raises -> Bool:
        if not record._record:
            raise Error("BamRecord is closed")

        var rc = sam_read1(self._file_ptr(), self._header_ptr(), record._ptr())
        if rc >= 0:
            return True
        if rc == -1:
            return False
        raise Error(String("sam_read1 failed with code ") + String(rc))

    def next(mut self) raises -> Optional[BamRecord]:
        var record = BamRecord()
        if not self.read_next(record):
            return None
        return record^


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


def _base_char(base: UInt8) -> String:
    if base == 1:
        return String("A")
    if base == 2:
        return String("C")
    if base == 4:
        return String("G")
    if base == 8:
        return String("T")
    if base == 15:
        return String("N")
    if base == 0:
        return String("=")
    if base == 3:
        return String("M")
    if base == 5:
        return String("R")
    if base == 6:
        return String("S")
    if base == 7:
        return String("V")
    if base == 9:
        return String("W")
    if base == 10:
        return String("Y")
    if base == 11:
        return String("H")
    if base == 12:
        return String("K")
    if base == 13:
        return String("D")
    if base == 14:
        return String("B")
    return String("N")
