from std.ffi import CStringSlice, c_char

from hts_mojo.bam._common import (
    _cstr_ptr,
    _check_sam_text_ascii,
    _terminated,
    _check_zero,
    _check_nonnegative,
    _check_nonnegative_i32,
    _check_ptr,
    _aux_tag,
    _aux_tag_cstr,
    _OwnedByteBuffer,
    _check_i32,
    _bytes_with_nul_ptr,
    _ensure_nul,
)
from hts_mojo.bam.header import Header, RawSamHeader
from hts_mojo.bam.index import RawHtsIndex, RawHtsIterator
from hts_mojo.bam.record import RawBamRecord, Record

from hts_mojo._ffi import (
    htsFile,
    hts_close,
    hts_itr_destroy,
    hts_itr_t,
    hts_mojo_sam_itr_next,
    hts_open,
    hts_set_fai_filename,
    hts_set_threads,
    malloc,
    sam_hdr_add_lines,
    sam_hdr_destroy,
    sam_hdr_dup,
    sam_hdr_init,
    sam_hdr_length,
    sam_hdr_name2tid,
    sam_hdr_nref,
    sam_hdr_parse,
    sam_hdr_read,
    sam_hdr_str,
    sam_hdr_tid2len,
    sam_hdr_tid2name,
    sam_hdr_t,
    sam_hdr_write,
    sam_index_build3,
    sam_index_load,
    sam_index_load2,
    sam_index_load3,
    sam_itr_queryi,
    sam_itr_querys,
    sam_read1,
    sam_write1,
    uint32_t,
)



def _writer_mode(path: String, options: WriteOptions) raises -> String:
    var mode = String("w")
    if not options.format:
        if options.compression_level:
            raise Error(
                "compression level requires an explicit BAM or CRAM output"
                " format"
            )
        return mode

    var format = options.format.value()
    if format == AlignmentFormat.Sam:
        if options.compression_level:
            raise Error("compression level is not supported for SAM output")
        return mode
    if format == AlignmentFormat.Bam:
        mode += "b"
    elif format == AlignmentFormat.Cram:
        mode += "c"
    else:
        raise Error("unknown alignment output format")

    if options.compression_level:
        var level = options.compression_level.value()
        if level < 0 or level > 9:
            raise Error("compression level must be between 0 and 9")
        mode += String(level)
    return mode


@fieldwise_init
struct ReadOptions(Copyable, Movable):
    var reference_path: Optional[String]
    var threads: Int
    var index_path: Optional[String]
    var require_index: Bool


@fieldwise_init
struct WriteOptions(Copyable, Movable):
    var reference_path: Optional[String]
    var threads: Int
    var format: Optional[AlignmentFormat]
    var compression_level: Optional[Int]


struct RecordsIter(Movable):
    var _reader: UnsafePointer[Reader, MutUntrackedOrigin]
    var _iter: Optional[RawHtsIterator]
    var _cached: Optional[RawBamRecord]

    def __init__(
        out self,
        reader: UnsafePointer[Reader, MutUntrackedOrigin],
        var iter: Optional[RawHtsIterator] = None,
    ):
        self._reader = reader
        self._iter = iter^
        self._cached = None

    def read_into(mut self, mut record: Record) raises -> Bool:
        if self._cached:
            var cached = self._cached^
            self._cached = None
            record._raw.copy_from(cached.value())
            return True
        if self._iter:
            var rc = self._iter.value().next_status(
                self._reader[]._file, record._raw
            )
            if rc >= 0:
                return True
            if rc == -1:
                return False
            raise Error("failed to read indexed alignment record")

        return self._reader[].read_into(record)

    def next(mut self) raises -> Optional[Record]:
        var record = Record()
        if not self.read_into(record):
            return None
        return record^

    def has_next(mut self) raises -> Bool:
        if self._cached:
            return True
        var raw_record = RawBamRecord()
        if self._iter:
            var rc = self._iter.value().next_status(
                self._reader[]._file, raw_record
            )
            if rc >= 0:
                self._cached = raw_record^
                return True
            if rc == -1:
                return False
            raise Error("failed to read indexed alignment record")

        var rc = self._reader[]._file.read1_status(
            self._reader[]._header, raw_record
        )
        if rc >= 0:
            self._cached = raw_record^
            return True
        if rc == -1:
            return False
        raise Error("failed to read alignment record")

    def pop_next(mut self) raises -> Optional[Record]:
        return self.next()


@fieldwise_init
struct AlignmentFormat(Comparable, TrivialRegisterPassable):
    var value: UInt8

    comptime Sam = Self(0)
    comptime Bam = Self(1)
    comptime Cram = Self(2)

    def __eq__(self: Self, other: Self) -> Bool:
        return self.value == other.value

    def __lt__(self: Self, other: Self) -> Bool:
        return self.value < other.value


struct IndexedReader(Movable):
    var _reader: Reader
    var _index: Optional[RawHtsIndex]

    @staticmethod
    def open(
        path: String,
        index_path: Optional[String] = None,
        reference_path: Optional[String] = None,
        threads: Int = 0,
    ) raises -> Self:
        return Self(path, index_path, reference_path, threads)

    @staticmethod
    def open(
        path: String,
        var options: ReadOptions,
        index_path: Optional[String] = None,
    ) raises -> Self:
        if index_path:
            return Self(
                path, index_path, options.reference_path^, options.threads
            )
        return Self(
            path,
            options.index_path^,
            options.reference_path^,
            options.threads,
            options.require_index,
        )

    def __init__(
        out self,
        path: String,
        index_path: Optional[String] = None,
        reference_path: Optional[String] = None,
        threads: Int = 0,
        require_index: Bool = True,
    ) raises:
        self._reader = Reader(path, reference_path, threads)
        self._index = None
        if index_path:
            if require_index:
                self._index = RawHtsIndex.load_at(
                    self._reader._file, path, index_path.value()
                )
            else:
                try:
                    self._index = RawHtsIndex.load_at(
                        self._reader._file, path, index_path.value()
                    )
                except e:
                    self._index = None
        elif require_index:
            self._index = RawHtsIndex.load(self._reader._file, path)
        else:
            try:
                self._index = RawHtsIndex.load(self._reader._file, path)
            except e:
                self._index = None

    def header(self) raises -> Header:
        return self._reader.header()

    def fetch(mut self, region: Region) raises -> RecordsIter:
        if not self._index:
            raise Error("alignment index is unavailable")
        var tid = self.header().require_tid(region.contig)
        return RecordsIter(
            UnsafePointer(to=self._reader).unsafe_origin_cast[
                MutUntrackedOrigin
            ](),
            RawHtsIterator.queryi(
                self._index.value(), tid, region.start0, region.end0
            ),
        )

    def fetch_string(mut self, region: String) raises -> RecordsIter:
        if not self._index:
            raise Error("alignment index is unavailable")
        return RecordsIter(
            UnsafePointer(to=self._reader).unsafe_origin_cast[
                MutUntrackedOrigin
            ](),
            RawHtsIterator.querys(
                self._index.value(), self._reader._header, region
            ),
        )

    def read_into(mut self, mut record: Record) raises -> Bool:
        return self._reader.read_into(record)

    def next(mut self) raises -> Optional[Record]:
        var record = Record()
        if not self.read_into(record):
            return None
        return record^

    def records(mut self) -> RecordsIter:
        return self._reader.records()

    def set_threads(mut self, n_threads: Int) raises:
        self._reader.set_threads(n_threads)

    def set_reference(mut self, reference_path: String) raises:
        self._reader.set_reference(reference_path)

    def close(mut self) raises:
        self._reader.close()


struct Reader(Movable):
    var _file: RawAlignmentFile
    var _header: RawSamHeader

    @staticmethod
    def open(
        path: String, reference_path: Optional[String] = None, threads: Int = 0
    ) raises -> Self:
        return Self(path, reference_path, threads)

    @staticmethod
    def open(path: String, var options: ReadOptions) raises -> Self:
        return Self(path, options.reference_path^, options.threads)

    def __init__(
        out self,
        path: String,
        reference_path: Optional[String] = None,
        threads: Int = 0,
    ) raises:
        self._file = RawAlignmentFile(path, String("r"))
        if reference_path:
            self._file.set_reference(reference_path.value())
        if threads > 0:
            self._file.set_threads(threads)
        self._header = self._file.read_header()

    def header(self) raises -> Header:
        var result = Header()
        result._raw = self._header.dup()
        return result^

    def read_into(mut self, mut record: Record) raises -> Bool:
        var rc = self._file.read1_status(self._header, record._raw)
        if rc >= 0:
            return True
        if rc == -1:
            return False
        raise Error("failed to read alignment record")

    def read_next(mut self, mut record: Record) raises -> Bool:
        return self.read_into(record)

    def next(mut self) raises -> Optional[Record]:
        var record = Record()
        if not self.read_into(record):
            return None
        return record^

    def records(mut self) -> RecordsIter:
        return RecordsIter(
            UnsafePointer(to=self).unsafe_origin_cast[MutUntrackedOrigin]()
        )

    def set_threads(mut self, n_threads: Int) raises:
        self._file.set_threads(n_threads)

    def set_reference(mut self, reference_path: String) raises:
        self._file.set_reference(reference_path)

    def close(mut self) raises:
        self._file.close()


struct Writer(Movable):
    var _file: RawAlignmentFile
    var _header: RawSamHeader

    @staticmethod
    def open(
        path: String,
        header: Header,
        reference_path: Optional[String] = None,
        threads: Int = 0,
        format: Optional[AlignmentFormat] = None,
        compression_level: Optional[Int] = None,
    ) raises -> Self:
        return Self(
            path,
            header,
            reference_path,
            threads,
            format,
            compression_level,
        )

    @staticmethod
    def open(
        path: String, header: Header, var options: WriteOptions
    ) raises -> Self:
        return Self(
            path,
            header,
            options.reference_path^,
            options.threads,
            options.format,
            options.compression_level,
        )

    def __init__(
        out self,
        path: String,
        header: Header,
        reference_path: Optional[String] = None,
        threads: Int = 0,
        format: Optional[AlignmentFormat] = None,
        compression_level: Optional[Int] = None,
    ) raises:
        var mode = _writer_mode(
            path,
            WriteOptions(reference_path, threads, format, compression_level),
        )
        self._file = RawAlignmentFile(path, mode)
        if reference_path:
            self._file.set_reference(reference_path.value())
        if threads > 0:
            self._file.set_threads(threads)
        self._header = header._raw.dup()
        self._file.write_header(self._header)

    def write(mut self, read record: Record) raises:
        self._file.write1(self._header, record._raw)

    def set_threads(mut self, n_threads: Int) raises:
        self._file.set_threads(n_threads)

    def close(mut self) raises:
        self._file.close()


struct RawAlignmentFile(Movable):
    var _ptr: Optional[UnsafePointer[htsFile, MutUntrackedOrigin]]

    def __init__(out self, path: String, mode: String) raises:
        var path_c = path
        var mode_c = mode
        self._ptr = hts_open(_cstr_ptr(path_c), _cstr_ptr(mode_c))
        if not self._ptr:
            raise Error("failed to open alignment file")

    def __del__(deinit self):
        if self._ptr:
            _ = hts_close(self._ptr.value())

    def ptr(self) raises -> UnsafePointer[htsFile, MutUntrackedOrigin]:
        if not self._ptr:
            raise Error("alignment file is closed")
        return self._ptr.value()

    def unsafe_ptr_unchecked(
        self,
    ) -> UnsafePointer[htsFile, MutUntrackedOrigin]:
        return self._ptr.value()

    def close(mut self) raises:
        if self._ptr:
            _check_zero(
                Int(hts_close(self._ptr.value())), "failed to close file"
            )
            self._ptr = None

    def set_threads(mut self, n_threads: Int) raises:
        var n_threads_i32 = _check_nonnegative_i32(
            n_threads, "thread count out of range"
        )
        _check_zero(
            Int(hts_set_threads(self.ptr(), n_threads_i32)),
            "failed to set alignment threads",
        )

    def set_reference(mut self, reference_path: String) raises:
        var reference_path_c = reference_path
        _check_zero(
            Int(hts_set_fai_filename(self.ptr(), _cstr_ptr(reference_path_c))),
            "failed to set reference FASTA",
        )
        # TODO: Expose richer file-format option plumbing here when Mojo can call
        # HTSlib vararg APIs such as hts_set_opt(...) safely.

    def read_header(mut self) raises -> RawSamHeader:
        return RawSamHeader.adopt(sam_hdr_read(self.ptr()))

    def write_header(mut self, header: RawSamHeader) raises:
        _check_zero(
            Int(
                sam_hdr_write(
                    self.ptr(),
                    header.ptr()
                    .unsafe_mut_cast[False]()
                    .unsafe_origin_cast[ImmutUntrackedOrigin](),
                )
            ),
            "failed to write alignment header",
        )

    def read1_status(
        mut self, header: RawSamHeader, mut record: RawBamRecord
    ) raises -> Int:
        return Int(sam_read1(self.ptr(), header.ptr(), record.ptr()))

    def write1(mut self, header: RawSamHeader, record: RawBamRecord) raises:
        _ = _check_nonnegative(
            Int(
                sam_write1(
                    self.ptr(),
                    header.ptr()
                    .unsafe_mut_cast[False]()
                    .unsafe_origin_cast[ImmutUntrackedOrigin](),
                    record.ptr()
                    .unsafe_mut_cast[False]()
                    .unsafe_origin_cast[ImmutUntrackedOrigin](),
                )
            ),
            "failed to write alignment record",
        )
