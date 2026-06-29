from hts_mojo.bam.file import (
    RawAlignmentFile,
    RawHtsIndex,
    RawHtsIterator,
    Region,
)
from hts_mojo.bam.header import Header, RawSamHeader
from hts_mojo.bam.pileup import Pileups
from hts_mojo.bam.record import RawBamRecord, Record


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


struct RecordsIter[origin: Origin](Iterator, Movable):
    var _reader: Pointer[Reader, Self.origin]
    var _iter: Optional[RawHtsIterator]
    var _cached: Optional[Record]

    comptime Element = Record

    def __init__(
        out self,
        reader: Pointer[Reader, Self.origin],
        var iter: Optional[RawHtsIterator] = None,
    ):
        self._reader = reader
        self._iter = iter^
        self._cached = None

    def read_into(mut self, mut record: Record) raises -> Bool:
        var reader = rebind[Pointer[Reader, MutUntrackedOrigin]](self._reader)
        if self._cached:
            var cached = self._cached.take()
            record._raw.copy_from(cached._raw)
            return True
        if self._iter:
            var rc = self._iter.value().next_status(reader[]._file, record._raw)
            if rc >= 0:
                return True
            if rc == -1:
                return False
            raise Error("failed to read indexed alignment record")

        return reader[].read_into(record)

    def next(mut self) raises -> Optional[Record]:
        var record = Record()
        if not self.read_into(record):
            return None
        return record^

    def __next__(mut self) raises StopIteration -> Self.Element:
        try:
            if not self.has_next():
                raise StopIteration()
        except Error:
            print(String(Error))
            raise StopIteration()
        var record = self._cached.take()
        return record^

    def __has_next__(mut self) -> Bool:
        try:
            return self.has_next()
        except Error:
            print(String(Error))
            return False

    def has_next(mut self) raises -> Bool:
        var reader = rebind[Pointer[Reader, MutUntrackedOrigin]](self._reader)
        if self._cached:
            return True
        var record = Record()
        if self._iter:
            var rc = self._iter.value().next_status(reader[]._file, record._raw)
            if rc >= 0:
                self._cached = record^
                return True
            if rc == -1:
                return False
            raise Error("failed to read indexed alignment record")

        var rc = reader[]._file.read1_status(reader[]._header, record._raw)
        if rc >= 0:
            self._cached = record^
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

    def fetch(
        ref self, region: Region
    ) raises -> RecordsIter[origin_of(self._reader)]:
        if not self._index:
            raise Error("alignment index is unavailable")
        var tid = self.header().require_tid(region.contig)
        return RecordsIter(
            Pointer(to=self._reader),
            RawHtsIterator.queryi(
                self._index.value(), tid, region.start0, region.end0
            ),
        )

    def fetch_string(
        ref self, region: String
    ) raises -> RecordsIter[origin_of(self._reader)]:
        if not self._index:
            raise Error("alignment index is unavailable")
        return RecordsIter(
            Pointer(to=self._reader),
            RawHtsIterator.querys(
                self._index.value(), self._reader._header, region
            ),
        )

    def read_into(mut self, mut record: Record) raises -> Bool:
        return self._reader.read_into(record)

    def pileup(mut self, max_depth: Optional[Int] = None) raises -> Pileups:
        return Pileups.from_reader(
            self._reader._file, self._reader._header, max_depth
        )

    def pileup_region(
        mut self, region: Region, max_depth: Optional[Int] = None
    ) raises -> Pileups:
        if not self._index:
            raise Error("alignment index is unavailable")
        var tid = self._reader.header().require_tid(region.contig)
        return Pileups.from_reader(
            self._reader._file,
            self._reader._header,
            max_depth,
            RawHtsIterator.queryi(
                self._index.value(), tid, region.start0, region.end0
            ),
        )

    def pileup_string(
        mut self, region: String, max_depth: Optional[Int] = None
    ) raises -> Pileups:
        if not self._index:
            raise Error("alignment index is unavailable")
        return Pileups.from_reader(
            self._reader._file,
            self._reader._header,
            max_depth,
            RawHtsIterator.querys(
                self._index.value(), self._reader._header, region
            ),
        )

    def next(mut self) raises -> Optional[Record]:
        var record = Record()
        if not self.read_into(record):
            return None
        return record^

    def records(ref self) -> RecordsIter[origin_of(self)]:
        return self._reader.records()

    def set_threads(mut self, n_threads: Int) raises:
        self._reader.set_threads(n_threads)

    def set_reference(mut self, reference_path: String) raises:
        self._reader.set_reference(reference_path)

    def close(mut self) raises:
        self._reader.close()


struct Reader(Iterable, Movable):
    var _file: RawAlignmentFile
    var _header: RawSamHeader

    comptime IteratorType[
        iterable_mut: Bool, //, iterable_origin: Origin[mut=iterable_mut]
    ]: Iterator = RecordsIter[iterable_origin]

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

    def __iter__(ref self) -> Self.IteratorType[origin_of(self)]:
        return self.records()

    def records(ref self) -> RecordsIter[origin_of(self)]:
        return RecordsIter(Pointer(to=self))

    def pileup(mut self, max_depth: Optional[Int] = None) raises -> Pileups:
        return Pileups.from_reader(self._file, self._header, max_depth)

    def set_threads(mut self, n_threads: Int) raises:
        self._file.set_threads(n_threads)

    def set_reference(mut self, reference_path: String) raises:
        self._file.set_reference(reference_path)

    def close(mut self) raises:
        self._file.close()


comptime BamReader = Reader


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
