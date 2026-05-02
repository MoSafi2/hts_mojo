from hts_mojo._ffi.hts import *


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


def main() raises:
    test_hts_version()
    test_hts_open_close()
    test_hts_expand()
    test_hts_expand0()
    test_bin_helpers()

    hts_lib_shutdown()
    print("HTSlib smoke test: OK")
