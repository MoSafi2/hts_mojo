/*  hts_defs.h -- Miscellaneous definitions.

    Copyright (C) 2013-2015,2017, 2019-2020, 2024 Genome Research Ltd.

    Author: John Marshall <jm18@sanger.ac.uk>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.  */

#ifndef HTSLIB_HTS_DEFS_H
#define HTSLIB_HTS_DEFS_H

#if defined __MINGW32__
#include <stdio.h>     // For __MINGW_PRINTF_FORMAT macro
#endif

#ifdef __clang__
#ifdef __has_attribute
#define HTS_COMPILER_HAS(attribute) __has_attribute(attribute)
#endif

#elif defined __GNUC__
#define HTS_GCC_AT_LEAST(major, minor) \
    (__GNUC__ > (major) || (__GNUC__ == (major) && __GNUC_MINOR__ >= (minor)))
#endif

#ifndef HTS_COMPILER_HAS
#define HTS_COMPILER_HAS(attribute) 0
#endif
#ifndef HTS_GCC_AT_LEAST
#define HTS_GCC_AT_LEAST(major, minor) 0
#endif

#if HTS_COMPILER_HAS(__nonstring__) || HTS_GCC_AT_LEAST(8,1)
#define HTS_NONSTRING __attribute__ ((__nonstring__))
#else
#define HTS_NONSTRING
#endif

#if HTS_COMPILER_HAS(__noreturn__) || HTS_GCC_AT_LEAST(3,0)
#define HTS_NORETURN __attribute__ ((__noreturn__))
#else
#define HTS_NORETURN
#endif

#if HTS_GCC_AT_LEAST(10,1)
#define HTS_ACCESS(access_mode, ...) __attribute__ ((access(access_mode, __VA_ARGS__)))
#else
#define HTS_ACCESS(access_mode, ...)
#endif

// Enable optimisation level 3, especially for gcc.  To be used
// where we want to force vectorisation in hot loops and the default -O2
// just doesn't cut it.
#if HTS_COMPILER_HAS(optimize) || HTS_GCC_AT_LEAST(4,4)
#define HTS_OPT3 __attribute__((optimize("O3")))
#else
#define HTS_OPT3
#endif

#if HTS_COMPILER_HAS(aligned) || HTS_GCC_AT_LEAST(4,3)
#define HTS_ALIGN32 __attribute__((aligned(32)))
#else
#define HTS_ALIGN32
#endif

// GCC introduced warn_unused_result in 3.4 but added -Wno-unused-result later
#if HTS_COMPILER_HAS(__warn_unused_result__) || HTS_GCC_AT_LEAST(4,5)
#define HTS_RESULT_USED __attribute__ ((__warn_unused_result__))
#else
#define HTS_RESULT_USED
#endif

#if HTS_COMPILER_HAS(__unused__) || HTS_GCC_AT_LEAST(3,0)
#define HTS_UNUSED __attribute__ ((__unused__))
#else
#define HTS_UNUSED
#endif

#if HTS_COMPILER_HAS(__deprecated__) || HTS_GCC_AT_LEAST(4,5)
#define HTS_DEPRECATED(message) __attribute__ ((__deprecated__ (message)))
#elif HTS_GCC_AT_LEAST(3,1)
#define HTS_DEPRECATED(message) __attribute__ ((__deprecated__))
#else
#define HTS_DEPRECATED(message)
#endif

#if (HTS_COMPILER_HAS(__deprecated__) || HTS_GCC_AT_LEAST(6,4)) && !defined(__ICC)
#define HTS_DEPRECATED_ENUM(message) __attribute__ ((__deprecated__ (message)))
#else
#define HTS_DEPRECATED_ENUM(message)
#endif

// On mingw the "printf" format type doesn't work.  It needs "gnu_printf"
// in order to check %lld and %z, otherwise it defaults to checking against
// the Microsoft library printf format options despite linking against the
// GNU posix implementation of printf.  The __MINGW_PRINTF_FORMAT macro
// expands to printf or gnu_printf as required, but obviously may not
// exist
#ifdef __MINGW_PRINTF_FORMAT
#define HTS_PRINTF_FMT __MINGW_PRINTF_FORMAT
#else
#define HTS_PRINTF_FMT printf
#endif

#if HTS_COMPILER_HAS(__format__) || HTS_GCC_AT_LEAST(3,0)
#define HTS_FORMAT(type, idx, first) __attribute__((__format__ (type, idx, first)))
#else
#define HTS_FORMAT(type, idx, first)
#endif

#if defined(_WIN32) || defined(__CYGWIN__)
#if defined(HTS_BUILDING_LIBRARY)
#define HTSLIB_EXPORT __declspec(dllexport)
#else
#define HTSLIB_EXPORT
#endif
#elif HTS_COMPILER_HAS(__visibility__) || HTS_GCC_AT_LEAST(4,0)
#define HTSLIB_EXPORT __attribute__((__visibility__("default")))
#elif defined(__SUNPRO_C) && __SUNPRO_C >= 0x550
#define HTSLIB_EXPORT __global
#else
#define HTSLIB_EXPORT
#endif

// Prefetch implementations.
// We only support a basic implementation here
#ifdef HAVE___BUILTIN_PREFETCH
static inline void hts_prefetch(void *p) {
    __builtin_prefetch(p);
}
#else
static inline void hts_prefetch(void *p) {
    // Fetch and discard is quite close to a genuine prefetch
    *(volatile char *)p;
}
#endif

#endif


/// @file hts_endian.h
/// Byte swapping and unaligned access functions.
/*
   Copyright (C) 2017 Genome Research Ltd.

    Author: Rob Davies <rmd@sanger.ac.uk>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.  */

#ifndef HTS_ENDIAN_H
#define HTS_ENDIAN_H

#include <stdint.h>

/*
 * Compile-time endianness tests.
 *
 * Note that these tests may fail.  They should only be used to enable
 * faster versions of endian-neutral implementations.  The endian-neutral
 * version should always be available as a fall-back.
 *
 * See https://sourceforge.net/p/predef/wiki/Endianness/
 */

/* Save typing as both endian and unaligned tests want to know about x86 */
#if (defined(__i386__) || defined(__i386) || defined(__amd64__) ||             \
     defined(__amd64) || defined(__x86_64__) || defined(__x86_64) ||           \
     defined(__i686__) || defined(__i686)) &&                                  \
    !defined(HTS_x86)
#define HTS_x86 /* x86 and x86_64 platform */
#endif

/** @def HTS_LITTLE_ENDIAN
 *  @brief Defined if platform is known to be little-endian
 */

#ifndef HTS_LITTLE_ENDIAN
#if (defined(__BYTE_ORDER__) && __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__) ||  \
    defined(__LITTLE_ENDIAN__) || defined(HTS_x86) || defined(__ARMEL__) ||    \
    defined(__THUMBEL__) || defined(__AARCH64EL__) || defined(_MIPSEL) ||      \
    defined(__MIPSEL) || defined(__MIPSEL__)
#define HTS_LITTLE_ENDIAN
#endif
#endif

/** @def HTS_BIG_ENDIAN
 *  @brief Defined if platform is known to be big-endian
 */

#ifndef HTS_BIG_ENDIAN
#if (defined(__BYTE_ORDER__) && __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__) ||     \
    defined(__BIG_ENDIAN__) || defined(__ARMEB__) || defined(__THUMBEB__) ||   \
    defined(__AAARCHEB__) || defined(_MIPSEB) || defined(__MIPSEB) ||          \
    defined(__MIPSEB__)
#define HTS_BIG_ENDIAN
#endif
#endif

/** @def HTS_ENDIAN_NEUTRAL
 *  @brief Define this to disable any endian-specific optimizations
 */

#if defined(HTS_ENDIAN_NEUTRAL) ||                                             \
    (defined(HTS_LITTLE_ENDIAN) && defined(HTS_BIG_ENDIAN))
/* Disable all endian-specific code. */
#undef HTS_LITTLE_ENDIAN
#undef HTS_BIG_ENDIAN
#endif

/** @def HTS_ALLOW_UNALIGNED
 *  @brief Control use of unaligned memory access.
 *
 * Defining HTS_ALLOW_UNALIGNED=1 converts shift-and-or to simple casts on
 * little-endian platforms that can tolerate unaligned access (notably Intel
 * x86).
 *
 * Defining HTS_ALLOW_UNALIGNED=0 forces shift-and-or.
 */

// Consider using AX_CHECK_ALIGNED_ACCESS_REQUIRED in autoconf.
#ifndef HTS_ALLOW_UNALIGNED
#if defined(HTS_x86)
#define HTS_ALLOW_UNALIGNED 1
#else
#define HTS_ALLOW_UNALIGNED 0
#endif
#endif

#if HTS_ALLOW_UNALIGNED != 0
#if defined(__GNUC__) &&                                                       \
        (__GNUC__ > 4 || (__GNUC__ == 4 && __GNUC_MINOR__ >= 3)) ||            \
    defined(__clang__)
// This prevents problems with gcc's vectoriser generating the wrong
// instructions for unaligned data.
typedef uint16_t uint16_u __attribute__((__aligned__(1)));
typedef uint32_t uint32_u __attribute__((__aligned__(1)));
typedef uint64_t uint64_u __attribute__((__aligned__(1)));
#else
typedef uint16_t uint16_u;
typedef uint32_t uint32_u;
typedef uint64_t uint64_u;
#endif
#endif

/// Get a uint8_t value from an unsigned byte array
/** @param buf Pointer to source byte, may be unaligned
 *  @return An 8-bit unsigned integer
 */
static inline uint8_t le_to_u8(const uint8_t *buf) { return *buf; }

/// Get a uint16_t value from an unsigned byte array
/** @param buf Pointer to source byte, may be unaligned
 *  @return A 16 bit unsigned integer
 *  The input is read in little-endian byte order.
 */
static inline uint16_t le_to_u16(const uint8_t *buf) {
#if defined(HTS_LITTLE_ENDIAN) && HTS_ALLOW_UNALIGNED != 0
  return *((uint16_u *)buf);
#else
  return (uint16_t)buf[0] | ((uint16_t)buf[1] << 8);
#endif
}

/// Get a uint32_t value from an unsigned byte array
/** @param buf Pointer to source byte array, may be unaligned
 *  @return A 32 bit unsigned integer
 *  The input is read in little-endian byte order.
 */
static inline uint32_t le_to_u32(const uint8_t *buf) {
#if defined(HTS_LITTLE_ENDIAN) && HTS_ALLOW_UNALIGNED != 0
  return *((uint32_u *)buf);
#else
  return ((uint32_t)buf[0] | ((uint32_t)buf[1] << 8) |
          ((uint32_t)buf[2] << 16) | ((uint32_t)buf[3] << 24));
#endif
}

/// Get a uint64_t value from an unsigned byte array
/** @param buf Pointer to source byte array, may be unaligned
 *  @return A 64 bit unsigned integer
 *  The input is read in little-endian byte order.
 */
static inline uint64_t le_to_u64(const uint8_t *buf) {
#if defined(HTS_LITTLE_ENDIAN) && HTS_ALLOW_UNALIGNED != 0
  return *((uint64_u *)buf);
#else
  return ((uint64_t)buf[0] | ((uint64_t)buf[1] << 8) |
          ((uint64_t)buf[2] << 16) | ((uint64_t)buf[3] << 24) |
          ((uint64_t)buf[4] << 32) | ((uint64_t)buf[5] << 40) |
          ((uint64_t)buf[6] << 48) | ((uint64_t)buf[7] << 56));
#endif
}

/// Store a uint16_t value in little-endian byte order
/** @param val The value to store
 *  @param buf Where to store it (may be unaligned)
 */
static inline void u16_to_le(uint16_t val, uint8_t *buf) {
#if defined(HTS_LITTLE_ENDIAN) && HTS_ALLOW_UNALIGNED != 0
  *((uint16_u *)buf) = val;
#else
  buf[0] = val & 0xff;
  buf[1] = (val >> 8) & 0xff;
#endif
}

/// Store a uint32_t value in little-endian byte order
/** @param val The value to store
 *  @param buf Where to store it (may be unaligned)
 */
static inline void u32_to_le(uint32_t val, uint8_t *buf) {
#if defined(HTS_LITTLE_ENDIAN) && HTS_ALLOW_UNALIGNED != 0
  *((uint32_u *)buf) = val;
#else
  buf[0] = val & 0xff;
  buf[1] = (val >> 8) & 0xff;
  buf[2] = (val >> 16) & 0xff;
  buf[3] = (val >> 24) & 0xff;
#endif
}

/// Store a uint64_t value in little-endian byte order
/** @param val The value to store
 *  @param buf Where to store it (may be unaligned)
 */
static inline void u64_to_le(uint64_t val, uint8_t *buf) {
#if defined(HTS_LITTLE_ENDIAN) && HTS_ALLOW_UNALIGNED != 0
  *((uint64_u *)buf) = val;
#else
  buf[0] = val & 0xff;
  buf[1] = (val >> 8) & 0xff;
  buf[2] = (val >> 16) & 0xff;
  buf[3] = (val >> 24) & 0xff;
  buf[4] = (val >> 32) & 0xff;
  buf[5] = (val >> 40) & 0xff;
  buf[6] = (val >> 48) & 0xff;
  buf[7] = (val >> 56) & 0xff;
#endif
}

/* Signed values.  Grab the data as unsigned, then convert to signed without
 * triggering undefined behaviour.  On any sensible platform, the conversion
 * should optimise away to nothing.
 */

/// Get an int8_t value from an unsigned byte array
/** @param buf Pointer to source byte array, may be unaligned
 *  @return A 8 bit signed integer
 *  The input data is interpreted as 2's complement representation.
 */
static inline int8_t le_to_i8(const uint8_t *buf) {
  return *buf < 0x80 ? (int8_t)*buf : -((int8_t)(0xff - *buf)) - 1;
}

/// Get an int16_t value from an unsigned byte array
/** @param buf Pointer to source byte array, may be unaligned
 *  @return A 16 bit signed integer
 *  The input data is interpreted as 2's complement representation in
 *  little-endian byte order.
 */
static inline int16_t le_to_i16(const uint8_t *buf) {
  uint16_t v = le_to_u16(buf);
  return v < 0x8000 ? (int16_t)v : -((int16_t)(0xffff - v)) - 1;
}

/// Get an int32_t value from an unsigned byte array
/** @param buf Pointer to source byte array, may be unaligned
 *  @return A 32 bit signed integer
 *  The input data is interpreted as 2's complement representation in
 *  little-endian byte order.
 */
static inline int32_t le_to_i32(const uint8_t *buf) {
  uint32_t v = le_to_u32(buf);
  return v < 0x80000000U ? (int32_t)v : -((int32_t)(0xffffffffU - v)) - 1;
}

/// Get an int64_t value from an unsigned byte array
/** @param buf Pointer to source byte array, may be unaligned
 *  @return A 64 bit signed integer
 *  The input data is interpreted as 2's complement representation in
 *  little-endian byte order.
 */
static inline int64_t le_to_i64(const uint8_t *buf) {
  uint64_t v = le_to_u64(buf);
  return (v < 0x8000000000000000ULL
              ? (int64_t)v
              : -((int64_t)(0xffffffffffffffffULL - v)) - 1);
}

// Converting the other way is easier as signed -> unsigned is well defined.

/// Store a uint16_t value in little-endian byte order
/** @param val The value to store
 *  @param buf Where to store it (may be unaligned)
 */
static inline void i16_to_le(int16_t val, uint8_t *buf) { u16_to_le(val, buf); }

/// Store a uint32_t value in little-endian byte order
/** @param val The value to store
 *  @param buf Where to store it (may be unaligned)
 */
static inline void i32_to_le(int32_t val, uint8_t *buf) { u32_to_le(val, buf); }

/// Store a uint64_t value in little-endian byte order
/** @param val The value to store
 *  @param buf Where to store it (may be unaligned)
 */
static inline void i64_to_le(int64_t val, uint8_t *buf) { u64_to_le(val, buf); }

/* Floating point.  Assumptions:
 *  Platform uses IEEE 754 format
 *  sizeof(float) == sizeof(uint32_t)
 *  sizeof(double) == sizeof(uint64_t)
 *  Endian-ness is the same for both floating point and integer
 *  Type-punning via a union is allowed
 */

/// Get a float value from an unsigned byte array
/** @param buf Pointer to source byte array, may be unaligned
 *  @return A 32 bit floating point value
 *  The input is interpreted as an IEEE 754 format float in little-endian
 *  byte order.
 */
static inline float le_to_float(const uint8_t *buf) {
  union {
    uint32_t u;
    float f;
  } convert;

  convert.u = le_to_u32(buf);
  return convert.f;
}

/// Get a double value from an unsigned byte array
/** @param buf Pointer to source byte array, may be unaligned
 *  @return A 64 bit floating point value
 *  The input is interpreted as an IEEE 754 format double in little-endian
 *  byte order.
 */
static inline double le_to_double(const uint8_t *buf) {
  union {
    uint64_t u;
    double f;
  } convert;

  convert.u = le_to_u64(buf);
  return convert.f;
}

/// Store a float value in little-endian byte order
/** @param val The value to store
 *  @param buf Where to store it (may be unaligned)
 */
static inline void float_to_le(float val, uint8_t *buf) {
  union {
    uint32_t u;
    float f;
  } convert;

  convert.f = val;
  u32_to_le(convert.u, buf);
}

/// Store a double value in little-endian byte order
/** @param val The value to store
 *  @param buf Where to store it (may be unaligned)
 */
static inline void double_to_le(double val, uint8_t *buf) {
  union {
    uint64_t u;
    double f;
  } convert;

  convert.f = val;
  u64_to_le(convert.u, buf);
}

#endif /* HTS_ENDIAN_H */


/// \file htslib/hts_log.h
/// Configuration of log levels.
/* The MIT License
Copyright (C) 2017 Genome Research Ltd.

Author: Anders Kaplan

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

#ifndef HTS_LOG_H
#define HTS_LOG_H

#include "hts_defs.h"

#ifdef __cplusplus
extern "C" {
#endif

/// Log levels.
enum htsLogLevel {
    HTS_LOG_OFF,            ///< All logging disabled.
    HTS_LOG_ERROR,          ///< Logging of errors only.
    HTS_LOG_WARNING = 3,    ///< Logging of errors and warnings.
    HTS_LOG_INFO,           ///< Logging of errors, warnings, and normal but significant events.
    HTS_LOG_DEBUG,          ///< Logging of all except the most detailed debug events.
    HTS_LOG_TRACE           ///< All logging enabled.
};

/// Sets the selected log level.
HTSLIB_EXPORT
void hts_set_log_level(enum htsLogLevel level);

/// Gets the selected log level.
HTSLIB_EXPORT
enum htsLogLevel hts_get_log_level(void);

/// Selected log level.
/*!
 * One of the HTS_LOG_* values. The default is HTS_LOG_WARNING.
 * \note Avoid direct use of this variable. Use hts_set_log_level and hts_get_log_level instead.
 */
HTSLIB_EXPORT
extern int hts_verbose;

/*! Logs an event.
* \param severity      Severity of the event:
*                      - HTS_LOG_ERROR means that something went wrong so that a task could not be completed.
*                      - HTS_LOG_WARNING means that something unexpected happened, but that execution can continue, perhaps in a degraded mode.
*                      - HTS_LOG_INFO means that something normal but significant happened.
*                      - HTS_LOG_DEBUG means that something normal and insignificant happened.
*                      - HTS_LOG_TRACE means that something happened that might be of interest when troubleshooting.
* \param context       Context where the event occurred. Typically set to "__func__".
* \param format        Format string with placeholders, like printf.
*/
HTSLIB_EXPORT
void hts_log(enum htsLogLevel severity, const char *context, const char *format, ...)
HTS_FORMAT(HTS_PRINTF_FMT, 3, 4);

/*! Logs an event with severity HTS_LOG_ERROR and default context. Parameters: format, ... */
#define hts_log_error(...) hts_log(HTS_LOG_ERROR, __func__, __VA_ARGS__)

/*! Logs an event with severity HTS_LOG_WARNING and default context. Parameters: format, ... */
#define hts_log_warning(...) hts_log(HTS_LOG_WARNING, __func__, __VA_ARGS__)

/*! Logs an event with severity HTS_LOG_INFO and default context. Parameters: format, ... */
#define hts_log_info(...) hts_log(HTS_LOG_INFO, __func__, __VA_ARGS__)

/*! Logs an event with severity HTS_LOG_DEBUG and default context. Parameters: format, ... */
#define hts_log_debug(...) hts_log(HTS_LOG_DEBUG, __func__, __VA_ARGS__)

/*! Logs an event with severity HTS_LOG_TRACE and default context. Parameters: format, ... */
#define hts_log_trace(...) hts_log(HTS_LOG_TRACE, __func__, __VA_ARGS__)

#ifdef __cplusplus
}
#endif

#endif // #ifndef HTS_LOG_H


/// @file htslib/hts.h
/// Format-neutral I/O, indexing, and iterator API functions.
/*
    Copyright (C) 2012-2022 Genome Research Ltd.
    Copyright (C) 2010, 2012 Broad Institute.
    Portions copyright (C) 2003-2006, 2008-2010 by Heng Li <lh3@live.co.uk>

    Author: Heng Li <lh3@sanger.ac.uk>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.  */

#ifndef HTSLIB_HTS_H
#define HTSLIB_HTS_H

#include <inttypes.h>
#include <stddef.h>
#include <stdint.h>

#include "hts_defs.h"
#include "hts_log.h"
#include "kroundup.h"
#include "kstring.h"

#ifdef __cplusplus
extern "C" {
#endif

// Separator used to split HTS_PATH (for plugins); REF_PATH (cram references)
#if defined(_WIN32) || defined(__MSYS__)
#define HTS_PATH_SEPARATOR_CHAR ';'
#define HTS_PATH_SEPARATOR_STR ";"
#else
#define HTS_PATH_SEPARATOR_CHAR ':'
#define HTS_PATH_SEPARATOR_STR ":"
#endif

#ifndef HTS_BGZF_TYPEDEF
typedef struct BGZF BGZF;
#define HTS_BGZF_TYPEDEF
#endif
struct cram_fd;
struct hFILE;
struct hts_tpool;
struct sam_hdr_t;

/**
 * @hideinitializer
 * Deprecated macro to expand a dynamic array of a given type
 *
 * @param         type_t The type of the array elements
 * @param[in]     n      Requested number of elements of type type_t
 * @param[in,out] m      Size of memory allocated
 * @param[in,out] ptr    Pointer to the array
 *
 * @discussion
 * Do not use this macro.  Use hts_resize() instead as allows allocation
 * failures to be handled more gracefully.
 *
 * The array *ptr will be expanded if necessary so that it can hold @p n
 * or more elements.  If the array is expanded then the new size will be
 * written to @p m and the value in @p ptr may change.
 *
 * It must be possible to take the address of @p ptr and @p m must be usable
 * as an lvalue.
 *
 * @bug
 * If the memory allocation fails, this will call exit(1).  This is
 * not ideal behaviour in a library.
 */
#define hts_expand(type_t, n, m, ptr)                                          \
  do {                                                                         \
    if ((n) > (m)) {                                                           \
      size_t hts_realloc_or_die(size_t, size_t, size_t, size_t, int, void **,  \
                                const char *);                                 \
      (m) = hts_realloc_or_die((n) >= 1 ? (n) : 1, (m), sizeof(m),             \
                               sizeof(type_t), 0, (void **)&(ptr), __func__);  \
    }                                                                          \
  } while (0)

/**
 * @hideinitializer
 * Macro to expand a dynamic array, zeroing any newly-allocated memory
 *
 * @param         type_t The type of the array elements
 * @param[in]     n      Requested number of elements of type type_t
 * @param[in,out] m      Size of memory allocated
 * @param[in,out] ptr    Pointer to the array
 *
 * @discussion
 * Do not use this macro.  Use hts_resize() instead as allows allocation
 * failures to be handled more gracefully.
 *
 * As for hts_expand(), except the bytes that make up the array elements
 * between the old and new values of @p m are set to zero using memset().
 *
 * @bug
 * If the memory allocation fails, this will call exit(1).  This is
 * not ideal behaviour in a library.
 */

#define hts_expand0(type_t, n, m, ptr)                                         \
  do {                                                                         \
    if ((n) > (m)) {                                                           \
      size_t hts_realloc_or_die(size_t, size_t, size_t, size_t, int, void **,  \
                                const char *);                                 \
      (m) = hts_realloc_or_die((n) >= 1 ? (n) : 1, (m), sizeof(m),             \
                               sizeof(type_t), 1, (void **)&(ptr), __func__);  \
    }                                                                          \
  } while (0)

// For internal use (by hts_resize()) only
HTSLIB_EXPORT
int hts_resize_array_(size_t, size_t, size_t, void *, void **, int,
                      const char *);

#define HTS_RESIZE_CLEAR 1

/**
 * @hideinitializer
 * Macro to expand a dynamic array of a given type
 *
 * @param         type_t    The type of the array elements
 * @param[in]     num       Requested number of elements of type type_t
 * @param[in,out] size_ptr  Pointer to where the size (in elements) of the
                            array is stored.
 * @param[in,out] ptr       Location of the pointer to the array
 * @param[in]     flags     Option flags
 *
 * @return        0 for success, or negative if an error occurred.
 *
 * @discussion
 * The array *ptr will be expanded if necessary so that it can hold @p num
 * or more elements.  If the array is expanded then the new size will be
 * written to @p *size_ptr and the value in @p *ptr may change.
 *
 * If ( @p flags & HTS_RESIZE_CLEAR ) is set, any newly allocated memory will
 * be cleared.
 */

#define hts_resize(type_t, num, size_ptr, ptr, flags)                          \
  ((num) > (*(size_ptr))                                                       \
       ? hts_resize_array_(sizeof(type_t), (num), sizeof(*(size_ptr)),         \
                           (size_ptr), (void **)(ptr), (flags), __func__)      \
       : 0)

/// Release resources when dlclosing a dynamically loaded HTSlib
/** @discussion
 *  Normally HTSlib cleans up automatically when your program exits,
 *  whether that is via exit(3) or returning from main(). However if you
 *  have dlopen(3)ed HTSlib and wish to close it before your main program
 *  exits, you must call hts_lib_shutdown() before dlclose(3).
 */
HTSLIB_EXPORT
void hts_lib_shutdown(void);

/**
 * Wrapper function for free(). Enables memory deallocation across DLL
 * boundary. Should be used by all applications, which are compiled
 * with a different standard library than htslib and call htslib
 * methods that return dynamically allocated data.
 */
HTSLIB_EXPORT
void hts_free(void *ptr);

/************
 * File I/O *
 ************/

// Add new entries only at the end (but before the *_maximum entry)
// of these enums, as their numbering is part of the htslib ABI.

enum htsFormatCategory {
  unknown_category,
  sequence_data, // Sequence data -- SAM, BAM, CRAM, etc
  variant_data,  // Variant calling data -- VCF, BCF, etc
  index_file,    // Index file associated with some data file
  region_list,   // Coordinate intervals or regions -- BED, etc
  category_maximum = 32767
};

enum htsExactFormat {
  unknown_format,
  binary_format,
  text_format,
  sam,
  bam,
  bai,
  cram,
  crai,
  vcf,
  bcf,
  csi,
  gzi,
  tbi,
  bed,
  htsget,
  json HTS_DEPRECATED_ENUM("Use htsExactFormat 'htsget' instead") = htsget,
  empty_format, // File is empty (or empty after decompression)
  fasta_format,
  fastq_format,
  fai_format,
  fqi_format,
  hts_crypt4gh_format,
  d4_format,
  format_maximum = 32767
};

enum htsCompression {
  no_compression,
  gzip,
  bgzf,
  custom,
  bzip2_compression,
  razf_compression,
  xz_compression,
  zstd_compression,
  compression_maximum = 32767
};

typedef struct htsFormat {
  enum htsFormatCategory category;
  enum htsExactFormat format;
  struct {
    short major, minor;
  } version;
  enum htsCompression compression;
  short compression_level; // currently unused
  void *specific;          // format specific options; see struct hts_opt.
} htsFormat;

struct hts_idx_t;
typedef struct hts_idx_t hts_idx_t;
struct hts_filter_t;

/**
 * @brief File handle returned by hts_open() etc.
 * This structure should be considered opaque by end users. There should be
 * no need to access most fields directly in user code, and in cases where
 * it is desirable accessor functions such as hts_get_format() are provided.
 */
// Maintainers note htsFile cannot be an incomplete struct because some of its
// fields are part of libhts.so's ABI (hence these fields must not be moved):
//  - fp is used in the public sam_itr_next()/etc macros
//  - is_bin is used directly in samtools <= 1.1 and bcftools <= 1.1
//  - is_write and is_cram are used directly in samtools <= 1.1
//  - fp is used directly in samtools (up to and including current develop)
//  - line is used directly in bcftools (up to and including current develop)
//  - is_bgzf and is_cram flags indicate which fp union member to use.
//    Note is_bgzf being set does not indicate the flag is BGZF compressed,
//    nor even whether it is compressed at all (eg on naked BAMs).
typedef struct htsFile {
  uint32_t is_bin : 1, is_write : 1, is_be : 1, is_cram : 1, is_bgzf : 1,
      dummy : 27;
  int64_t lineno;
  kstring_t line;
  char *fn, *fn_aux;
  union {
    BGZF *bgzf;
    struct cram_fd *cram;
    struct hFILE *hfile;
  } fp;
  void *state; // format specific state information
  htsFormat format;
  hts_idx_t *idx;
  const char *fnidx;
  struct sam_hdr_t *bam_header;
  struct hts_filter_t *filter;
} htsFile;

// A combined thread pool and queue allocation size.
// The pool should already be defined, but qsize may be zero to
// indicate an appropriate queue size is taken from the pool.
//
// Reasons for explicitly setting it could be where many more file
// descriptors are in use than threads, so keeping memory low is
// important.
typedef struct htsThreadPool {
  struct hts_tpool *pool; // The shared thread pool itself
  int qsize;              // Size of I/O queue to use for this fp
} htsThreadPool;

// REQUIRED_FIELDS
enum sam_fields {
  SAM_QNAME = 0x00000001,
  SAM_FLAG = 0x00000002,
  SAM_RNAME = 0x00000004,
  SAM_POS = 0x00000008,
  SAM_MAPQ = 0x00000010,
  SAM_CIGAR = 0x00000020,
  SAM_RNEXT = 0x00000040,
  SAM_PNEXT = 0x00000080,
  SAM_TLEN = 0x00000100,
  SAM_SEQ = 0x00000200,
  SAM_QUAL = 0x00000400,
  SAM_AUX = 0x00000800,
  SAM_RGAUX = 0x00001000,
};

// Mostly CRAM only, but this could also include other format options
enum hts_fmt_option {
  // CRAM specific
  CRAM_OPT_DECODE_MD,
  CRAM_OPT_PREFIX,
  CRAM_OPT_VERBOSITY, // obsolete, use hts_set_log_level() instead
  CRAM_OPT_SEQS_PER_SLICE,
  CRAM_OPT_SLICES_PER_CONTAINER,
  CRAM_OPT_RANGE,
  CRAM_OPT_VERSION, // rename to cram_version?
  CRAM_OPT_EMBED_REF,
  CRAM_OPT_IGNORE_MD5,
  CRAM_OPT_REFERENCE, // make general
  CRAM_OPT_MULTI_SEQ_PER_SLICE,
  CRAM_OPT_NO_REF,
  CRAM_OPT_USE_BZIP2,
  CRAM_OPT_SHARED_REF,
  CRAM_OPT_NTHREADS,    // deprecated, use HTS_OPT_NTHREADS
  CRAM_OPT_THREAD_POOL, // make general
  CRAM_OPT_USE_LZMA,
  CRAM_OPT_USE_RANS,
  CRAM_OPT_REQUIRED_FIELDS,
  CRAM_OPT_LOSSY_NAMES,
  CRAM_OPT_BASES_PER_SLICE,
  CRAM_OPT_STORE_MD,
  CRAM_OPT_STORE_NM,
  CRAM_OPT_RANGE_NOSEEK, // CRAM_OPT_RANGE minus the seek
  CRAM_OPT_USE_TOK,
  CRAM_OPT_USE_FQZ,
  CRAM_OPT_USE_ARITH,
  CRAM_OPT_POS_DELTA, // force delta for AP, even on non-pos sorted data

  // General purpose
  HTS_OPT_COMPRESSION_LEVEL = 100,
  HTS_OPT_NTHREADS,
  HTS_OPT_THREAD_POOL,
  HTS_OPT_CACHE_SIZE,
  HTS_OPT_BLOCK_SIZE,
  HTS_OPT_FILTER,
  HTS_OPT_PROFILE,

  // Fastq

  // Boolean.
  // Read / Write CASAVA 1.8 format.
  // See
  // https://emea.support.illumina.com/content/dam/illumina-support/documents/documentation/software_documentation/bcl2fastq/bcl2fastq_letterbooklet_15038058brpmi.pdf
  //
  // The CASAVA tag matches \d:[YN]:\d+:[ACGTN]+
  // The first \d is read 1/2 (1 or 2), [YN] is QC-PASS/FAIL flag,
  // \d+ is a control number, and the sequence at the end is
  // for barcode sequence.  Barcodes are read into the aux tag defined
  // by FASTQ_OPT_BARCODE ("BC" by default).
  FASTQ_OPT_CASAVA = 1000,

  // String.
  // Whether to read / write extra SAM format aux tags from the fastq
  // identifier line.  For reading this can simply be "1" to request
  // decoding aux tags.  For writing it is a comma separated list of aux
  // tag types to be written out.
  FASTQ_OPT_AUX,

  // Boolean.
  // Whether to add /1 and /2 to read identifiers when writing FASTQ.
  // These come from the BAM_FREAD1 or BAM_FREAD2 flags.
  // (Detecting the /1 and /2 is automatic when reading fastq.)
  FASTQ_OPT_RNUM,

  // Two character string.
  // Barcode aux tag for CASAVA; defaults to "BC".
  FASTQ_OPT_BARCODE,

  // Process SRA and ENA read names which pointlessly move the original
  // name to the second field and insert a constructed <run>.<number>
  // name in its place.
  FASTQ_OPT_NAME2,

  // Process the UMI tag.  Tag or Tag,tag,tag...
  // On read, this converts the last read-name element (Illumina) to the tag.
  // On write, it queries the tags in turn and copies the first found
  // to the read name suffix, converting any non-alpha to "+".
  FASTQ_OPT_UMI,

  // Regex to use for matching read name.
  // Def: "^[^:]+:[^:]+:[^:]+:[^:]+:[^:]+:[^:]+:[^:]+:([^:#/]+)"
  FASTQ_OPT_UMI_REGEX,
};

// Profile options for encoding; primarily used at present in CRAM
// but also usable in BAM as a synonym for deflate compression levels.
enum hts_profile_option {
  HTS_PROFILE_FAST,
  HTS_PROFILE_NORMAL,
  HTS_PROFILE_SMALL,
  HTS_PROFILE_ARCHIVE,
};

// For backwards compatibility
#define cram_option hts_fmt_option

typedef struct hts_opt {
  char *arg;               // string form, strdup()ed
  enum hts_fmt_option opt; // tokenised key
  union {                  // ... and value
    int i;
    char *s;
  } val;
  struct hts_opt *next;
} hts_opt;

#define HTS_FILE_OPTS_INIT                                                     \
  { {0}, 0 }

/*
 * Explicit index file name delimiter, see below
 */
#define HTS_IDX_DELIM "##idx##"

/**********************
 * Exported functions *
 **********************/

/*
 * Parses arg and appends it to the option list.
 *
 * Returns 0 on success;
 *        -1 on failure.
 */
HTSLIB_EXPORT
int hts_opt_add(hts_opt **opts, const char *c_arg);

/*
 * Applies an hts_opt option list to a given htsFile.
 *
 * Returns 0 on success
 *        -1 on failure
 */
HTSLIB_EXPORT
int hts_opt_apply(htsFile *fp, hts_opt *opts);

/*
 * Frees an hts_opt list.
 */
HTSLIB_EXPORT
void hts_opt_free(hts_opt *opts);

/*
 * Accepts a string file format (sam, bam, cram, vcf, bam) optionally
 * followed by a comma separated list of key=value options and splits
 * these up into the fields of htsFormat struct.
 *
 * Returns 0 on success
 *        -1 on failure.
 */
HTSLIB_EXPORT
int hts_parse_format(htsFormat *opt, const char *str);

/*
 * Tokenise options as (key(=value)?,)*(key(=value)?)?
 * NB: No provision for ',' appearing in the value!
 * Add backslashing rules?
 *
 * This could be used as part of a general command line option parser or
 * as a string concatenated onto the file open mode.
 *
 * Returns 0 on success
 *        -1 on failure.
 */
HTSLIB_EXPORT
int hts_parse_opt_list(htsFormat *opt, const char *str);

/*! @abstract Table for converting a nucleotide character to 4-bit encoding.
The input character may be either an IUPAC ambiguity code, '=' for 0, or
'0'/'1'/'2'/'3' for a result of 1/2/4/8.  The result is encoded as 1/2/4/8
for A/C/G/T or combinations of these bits for ambiguous bases.
Additionally RNA U is treated as a T (8).
*/
HTSLIB_EXPORT
extern const unsigned char seq_nt16_table[256];

/*! @abstract Table for converting a 4-bit encoded nucleotide to an IUPAC
ambiguity code letter (or '=' when given 0).
*/
HTSLIB_EXPORT
extern const char seq_nt16_str[];

/*! @abstract Table for converting a 4-bit encoded nucleotide to about 2 bits.
Returns 0/1/2/3 for 1/2/4/8 (i.e., A/C/G/T), or 4 otherwise (0 or ambiguous).
*/
HTSLIB_EXPORT
extern const int seq_nt16_int[];

/*!
  @abstract  Get the htslib version number
  @return    For released versions, a string like "N.N[.N]"; or git describe
  output if using a library built within a Git repository.
*/
HTSLIB_EXPORT
const char *hts_version(void);

/*!
  @abstract  Compile-time HTSlib version number, for use in #if checks
  @return    For released versions X.Y[.Z], an integer of the form XYYYZZ;
  useful for preprocessor conditionals such as
      #if HTS_VERSION >= 101000  // Check for v1.10 or later
*/
// Maintainers: Bump this in the final stage of preparing a new release.
// Immediately after release, bump ZZ to 90 to distinguish in-development
// Git repository builds from the release; you may wish to increment this
// further when significant features are merged.
#define HTS_VERSION 102390

/*! @abstract Introspection on the features enabled in htslib
 *
 * @return a bitfield of HTS_FEATURE_* macros.
 */
HTSLIB_EXPORT
unsigned int hts_features(void);

HTSLIB_EXPORT
const char *hts_test_feature(unsigned int id);

/*! @abstract Introspection on the features enabled in htslib, string form
 *
 * @return a string describing htslib build features
 */
HTSLIB_EXPORT
const char *hts_feature_string(void);

// Whether ./configure was used or vanilla Makefile
#define HTS_FEATURE_CONFIGURE 1

// Whether --enable-plugins was used
#define HTS_FEATURE_PLUGINS 2

// Transport specific
#define HTS_FEATURE_LIBCURL (1u << 10)
#define HTS_FEATURE_S3 (1u << 11)
#define HTS_FEATURE_GCS (1u << 12)

// Compression options
#define HTS_FEATURE_LIBDEFLATE (1u << 20)
#define HTS_FEATURE_LZMA (1u << 21)
#define HTS_FEATURE_BZIP2 (1u << 22)
#define HTS_FEATURE_HTSCODECS (1u << 23) // htscodecs library version

// Build params
#define HTS_FEATURE_CC (1u << 27)
#define HTS_FEATURE_CFLAGS (1u << 28)
#define HTS_FEATURE_CPPFLAGS (1u << 29)
#define HTS_FEATURE_LDFLAGS (1u << 30)

/*!
  @abstract    Determine format by peeking at the start of a file
  @param fp    File opened for reading, positioned at the beginning
  @param fmt   Format structure that will be filled out on return
  @return      0 for success, or negative if an error occurred.

  Equivalent to hts_detect_format2(fp, NULL, fmt).
*/
HTSLIB_EXPORT
int hts_detect_format(struct hFILE *fp, htsFormat *fmt);

/*!
  @abstract    Determine format primarily by peeking at the start of a file
  @param fp    File opened for reading, positioned at the beginning
  @param fname Name of the file, or NULL if not available
  @param fmt   Format structure that will be filled out on return
  @return      0 for success, or negative if an error occurred.
  @since       1.15

Some formats are only recognised if the filename is available and has the
expected extension, as otherwise more generic files may be misrecognised.
In particular:
 - FASTA/Q indexes must have .fai/.fqi extensions; without this requirement,
   some similar BED files would be misrecognised as indexes.
*/
HTSLIB_EXPORT
int hts_detect_format2(struct hFILE *fp, const char *fname, htsFormat *fmt);

/*!
  @abstract    Get a human-readable description of the file format
  @param fmt   Format structure holding type, version, compression, etc.
  @return      Description string, to be freed by the caller after use.
*/
HTSLIB_EXPORT
char *hts_format_description(const htsFormat *format);

/*!
  @abstract       Open a sequence data (SAM/BAM/CRAM) or variant data (VCF/BCF)
                  or possibly-compressed textual line-orientated file
  @param fn       The file name or "-" for stdin/stdout. For indexed files
                  with a non-standard naming, the file name can include the
                  name of the index file delimited with HTS_IDX_DELIM
  @param mode     Mode matching / [rwa][bcefFguxz0-9]* /
  @discussion
      With 'r' opens for reading; any further format mode letters are ignored
      as the format is detected by checking the first few bytes or BGZF blocks
      of the file.  With 'w' or 'a' opens for writing or appending, with format
      specifier letters:
        b  binary format (BAM, BCF, etc) rather than text (SAM, VCF, etc)
        c  CRAM format
        f  FASTQ format
        F  FASTA format
        g  gzip compressed
        u  uncompressed
        z  bgzf compressed
        [0-9]  zlib compression level
      and with non-format option letters (for any of 'r'/'w'/'a'):
        e  close the file on exec(2) (opens with O_CLOEXEC, where supported)
        x  create the file exclusively (opens with O_EXCL, where supported)
      Note that there is a distinction between 'u' and '0': the first yields
      plain uncompressed output whereas the latter outputs uncompressed data
      wrapped in the zlib format.
  @example
      [rw]b  .. compressed BCF, BAM, FAI
      [rw]bu .. uncompressed BCF
      [rw]z  .. compressed VCF
      [rw]   .. uncompressed VCF
*/
HTSLIB_EXPORT
htsFile *hts_open(const char *fn, const char *mode);

/*!
  @abstract       Open a SAM/BAM/CRAM/VCF/BCF/etc file
  @param fn       The file name or "-" for stdin/stdout
  @param mode     Open mode, as per hts_open()
  @param fmt      Optional format specific parameters
  @discussion
      See hts_open() for description of fn and mode.
      // TODO Update documentation for s/opts/fmt/
      Opts contains a format string (sam, bam, cram, vcf, bcf) which will,
      if defined, override mode.  Opts also contains a linked list of hts_opt
      structures to apply to the open file handle.  These can contain things
      like pointers to the reference or information on compression levels,
      block sizes, etc.
*/
HTSLIB_EXPORT
htsFile *hts_open_format(const char *fn, const char *mode,
                         const htsFormat *fmt);

/*!
  @abstract       Open an existing stream as a SAM/BAM/CRAM/VCF/BCF/etc file
  @param fn       The already-open file handle
  @param mode     Open mode, as per hts_open()
*/
HTSLIB_EXPORT
htsFile *hts_hopen(struct hFILE *fp, const char *fn, const char *mode);

/*!
  @abstract  For output streams, flush any buffered data
  @param fp  The file handle to be flushed
  @return    0 for success, or negative if an error occurred.
  @since     1.14
*/
HTSLIB_EXPORT
int hts_flush(htsFile *fp);

/*!
  @abstract  Close a file handle, flushing buffered data for output streams
  @param fp  The file handle to be closed
  @return    0 for success, or negative if an error occurred.
*/
HTSLIB_EXPORT
int hts_close(htsFile *fp);

/*!
  @abstract  Returns the file's format information
  @param fp  The file handle
  @return    Read-only pointer to the file's htsFormat.
*/
HTSLIB_EXPORT
const htsFormat *hts_get_format(htsFile *fp);

/*!
  @ abstract      Returns a string containing the file format extension.
  @ param format  Format structure containing the file type.
  @ return        A string ("sam", "bam", etc) or "?" for unknown formats.
 */
HTSLIB_EXPORT
const char *hts_format_file_extension(const htsFormat *format);

/*!
  @abstract  Sets a specified CRAM option on the open file handle.
  @param fp  The file handle open the open file.
  @param opt The CRAM_OPT_* option.
  @param ... Optional arguments, dependent on the option used.
  @return    0 for success, or negative if an error occurred.
*/
HTSLIB_EXPORT
int hts_set_opt(htsFile *fp, enum hts_fmt_option opt, ...);

/*!
  @abstract         Read a line (and its \n or \r\n terminator) from a file
  @param fp         The file handle
  @param delimiter  Unused, but must be '\n' (or KS_SEP_LINE)
  @param str        The line (not including the terminator) is written here
  @return           Length of the string read (capped at INT_MAX);
                    -1 on end-of-file; <= -2 on error
*/
HTSLIB_EXPORT
int hts_getline(htsFile *fp, int delimiter, kstring_t *str);

HTSLIB_EXPORT
char **hts_readlines(const char *fn, int *_n);
/*!
    @abstract       Parse comma-separated list or read list from a file
    @param list     File name or comma-separated list
    @param is_file
    @param _n       Size of the output array (number of items read)
    @return         NULL on failure or pointer to newly allocated array of
                    strings
*/
HTSLIB_EXPORT
char **hts_readlist(const char *fn, int is_file, int *_n);

/*!
  @abstract  Create extra threads to aid compress/decompression for this file
  @param fp  The file handle
  @param n   The number of worker threads to create
  @return    0 for success, or negative if an error occurred.
  @notes     This function creates non-shared threads for use solely by fp.
             The hts_set_thread_pool function is the recommended alternative.
*/
HTSLIB_EXPORT
int hts_set_threads(htsFile *fp, int n);

/*!
  @abstract  Create extra threads to aid compress/decompression for this file
  @param fp  The file handle
  @param p   A pool of worker threads, previously allocated by
  hts_create_threads().
  @return    0 for success, or negative if an error occurred.
*/
HTSLIB_EXPORT
int hts_set_thread_pool(htsFile *fp, htsThreadPool *p);

/*!
  @abstract  Adds a cache of decompressed blocks, potentially speeding up seeks.
             This may not work for all file types (currently it is bgzf only).
  @param fp  The file handle
  @param n   The size of cache, in bytes
*/
HTSLIB_EXPORT
void hts_set_cache_size(htsFile *fp, int n);

/*!
  @abstract  Set .fai filename for a file opened for reading
  @return    0 for success, negative on failure
  @discussion
      Called before *_hdr_read(), this provides the name of a .fai file
      used to provide a reference list if the htsFile contains no @SQ headers.
*/
HTSLIB_EXPORT
int hts_set_fai_filename(htsFile *fp, const char *fn_aux);

/*!
  @abstract  Sets a filter expression
  @return    0 for success, negative on failure
  @discussion
      To clear an existing filter, specifying expr as NULL.
*/
HTSLIB_EXPORT
int hts_set_filter_expression(htsFile *fp, const char *expr);

/*!
  @abstract  Determine whether a given htsFile contains a valid EOF block
  @return    3 for a non-EOF checkable filetype;
             2 for an unseekable file type where EOF cannot be checked;
             1 for a valid EOF block;
             0 for if the EOF marker is absent when it should be present;
            -1 (with errno set) on failure
  @discussion
      Check if the BGZF end-of-file (EOF) marker is present
*/
HTSLIB_EXPORT
int hts_check_EOF(htsFile *fp);

/************
 * Indexing *
 ************/

/*!
These HTS_IDX_* macros are used as special tid values for hts_itr_query()/etc,
producing iterators operating as follows:
 - HTS_IDX_NOCOOR iterates over unmapped reads sorted at the end of the file
 - HTS_IDX_START  iterates over the entire file
 - HTS_IDX_REST   iterates from the current position to the end of the file
 - HTS_IDX_NONE   always returns "no more alignment records"
When one of these special tid values is used, beg and end are ignored.
When REST or NONE is used, idx is also ignored and may be NULL.
*/
#define HTS_IDX_NOCOOR (-2)
#define HTS_IDX_START (-3)
#define HTS_IDX_REST (-4)
#define HTS_IDX_NONE (-5)

#define HTS_FMT_CSI 0
#define HTS_FMT_BAI 1
#define HTS_FMT_TBI 2
#define HTS_FMT_CRAI 3
#define HTS_FMT_FAI 4

// Almost INT64_MAX, but when cast into a 32-bit int it's
// also INT_MAX instead of -1.  This avoids bugs with old code
// using the new hts_pos_t data type.
#define HTS_POS_MAX ((((int64_t)INT_MAX) << 32) | INT_MAX)
#define HTS_POS_MIN INT64_MIN
#define PRIhts_pos PRId64
typedef int64_t hts_pos_t;

// For comparison with previous release:
//
// #define HTS_POS_MAX INT_MAX
// #define HTS_POS_MIN INT_MIN
// #define PRIhts_pos PRId32
// typedef int32_t hts_pos_t;

typedef struct hts_pair_pos_t {
  hts_pos_t beg, end;
} hts_pair_pos_t;

typedef hts_pair_pos_t hts_pair32_t; // For backwards compatibility

typedef struct hts_pair64_t {
  uint64_t u, v;
} hts_pair64_t;

typedef struct hts_pair64_max_t {
  uint64_t u, v;
  uint64_t max;
} hts_pair64_max_t;

typedef struct hts_reglist_t {
  const char *reg;
  hts_pair_pos_t *intervals;
  int tid;
  uint32_t count;
  hts_pos_t min_beg, max_end;
} hts_reglist_t;

typedef int hts_readrec_func(BGZF *fp, void *data, void *r, int *tid,
                             hts_pos_t *beg, hts_pos_t *end);
typedef int hts_seek_func(void *fp, int64_t offset, int where);
typedef int64_t hts_tell_func(void *fp);

/**
 * @brief File iterator that can handle multiple target regions.
 * This structure should be considered opaque by end users.
 * It does both the stepping inside the file and the filtering of alignments.
 * It can operate in single or multi-region mode, and depending on this,
 * it uses different fields.
 *
 * read_rest (1) - read everything from the current offset, without filtering
 * finished  (1) - no more iterations
 * is_cram   (1) - current file has CRAM format
 * nocoor    (1) - read all unmapped reads
 *
 * multi     (1) - multi-region moode
 * reg_list  - List of target regions
 * n_reg     - Size of the above list
 * curr_reg  - List index of the current region of search
 * curr_intv - Interval index inside the current region; points to a (beg, end)
 * end       - Used for CRAM files, to preserve the max end coordinate
 *
 * multi     (0) - single-region mode
 * tid       - Reference id of the target region
 * beg       - Start position of the target region
 * end       - End position of the target region
 *
 * Common fields:
 * off        - List of file offsets computed from the index
 * n_off      - Size of the above list
 * i          - List index of the current file offset
 * curr_off   - File offset for the next file read
 * curr_tid   - Reference id of the current alignment
 * curr_beg   - Start position of the current alignment
 * curr_end   - End position of the current alignment
 * nocoor_off - File offset where the unmapped reads start
 *
 * readrec    - File specific function that reads an alignment
 * seek       - File specific function for changing the file offset
 * tell       - File specific function for indicating the file offset
 */

typedef struct hts_itr_t {
  uint32_t read_rest : 1, finished : 1, is_cram : 1, nocoor : 1, multi : 1,
      dummy : 27;
  int tid, n_off, i, n_reg;
  hts_pos_t beg, end;
  hts_reglist_t *reg_list;
  int curr_tid, curr_reg, curr_intv;
  hts_pos_t curr_beg, curr_end;
  uint64_t curr_off, nocoor_off;
  hts_pair64_max_t *off;
  hts_readrec_func *readrec;
  hts_seek_func *seek;
  hts_tell_func *tell;
  struct {
    int n, m;
    int *a;
  } bins;
} hts_itr_t;

typedef hts_itr_t hts_itr_multi_t;

/// Compute the first bin on a given level
#define hts_bin_first(l) (((1 << (((l) << 1) + (l))) - 1) / 7)
/// Compute the parent bin of a given bin
#define hts_bin_parent(b) (((b)-1) >> 3)

///////////////////////////////////////////////////////////
// Low-level API for building indexes.

/// Create a BAI/CSI/TBI type index structure
/** @param n          Initial number of targets
    @param fmt        Format, one of HTS_FMT_CSI, HTS_FMT_BAI or HTS_FMT_TBI
    @param offset0    Initial file offset
    @param min_shift  Number of bits for the minimal interval
    @param n_lvls     Number of levels in the binning index
    @return An initialised hts_idx_t struct on success; NULL on failure

The struct returned by a successful call should be freed via hts_idx_destroy()
when it is no longer needed.
*/
HTSLIB_EXPORT
hts_idx_t *hts_idx_init(int n, int fmt, uint64_t offset0, int min_shift,
                        int n_lvls);

/// Free a BAI/CSI/TBI type index
/** @param idx   Index structure to free
 */
HTSLIB_EXPORT
void hts_idx_destroy(hts_idx_t *idx);

/// Push an index entry
/** @param idx        Index
    @param tid        Target id
    @param beg        Range start (zero-based)
    @param end        Range end (zero-based, half-open)
    @param offset     File offset
    @param is_mapped  Range corresponds to a mapped read
    @return 0 on success; -1 on failure

The @p is_mapped parameter is used to update the n_mapped / n_unmapped counts
stored in the meta-data bin.
 */
HTSLIB_EXPORT
int hts_idx_push(hts_idx_t *idx, int tid, hts_pos_t beg, hts_pos_t end,
                 uint64_t offset, int is_mapped);

/// Finish building an index
/** @param idx          Index
    @param final_offset Last file offset
    @return 0 on success; non-zero on failure.
*/
HTSLIB_EXPORT
int hts_idx_finish(hts_idx_t *idx, uint64_t final_offset);

/// Returns index format
/** @param idx   Index
    @return One of HTS_FMT_CSI, HTS_FMT_BAI or HTS_FMT_TBI
*/
HTSLIB_EXPORT
int hts_idx_fmt(hts_idx_t *idx);

/// Add name to TBI index meta-data
/** @param idx   Index
    @param tid   Target identifier
    @param name  Target name
    @return Index number of name in names list on success; -1 on failure.
*/
HTSLIB_EXPORT
int hts_idx_tbi_name(hts_idx_t *idx, int tid, const char *name);

// Index loading and saving

/// Save an index to a file
/** @param idx  Index to be written
    @param fn   Input BAM/BCF/etc filename, to which .bai/.csi/etc will be added
    @param fmt  One of the HTS_FMT_* index formats
    @return  0 if successful, or negative if an error occurred.
*/
HTSLIB_EXPORT
int hts_idx_save(const hts_idx_t *idx, const char *fn, int fmt) HTS_RESULT_USED;

/// Save an index to a specific file
/** @param idx    Index to be written
    @param fn     Input BAM/BCF/etc filename
    @param fnidx  Output filename, or NULL to add .bai/.csi/etc to @a fn
    @param fmt    One of the HTS_FMT_* index formats
    @return  0 if successful, or negative if an error occurred.
*/
HTSLIB_EXPORT
int hts_idx_save_as(const hts_idx_t *idx, const char *fn, const char *fnidx,
                    int fmt) HTS_RESULT_USED;

/// Load an index file
/** @param fn   BAM/BCF/etc filename, to which .bai/.csi/etc will be added or
                the extension substituted, to search for an existing index file.
                In case of a non-standard naming, the file name can include the
                name of the index file delimited with HTS_IDX_DELIM.
    @param fmt  One of the HTS_FMT_* index formats
    @return  The index, or NULL if an error occurred.

If @p fn contains the string "##idx##" (HTS_IDX_DELIM), the part before
the delimiter will be used as the name of the data file and the part after
it will be used as the name of the index.

Otherwise, this function tries to work out the index name as follows:

  It will try appending ".csi" to @p fn
  It will try substituting an existing suffix (e.g. .bam, .vcf) with ".csi"
  Then, if @p fmt is HTS_FMT_BAI:
    It will try appending ".bai" to @p fn
    To will substituting the existing suffix (e.g. .bam) with ".bai"
  else if @p fmt is HTS_FMT_TBI:
    It will try appending ".tbi" to @p fn
    To will substituting the existing suffix (e.g. .vcf) with ".tbi"

If the index file is remote (served over a protocol like https), first a check
is made to see is a locally cached copy is available.  This is done for all
of the possible names listed above.  If a cached copy is not available then
the index will be downloaded and stored in the current working directory,
with the same name as the remote index.

    Equivalent to hts_idx_load3(fn, NULL, fmt, HTS_IDX_SAVE_REMOTE);
*/
HTSLIB_EXPORT
hts_idx_t *hts_idx_load(const char *fn, int fmt);

/// Load a specific index file
/** @param fn     Input BAM/BCF/etc filename
    @param fnidx  The input index filename
    @return  The index, or NULL if an error occurred.

    Equivalent to hts_idx_load3(fn, fnidx, 0, 0);

    This function will not attempt to save index files locally.
*/
HTSLIB_EXPORT
hts_idx_t *hts_idx_load2(const char *fn, const char *fnidx);

/// Load a specific index file
/** @param fn     Input BAM/BCF/etc filename
    @param fnidx  The input index filename
    @param fmt    One of the HTS_FMT_* index formats
    @param flags  Flags to alter behaviour (see description)
    @return  The index, or NULL if an error occurred.

    If @p fnidx is NULL, the index name will be derived from @p fn in the
    same way as hts_idx_load().

    If @p fnidx is not NULL, @p fmt is ignored.

    The @p flags parameter can be set to a combination of the following
    values:

        HTS_IDX_SAVE_REMOTE   Save a local copy of any remote indexes
        HTS_IDX_SILENT_FAIL   Fail silently if the index is not present

    The index struct returned by a successful call should be freed
    via hts_idx_destroy() when it is no longer needed.
*/
HTSLIB_EXPORT
hts_idx_t *hts_idx_load3(const char *fn, const char *fnidx, int fmt, int flags);

/// Flags for hts_idx_load3() ( and also sam_idx_load3(), tbx_idx_load3() )
#define HTS_IDX_SAVE_REMOTE 1
#define HTS_IDX_SILENT_FAIL 2

///////////////////////////////////////////////////////////
// Functions for accessing meta-data stored in indexes

typedef const char *(*hts_id2name_f)(void *, int);

/// Get extra index meta-data
/** @param idx    The index
    @param l_meta Pointer to where the length of the extra data is stored
    @return Pointer to the extra data if present; NULL otherwise

    Indexes (both .tbi and .csi) made by tabix include extra data about
    the indexed file.  The returns a pointer to this data.  Note that the
    data is stored exactly as it is in the index.  Callers need to interpret
    the results themselves, including knowing what sort of data to expect;
    byte swapping etc.
*/
HTSLIB_EXPORT
uint8_t *hts_idx_get_meta(hts_idx_t *idx, uint32_t *l_meta);

/// Set extra index meta-data
/** @param idx     The index
    @param l_meta  Length of data
    @param meta    Pointer to the extra data
    @param is_copy If not zero, a copy of the data is taken
    @return 0 on success; -1 on failure (out of memory).

    Sets the data that is returned by hts_idx_get_meta().

    If is_copy != 0, a copy of the input data is taken.  If not, ownership of
    the data pointed to by *meta passes to the index.
*/
HTSLIB_EXPORT
int hts_idx_set_meta(hts_idx_t *idx, uint32_t l_meta, uint8_t *meta,
                     int is_copy);

/// Get number of mapped and unmapped reads from an index
/** @param      idx      Index
    @param      tid      Target ID
    @param[out] mapped   Location to store number of mapped reads
    @param[out] unmapped Location to store number of unmapped reads
    @return 0 on success; -1 on failure (data not available)

    BAI and CSI indexes store information on the number of reads for each
    target that were mapped or unmapped (unmapped reads will generally have
    a paired read that is mapped to the target).  This function returns this
    information if it is available.

    @note Cram CRAI indexes do not include this information.
*/
HTSLIB_EXPORT
int hts_idx_get_stat(const hts_idx_t *idx, int tid, uint64_t *mapped,
                     uint64_t *unmapped);

/// Return the number of unplaced reads from an index
/** @param idx    Index
    @return Unplaced reads count

    Unplaced reads are not linked to any reference (e.g. RNAME is '*' in SAM
    files).
*/
HTSLIB_EXPORT
uint64_t hts_idx_get_n_no_coor(const hts_idx_t *idx);

/// Return a list of target names from an index
/** @param      idx    Index
    @param[out] n      Location to store the number of targets
    @param      getid  Callback function to get the name for a target ID
    @param      hdr    Header from indexed file
    @return An array of pointers to the names on success; NULL on failure

    @note The names are pointers into the header data structure.  When cleaning
    up, only the array should be freed, not the names.
 */
HTSLIB_EXPORT
const char **hts_idx_seqnames(const hts_idx_t *idx, int *n, hts_id2name_f getid,
                              void *hdr); // free only the array, not the values

/// Return the number of targets from an index
/** @param      idx    Index
    @return The number of targets
 */
HTSLIB_EXPORT
int hts_idx_nseq(const hts_idx_t *idx);

///////////////////////////////////////////////////////////
// Region parsing

#define HTS_PARSE_THOUSANDS_SEP 1 ///< Ignore ',' separators within numbers
#define HTS_PARSE_ONE_COORD 2 ///< chr:pos means chr:pos-pos and not chr:pos-end
#define HTS_PARSE_LIST                                                         \
  4 ///< Expect a comma separated list of regions. (Disables
    ///< HTS_PARSE_THOUSANDS_SEP)

/// Parse a numeric string
/** The number may be expressed in scientific notation, and optionally may
    contain commas in the integer part (before any decimal point or E notation).
    @param str     String to be parsed
    @param strend  If non-NULL, set on return to point to the first character
                   in @a str after those forming the parsed number
    @param flags   Or'ed-together combination of HTS_PARSE_* flags
    @return  Integer value of the parsed number, or 0 if no valid number

    The input string is parsed as: optional whitespace; an optional '+' or
    '-' sign; decimal digits possibly including ',' characters (if @a flags
    includes HTS_PARSE_THOUSANDS_SEP) and a '.' decimal point; and an optional
    case-insensitive suffix, which may be either 'k', 'M', 'G', or scientific
    notation consisting of 'e'/'E' followed by an optional '+' or '-' sign and
    decimal digits. To be considered a valid numeric value, the main part (not
    including any suffix or scientific notation) must contain at least one
    digit (either before or after the decimal point).

    When @a strend is NULL, @a str is expected to contain only (optional
    whitespace followed by) the numeric value. A warning will be printed
    (if hts_verbose is HTS_LOG_WARNING or more) if no valid parsable number
    is found or if there are any unused characters after the number.

    When @a strend is non-NULL, @a str starts with (optional whitespace
    followed by) the numeric value. On return, @a strend is set to point
    to the first unused character after the numeric value, or to @a str
    if no valid parsable number is found.
*/
HTSLIB_EXPORT
long long hts_parse_decimal(const char *str, char **strend, int flags);

typedef int (*hts_name2id_f)(void *, const char *);

/// Parse a "CHR:START-END"-style region string
/** @param str  String to be parsed
    @param beg  Set on return to the 0-based start of the region
    @param end  Set on return to the 1-based end of the region
    @return  Pointer to the colon or '\0' after the reference sequence name,
             or NULL if @a str could not be parsed.

    NOTE: For compatibility with hts_parse_reg only.
    Please use hts_parse_region instead.
*/
HTSLIB_EXPORT
const char *hts_parse_reg64(const char *str, hts_pos_t *beg, hts_pos_t *end);

/// Parse a "CHR:START-END"-style region string
/** @param str  String to be parsed
    @param beg  Set on return to the 0-based start of the region
    @param end  Set on return to the 1-based end of the region
    @return  Pointer to the colon or '\0' after the reference sequence name,
             or NULL if @a str could not be parsed.
*/
HTSLIB_EXPORT
const char *hts_parse_reg(const char *str, int *beg, int *end);

/// Parse a "CHR:START-END"-style region string
/** @param str   String to be parsed
    @param tid   Set on return (if not NULL) to be reference index (-1 if
   invalid)
    @param beg   Set on return to the 0-based start of the region
    @param end   Set on return to the 1-based end of the region
    @param getid Function pointer.  Called if not NULL to set tid.
    @param hdr   Caller data passed to getid.
    @param flags Bitwise HTS_PARSE_* flags listed above.
    @return      Pointer to the byte after the end of the entire region
                 specifier (including any trailing comma) on success,
                 or NULL if @a str could not be parsed.

    A variant of hts_parse_reg which is reference-id aware.  It uses
    the iterator name2id callbacks to validate the region tokenisation works.

    This is necessary due to GRCh38 HLA additions which have reference names
    like "HLA-DRB1*12:17".

    To work around ambiguous parsing issues, eg both "chr1" and "chr1:100-200"
    are reference names, quote using curly braces.
    Thus "{chr1}:100-200" and "{chr1:100-200}" disambiguate the above example.

    Flags are used to control how parsing works, and can be one of the below.

    HTS_PARSE_THOUSANDS_SEP:
        Ignore commas in numbers.  For example with this flag 1,234,567
        is interpreted as 1234567.

    HTS_PARSE_LIST:
        If present, the region is assmed to be a comma separated list and
        position parsing will not contain commas (this implicitly
        clears HTS_PARSE_THOUSANDS_SEP in the call to hts_parse_decimal).
        On success the return pointer will be the start of the next region, ie
        the character after the comma.  (If *ret != '\0' then the caller can
        assume another region is present in the list.)

        If not set then positions may contain commas.  In this case the return
        value should point to the end of the string, or NULL on failure.

    HTS_PARSE_ONE_COORD:
        If present, X:100 is treated as the single base pair region X:100-100.
        In this case X:-100 is shorthand for X:1-100 and X:100- is X:100-<end>.
        (This is the standard bcftools region convention.)

        When not set X:100 is considered to be X:100-<end> where <end> is
        the end of chromosome X (set to INT_MAX here).  X:100- and X:-100 are
        invalid.
        (This is the standard samtools region convention.)

    Note the supplied string expects 1 based inclusive coordinates, but the
    returned coordinates start from 0 and are half open, so pos0 is valid
    for use in e.g. "for (pos0 = beg; pos0 < end; pos0++) {...}"

    If NULL is returned, the value in tid mat give additional information
    about the error:

        -2   Failed to parse @p hdr; or out of memory
        -1   The reference in @p str has mismatched braces, or does not
             exist in @p hdr
        >= 0 The specified range in @p str could not be parsed
*/
HTSLIB_EXPORT
const char *hts_parse_region(const char *s, int *tid, hts_pos_t *beg,
                             hts_pos_t *end, hts_name2id_f getid, void *hdr,
                             int flags);

///////////////////////////////////////////////////////////
// Generic iterators
//
// These functions provide the low-level infrastructure for iterators.
// Wrappers around these are used to make iterators for specific file types.
// See:
//     htslib/sam.h  for SAM/BAM/CRAM iterators
//     htslib/vcf.h  for VCF/BCF iterators
//     htslib/tbx.h  for files indexed by tabix

/// Create a single-region iterator
/** @param idx      Index
    @param tid      Target ID
    @param beg      Start of region
    @param end      End of region
    @param readrec  Callback to read a record from the input file
    @return An iterator on success; NULL on failure

    The iterator struct returned by a successful call should be freed
    via hts_itr_destroy() when it is no longer needed.
 */
HTSLIB_EXPORT
hts_itr_t *hts_itr_query(const hts_idx_t *idx, int tid, hts_pos_t beg,
                         hts_pos_t end, hts_readrec_func *readrec);

/// Free an iterator
/** @param iter   Iterator to free
 */
HTSLIB_EXPORT
void hts_itr_destroy(hts_itr_t *iter);

typedef hts_itr_t *hts_itr_query_func(const hts_idx_t *idx, int tid,
                                      hts_pos_t beg, hts_pos_t end,
                                      hts_readrec_func *readrec);

/// Create a single-region iterator from a text region specification
/** @param idx       Index
    @param reg       Region specifier
    @param getid     Callback function to return the target ID for a name
    @param hdr       Input file header
    @param itr_query Callback function returning an iterator for a numeric tid,
                     start and end position
    @param readrec   Callback to read a record from the input file
    @return An iterator on success; NULL on error

    The iterator struct returned by a successful call should be freed
    via hts_itr_destroy() when it is no longer needed.
 */
HTSLIB_EXPORT
hts_itr_t *hts_itr_querys(const hts_idx_t *idx, const char *reg,
                          hts_name2id_f getid, void *hdr,
                          hts_itr_query_func *itr_query,
                          hts_readrec_func *readrec);

/// Return the next record from an iterator
/** @param fp      Input file handle
    @param iter    Iterator
    @param r       Pointer to record placeholder
    @param data    Data passed to the readrec callback
    @return >= 0 on success, -1 when there is no more data, < -1 on error
 */
HTSLIB_EXPORT
int hts_itr_next(BGZF *fp, hts_itr_t *iter, void *r,
                 void *data) HTS_RESULT_USED;

/**********************************
 * Iterator with multiple regions *
 **********************************/

typedef int hts_itr_multi_query_func(const hts_idx_t *idx, hts_itr_t *itr);
HTSLIB_EXPORT
int hts_itr_multi_bam(const hts_idx_t *idx, hts_itr_t *iter);
HTSLIB_EXPORT
int hts_itr_multi_cram(const hts_idx_t *idx, hts_itr_t *iter);

/// Create a multi-region iterator from a region list
/** @param idx          Index
    @param reglist      Region list
    @param count        Number of items in region list
    @param getid        Callback to convert names to target IDs
    @param hdr          Indexed file header (passed to getid)
    @param itr_specific Filetype-specific callback function
    @param readrec      Callback to read an input file record
    @param seek         Callback to seek in the input file
    @param tell         Callback to return current input file location
    @return An iterator on success; NULL on failure

    The iterator struct returned by a successful call should be freed
    via hts_itr_destroy() when it is no longer needed.
 */
HTSLIB_EXPORT
hts_itr_t *hts_itr_regions(const hts_idx_t *idx, hts_reglist_t *reglist,
                           int count, hts_name2id_f getid, void *hdr,
                           hts_itr_multi_query_func *itr_specific,
                           hts_readrec_func *readrec, hts_seek_func *seek,
                           hts_tell_func *tell);

/// Return the next record from an iterator
/** @param fp      Input file handle
    @param iter    Iterator
    @param r       Pointer to record placeholder
    @return >= 0 on success, -1 when there is no more data, < -1 on error
 */
HTSLIB_EXPORT
int hts_itr_multi_next(htsFile *fd, hts_itr_t *iter, void *r);

/// Create a region list from a char array
/** @param argv      Char array of target:interval elements, e.g.
   chr1:2500-3600, chr1:5100, chr2
    @param argc      Number of items in the array
    @param r_count   Pointer to the number of items in the resulting region list
    @param hdr       Header for the sam/bam/cram file
    @param getid     Callback to convert target names to target ids.
    @return  A region list on success, NULL on failure

    The hts_reglist_t struct returned by a successful call should be freed
    via hts_reglist_free() when it is no longer needed.
 */
HTSLIB_EXPORT
hts_reglist_t *hts_reglist_create(char **argv, int argc, int *r_count,
                                  void *hdr, hts_name2id_f getid);

/// Free a region list
/** @param reglist    Region list
    @param count      Number of items in the list
 */
HTSLIB_EXPORT
void hts_reglist_free(hts_reglist_t *reglist, int count);

/// Free a multi-region iterator
/** @param iter   Iterator to free
 */
#define hts_itr_multi_destroy(iter) hts_itr_destroy(iter)

/**
 * hts_file_type() - Convenience function to determine file type
 * DEPRECATED:  This function has been replaced by hts_detect_format().
 * It and these FT_* macros will be removed in a future HTSlib release.
 */
#define FT_UNKN 0
#define FT_GZ 1
#define FT_VCF 2
#define FT_VCF_GZ (FT_GZ | FT_VCF)
#define FT_BCF (1 << 2)
#define FT_BCF_GZ (FT_GZ | FT_BCF)
#define FT_STDIN (1 << 3)
HTSLIB_EXPORT
int hts_file_type(const char *fname);

/***************************
 * Revised MAQ error model *
 ***************************/

struct errmod_t;
typedef struct errmod_t errmod_t;

HTSLIB_EXPORT
errmod_t *errmod_init(double depcorr);
HTSLIB_EXPORT
void errmod_destroy(errmod_t *em);

/*
    n: number of bases
    m: maximum base
    bases[i]: qual:6, strand:1, base:4
    q[i*m+j]: phred-scaled likelihood of (i,j)
 */
HTSLIB_EXPORT
int errmod_cal(const errmod_t *em, int n, int m, uint16_t *bases, float *q);

/*****************************************************
 * Probabilistic banded glocal alignment             *
 * See https://doi.org/10.1093/bioinformatics/btr076 *
 *****************************************************/

typedef struct probaln_par_t {
  float d, e;
  int bw;
} probaln_par_t;

/// Perform probabilistic banded glocal alignment
/** @param      ref     Reference sequence
    @param      l_ref   Length of reference
    @param      query   Query sequence
    @param      l_query Length of query sequence
    @param      iqual   Query base qualities
    @param      c       Alignment parameters
    @param[out] state   Output alignment
    @param[out] q    Phred scaled posterior probability of state[i] being wrong
    @return     Phred-scaled likelihood score, or INT_MIN on failure.

The reference and query sequences are coded using integers 0,1,2,3,4 for
bases A,C,G,T,N respectively (N here is for any ambiguity code).

On output, state and q are arrays of length l_query. The higher 30
bits give the reference position the query base is matched to and the
lower two bits can be 0 (an alignment match) or 1 (an
insertion). q[i] gives the phred scaled posterior probability of
state[i] being wrong.

On failure, errno will be set to EINVAL if the values of l_ref or l_query
were invalid; or ENOMEM if a memory allocation failed.
*/

HTSLIB_EXPORT
int probaln_glocal(const uint8_t *ref, int l_ref, const uint8_t *query,
                   int l_query, const uint8_t *iqual, const probaln_par_t *c,
                   int *state, uint8_t *q);

/**********************
 * MD5 implementation *
 **********************/

struct hts_md5_context;
typedef struct hts_md5_context hts_md5_context;

/*! @abstract   Initialises an MD5 context.
 *  @discussion
 *    The expected use is to allocate an hts_md5_context using
 *    hts_md5_init().  This pointer is then passed into one or more calls
 *    of hts_md5_update() to compute successive internal portions of the
 *    MD5 sum, which can then be externalised as a full 16-byte MD5sum
 *    calculation by calling hts_md5_final().  This can then be turned
 *    into ASCII via hts_md5_hex().
 *
 *    To dealloate any resources created by hts_md5_init() call the
 *    hts_md5_destroy() function.
 *
 *  @return     hts_md5_context pointer on success, NULL otherwise.
 */
HTSLIB_EXPORT
hts_md5_context *hts_md5_init(void);

/*! @abstract Updates the context with the MD5 of the data. */
HTSLIB_EXPORT
void hts_md5_update(hts_md5_context *ctx, const void *data, unsigned long size);

/*! @abstract Computes the final 128-bit MD5 hash from the given context */
HTSLIB_EXPORT
void hts_md5_final(unsigned char *digest, hts_md5_context *ctx);

/*! @abstract Resets an md5_context to the initial state, as returned
 *            by hts_md5_init().
 */
HTSLIB_EXPORT
void hts_md5_reset(hts_md5_context *ctx);

/*! @abstract Converts a 128-bit MD5 hash into a 33-byte nul-termninated
 *            hex string.
 */
HTSLIB_EXPORT
void hts_md5_hex(char *hex, const unsigned char *digest);

/*! @abstract Deallocates any memory allocated by hts_md5_init. */
HTSLIB_EXPORT
void hts_md5_destroy(hts_md5_context *ctx);

static inline int hts_reg2bin(hts_pos_t beg, hts_pos_t end, int min_shift,
                              int n_lvls) {
  int l, s = min_shift, t = ((1 << ((n_lvls << 1) + n_lvls)) - 1) / 7;
  for (--end, l = n_lvls; l > 0; --l, s += 3, t -= 1 << ((l << 1) + l))
    if (beg >> s == end >> s)
      return t + (beg >> s);
  return 0;
}

/// Compute the level of a bin in a binning index
static inline int hts_bin_level(int bin) {
  int l, b;
  for (l = 0, b = bin; b; ++l, b = hts_bin_parent(b))
    ;
  return l;
}

/**************************************
 * Exposing the CRC32 implementation  *
 * Either from zlib or libdeflate.    *
 *************************************/
HTSLIB_EXPORT
uint32_t hts_crc32(uint32_t crc, const void *buf, size_t len);

//! Compute the corresponding entry into the linear index of a given bin from
//! a binning index
/*!
 *  @param bin    The bin number
 *  @param n_lvls The index depth (number of levels - 0 based)
 *  @return       The integer offset into the linear index
 *
 *  Explanation of the return value formula:
 *  Each bin on level l covers exp(2, (n_lvls - l)*3 + min_shift) base pairs.
 *  A linear index entry covers exp(2, min_shift) base pairs.
 */
static inline int hts_bin_bot(int bin, int n_lvls) {
  int l = hts_bin_level(bin);
  return (bin - hts_bin_first(l)) << (n_lvls - l) * 3;
}

/// Compute the (0-based exclusive) maximum position covered by a binning index
static inline hts_pos_t hts_bin_maxpos(int min_shift, int n_lvls) {
  hts_pos_t one = 1;
  return one << (min_shift + n_lvls * 3);
}

/**************
 * Endianness *
 **************/

static inline int ed_is_big(void) {
  long one = 1;
  return !(*((char *)(&one)));
}
static inline uint16_t ed_swap_2(uint16_t v) {
  return (uint16_t)(((v & 0x00FF00FFU) << 8) | ((v & 0xFF00FF00U) >> 8));
}
static inline void *ed_swap_2p(void *x) {
  *(uint16_t *)x = ed_swap_2(*(uint16_t *)x);
  return x;
}
static inline uint32_t ed_swap_4(uint32_t v) {
  v = ((v & 0x0000FFFFU) << 16) | (v >> 16);
  return ((v & 0x00FF00FFU) << 8) | ((v & 0xFF00FF00U) >> 8);
}
static inline void *ed_swap_4p(void *x) {
  *(uint32_t *)x = ed_swap_4(*(uint32_t *)x);
  return x;
}
static inline uint64_t ed_swap_8(uint64_t v) {
  v = ((v & 0x00000000FFFFFFFFLLU) << 32) | (v >> 32);
  v = ((v & 0x0000FFFF0000FFFFLLU) << 16) | ((v & 0xFFFF0000FFFF0000LLU) >> 16);
  return ((v & 0x00FF00FF00FF00FFLLU) << 8) |
         ((v & 0xFF00FF00FF00FF00LLU) >> 8);
}
static inline void *ed_swap_8p(void *x) {
  *(uint64_t *)x = ed_swap_8(*(uint64_t *)x);
  return x;
}

#ifdef __cplusplus
}
#endif

#endif

/* The MIT License

   Copyright (C) 2020 Genome Research Ltd.

   Permission is hereby granted, free of charge, to any person obtaining
   a copy of this software and associated documentation files (the
   "Software"), to deal in the Software without restriction, including
   without limitation the rights to use, copy, modify, merge, publish,
   distribute, sublicense, and/or sell copies of the Software, and to
   permit persons to whom the Software is furnished to do so, subject to
   the following conditions:

   The above copyright notice and this permission notice shall be
   included in all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
   EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
   NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
   BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
   ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
   CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
   SOFTWARE.
*/

#ifndef KROUNDUP_H
#define KROUNDUP_H

// Value of this macro is 1 if x is a signed type; 0 if unsigned
#define k_signed_type(x) (!(-((x) * 0 + 1) > 0))

/*
  Macro with value 1 if the highest bit in x is set for any integer type

  This is written avoiding conditionals (?: operator) to reduce the likelihood
  of gcc attempting jump thread optimisations for code paths where (x) is
  large.  These optimisations can cause gcc to issue warnings about excessively
  large memory allocations when the kroundup64() macro below is used with
  malloc().  Such warnings can be misleading as they imply only the large
  allocation happens when it's actually working fine for normal values of (x).

  See https://developers.redhat.com/blog/2019/03/13/understanding-gcc-warnings-part-2/
*/
#define k_high_bit_set(x) ((((x) >> (sizeof(x) * 8 - 1 - k_signed_type(x))) & 1))

/*! @hideinitializer
  @abstract  Round up to next power of two
  @discussion
  This macro will work for unsigned types up to uint64_t.

  If the next power of two does not fit in the given type, it will set
  the largest value that does.
 */
#define kroundup64(x) ((x) > 0 ?                                        \
                       (--(x),                                          \
                        (x)|=(x)>>(sizeof(x)/8),                        \
                        (x)|=(x)>>(sizeof(x)/4),                        \
                        (x)|=(x)>>(sizeof(x)/2),                        \
                        (x)|=(x)>>(sizeof(x)),                          \
                        (x)|=(x)>>(sizeof(x)*2),                        \
                        (x)|=(x)>>(sizeof(x)*4),                        \
                        (x) += !k_high_bit_set(x),                      \
                        (x))                                            \
                       : 0)

// Historic interfaces for 32-bit and size_t values.  The macro above
// works for both (as long as size_t is no more than 64 bits).

#ifndef kroundup32
#define kroundup32(x) kroundup64(x)
#endif
#ifndef kroundup_size_t
#define kroundup_size_t(x) kroundup64(x)
#endif

#endif

/* The MIT License

   Copyright (C) 2011 by Attractive Chaos <attractor@live.co.uk>
   Copyright (C) 2013-2014, 2016, 2018-2020, 2022, 2024-2025 Genome Research
   Ltd.

   Permission is hereby granted, free of charge, to any person obtaining
   a copy of this software and associated documentation files (the
   "Software"), to deal in the Software without restriction, including
   without limitation the rights to use, copy, modify, merge, publish,
   distribute, sublicense, and/or sell copies of the Software, and to
   permit persons to whom the Software is furnished to do so, subject to
   the following conditions:

   The above copyright notice and this permission notice shall be
   included in all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
   EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
   NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
   BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
   ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
   CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
   SOFTWARE.
*/

#ifndef KSTRING_H
#define KSTRING_H

#include <errno.h>
#include <limits.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>

#include "hts_defs.h"
#include "kroundup.h"

#if defined __GNUC__ && (__GNUC__ > 2 || (__GNUC__ == 2 && __GNUC_MINOR__ > 4))
#ifdef __MINGW_PRINTF_FORMAT
#define KS_ATTR_PRINTF(fmt, arg)                                               \
  __attribute__((__format__(__MINGW_PRINTF_FORMAT, fmt, arg)))
#else
#define KS_ATTR_PRINTF(fmt, arg)                                               \
  __attribute__((__format__(__printf__, fmt, arg)))
#endif // __MINGW_PRINTF_FORMAT
#else
#define KS_ATTR_PRINTF(fmt, arg)
#endif

#ifndef HAVE___BUILTIN_CLZ
#if defined __GNUC__ && (__GNUC__ > 3 || (__GNUC__ == 3 && __GNUC_MINOR__ >= 4))
#define HAVE___BUILTIN_CLZ 1
#endif
#endif

// Ensure ssize_t exists within this header. All #includes must precede this,
// and ssize_t must be undefined again at the end of this header.
#if defined _MSC_VER && defined _INTPTR_T_DEFINED &&                           \
    !defined _SSIZE_T_DEFINED && !defined ssize_t
#define HTSLIB_SSIZE_T
#define ssize_t intptr_t
#endif

#ifndef EOVERFLOW
#define HTSLIB_EOVERFLOW
#define EOVERFLOW ERANGE
#endif

/* kstring_t is a simple non-opaque type whose fields are likely to be
 * used directly by user code (but see also ks_str() and ks_len() below).
 * A kstring_t object is initialised by either of
 *       kstring_t str = KS_INITIALIZE;
 *       kstring_t str; ...; ks_initialize(&str);
 * and either ownership of the underlying buffer should be given away before
 * the object disappears (see ks_release() below) or the kstring_t should be
 * destroyed with  ks_free(&str) or free(str.s) */
#ifndef KSTRING_T
#define KSTRING_T kstring_t
typedef struct kstring_t {
  size_t l, m;
  char *s;
} kstring_t;
#endif

typedef struct ks_tokaux_t {
  uint64_t tab[4];
  int sep, finished;
  const char *p; // end of the current token
} ks_tokaux_t;

#ifdef __cplusplus
extern "C" {
#endif

HTSLIB_EXPORT
int kvsprintf(kstring_t *s, const char *fmt, va_list ap) KS_ATTR_PRINTF(2, 0);

HTSLIB_EXPORT
int ksprintf(kstring_t *s, const char *fmt, ...) KS_ATTR_PRINTF(2, 3);

HTSLIB_EXPORT
int kputd(double d, kstring_t *s); // custom %g only handler

HTSLIB_EXPORT
int ksplit_core(char *s, int delimiter, int *_max, int **_offsets);

HTSLIB_EXPORT
char *kstrstr(const char *str, const char *pat, int **prep);

HTSLIB_EXPORT
char *kstrnstr(const char *str, const char *pat, int n, int **prep);

HTSLIB_EXPORT
void *kmemmem(const void *str, int n, const void *pat, int m, int **prep);

/* kstrtok() is similar to strtok_r() except that str is not
 * modified and both str and sep can be NULL. For efficiency, it is
 * actually recommended to set both to NULL in the subsequent calls
 * if sep is not changed. */
HTSLIB_EXPORT
char *kstrtok(const char *str, const char *sep, ks_tokaux_t *aux);

/* kgetline() uses the supplied fgets()-like function to read a "\n"-
 * or "\r\n"-terminated line from fp.  The line read is appended to the
 * kstring without its terminator and 0 is returned; EOF is returned at
 * EOF or on error (determined by querying fp, as per fgets()). */
typedef char *kgets_func(char *, int, void *);
HTSLIB_EXPORT
int kgetline(kstring_t *s, kgets_func *fgets_fn, void *fp);

/* Convenience function to call kgetline with a FILE * */
HTSLIB_EXPORT
int kfgetline(kstring_t *s, FILE *fp);

/* kgetline2() uses the supplied hgetln()-like function to read a "\n"-
 * or "\r\n"-terminated line from fp.  The line read is appended to the
 * ksring without its terminator and 0 is returned; EOF is returned at
 * EOF or on error (determined by querying fp, as per fgets()). */
typedef ssize_t kgets_func2(char *, size_t, void *);
HTSLIB_EXPORT
int kgetline2(kstring_t *s, kgets_func2 *fgets_fn, void *fp);

#ifdef __cplusplus
}
#endif

/// kstring initializer for structure assignment
#define KS_INITIALIZE                                                          \
  { 0, 0, NULL }

/// kstring initializer for pointers
/**
   @note Not to be used if the buffer has been allocated.  Use ks_release()
   or ks_clear() instead.
*/

static inline void ks_initialize(kstring_t *s) {
  s->l = s->m = 0;
  s->s = NULL;
}

/// Resize a kstring to a given capacity
static inline int ks_resize(kstring_t *s, size_t size) {
  if (s->m < size) {
    char *tmp;
    size = (size > (SIZE_MAX >> 2)) ? size : size + (size >> 1);
    tmp = (char *)realloc(s->s, size);
    if (!tmp)
      return -1;
    s->s = tmp;
    s->m = size;
  }
  return 0;
}

/// Increase kstring capacity by a given number of bytes
static inline int ks_expand(kstring_t *s, size_t expansion) {
  size_t new_size = s->l + expansion;

  if (new_size < s->l) {
    errno = EOVERFLOW;
    return -1;
  }
  return ks_resize(s, new_size);
}

/// Returns the kstring buffer
static inline char *ks_str(kstring_t *s) { return s->s; }

/// Returns the kstring buffer, or an empty string if l == 0
/**
 * Unlike ks_str(), this function will never return NULL.  If the kstring is
 * empty it will return a read-only empty string.  As the returned value
 * may be read-only, the caller should not attempt to modify it.
 */
static inline const char *ks_c_str(kstring_t *s) {
  return s->l && s->s ? s->s : "";
}

static inline size_t ks_len(kstring_t *s) { return s->l; }

/// Reset kstring length to zero
/**
   @return The kstring itself

   Example use: kputsn(string, len, ks_clear(s))
*/
static inline kstring_t *ks_clear(kstring_t *s) {
  s->l = 0;
  return s;
}

// Give ownership of the underlying buffer away to something else (making
// that something else responsible for freeing it), leaving the kstring_t
// empty and ready to be used again, or ready to go out of scope without
// needing  free(str.s)  to prevent a memory leak.
static inline char *ks_release(kstring_t *s) {
  char *ss = s->s;
  s->l = s->m = 0;
  s->s = NULL;
  return ss;
}

/// Safely free the underlying buffer in a kstring.
static inline void ks_free(kstring_t *s) {
  if (s) {
    free(s->s);
    ks_initialize(s);
  }
}

static inline int kputsn(const char *p, size_t l, kstring_t *s) {
  size_t new_sz = s->l + l + 2;
  if (new_sz <= s->l) {
    errno = EOVERFLOW;
    return EOF;
  }
  if (ks_resize(s, new_sz) < 0)
    return EOF;
  memcpy(s->s + s->l, p, l);
  s->l += l;
  s->s[s->l] = 0;
  return l;
}

static inline int kputs(const char *p, kstring_t *s) {
  if (!p) {
    errno = EFAULT;
    return -1;
  }
  return kputsn(p, strlen(p), s);
}

static inline int kputc(int c, kstring_t *s) {
  if (ks_resize(s, s->l + 2) < 0)
    return EOF;
  s->s[s->l++] = c;
  s->s[s->l] = 0;
  return (unsigned char)c;
}

static inline int kputc_(int c, kstring_t *s) {
  if (ks_resize(s, s->l + 1) < 0)
    return EOF;
  s->s[s->l++] = c;
  return 1;
}

static inline int kputsn_(const void *p, size_t l, kstring_t *s) {
  size_t new_sz = s->l + l;
  if (new_sz < s->l) {
    errno = EOVERFLOW;
    return EOF;
  }
  if (ks_resize(s, new_sz ? new_sz : 1) < 0)
    return EOF;
  memcpy(s->s + s->l, p, l);
  s->l += l;
  return l;
}

static inline int kputuw(unsigned x, kstring_t *s) {
#if HAVE___BUILTIN_CLZ && UINT_MAX == 4294967295U
  static const unsigned int kputuw_num_digits[32] = {
      10, 10, 10, 9, 9, 9, 8, 8, 8, 7, 7, 7, 7, 6, 6, 6,
      5,  5,  5,  4, 4, 4, 4, 3, 3, 3, 2, 2, 2, 1, 1, 1};
  static const unsigned int kputuw_thresholds[32] = {
      0, 0, 1000000000U, 0, 0, 100000000U, 0, 0, 10000000, 0,    0, 0, 1000000,
      0, 0, 100000,      0, 0, 10000,      0, 0, 0,        1000, 0, 0, 100,
      0, 0, 10,          0, 0, 0};
#else
  uint64_t m;
#endif
  static const char kputuw_dig2r[] = "00010203040506070809"
                                     "10111213141516171819"
                                     "20212223242526272829"
                                     "30313233343536373839"
                                     "40414243444546474849"
                                     "50515253545556575859"
                                     "60616263646566676869"
                                     "70717273747576777879"
                                     "80818283848586878889"
                                     "90919293949596979899";
  unsigned int l, j;
  char *cp;

  // Trivial case - also prevents __builtin_clz(0), which is undefined
  if (x < 10) {
    if (ks_resize(s, s->l + 2) < 0)
      return EOF;
    s->s[s->l++] = '0' + x;
    s->s[s->l] = 0;
    return 0;
  }

  // Find out how many digits are to be printed.
#if HAVE___BUILTIN_CLZ && UINT_MAX == 4294967295U
  /*
   * Table method - should be quick if clz can be done in hardware.
   * Find the most significant bit of the value to print and look
   * up in a table to find out how many decimal digits are needed.
   * This number needs to be adjusted by 1 for cases where the decimal
   * length could vary for a given number of bits (for example,
   * a four bit number could be between 8 and 15).
   */

  l = __builtin_clz(x);
  l = kputuw_num_digits[l] - (x < kputuw_thresholds[l]);
#else
  // Fallback for when clz is not available
  m = 1;
  l = 0;
  do {
    l++;
    m *= 10;
  } while (x >= m);
#endif

  if (ks_resize(s, s->l + l + 2) < 0)
    return EOF;

  // Add digits two at a time
  j = l;
  cp = s->s + s->l;
  while (x >= 10) {
    const char *d = &kputuw_dig2r[2 * (x % 100)];
    x /= 100;
    memcpy(&cp[j -= 2], d, 2);
  }

  // Last one (if necessary).  We know that x < 10 by now.
  if (j == 1)
    cp[0] = x + '0';

  s->l += l;
  s->s[s->l] = 0;
  return 0;
}

static inline int kputw(int c, kstring_t *s) {
  unsigned int x = c;
  if (c < 0) {
    x = -x;
    if (ks_resize(s, s->l + 3) < 0)
      return EOF;
    s->s[s->l++] = '-';
  }

  return kputuw(x, s);
}

static inline int kputll(long long c, kstring_t *s) {
  // Worst case expansion.  One check reduces function size
  // and aids inlining chance.  Memory overhead is minimal.
  if (ks_resize(s, s->l + 23) < 0)
    return EOF;

  unsigned long long x = c;
  if (c < 0) {
    x = -x;
    s->s[s->l++] = '-';
  }

  if (x <= UINT32_MAX)
    return kputuw(x, s);

  static const char kputull_dig2r[] = "00010203040506070809"
                                      "10111213141516171819"
                                      "20212223242526272829"
                                      "30313233343536373839"
                                      "40414243444546474849"
                                      "50515253545556575859"
                                      "60616263646566676869"
                                      "70717273747576777879"
                                      "80818283848586878889"
                                      "90919293949596979899";
  unsigned int l, j;
  char *cp;

  // Find out how long the number is (could consider clzll)
  uint64_t m = 1;
  l = 0;
  if (sizeof(long long) == sizeof(uint64_t) && x >= 10000000000000000000ULL) {
    // avoids overflow below
    l = 20;
  } else {
    do {
      l++;
      m *= 10;
    } while (x >= m);
  }

  // Add digits two at a time
  j = l;
  cp = s->s + s->l;
  while (x >= 10) {
    const char *d = &kputull_dig2r[2 * (x % 100)];
    x /= 100;
    memcpy(&cp[j -= 2], d, 2);
  }

  // Last one (if necessary).  We know that x < 10 by now.
  if (j == 1)
    cp[0] = x + '0';

  s->l += l;
  s->s[s->l] = 0;
  return 0;
}

static inline int kputl(long c, kstring_t *s) { return kputll(c, s); }

/*
 * Returns 's' split by delimiter, with *n being the number of components;
 *         NULL on failure.
 */
static inline int *ksplit(kstring_t *s, int delimiter, int *n) {
  int max = 0, *offsets = 0;
  *n = ksplit_core(s->s, delimiter, &max, &offsets);
  return offsets;
}

/**
 *  kinsert_char - inserts a char to kstring
 *  @param c   - char to insert
 *  @param pos - position at which to insert, starting from 0
 *  @param s   - pointer to output string
 *  Returns 0 on success and -1 on failure
 *  0 for pos inserts at start and length of current string as pos appends at
 *  the end.
 */
static inline int kinsert_char(char c, size_t pos, kstring_t *s) {
  if (!s || pos > s->l) {
    return EOF;
  }
  if (ks_resize(s, s->l + 2) < 0) {
    return EOF;
  }
  memmove(s->s + pos + 1, s->s + pos, s->l - pos);
  s->s[pos] = c;
  s->s[++s->l] = 0;
  return 0;
}

/**
 *  kinsert_str - inserts a null terminated string to kstring
 *  @param str - string to insert
 *  @param pos - position at which to insert, starting from 0
 *  @param s   - pointer to output string
 *  Returns 0 on success and -1 on failure
 *  0 for pos inserts at start and length of current string as pos appends at
 *  the end. empty string makes no update.
 */
static inline int kinsert_str(const char *str, size_t pos, kstring_t *s) {
  size_t len = 0;
  if (!s || pos > s->l || !str) {
    return EOF;
  }
  if (!(len = strlen(str))) {
    return 0;
  }
  if (ks_resize(s, s->l + len + 1) < 0) {
    return EOF;
  }
  memmove(s->s + pos + len, s->s + pos, s->l - pos);
  memcpy(s->s + pos, str, len);
  s->l += len;
  s->s[s->l] = '\0';
  return 0;
}

#ifdef HTSLIB_SSIZE_T
#undef HTSLIB_SSIZE_T
#undef ssize_t
#endif

#ifdef HTSLIB_EOVERFLOW
#undef HTSLIB_EOVERFLOW
#undef EOVERFLOW
#endif

#endif

/// @file htslib/sam.h
/// High-level SAM/BAM/CRAM sequence file operations.
/*
    Copyright (C) 2008, 2009, 2013-2023, 2025 Genome Research Ltd.
    Copyright (C) 2010, 2012, 2013 Broad Institute.

    Author: Heng Li <lh3@sanger.ac.uk>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.  */

#ifndef HTSLIB_SAM_H
#define HTSLIB_SAM_H

#include "hts.h"
#include "hts_endian.h"
#include <errno.h>
#include <stdint.h>
#include <sys/types.h>

// Ensure ssize_t exists within this header. All #includes must precede this,
// and ssize_t must be undefined again at the end of this header.
#if defined _MSC_VER && defined _INTPTR_T_DEFINED &&                           \
    !defined _SSIZE_T_DEFINED && !defined ssize_t
#define HTSLIB_SSIZE_T
#define ssize_t intptr_t
#endif

#ifdef __cplusplus
extern "C" {
#endif

/// Highest SAM format version supported by this library
#define SAM_FORMAT_VERSION "1.6"

/***************************
 *** SAM/BAM/CRAM header ***
 ***************************/

/*! @typedef
 * @abstract Header extension structure, grouping a collection
 *  of hash tables that contain the parsed header data.
 */

typedef struct sam_hrecs_t sam_hrecs_t;

/*! @typedef
 @abstract Structure for the alignment header.
 @field n_targets   number of reference sequences
 @field l_text      length of the plain text in the header (may be zero if
                    the header has been edited)
 @field target_len  lengths of the reference sequences
 @field target_name names of the reference sequences
 @field text        plain text (may be NULL if the header has been edited)
 @field sdict       header dictionary
 @field hrecs       pointer to the extended header struct (internal use only)
 @field ref_count   reference count

 @note The text and l_text fields are included for backwards compatibility.
 These fields may be set to NULL and zero respectively as a side-effect
 of calling some header API functions.  New code that needs to access the
 header text should use the sam_hdr_str() and sam_hdr_length() functions
 instead of these fields.
 */

typedef struct sam_hdr_t {
  int32_t n_targets, ignore_sam_err;
  size_t l_text;
  uint32_t *target_len;
  const int8_t *cigar_tab HTS_DEPRECATED("Use bam_cigar_table[] instead");
  char **target_name;
  char *text;
  void *sdict;
  sam_hrecs_t *hrecs;
  uint32_t ref_count;
} sam_hdr_t;

/*! @typedef
 * @abstract Old name for compatibility with existing code.
 */
typedef sam_hdr_t bam_hdr_t;

/****************************
 *** CIGAR related macros ***
 ****************************/

#define BAM_CMATCH 0
#define BAM_CINS 1
#define BAM_CDEL 2
#define BAM_CREF_SKIP 3
#define BAM_CSOFT_CLIP 4
#define BAM_CHARD_CLIP 5
#define BAM_CPAD 6
#define BAM_CEQUAL 7
#define BAM_CDIFF 8
#define BAM_CBACK 9

#define BAM_CIGAR_STR "MIDNSHP=XB"
#define BAM_CIGAR_SHIFT 4
#define BAM_CIGAR_MASK 0xf
#define BAM_CIGAR_TYPE 0x3C1A7

/*! @abstract Table for converting a CIGAR operator character to BAM_CMATCH etc.
Result is operator code or -1. Be sure to cast the index if it is a plain char:
    int op = bam_cigar_table[(unsigned char) ch];
*/
HTSLIB_EXPORT
extern const int8_t bam_cigar_table[256];

#define bam_cigar_op(c) ((c)&BAM_CIGAR_MASK)
#define bam_cigar_oplen(c) ((c) >> BAM_CIGAR_SHIFT)
// Note that BAM_CIGAR_STR is padded to length 16 bytes below so that
// the array look-up will not fall off the end.  '?' is chosen as the
// padding character so it's easy to spot if one is emitted, and will
// result in a parsing failure (in sam_parse1(), at least) if read.
#define bam_cigar_opchr(c) (BAM_CIGAR_STR "??????"[bam_cigar_op(c)])
#define bam_cigar_gen(l, o) ((l) << BAM_CIGAR_SHIFT | (o))

/* bam_cigar_type returns a bit flag with:
 *   bit 1 set if the cigar operation consumes the query
 *   bit 2 set if the cigar operation consumes the reference
 *
 * For reference, the unobfuscated truth table for this function is:
 * BAM_CIGAR_TYPE  QUERY  REFERENCE
 * --------------------------------
 * BAM_CMATCH      1      1
 * BAM_CINS        1      0
 * BAM_CDEL        0      1
 * BAM_CREF_SKIP   0      1
 * BAM_CSOFT_CLIP  1      0
 * BAM_CHARD_CLIP  0      0
 * BAM_CPAD        0      0
 * BAM_CEQUAL      1      1
 * BAM_CDIFF       1      1
 * BAM_CBACK       0      0
 * --------------------------------
 */
#define bam_cigar_type(o)                                                      \
  (BAM_CIGAR_TYPE >> ((o) << 1) &                                              \
   3) // bit 1: consume query; bit 2: consume reference

/*! @abstract the read is paired in sequencing, no matter whether it is mapped
 * in a pair */
#define BAM_FPAIRED 1
/*! @abstract the read is mapped in a proper pair */
#define BAM_FPROPER_PAIR 2
/*! @abstract the read itself is unmapped; conflictive with BAM_FPROPER_PAIR */
#define BAM_FUNMAP 4
/*! @abstract the mate is unmapped */
#define BAM_FMUNMAP 8
/*! @abstract the read is mapped to the reverse strand */
#define BAM_FREVERSE 16
/*! @abstract the mate is mapped to the reverse strand */
#define BAM_FMREVERSE 32
/*! @abstract this is read1 */
#define BAM_FREAD1 64
/*! @abstract this is read2 */
#define BAM_FREAD2 128
/*! @abstract not primary alignment */
#define BAM_FSECONDARY 256
/*! @abstract QC failure */
#define BAM_FQCFAIL 512
/*! @abstract optical or PCR duplicate */
#define BAM_FDUP 1024
/*! @abstract supplementary alignment */
#define BAM_FSUPPLEMENTARY 2048

/*************************
 *** Alignment records ***
 *************************/

/*
 * Assumptions made here.  While pos can be 64-bit, no sequence
 * itself is that long, but due to ref skip CIGAR fields it
 * may span more than that.  (CIGAR itself is 28-bit len + 4 bit
 * type, but in theory we can combine multiples together.)
 *
 * Mate position and insert size also need to be 64-bit, but
 * we won't accept more than 32-bit for tid.
 *
 * The bam1_core_t structure is the *in memory* layout and not
 * the same as the on-disk format.  64-bit changes here permit
 * SAM to work with very long chromosomes and permit BAM and CRAM
 * to seamlessly update in the future without further API/ABI
 * revisions.
 */

/*! @typedef
 @abstract Structure for core alignment information.
 @field  pos     0-based leftmost coordinate
 @field  tid     chromosome ID, defined by sam_hdr_t
 @field  bin     bin calculated by bam_reg2bin()
 @field  qual    mapping quality
 @field  l_extranul length of extra NULs between qname & cigar (for alignment)
 @field  flag    bitwise flag
 @field  l_qname length of the query name
 @field  n_cigar number of CIGAR operations
 @field  l_qseq  length of the query sequence (read)
 @field  mtid    chromosome ID of next read in template, defined by sam_hdr_t
 @field  mpos    0-based leftmost coordinate of next read in template
 @field  isize   observed template length ("insert size")
 */
typedef struct bam1_core_t {
  hts_pos_t pos;
  int32_t tid;
  uint16_t bin; // NB: invalid on 64-bit pos
  uint8_t qual;
  uint8_t l_extranul;
  uint16_t flag;
  uint16_t l_qname;
  uint32_t n_cigar;
  int32_t l_qseq;
  int32_t mtid;
  hts_pos_t mpos;
  hts_pos_t isize;
} bam1_core_t;

/*! @typedef
 @abstract Structure for one alignment.
 @field  core       core information about the alignment
 @field  id
 @field  data       all variable-length data, concatenated; structure:
 qname-cigar-seq-qual-aux
 @field  l_data     current length of bam1_t::data
 @field  m_data     maximum length of bam1_t::data
 @field  mempolicy  memory handling policy, see bam_set_mempolicy()

 @discussion Notes:

 1. The data blob should be accessed using bam_get_qname, bam_get_cigar,
    bam_get_seq, bam_get_qual and bam_get_aux macros.  These returns pointers
    to the start of each type of data.
 2. qname is terminated by one to four NULs, so that the following
    cigar data is 32-bit aligned; core.l_qname includes these trailing NULs,
    while core.l_extranul counts the excess NULs (so 0 <= l_extranul <= 3).
 3. Cigar data is encoded 4 bytes per CIGAR operation.
    See the bam_cigar_* macros for manipulation.
 4. seq is nibble-encoded according to seq_nt16_table.
    See the bam_seqi macro for retrieving individual bases.
 5. Per base qualities are stored in the Phred scale with no +33 offset.
    Ie as per the BAM specification and not the SAM ASCII printable method.
 */
typedef struct bam1_t {
  bam1_core_t core;
  uint64_t id;
  uint8_t *data;
  int l_data;
  uint32_t m_data;
  uint32_t mempolicy : 2, : 30 /* Reserved */;
} bam1_t;

/*! @function
 @abstract  Get whether the query is on the reverse strand
 @param  b  pointer to an alignment
 @return    boolean true if query is on the reverse strand
 */
#define bam_is_rev(b) (((b)->core.flag & BAM_FREVERSE) != 0)
/*! @function
 @abstract  Get whether the query's mate is on the reverse strand
 @param  b  pointer to an alignment
 @return    boolean true if query's mate on the reverse strand
 */
#define bam_is_mrev(b) (((b)->core.flag & BAM_FMREVERSE) != 0)
/*! @function
 @abstract  Get the name of the query
 @param  b  pointer to an alignment
 @return    pointer to the name string, null terminated
 */
#define bam_get_qname(b) ((char *)(b)->data)
/*! @function
 @abstract  Get the CIGAR array
 @param  b  pointer to an alignment
 @return    pointer to the CIGAR array

 @discussion In the CIGAR array, each element is a 32-bit integer. The
 lower 4 bits gives a CIGAR operation and the higher 28 bits keep the
 length of a CIGAR.
 */
#define bam_get_cigar(b) ((uint32_t *)((b)->data + (b)->core.l_qname))
/*! @function
 @abstract  Get query sequence
 @param  b  pointer to an alignment
 @return    pointer to sequence

 @discussion Each base is encoded in 4 bits: 1 for A, 2 for C, 4 for G,
 8 for T and 15 for N. Two bases are packed in one byte with the base
 at the higher 4 bits having smaller coordinate on the read. It is
 recommended to use bam_seqi() macro to get the base.
 */
#define bam_get_seq(b)                                                         \
  ((b)->data + ((b)->core.n_cigar << 2) + (b)->core.l_qname)
/*! @function
 @abstract  Get query quality
 @param  b  pointer to an alignment
 @return    pointer to quality string
 */
#define bam_get_qual(b)                                                        \
  ((b)->data + ((b)->core.n_cigar << 2) + (b)->core.l_qname +                  \
   (((b)->core.l_qseq + 1) >> 1))
/*! @function
 @abstract  Get auxiliary data
 @param  b  pointer to an alignment
 @return    pointer to the concatenated auxiliary data
 */
#define bam_get_aux(b)                                                         \
  ((b)->data + ((b)->core.n_cigar << 2) + (b)->core.l_qname +                  \
   (((b)->core.l_qseq + 1) >> 1) + (b)->core.l_qseq)
/*! @function
 @abstract  Get length of auxiliary data
 @param  b  pointer to an alignment
 @return    length of the concatenated auxiliary data
 */
#define bam_get_l_aux(b)                                                       \
  ((b)->l_data - ((b)->core.n_cigar << 2) - (b)->core.l_qname -                \
   (b)->core.l_qseq - (((b)->core.l_qseq + 1) >> 1))
/*! @function
 @abstract  Get a base on read
 @param  s  Query sequence returned by bam_get_seq()
 @param  i  The i-th position, 0-based
 @return    4-bit integer representing the base.
 */
#define bam_seqi(s, i) ((s)[(i) >> 1] >> ((~(i)&1) << 2) & 0xf)
/*!
 @abstract  Modifies a single base in the bam structure.
 @param s   Query sequence returned by bam_get_seq()
 @param i   The i-th position, 0-based
 @param b   Base in nt16 nomenclature (see seq_nt16_table)
*/
#define bam_set_seqi(s, i, b)                                                  \
  ((s)[(i) >> 1] =                                                             \
       ((s)[(i) >> 1] & (0xf0 >> ((~(i)&1) << 2))) | ((b) << ((~(i)&1) << 2)))

/**************************
 *** Exported functions ***
 **************************/

/***************
 *** BAM I/O ***
 ***************/

/* Header */

/// Generates a new unpopulated header structure.
/*!
 *
 * @return  A valid pointer to new header on success, NULL on failure
 *
 * The sam_hdr_t struct returned by a successful call should be freed
 * via sam_hdr_destroy() when it is no longer needed.
 */
HTSLIB_EXPORT
sam_hdr_t *sam_hdr_init(void);

/// Read the header from a BAM compressed file.
/*!
 * @param fp  File pointer
 * @return    A valid pointer to new header on success, NULL on failure
 *
 * This function only works with BAM files.  It is usually better to use
 * sam_hdr_read(), which works on SAM, BAM and CRAM files.
 *
 * The sam_hdr_t struct returned by a successful call should be freed
 * via sam_hdr_destroy() when it is no longer needed.
 */
HTSLIB_EXPORT
sam_hdr_t *bam_hdr_read(BGZF *fp);

/// Writes the header to a BAM file.
/*!
 * @param fp  File pointer
 * @param h   Header pointer
 * @return    0 on success, -1 on failure
 *
 * This function only works with BAM files.  Use sam_hdr_write() to
 * write in any of the SAM, BAM or CRAM formats.
 */
HTSLIB_EXPORT
int bam_hdr_write(BGZF *fp, const sam_hdr_t *h) HTS_RESULT_USED;

/*!
 * Frees the resources associated with a header.
 */
HTSLIB_EXPORT
void sam_hdr_destroy(sam_hdr_t *h);

/// Duplicate a header structure.
/*!
 * @return  A valid pointer to new header on success, NULL on failure
 *
 * The sam_hdr_t struct returned by a successful call should be freed
 * via sam_hdr_destroy() when it is no longer needed.
 */
HTSLIB_EXPORT
sam_hdr_t *sam_hdr_dup(const sam_hdr_t *h0);

/*!
 * @abstract Old names for compatibility with existing code.
 */
static inline sam_hdr_t *bam_hdr_init(void) { return sam_hdr_init(); }
static inline void bam_hdr_destroy(sam_hdr_t *h) { sam_hdr_destroy(h); }
static inline sam_hdr_t *bam_hdr_dup(const sam_hdr_t *h0) {
  return sam_hdr_dup(h0);
}

typedef htsFile samFile;

/// Create a header from existing text.
/*!
 * @param l_text    Length of text
 * @param text      Header text
 * @return A populated sam_hdr_t structure on success; NULL on failure.
 * @note The text field of the returned header will be NULL, and the l_text
 * field will be zero.
 *
 * The sam_hdr_t struct returned by a successful call should be freed
 * via sam_hdr_destroy() when it is no longer needed.
 */
HTSLIB_EXPORT
sam_hdr_t *sam_hdr_parse(size_t l_text, const char *text);

/// Read a header from a SAM, BAM or CRAM file.
/*!
 * @param fp    Pointer to a SAM, BAM or CRAM file handle
 * @return  A populated sam_hdr_t struct on success; NULL on failure.
 *
 * The sam_hdr_t struct returned by a successful call should be freed
 * via sam_hdr_destroy() when it is no longer needed.
 */
HTSLIB_EXPORT
sam_hdr_t *sam_hdr_read(samFile *fp);

/// Write a header to a SAM, BAM or CRAM file.
/*!
 * @param fp    SAM, BAM or CRAM file header
 * @param h     Header structure to write
 * @return  0 on success; -1 on failure
 */
HTSLIB_EXPORT
int sam_hdr_write(samFile *fp, const sam_hdr_t *h) HTS_RESULT_USED;

/// Returns the current length of the header text.
/*!
 * @return  >= 0 on success, SIZE_MAX on failure
 */
HTSLIB_EXPORT
size_t sam_hdr_length(sam_hdr_t *h);

/// Returns the text representation of the header.
/*!
 * @return  valid char pointer on success, NULL on failure
 *
 * The returned string is part of the header structure.  It will remain
 * valid until a call to a header API function causes the string to be
 * invalidated, or the header is destroyed.
 *
 * The caller should not attempt to free or realloc this pointer.
 */
HTSLIB_EXPORT
const char *sam_hdr_str(sam_hdr_t *h);

/// Returns the number of references in the header.
/*!
 * @return  >= 0 on success, -1 on failure
 */
HTSLIB_EXPORT
int sam_hdr_nref(const sam_hdr_t *h);

/* ==== Line level methods ==== */

/// Add formatted lines to an existing header.
/*!
 * @param lines  Full SAM header record, eg "@SQ\tSN:foo\tLN:100", with
 *               optional new-line. If it contains more than 1 line then
 *               multiple lines will be added in order
 * @param len    The maximum length of lines (if an early NUL is not
 *               encountered). len may be 0 if unknown, in which case
 *               lines must be NUL-terminated
 * @return       0 on success, -1 on failure
 *
 * The lines will be appended to the end of the existing header
 * (apart from HD, which always comes first).
 */
HTSLIB_EXPORT
int sam_hdr_add_lines(sam_hdr_t *h, const char *lines, size_t len);

/// Adds a single line to an existing header.
/*!
 * Specify type and one or more key,value pairs, ending with the NULL key.
 * Eg. sam_hdr_add_line(h, "SQ", "SN", "foo", "LN", "100", NULL).
 *
 * @param type  Type of the added line. Eg. "SQ"
 * @return      0 on success, -1 on failure
 *
 * The new line will be added immediately after any others of the same
 * type, or at the end of the existing header if no lines of the
 * given type currently exist.  The exception is HD lines, which always
 * come first.  If an HD line already exists, it will be replaced.
 */
HTSLIB_EXPORT
int sam_hdr_add_line(sam_hdr_t *h, const char *type, ...);

/// Returns a complete line of formatted text for a given type and ID.
/*!
 * @param type      Type of the searched line. Eg. "SQ"
 * @param ID_key    Tag key defining the line. Eg. "SN"
 * @param ID_value  Tag value associated with the key above. Eg. "ref1"
 * @param ks        kstring to hold the result
 * @return          0 on success;
 *                 -1 if no matching line is found
 *                 -2 on other failures
 *
 * Puts a complete line of formatted text for a specific header type/ID
 * combination into @p ks. If ID_key is NULL then it returns the first line of
 * the specified type.
 *
 * Any existing content in @p ks will be overwritten.
 */
HTSLIB_EXPORT
int sam_hdr_find_line_id(sam_hdr_t *h, const char *type, const char *ID_key,
                         const char *ID_val, kstring_t *ks);

/// Returns a complete line of formatted text for a given type and index.
/*!
 * @param type      Type of the searched line. Eg. "SQ"
 * @param position  Index in lines of this type (zero-based)
 * @param ks        kstring to hold the result
 * @return          0 on success;
 *                 -1 if no matching line is found
 *                 -2 on other failures
 *
 * Puts a complete line of formatted text for a specific line into @p ks.
 * The header line is selected using the @p type and @p position parameters.
 *
 * Any existing content in @p ks will be overwritten.
 */
HTSLIB_EXPORT
int sam_hdr_find_line_pos(sam_hdr_t *h, const char *type, int pos,
                          kstring_t *ks);

/// Remove a line with given type / id from a header
/*!
 * @param type      Type of the searched line. Eg. "SQ"
 * @param ID_key    Tag key defining the line. Eg. "SN"
 * @param ID_value  Tag value associated with the key above. Eg. "ref1"
 * @return          0 on success, -1 on error
 *
 * Remove a line from the header by specifying a tag:value that uniquely
 * identifies the line, i.e. the @SQ line containing "SN:ref1".
 *
 * \@SQ line is uniquely identified by the SN tag.
 * \@RG line is uniquely identified by the ID tag.
 * \@PG line is uniquely identified by the ID tag.
 * Eg. sam_hdr_remove_line_id(h, "SQ", "SN", "ref1")
 *
 * If no key:value pair is specified, the type MUST be followed by a NULL
 * argument and the first line of the type will be removed, if any. Eg.
 * sam_hdr_remove_line_id(h, "SQ", NULL, NULL)
 *
 * @note Removing \@PG lines is currently unsupported.
 */
HTSLIB_EXPORT
int sam_hdr_remove_line_id(sam_hdr_t *h, const char *type, const char *ID_key,
                           const char *ID_value);

/// Remove nth line of a given type from a header
/*!
 * @param type     Type of the searched line. Eg. "SQ"
 * @param position Index in lines of this type (zero-based). E.g. 3
 * @return         0 on success, -1 on error
 *
 * Remove a line from the header by specifying the position in the type
 * group, i.e. 3rd @SQ line.
 */
HTSLIB_EXPORT
int sam_hdr_remove_line_pos(sam_hdr_t *h, const char *type, int position);

/// Add or update tag key,value pairs in a header line.
/*!
 * @param type      Type of the searched line. Eg. "SQ"
 * @param ID_key    Tag key defining the line. Eg. "SN"
 * @param ID_value  Tag value associated with the key above. Eg. "ref1"
 * @return          0 on success, -1 on error
 *
 * Adds or updates tag key,value pairs in a header line.
 * Eg. for adding M5 tags to @SQ lines or updating sort order for the
 * @HD line.
 *
 * Specify multiple key,value pairs ending in NULL. Eg.
 * sam_hdr_update_line(h, "RG", "ID", "rg1", "DS", "description", "PG",
 * "samtools", NULL)
 *
 * Attempting to update the record name (i.e. @SQ SN or @RG ID) will
 * work as long as the new name is not already in use, however doing this
 * on a file opened for reading may produce unexpected results.
 *
 * Renaming an @RG record in this way will only change the header.  Alignment
 * records written later will not be updated automatically even if they
 * reference the old read group name.
 *
 * Attempting to change an @PG ID tag is not permitted.
 */
HTSLIB_EXPORT
int sam_hdr_update_line(sam_hdr_t *h, const char *type, const char *ID_key,
                        const char *ID_value, ...);

/// Remove all lines of a given type from a header, except the one matching an
/// ID
/*!
 * @param type      Type of the searched line. Eg. "SQ"
 * @param ID_key    Tag key defining the line. Eg. "SN"
 * @param ID_value  Tag value associated with the key above. Eg. "ref1"
 * @return          0 on success, -1 on failure
 *
 * Remove all lines of type <type> from the header, except the one
 * specified by tag:value, i.e. the @SQ line containing "SN:ref1".
 *
 * If no line matches the key:value ID, all lines of the given type are removed.
 * To remove all lines of a given type, use NULL for both ID_key and ID_value.
 */
HTSLIB_EXPORT
int sam_hdr_remove_except(sam_hdr_t *h, const char *type, const char *ID_key,
                          const char *ID_value);

/// Remove header lines of a given type, except those in a given ID set
/*!
 * @param type  Type of the searched line. Eg. "RG"
 * @param id    Tag key defining the line. Eg. "ID"
 * @param rh    Hash set initialised by the caller with the values to be kept.
 *              See description for how to create this. If @p rh is NULL, all
 *              lines of this type will be removed.
 * @return      0 on success, -1 on failure
 *
 * Remove all lines of type @p type from the header, except the ones
 * specified in the hash set @p rh. If @p rh is NULL, all lines of
 * this type will be removed.
 * Declaration of @p rh is done using KHASH_SET_INIT_STR macro. Eg.
 * @code{.c}
 *              #include "htslib/khash.h"
 *              KHASH_SET_INIT_STR(keep)
 *              typedef khash_t(keep) *keephash_t;
 *
 *              void your_method() {
 *                  samFile *sf = sam_open("alignment.bam", "r");
 *                  sam_hdr_t *h = sam_hdr_read(sf);
 *                  keephash_t rh = kh_init(keep);
 *                  int ret = 0;
 *                  kh_put(keep, rh, strdup("chr2"), &ret);
 *                  kh_put(keep, rh, strdup("chr3"), &ret);
 *                  if (sam_hdr_remove_lines(h, "SQ", "SN", rh) == -1)
 *                      fprintf(stderr, "Error removing lines\n");
 *                  khint_t k;
 *                  for (k = 0; k < kh_end(rh); ++k)
 *                     if (kh_exist(rh, k)) free((char*)kh_key(rh, k));
 *                  kh_destroy(keep, rh);
 *                  sam_hdr_destroy(h);
 *                  sam_close(sf);
 *              }
 * @endcode
 *
 */
HTSLIB_EXPORT
int sam_hdr_remove_lines(sam_hdr_t *h, const char *type, const char *id,
                         void *rh);

/// Count the number of lines for a given header type
/*!
 * @param h     BAM header
 * @param type  Header type to count. Eg. "RG"
 * @return  Number of lines of this type on success; -1 on failure
 */
HTSLIB_EXPORT
int sam_hdr_count_lines(sam_hdr_t *h, const char *type);

/// Index of the line for the types that have dedicated look-up tables (SQ, RG,
/// PG)
/*!
 * @param h     BAM header
 * @param type  Type of the searched line. Eg. "RG"
 * @param key   The value of the identifying key. Eg. "rg1"
 * @return  0-based index on success; -1 if line does not exist; -2 on failure
 */
HTSLIB_EXPORT
int sam_hdr_line_index(sam_hdr_t *bh, const char *type, const char *key);

/// Id key of the line for the types that have dedicated look-up tables (SQ, RG,
/// PG)
/*!
 * @param h     BAM header
 * @param type  Type of the searched line. Eg. "RG"
 * @param pos   Zero-based index inside the type group. Eg. 2 (for the third RG
 * line)
 * @return  Valid key string on success; NULL on failure
 */
HTSLIB_EXPORT
const char *sam_hdr_line_name(sam_hdr_t *bh, const char *type, int pos);

/* ==== Key:val level methods ==== */

/// Return the value associated with a key for a header line identified by
/// ID_key:ID_val
/*!
 * @param type      Type of the line to which the tag belongs. Eg. "SQ"
 * @param ID_key    Tag key defining the line. Eg. "SN". Can be NULL, if looking
 * for the first line.
 * @param ID_value  Tag value associated with the key above. Eg. "ref1". Can be
 * NULL, if ID_key is NULL.
 * @param key       Key of the searched tag. Eg. "LN"
 * @param ks        kstring where the value will be written
 * @return          0 on success
 *                 -1 if the requested tag does not exist
 *                 -2 on other errors
 *
 * Looks for a specific key in a single SAM header line and writes the
 * associated value into @p ks.  The header line is selected using the ID_key
 * and ID_value parameters.  Any pre-existing content in @p ks will be
 * overwritten.
 */
HTSLIB_EXPORT
int sam_hdr_find_tag_id(sam_hdr_t *h, const char *type, const char *ID_key,
                        const char *ID_value, const char *key, kstring_t *ks);

/// Return the value associated with a key for a header line identified by
/// position
/*!
 * @param type      Type of the line to which the tag belongs. Eg. "SQ"
 * @param position  Index in lines of this type (zero-based). E.g. 3
 * @param key       Key of the searched tag. Eg. "LN"
 * @param ks        kstring where the value will be written
 * @return          0 on success
 *                 -1 if the requested tag does not exist
 *                 -2 on other errors
 *
 * Looks for a specific key in a single SAM header line and writes the
 * associated value into @p ks.  The header line is selected using the @p type
 * and @p position parameters.  Any pre-existing content in @p ks will be
 * overwritten.
 */
HTSLIB_EXPORT
int sam_hdr_find_tag_pos(sam_hdr_t *h, const char *type, int pos,
                         const char *key, kstring_t *ks);

/// Remove the key from the line identified by type, ID_key and ID_value.
/*!
 * @param type      Type of the line to which the tag belongs. Eg. "SQ"
 * @param ID_key    Tag key defining the line. Eg. "SN"
 * @param ID_value  Tag value associated with the key above. Eg. "ref1"
 * @param key       Key of the targeted tag. Eg. "M5"
 * @return          1 if the key was removed; 0 if it was not present; -1 on
 * error
 */
HTSLIB_EXPORT
int sam_hdr_remove_tag_id(sam_hdr_t *h, const char *type, const char *ID_key,
                          const char *ID_value, const char *key);

/// Get the target id for a given reference sequence name
/*!
 * @param ref  Reference name
 * @return     Positive value on success,
 *             -1 if unknown reference,
 *             -2 if the header could not be parsed
 *
 * Looks up a reference sequence by name in the reference hash table
 * and returns the numerical target id.
 */
HTSLIB_EXPORT
int sam_hdr_name2tid(sam_hdr_t *h, const char *ref);

/// Get the reference sequence name from a target index
/*!
 * @param tid  Target index
 * @return     Valid reference name on success, NULL on failure
 *
 * Fetch the reference sequence name from the target name array,
 * using the numerical target id.
 */
HTSLIB_EXPORT
const char *sam_hdr_tid2name(const sam_hdr_t *h, int tid);

/// Get the reference sequence length from a target index
/*!
 * @param tid  Target index
 * @return     Strictly positive value on success, 0 on failure
 *
 * Fetch the reference sequence length from the target length array,
 * using the numerical target id.
 */
HTSLIB_EXPORT
hts_pos_t sam_hdr_tid2len(const sam_hdr_t *h, int tid);

/// Alias of sam_hdr_name2tid(), for backwards compatibility.
/*!
 * @param ref  Reference name
 * @return     Positive value on success,
 *             -1 if unknown reference,
 *             -2 if the header could not be parsed
 */
static inline int bam_name2id(sam_hdr_t *h, const char *ref) {
  return sam_hdr_name2tid(h, ref);
}

/// Generate a unique \@PG ID: value
/*!
 * @param name  Name of the program. Eg. samtools
 * @return      Valid ID on success, NULL on failure
 *
 * Returns a unique ID from a base name.  The string returned will remain
 * valid until the next call to this function, or the header is destroyed.
 * The caller should not attempt to free() or realloc() it.
 */
HTSLIB_EXPORT
const char *sam_hdr_pg_id(sam_hdr_t *h, const char *name);

/// Add an \@PG line.
/*!
 * @param name  Name of the program. Eg. samtools
 * @return      0 on success, -1 on failure
 *
 * If we wish complete control over this use sam_hdr_add_line() directly. This
 * function uses that, but attempts to do a lot of tedious house work for
 * you too.
 *
 * - It will generate a suitable ID if the supplied one clashes.
 * - It will generate multiple \@PG records if we have multiple PG chains.
 *
 * Call it as per sam_hdr_add_line() with a series of key,value pairs ending
 * in NULL.
 */
HTSLIB_EXPORT
int sam_hdr_add_pg(sam_hdr_t *h, const char *name, ...);

/*!
 * A function to help with construction of CL tags in @PG records.
 * Takes an argc, argv pair and returns a single space-separated string.
 * This string should be deallocated by the calling function.
 *
 * @return
 * Returns malloced char * on success;
 *         NULL on failure
 */
HTSLIB_EXPORT
char *stringify_argv(int argc, char *argv[]);

/// Increments the reference count on a header
/*!
 * This permits multiple files to share the same header, all calling
 * sam_hdr_destroy when done, without causing errors for other open files.
 */
HTSLIB_EXPORT
void sam_hdr_incr_ref(sam_hdr_t *h);

/*
 * Macros for changing the \@HD line. They eliminate the need to use NULL method
 * arguments.
 */

/// Returns the SAM formatted text of the \@HD header line
#define sam_hdr_find_hd(h, ks) sam_hdr_find_line_id((h), "HD", NULL, NULL, (ks))
/// Returns the value associated with a given \@HD line tag
#define sam_hdr_find_tag_hd(h, key, ks)                                        \
  sam_hdr_find_tag_id((h), "HD", NULL, NULL, (key), (ks))
/// Adds or updates tags on the header \@HD line
#define sam_hdr_update_hd(h, ...)                                              \
  sam_hdr_update_line((h), "HD", NULL, NULL, __VA_ARGS__, NULL)
/// Removes the \@HD line tag with the given key
#define sam_hdr_remove_tag_hd(h, key)                                          \
  sam_hdr_remove_tag_id((h), "HD", NULL, NULL, (key))

/* Alignment */

/// Create a new bam1_t alignment structure
/**
   @return An empty bam1_t structure on success, NULL on failure

   The bam1_t struct returned by a successful call should be freed
   via bam_destroy1() when it is no longer needed.
 */
HTSLIB_EXPORT
bam1_t *bam_init1(void);

/// Destroy a bam1_t structure
/**
   @param b  structure to destroy

   Does nothing if @p b is NULL.  If not, all memory associated with @p b
   will be freed, along with the structure itself.  @p b should not be
   accessed after calling this function.
 */
HTSLIB_EXPORT
void bam_destroy1(bam1_t *b);

#define BAM_USER_OWNS_STRUCT 1
#define BAM_USER_OWNS_DATA 2

/// Set alignment record memory policy
/**
   @param b       Alignment record
   @param policy  Desired policy

   Allows the way HTSlib reallocates and frees bam1_t data to be
   changed.  @policy can be set to the bitwise-or of the following
   values:

   \li \c BAM_USER_OWNS_STRUCT
   If this is set then bam_destroy1() will not try to free the bam1_t struct.

   \li \c BAM_USER_OWNS_DATA
   If this is set, bam_destroy1() will not free the bam1_t::data pointer.
   Also, functions which need to expand bam1_t::data memory will change
   behaviour.  Instead of calling realloc() on the pointer, they will
   allocate a new data buffer and copy any existing content in to it.
   The existing memory will \b not be freed.  bam1_t::data will be
   set to point to the new memory and the BAM_USER_OWNS_DATA flag will be
   cleared.

   BAM_USER_OWNS_STRUCT allows bam_destroy1() to be called on bam1_t
   structures that are members of an array.

   BAM_USER_OWNS_DATA can be used by applications that want more control
   over where the variable-length parts of the bam record will be stored.
   By preventing calls to free() and realloc(), it allows bam1_t::data
   to hold pointers to memory that cannot be passed to those functions.

   Example:  Read a block of alignment records, storing the variable-length
   data in a single buffer and the records in an array.  Stop when either
   the array or the buffer is full.

   \code{.c}
   #define MAX_RECS 1000
   #define REC_LENGTH 400  // Average length estimate, to get buffer size
   size_t bufsz = MAX_RECS * REC_LENGTH, nrecs, buff_used = 0;
   bam1_t *recs = calloc(MAX_RECS, sizeof(bam1_t));
   uint8_t *buffer = malloc(bufsz);
   int res = 0, result = EXIT_FAILURE;
   uint32_t new_m_data;

   if (!recs || !buffer) goto cleanup;
   for (nrecs = 0; nrecs < MAX_RECS; nrecs++) {
      bam_set_mempolicy(&recs[nrecs], BAM_USER_OWNS_STRUCT|BAM_USER_OWNS_DATA);

      // Set data pointer to unused part of buffer
      recs[nrecs].data = &buffer[buff_used];

      // Set m_data to size of unused part of buffer.  On 64-bit platforms it
      // will be necessary to limit this to UINT32_MAX due to the size of
      // bam1_t::m_data (not done here as our buffer is only 400K).
      recs[nrecs].m_data = bufsz - buff_used;

      // Read the record
      res = sam_read1(file_handle, header, &recs[nrecs]);
      if (res <= 0) break; // EOF or error

      // Check if the record data didn't fit - if not, stop reading
      if ((bam_get_mempolicy(&recs[nrecs]) & BAM_USER_OWNS_DATA) == 0) {
         nrecs++; // Include last record in count
         break;
      }

      // Adjust m_data to the space actually used.  If space is available,
      // round up to eight bytes so the next record aligns nicely.
      new_m_data = ((uint32_t) recs[nrecs].l_data + 7) & (~7U);
      if (new_m_data < recs[nrecs].m_data) recs[nrecs].m_data = new_m_data;

      buff_used += recs[nrecs].m_data;
   }
   if (res < 0) goto cleanup;
   result = EXIT_SUCCESS;

   // ... use data ...

 cleanup:
   if (recs) {
      for (size_t i = 0; i < nrecs; i++)
         bam_destroy1(&recs[i]);
      free(recs);
   }
   free(buffer);

   \endcode
*/
static inline void bam_set_mempolicy(bam1_t *b, uint32_t policy) {
  b->mempolicy = policy;
}

/// Get alignment record memory policy
/** @param b    Alignment record

    See bam_set_mempolicy()
 */
static inline uint32_t bam_get_mempolicy(bam1_t *b) { return b->mempolicy; }

/// Read a BAM format alignment record
/**
   @param fp   BGZF file being read
   @param b    Destination for the alignment data
   @return number of bytes read on success
           -1 at end of file
           < -1 on failure

   This function can only read BAM format files.  Most code should use
   sam_read1() instead, which can be used with BAM, SAM and CRAM formats.
*/
HTSLIB_EXPORT
int bam_read1(BGZF *fp, bam1_t *b) HTS_RESULT_USED;

/// Write a BAM format alignment record
/**
   @param fp  BGZF file being written
   @param b   Alignment record to write
   @return number of bytes written on success
           -1 on error

   This function can only write BAM format files.  Most code should use
   sam_write1() instead, which can be used with BAM, SAM and CRAM formats.
*/
HTSLIB_EXPORT
int bam_write1(BGZF *fp, const bam1_t *b) HTS_RESULT_USED;

/// Copy alignment record data
/**
   @param bdst  Destination alignment record
   @param bsrc  Source alignment record
   @return bdst on success; NULL on failure
 */
HTSLIB_EXPORT
bam1_t *bam_copy1(bam1_t *bdst, const bam1_t *bsrc) HTS_RESULT_USED;

/// Create a duplicate alignment record
/**
   @param bsrc  Source alignment record
   @return Pointer to a new alignment record on success; NULL on failure

   The bam1_t struct returned by a successful call should be freed
   via bam_destroy1() when it is no longer needed.
 */
HTSLIB_EXPORT
bam1_t *bam_dup1(const bam1_t *bsrc);

/// Sets all components of an alignment structure
/**
   @param bam      Target alignment structure. Must be initialized by a call to
   bam_init1(). The data field will be reallocated automatically as needed.
   @param l_qname  Length of the query name. If set to 0, the placeholder query
   name "*" will be used.
   @param qname    Query name, may be NULL if l_qname = 0
   @param flag     Bitwise flag, a combination of the BAM_F* constants.
   @param tid      Chromosome ID, defined by sam_hdr_t (a.k.a. RNAME).
   @param pos      0-based leftmost coordinate.
   @param mapq     Mapping quality.
   @param n_cigar  Number of CIGAR operations.
   @param cigar    CIGAR data, may be NULL if n_cigar = 0.
   @param mtid     Chromosome ID of next read in template, defined by sam_hdr_t
   (a.k.a. RNEXT).
   @param mpos     0-based leftmost coordinate of next read in template (a.k.a.
   PNEXT).
   @param isize    Observed template length ("insert size") (a.k.a. TLEN).
   @param l_seq    Length of the query sequence (read) and sequence quality
   string.
   @param seq      Sequence, may be NULL if l_seq = 0.
   @param qual     Sequence quality, may be NULL. Should be provided without
   ASCII 33 offset.
   @param l_aux    Length to be reserved for auxiliary field data, may be 0.

   @return >= 0 on success (number of bytes written to bam->data), negative
   (with errno set) on failure.
*/
HTSLIB_EXPORT
int bam_set1(bam1_t *bam, size_t l_qname, const char *qname, uint16_t flag,
             int32_t tid, hts_pos_t pos, uint8_t mapq, size_t n_cigar,
             const uint32_t *cigar, int32_t mtid, hts_pos_t mpos,
             hts_pos_t isize, size_t l_seq, const char *seq, const char *qual,
             size_t l_aux);

/// Calculate query length from CIGAR data
/**
   @param n_cigar   Number of items in @p cigar
   @param cigar     CIGAR data
   @return Query length

   CIGAR data is stored as in the BAM format, i.e. (op_len << 4) | op
   where op_len is the length in bases and op is a value between 0 and 8
   representing one of the operations "MIDNSHP=X" (M = 0; X = 8)

   This function returns the sum of the lengths of the M, I, S, = and X
   operations in @p cigar (these are the operations that "consume" query
   bases).  All other operations (including invalid ones) are ignored.

   @note This return type of this function is hts_pos_t so that it can
   correctly return the length of CIGAR sequences including many long
   operations without overflow. However, other restrictions (notably the sizes
   of bam1_core_t::l_qseq and bam1_t::data) limit the maximum query sequence
   length supported by HTSlib to fewer than INT_MAX bases.
 */
HTSLIB_EXPORT
hts_pos_t bam_cigar2qlen(int n_cigar, const uint32_t *cigar);

/// Calculate reference length from CIGAR data
/**
   @param n_cigar   Number of items in @p cigar
   @param cigar     CIGAR data
   @return Reference length

   CIGAR data is stored as in the BAM format, i.e. (op_len << 4) | op
   where op_len is the length in bases and op is a value between 0 and 8
   representing one of the operations "MIDNSHP=X" (M = 0; X = 8)

   This function returns the sum of the lengths of the M, D, N, = and X
   operations in @p cigar (these are the operations that "consume" reference
   bases).  All other operations (including invalid ones) are ignored.
 */
HTSLIB_EXPORT
hts_pos_t bam_cigar2rlen(int n_cigar, const uint32_t *cigar);

/*!
      @abstract Calculate the rightmost base position of an alignment on the
      reference genome.

      @param  b  pointer to an alignment
      @return    the coordinate of the first base after the alignment, 0-based

      @discussion For a mapped read, this is just b->core.pos + bam_cigar2rlen.
      For an unmapped read (either according to its flags or if it has no cigar
      string) or a read whose cigar string consumes no reference bases at all,
      we return b->core.pos + 1 by convention.
 */
HTSLIB_EXPORT
hts_pos_t bam_endpos(const bam1_t *b);

HTSLIB_EXPORT
int bam_str2flag(const char *str); /** returns negative value on error */

HTSLIB_EXPORT
char *bam_flag2str(int flag); /** The string must be freed by the user */

/*! @function
 @abstract  Set the name of the query
 @param  b  pointer to an alignment
 @return    0 on success, -1 on failure
 */
HTSLIB_EXPORT
int bam_set_qname(bam1_t *b, const char *qname);

/*! @function
 @abstract  Parse a CIGAR string into a uint32_t array
 @param  in      [in]  pointer to the source string
 @param  end     [out] address of the pointer to the new end of the input string
                       can be NULL
 @param  a_cigar [in/out]  address of the destination uint32_t buffer
 @param  a_mem   [in/out]  address of the allocated number of buffer elements
 @return         number of processed CIGAR operators; -1 on error
 */
HTSLIB_EXPORT
ssize_t sam_parse_cigar(const char *in, char **end, uint32_t **a_cigar,
                        size_t *a_mem);

/*! @function
 @abstract  Parse a CIGAR string into a bam1_t struct
 @param  in      [in]  pointer to the source string
 @param  end     [out] address of the pointer to the new end of the input string
                       can be NULL
 @param  b       [in/out]  address of the destination bam1_t struct
 @return         number of processed CIGAR operators; -1 on error

 @discussion The BAM record may be partial and empty of existing cigar, seq
 and quality, as is the case during SAM parsing, or it may be an existing
 BAM record in which case this function replaces the existing CIGAR field
 and shuffles data accordingly.  A CIGAR of "*" will remove the CIGAR,
 returning zero.
 */
HTSLIB_EXPORT
ssize_t bam_parse_cigar(const char *in, char **end, bam1_t *b);

/*************************
 *** BAM/CRAM indexing ***
 *************************/

// These BAM iterator functions work only on BAM files.  To work with either
// BAM or CRAM files use the sam_index_load() & sam_itr_*() functions.
#define bam_itr_destroy(iter) hts_itr_destroy(iter)
#define bam_itr_queryi(idx, tid, beg, end) sam_itr_queryi(idx, tid, beg, end)
#define bam_itr_querys(idx, hdr, region) sam_itr_querys(idx, hdr, region)
#define bam_itr_next(htsfp, itr, r) sam_itr_next((htsfp), (itr), (r))

// Load/build .csi or .bai BAM index file.  Does not work with CRAM.
// It is recommended to use the sam_index_* functions below instead.
#define bam_index_load(fn) hts_idx_load((fn), HTS_FMT_BAI)
#define bam_index_build(fn, min_shift) (sam_index_build((fn), (min_shift)))

/// Initialise fp->idx for the current format type for SAM, BAM and CRAM types .
/** @param fp        File handle for the data file being written.
    @param h         Bam header structured (needed for BAI and CSI).
    @param min_shift 0 for BAI, or larger for CSI (CSI defaults to 14).
    @param fnidx     Filename to write index to.  This pointer must remain valid
                     until after sam_idx_save is called.
    @return          0 on success, <0 on failure.

    @note This must be called after the header has been written, but before
          any other data.
*/
HTSLIB_EXPORT
int sam_idx_init(htsFile *fp, sam_hdr_t *h, int min_shift, const char *fnidx);

/// Writes the index initialised with sam_idx_init to disk.
/** @param fp        File handle for the data file being written.
    @return          0 on success, <0 on failure.
*/
HTSLIB_EXPORT
int sam_idx_save(htsFile *fp) HTS_RESULT_USED;

/// Load a BAM (.csi or .bai) or CRAM (.crai) index file
/** @param fp  File handle of the data file whose index is being opened
    @param fn  BAM/CRAM/etc filename to search alongside for the index file
    @return  The index, or NULL if an error occurred.

Equivalent to sam_index_load3(fp, fn, NULL, HTS_IDX_SAVE_REMOTE);
*/
HTSLIB_EXPORT
hts_idx_t *sam_index_load(htsFile *fp, const char *fn);

/// Load a specific BAM (.csi or .bai) or CRAM (.crai) index file
/** @param fp     File handle of the data file whose index is being opened
    @param fn     BAM/CRAM/etc data file filename
    @param fnidx  Index filename, or NULL to search alongside @a fn
    @return  The index, or NULL if an error occurred.

Equivalent to sam_index_load3(fp, fn, fnidx, HTS_IDX_SAVE_REMOTE);
*/
HTSLIB_EXPORT
hts_idx_t *sam_index_load2(htsFile *fp, const char *fn, const char *fnidx);

/// Load or stream a BAM (.csi or .bai) or CRAM (.crai) index file
/** @param fp     File handle of the data file whose index is being opened
    @param fn     BAM/CRAM/etc data file filename
    @param fnidx  Index filename, or NULL to search alongside @a fn
    @param flags  Flags to alter behaviour (see description)
    @return  The index, or NULL if an error occurred.

The @p flags parameter can be set to a combination of the following values:

        HTS_IDX_SAVE_REMOTE   Save a local copy of any remote indexes
        HTS_IDX_SILENT_FAIL   Fail silently if the index is not present

Note that HTS_IDX_SAVE_REMOTE has no effect for remote CRAM indexes.  They
are always downloaded and never cached locally.

The index struct returned by a successful call should be freed
via hts_idx_destroy() when it is no longer needed.
*/
HTSLIB_EXPORT
hts_idx_t *sam_index_load3(htsFile *fp, const char *fn, const char *fnidx,
                           int flags);

/// Generate and save an index file
/** @param fn        Input BAM/etc filename, to which .csi/etc will be added
    @param min_shift Positive to generate CSI, or 0 to generate BAI
    @return  0 if successful, or negative if an error occurred (usually -1; or
             -2: opening fn failed; -3: format not indexable; -4:
             failed to create and/or save the index)
*/
HTSLIB_EXPORT
int sam_index_build(const char *fn, int min_shift) HTS_RESULT_USED;

/// Generate and save an index to a specific file
/** @param fn        Input BAM/CRAM/etc filename
    @param fnidx     Output filename, or NULL to add .bai/.csi/etc to @a fn
    @param min_shift Positive to generate CSI, or 0 to generate BAI
    @return  0 if successful, or negative if an error occurred (see
             sam_index_build for error codes)
*/
HTSLIB_EXPORT
int sam_index_build2(const char *fn, const char *fnidx,
                     int min_shift) HTS_RESULT_USED;

/// Generate and save an index to a specific file
/** @param fn        Input BAM/CRAM/etc filename
    @param fnidx     Output filename, or NULL to add .bai/.csi/etc to @a fn
    @param min_shift Positive to generate CSI, or 0 to generate BAI
    @param nthreads  Number of threads to use when building the index
    @return  0 if successful, or negative if an error occurred (see
             sam_index_build for error codes)
*/
HTSLIB_EXPORT
int sam_index_build3(const char *fn, const char *fnidx, int min_shift,
                     int nthreads) HTS_RESULT_USED;

/// Free a SAM iterator
/// @param iter     Iterator to free
#define sam_itr_destroy(iter) hts_itr_destroy(iter)

/// Create a BAM/CRAM iterator
/** @param idx     Index
    @param tid     Target id
    @param beg     Start position in target
    @param end     End position in target
    @return An iterator on success; NULL on failure

The following special values (defined in htslib/hts.h)can be used for @p tid.
When using one of these values, @p beg and @p end are ignored.

  HTS_IDX_NOCOOR iterates over unmapped reads sorted at the end of the file
  HTS_IDX_START  iterates over the entire file
  HTS_IDX_REST   iterates from the current position to the end of the file
  HTS_IDX_NONE   always returns "no more alignment records"

When using HTS_IDX_REST or HTS_IDX_NONE, NULL can be passed in to @p idx.
 */
HTSLIB_EXPORT
hts_itr_t *sam_itr_queryi(const hts_idx_t *idx, int tid, hts_pos_t beg,
                          hts_pos_t end);

/// Create a SAM/BAM/CRAM iterator
/** @param idx     Index
    @param hdr     Header
    @param region  Region specification
    @return An iterator on success; NULL on failure

Regions are parsed by hts_parse_reg(), and take one of the following forms:

region          | Outputs
--------------- | -------------
REF             | All reads with RNAME REF
REF:            | All reads with RNAME REF
REF:START       | Reads with RNAME REF overlapping START to end of REF
REF:-END        | Reads with RNAME REF overlapping start of REF to END
REF:START-END   | Reads with RNAME REF overlapping START to END
.               | All reads from the start of the file
*               | Unmapped reads at the end of the file (RNAME '*' in SAM)

The form `REF:` should be used when the reference name itself contains a colon.

Note that SAM files must be bgzf-compressed for iterators to work.
 */
HTSLIB_EXPORT
hts_itr_t *sam_itr_querys(const hts_idx_t *idx, sam_hdr_t *hdr,
                          const char *region);

/// Create a multi-region iterator
/** @param idx       Index
    @param hdr       Header
    @param reglist   Array of regions to iterate over
    @param regcount  Number of items in reglist

Each @p reglist entry should have the reference name in the `reg` field, an
array of regions for that reference in `intervals` and the number of items
in `intervals` should be stored in `count`.  No other fields need to be filled
in.

The iterator will return all reads overlapping the given regions.  If a read
overlaps more than one region, it will only be returned once.
 */
HTSLIB_EXPORT
hts_itr_t *sam_itr_regions(const hts_idx_t *idx, sam_hdr_t *hdr,
                           hts_reglist_t *reglist, unsigned int regcount);

/// Create a multi-region iterator
/** @param idx       Index
    @param hdr       Header
    @param regarray  Array of ref:interval region specifiers
    @param regcount  Number of items in regarray

Each @p regarray entry is parsed by hts_parse_reg(), and takes one of the
following forms:

region          | Outputs
--------------- | -------------
REF             | All reads with RNAME REF
REF:            | All reads with RNAME REF
REF:START       | Reads with RNAME REF overlapping START to end of REF
REF:-END        | Reads with RNAME REF overlapping start of REF to END
REF:START-END   | Reads with RNAME REF overlapping START to END
.               | All reads from the start of the file
*               | Unmapped reads at the end of the file (RNAME '*' in SAM)

The form `REF:` should be used when the reference name itself contains a colon.

The iterator will return all reads overlapping the given regions.  If a read
overlaps more than one region, it will only be returned once.
 */
HTSLIB_EXPORT
hts_itr_t *sam_itr_regarray(const hts_idx_t *idx, sam_hdr_t *hdr,
                            char **regarray, unsigned int regcount);

/// Get the next read from a SAM/BAM/CRAM iterator
/** @param htsfp       Htsfile pointer for the input file
    @param itr         Iterator
    @param r           Pointer to a bam1_t struct
    @return >= 0 on success; -1 when there is no more data; < -1 on error
 */
static inline int sam_itr_next(htsFile *htsfp, hts_itr_t *itr, bam1_t *r) {
  if (!htsfp->is_bgzf && !htsfp->is_cram) {
    hts_log_error("%s not BGZF compressed", htsfp->fn ? htsfp->fn : "File");
    return -2;
  }
  if (!itr) {
    hts_log_error("Null iterator");
    return -2;
  }

  if (itr->multi)
    return hts_itr_multi_next(htsfp, itr, r);
  else
    return hts_itr_next(htsfp->is_bgzf ? htsfp->fp.bgzf : NULL, itr, r, htsfp);
}

/// Get the next read from a BAM/CRAM multi-iterator
/** @param htsfp       Htsfile pointer for the input file
    @param itr         Iterator
    @param r           Pointer to a bam1_t struct
    @return >= 0 on success; -1 when there is no more data; < -1 on error
 */
#define sam_itr_multi_next(htsfp, itr, r) sam_itr_next(htsfp, itr, r)

HTSLIB_EXPORT
const char *sam_parse_region(sam_hdr_t *h, const char *s, int *tid,
                             hts_pos_t *beg, hts_pos_t *end, int flags);

/***************
 *** SAM I/O ***
 ***************/

#define sam_open(fn, mode) (hts_open((fn), (mode)))
#define sam_open_format(fn, mode, fmt) (hts_open_format((fn), (mode), (fmt)))
#define sam_flush(fp) hts_flush((fp))
#define sam_close(fp) hts_close(fp)

HTSLIB_EXPORT
int sam_open_mode(char *mode, const char *fn, const char *format);

// A version of sam_open_mode that can handle ,key=value options.
// The format string is allocated and returned, to be freed by the caller.
// Prefix should be "r" or "w",
HTSLIB_EXPORT
char *sam_open_mode_opts(const char *fn, const char *mode, const char *format);

HTSLIB_EXPORT
int sam_hdr_change_HD(sam_hdr_t *h, const char *key, const char *val);

HTSLIB_EXPORT
int sam_parse1(kstring_t *s, sam_hdr_t *h, bam1_t *b) HTS_RESULT_USED;
HTSLIB_EXPORT
int sam_format1(const sam_hdr_t *h, const bam1_t *b,
                kstring_t *str) HTS_RESULT_USED;

/// sam_read1 - Read a record from a file
/** @param fp   Pointer to the source file
 *  @param h    Pointer to the header previously read (fully or partially)
 *  @param b    Pointer to the record placeholder
 *  @return >= 0 on successfully reading a new record, -1 on end of stream, < -1
 * on error
 */
HTSLIB_EXPORT
int sam_read1(samFile *fp, sam_hdr_t *h, bam1_t *b) HTS_RESULT_USED;
/// sam_write1 - Write a record to a file
/** @param fp    Pointer to the destination file
 *  @param h     Pointer to the header structure previously read
 *  @param b     Pointer to the record to be written
 *  @return >= 0 on successfully writing the record, -ve on error
 */
HTSLIB_EXPORT
int sam_write1(samFile *fp, const sam_hdr_t *h,
               const bam1_t *b) HTS_RESULT_USED;

// Forward declaration, see hts_expr.h for full.
struct hts_filter_t;

/// sam_passes_filter - Checks whether a record passes an hts_filter.
/** @param h      Pointer to the header structure previously read
 *  @param b      Pointer to the BAM record to be checked
 *  @param filt   Pointer to the filter, created from hts_filter_init.
 *  @return       1 if passes, 0 if not, and <0 on error.
 */
HTSLIB_EXPORT
int sam_passes_filter(const sam_hdr_t *h, const bam1_t *b,
                      struct hts_filter_t *filt);

/*************************************
 *** Manipulating auxiliary fields ***
 *************************************/

/// Converts a BAM aux tag to SAM format
/*
 * @param key  Two letter tag key
 * @param type Single letter type code: ACcSsIifHZB.
 * @param tag  Tag data pointer, in BAM format
 * @param end  Pointer to end of bam record (largest extent of tag)
 * @param ks   kstring to write the formatted tag to
 *
 * @return pointer to end of tag on success,
 *         NULL on failure.
 *
 * @discussion The three separate parameters key, type, tag may be
 * derived from a s=bam_aux_get() query as s-2, *s and s+1.  However
 * it is recommended to use bam_aux_get_str in this situation.
 * The desire to split these parameters up is for potential processing
 * of non-BAM formats that encode using a BAM type mechanism
 * (such as the internal CRAM representation).
 */
static inline const uint8_t *
sam_format_aux1(const uint8_t *key, const uint8_t type, const uint8_t *tag,
                const uint8_t *end, kstring_t *ks) {
  int r = 0;
  const uint8_t *s = tag; // brevity and consistency with other code.
  r |= kputsn_((char *)key, 2, ks) < 0;
  r |= kputc_(':', ks) < 0;
  if (type == 'C') {
    r |= kputsn_("i:", 2, ks) < 0;
    r |= kputw(*s, ks) < 0;
    ++s;
  } else if (type == 'c') {
    r |= kputsn_("i:", 2, ks) < 0;
    r |= kputw(*(int8_t *)s, ks) < 0;
    ++s;
  } else if (type == 'S') {
    if (end - s >= 2) {
      r |= kputsn_("i:", 2, ks) < 0;
      r |= kputuw(le_to_u16(s), ks) < 0;
      s += 2;
    } else
      goto bad_aux;
  } else if (type == 's') {
    if (end - s >= 2) {
      r |= kputsn_("i:", 2, ks) < 0;
      r |= kputw(le_to_i16(s), ks) < 0;
      s += 2;
    } else
      goto bad_aux;
  } else if (type == 'I') {
    if (end - s >= 4) {
      r |= kputsn_("i:", 2, ks) < 0;
      r |= kputuw(le_to_u32(s), ks) < 0;
      s += 4;
    } else
      goto bad_aux;
  } else if (type == 'i') {
    if (end - s >= 4) {
      r |= kputsn_("i:", 2, ks) < 0;
      r |= kputw(le_to_i32(s), ks) < 0;
      s += 4;
    } else
      goto bad_aux;
  } else if (type == 'A') {
    r |= kputsn_("A:", 2, ks) < 0;
    r |= kputc_(*s, ks) < 0;
    ++s;
  } else if (type == 'f') {
    if (end - s >= 4) {
      // cast to avoid triggering -Wdouble-promotion
      ksprintf(ks, "f:%g", (double)le_to_float(s));
      s += 4;
    } else
      goto bad_aux;

  } else if (type == 'd') {
    // NB: "d" is not an official type in the SAM spec.
    // However for unknown reasons samtools has always supported this.
    // We believe, HOPE, it is not in general usage and we do not
    // encourage it.
    if (end - s >= 8) {
      ksprintf(ks, "d:%g", le_to_double(s));
      s += 8;
    } else
      goto bad_aux;
  } else if (type == 'Z' || type == 'H') {
    r |= kputc_(type, ks) < 0;
    r |= kputc_(':', ks) < 0;
    while (s < end && *s)
      r |= kputc_(*s++, ks) < 0;
    r |= kputsn("", 0, ks) < 0; // ensures NUL termination
    if (s >= end)
      goto bad_aux;
    ++s;
  } else if (type == 'B') {
    uint8_t sub_type = *(s++);
    unsigned sub_type_size;

    // or externalise sam.c's aux_type2size function?
    switch (sub_type) {
    case 'A':
    case 'c':
    case 'C':
      sub_type_size = 1;
      break;
    case 's':
    case 'S':
      sub_type_size = 2;
      break;
    case 'i':
    case 'I':
    case 'f':
      sub_type_size = 4;
      break;
    default:
      sub_type_size = 0;
      break;
    }

    uint32_t i, n;
    if (sub_type_size == 0 || end - s < 4)
      goto bad_aux;
    n = le_to_u32(s);
    s += 4; // now points to the start of the array
    if ((size_t)(end - s) / sub_type_size < n)
      goto bad_aux;
    r |= kputsn_("B:", 2, ks) < 0;
    r |= kputc(sub_type, ks) < 0; // write the type
    switch (sub_type) {
    case 'c':
      if (ks_expand(ks, n * 2) < 0)
        goto mem_err;
      for (i = 0; i < n; ++i) {
        ks->s[ks->l++] = ',';
        r |= kputw(*(int8_t *)s, ks) < 0;
        ++s;
      }
      break;
    case 'C':
      if (ks_expand(ks, n * 2) < 0)
        goto mem_err;
      for (i = 0; i < n; ++i) {
        ks->s[ks->l++] = ',';
        r |= kputuw(*(uint8_t *)s, ks) < 0;
        ++s;
      }
      break;
    case 's':
      if (ks_expand(ks, n * 4) < 0)
        goto mem_err;
      for (i = 0; i < n; ++i) {
        ks->s[ks->l++] = ',';
        r |= kputw(le_to_i16(s), ks) < 0;
        s += 2;
      }
      break;
    case 'S':
      if (ks_expand(ks, n * 4) < 0)
        goto mem_err;
      for (i = 0; i < n; ++i) {
        ks->s[ks->l++] = ',';
        r |= kputuw(le_to_u16(s), ks) < 0;
        s += 2;
      }
      break;
    case 'i':
      if (ks_expand(ks, n * 6) < 0)
        goto mem_err;
      for (i = 0; i < n; ++i) {
        ks->s[ks->l++] = ',';
        r |= kputw(le_to_i32(s), ks) < 0;
        s += 4;
      }
      break;
    case 'I':
      if (ks_expand(ks, n * 6) < 0)
        goto mem_err;
      for (i = 0; i < n; ++i) {
        ks->s[ks->l++] = ',';
        r |= kputuw(le_to_u32(s), ks) < 0;
        s += 4;
      }
      break;
    case 'f':
      if (ks_expand(ks, n * 8) < 0)
        goto mem_err;
      for (i = 0; i < n; ++i) {
        ks->s[ks->l++] = ',';
        // cast to avoid triggering -Wdouble-promotion
        r |= kputd((double)le_to_float(s), ks) < 0;
        s += 4;
      }
      break;
    default:
      goto bad_aux;
    }
  } else { // Unknown type
    goto bad_aux;
  }
  return r ? NULL : s;

bad_aux:
  errno = EINVAL;
  return NULL;

mem_err:
  hts_log_error("Out of memory");
  errno = ENOMEM;
  return NULL;
}

/// Return a pointer to a BAM record's first aux field
/** @param b   Pointer to the BAM record
    @return    Aux field pointer, or NULL if the record has none

When NULL is returned, errno will also be set to ENOENT. ("Aux field pointers"
point to the TYPE byte within the auxiliary data for that field; but in general
it is unnecessary for user code to be aware of this.)
 */
HTSLIB_EXPORT
uint8_t *bam_aux_first(const bam1_t *b);

/// Return a pointer to a BAM record's next aux field
/** @param b   Pointer to the BAM record
    @param s   Aux field pointer, as returned by bam_aux_first()/_next()/_get()
    @return    Pointer to the next aux field, or NULL if no next field or error

Whenever NULL is returned, errno will also be set: ENOENT if @p s was the
record's last aux field; otherwise EINVAL, indicating that the BAM record's
aux data is corrupt.
 */
HTSLIB_EXPORT
uint8_t *bam_aux_next(const bam1_t *b, const uint8_t *s);

/// Return a pointer to an aux record
/** @param b   Pointer to the bam record
    @param tag Desired aux tag
    @return Pointer to the tag data, or NULL if tag is not present or on error
    If the tag is not present, this function returns NULL and sets errno to
    ENOENT.  If the bam record's aux data is corrupt (either a tag has an
    invalid type, or the last record is incomplete) then errno is set to
    EINVAL and NULL is returned.
 */
HTSLIB_EXPORT
uint8_t *bam_aux_get(const bam1_t *b, const char tag[2]);

/// Return the aux field's 2-character tag
/** @param s   Aux field pointer, as returned by bam_aux_first()/_next()/_get()
    @return    Pointer to the tag characters, NOT NUL-terminated
 */
static inline const char *bam_aux_tag(const uint8_t *s) {
  return (const char *)(s - 2);
}

/// Return the aux field's type character
/** @param s   Aux field pointer, as returned by bam_aux_first()/_next()/_get()
    @return    The type character: one of cCsSiI/fd/A/Z/H/B
 */
static inline char bam_aux_type(const uint8_t *s) { return *s; }

/// Return a SAM formatting string containing a BAM tag
/** @param b   Pointer to the bam record
    @param tag Desired aux tag
    @param s   The kstring to write to.

    @return 1 on success,
            0 on no tag found with errno = ENOENT,
           -1 on error (errno will be either EINVAL or ENOMEM).
 */
static inline int bam_aux_get_str(const bam1_t *b, const char tag[2],
                                  kstring_t *s) {
  const uint8_t *t = bam_aux_get(b, tag);
  if (!t)
    return errno == ENOENT ? 0 : -1;

  if (!sam_format_aux1(t - 2, *t, t + 1, b->data + b->l_data, s))
    return -1;

  return 1;
}

/// Get an integer aux value
/** @param s Pointer to the tag data, as returned by bam_aux_get()
    @return The value, or 0 if the tag was not an integer type
    If the tag is not an integer type, errno is set to EINVAL.  This function
    will not return the value of floating-point tags.
*/
HTSLIB_EXPORT
int64_t bam_aux2i(const uint8_t *s);

/// Get a float aux value
/** @param s Pointer to the tag data, as returned by bam_aux_get()
    @return The value, or 0 if the tag was not a float type
    If the tag is not an numeric type, errno is set to EINVAL.  The value of
    the float will be returned cast to a double.
*/
HTSLIB_EXPORT
double bam_aux2f(const uint8_t *s);

/// Get a character aux value
/** @param s Pointer to the tag data, as returned by bam_aux_get().
    @return The value, or 0 if the tag was not a character ('A') type
    If the tag is not a character type, errno is set to EINVAL.
*/
HTSLIB_EXPORT
char bam_aux2A(const uint8_t *s);

/// Get a string aux value
/** @param s Pointer to the tag data, as returned by bam_aux_get().
    @return Pointer to the string, or NULL if the tag was not a string type
    If the tag is not a string type ('Z' or 'H'), errno is set to EINVAL.
*/
HTSLIB_EXPORT
char *bam_aux2Z(const uint8_t *s);

/// Get the length of an array-type ('B') tag
/** @param s Pointer to the tag data, as returned by bam_aux_get().
    @return The length of the array, or 0 if the tag is not an array type.
    If the tag is not an array type, errno is set to EINVAL.
 */
HTSLIB_EXPORT
uint32_t bam_auxB_len(const uint8_t *s);

/// Get an integer value from an array-type tag
/** @param s   Pointer to the tag data, as returned by bam_aux_get().
    @param idx 0-based Index into the array
    @return The idx'th value, or 0 on error.
    If the array is not an integer type, errno is set to EINVAL.  If idx
    is greater than or equal to  the value returned by bam_auxB_len(s),
    errno is set to ERANGE.  In both cases, 0 will be returned.
 */
HTSLIB_EXPORT
int64_t bam_auxB2i(const uint8_t *s, uint32_t idx);

/// Get a floating-point value from an array-type tag
/** @param s   Pointer to the tag data, as returned by bam_aux_get().
    @param idx 0-based Index into the array
    @return The idx'th value, or 0.0 on error.
    If the array is not a numeric type, errno is set to EINVAL.  This can
    only actually happen if the input record has an invalid type field.  If
    idx is greater than or equal to  the value returned by bam_auxB_len(s),
    errno is set to ERANGE.  In both cases, 0.0 will be returned.
 */
HTSLIB_EXPORT
double bam_auxB2f(const uint8_t *s, uint32_t idx);

/// Append tag data to a bam record
/* @param b    The bam record to append to.
   @param tag  Tag identifier
   @param type Tag data type
   @param len  Length of the data in bytes
   @param data The data to append
   @return 0 on success; -1 on failure.
If there is not enough space to store the additional tag, errno is set to
ENOMEM.  If the type is invalid, errno may be set to EINVAL.  errno is
also set to EINVAL if the bam record's aux data is corrupt.
*/
HTSLIB_EXPORT
int bam_aux_append(bam1_t *b, const char tag[2], char type, int len,
                   const uint8_t *data);

/// Delete tag data from a bam record
/** @param b   The BAM record to update
    @param s   Pointer to the aux field to delete, as returned by bam_aux_get()
               Must not be NULL
    @return    0 on success; -1 on failure

If the BAM record's aux data is corrupt, errno is set to EINVAL and this
function returns -1.
*/
HTSLIB_EXPORT
int bam_aux_del(bam1_t *b, uint8_t *s);

/// Delete an aux field from a BAM record
/** @param b   The BAM record to update
    @param s   Pointer to the aux field to delete, as returned by
               bam_aux_first()/_next()/_get(); must not be NULL
    @return    Pointer to the following aux field, or NULL if none or on error

Identical to @c bam_aux_del() apart from the return value, which is an
aux iterator suitable for use with @c bam_aux_next()/etc.

Whenever NULL is returned, errno will also be set: ENOENT if the aux field
deleted was the record's last one; otherwise EINVAL, indicating that the
BAM record's aux data is corrupt.
 */
HTSLIB_EXPORT
uint8_t *bam_aux_remove(bam1_t *b, uint8_t *s);

/// Update or add a string-type tag
/* @param b    The bam record to update
   @param tag  Tag identifier
   @param len  The length of the new string
   @param data The new string
   @return 0 on success, -1 on failure
   This function will not change the ordering of tags in the bam record.
   New tags will be appended to any existing aux records.

   If @p len is less than zero, the length of the input string will be
   calculated using strlen().  Otherwise exactly @p len bytes will be
   copied from @p data to make the new tag.  If these bytes do not
   include a terminating NUL character, one will be added.  (Note that
   versions of HTSlib up to 1.10.2 had different behaviour here and
   simply copied @p len bytes from data.  To generate a valid tag it
   was necessary to ensure the last character was a NUL, and include
   it in @p len.)

   On failure, errno may be set to one of the following values:

   EINVAL: The bam record's aux data is corrupt or an existing tag with the
   given ID is not of type 'Z'.

   ENOMEM: The bam data needs to be expanded and either the attempt to
   reallocate the data buffer failed or the resulting buffer would be
   longer than the maximum size allowed in a bam record (2Gbytes).
*/
HTSLIB_EXPORT
int bam_aux_update_str(bam1_t *b, const char tag[2], int len, const char *data);

/// Update or add an integer tag
/* @param b    The bam record to update
   @param tag  Tag identifier
   @param val  The new value
   @return 0 on success, -1 on failure
   This function will not change the ordering of tags in the bam record.
   New tags will be appended to any existing aux records.

   On failure, errno may be set to one of the following values:

   EINVAL: The bam record's aux data is corrupt or an existing tag with the
   given ID is not of an integer type (c, C, s, S, i or I).

   EOVERFLOW (or ERANGE on systems that do not have EOVERFLOW): val is
   outside the range that can be stored in an integer bam tag (-2147483647
   to 4294967295).

   ENOMEM: The bam data needs to be expanded and either the attempt to
   reallocate the data buffer failed or the resulting buffer would be
   longer than the maximum size allowed in a bam record (2Gbytes).
*/
HTSLIB_EXPORT
int bam_aux_update_int(bam1_t *b, const char tag[2], int64_t val);

/// Update or add a floating-point tag
/* @param b    The bam record to update
   @param tag  Tag identifier
   @param val  The new value
   @return 0 on success, -1 on failure
   This function will not change the ordering of tags in the bam record.
   New tags will be appended to any existing aux records.

   On failure, errno may be set to one of the following values:

   EINVAL: The bam record's aux data is corrupt or an existing tag with the
   given ID is not of a float type.

   ENOMEM: The bam data needs to be expanded and either the attempt to
   reallocate the data buffer failed or the resulting buffer would be
   longer than the maximum size allowed in a bam record (2Gbytes).
*/
HTSLIB_EXPORT
int bam_aux_update_float(bam1_t *b, const char tag[2], float val);

/// Update or add an array tag
/* @param b     The bam record to update
   @param tag   Tag identifier
   @param type  Data type (one of c, C, s, S, i, I or f)
   @param items Number of items
   @param data  Pointer to data
   @return 0 on success, -1 on failure
   The type parameter indicates the how the data is interpreted:

   Letter code | Data type | Item Size (bytes)
   ----------- | --------- | -----------------
   c           | int8_t    | 1
   C           | uint8_t   | 1
   s           | int16_t   | 2
   S           | uint16_t  | 2
   i           | int32_t   | 4
   I           | uint32_t  | 4
   f           | float     | 4

   This function will not change the ordering of tags in the bam record.
   New tags will be appended to any existing aux records.  The bam record
   will grow or shrink in order to accommodate the new data.

   The data parameter must not point to any data in the bam record itself or
   undefined behaviour may result.

   On failure, errno may be set to one of the following values:

   EINVAL: The bam record's aux data is corrupt, an existing tag with the
   given ID is not of an array type or the type parameter is not one of
   the values listed above.

   ENOMEM: The bam data needs to be expanded and either the attempt to
   reallocate the data buffer failed or the resulting buffer would be
   longer than the maximum size allowed in a bam record (2Gbytes).
*/
HTSLIB_EXPORT
int bam_aux_update_array(bam1_t *b, const char tag[2], uint8_t type,
                         uint32_t items, void *data);

/**************************
 *** Pileup and Mpileup ***
 **************************/

#if !defined(BAM_NO_PILEUP)

/*! @typedef
 @abstract Generic pileup 'client data'.

 @discussion The pileup iterator allows setting a constructor and
 destructor function, which will be called every time a sequence is
 fetched and discarded.  This permits caching of per-sequence data in
 a tidy manner during the pileup process.  This union is the cached
 data to be manipulated by the "client" (the caller of pileup).
*/
typedef union {
  void *p;
  int64_t i;
  double f;
} bam_pileup_cd;

/*! @typedef
 @abstract Structure for one alignment covering the pileup position.
 @field  b          pointer to the alignment
 @field  qpos       position of the read base at the pileup site, 0-based
 @field  indel      indel length; 0 for no indel, positive for ins and negative
 for del
 @field  level      the level of the read in the "viewer" mode
 @field  is_del     1 iff the base on the padded read is a deletion
 @field  is_head    1 iff this is the first base in the query sequence
 @field  is_tail    1 iff this is the last base in the query sequence
 @field  is_refskip 1 iff the base on the padded read is part of CIGAR N op
 @field  aux        (used by bcf_call_gap_prep())
 @field  cigar_ind  index of the CIGAR operator that has just been processed

 @discussion See also bam_plbuf_push() and bam_lplbuf_push(). The
 difference between the two functions is that the former does not
 set bam_pileup1_t::level, while the later does. Level helps the
 implementation of alignment viewers, but calculating this has some
 overhead.
 */
typedef struct bam_pileup1_t {
  bam1_t *b;
  int32_t qpos;
  int indel, level;
  uint32_t is_del : 1, is_head : 1, is_tail : 1, is_refskip : 1,
      /* reserved */ : 1, aux : 27;
  bam_pileup_cd cd; // generic per-struct data, owned by caller.
  int cigar_ind;
} bam_pileup1_t;

typedef int (*bam_plp_auto_f)(void *data, bam1_t *b);

struct bam_plp_s;
typedef struct bam_plp_s *bam_plp_t;

struct bam_mplp_s;
typedef struct bam_mplp_s *bam_mplp_t;

/**
 *  bam_plp_init() - sets an iterator over multiple
 *  @func:      see mplp_func in bam_plcmd.c in samtools for an example.
 * Expected return status: 0 on success, -1 on end, < -1 on non-recoverable
 * errors
 *  @data:      user data to pass to @func
 *
 *  The struct returned by a successful call should be freed
 *  via bam_plp_destroy() when it is no longer needed.
 */
HTSLIB_EXPORT
bam_plp_t bam_plp_init(bam_plp_auto_f func, void *data);

HTSLIB_EXPORT
void bam_plp_destroy(bam_plp_t iter);

HTSLIB_EXPORT
int bam_plp_push(bam_plp_t iter, const bam1_t *b);

HTSLIB_EXPORT
const bam_pileup1_t *bam_plp_next(bam_plp_t iter, int *_tid, int *_pos,
                                  int *_n_plp);

HTSLIB_EXPORT
const bam_pileup1_t *bam_plp_auto(bam_plp_t iter, int *_tid, int *_pos,
                                  int *_n_plp);

HTSLIB_EXPORT
const bam_pileup1_t *bam_plp64_next(bam_plp_t iter, int *_tid, hts_pos_t *_pos,
                                    int *_n_plp);

HTSLIB_EXPORT
const bam_pileup1_t *bam_plp64_auto(bam_plp_t iter, int *_tid, hts_pos_t *_pos,
                                    int *_n_plp);

HTSLIB_EXPORT
void bam_plp_set_maxcnt(bam_plp_t iter, int maxcnt);

HTSLIB_EXPORT
void bam_plp_reset(bam_plp_t iter);

/**
 *  bam_plp_constructor() - sets a callback to initialise any per-pileup1_t
 * fields.
 *  @plp:       The bam_plp_t initialised using bam_plp_init.
 *  @func:      The callback function itself.  When called, it is given
 *              the data argument (specified in bam_plp_init), the bam
 *              structure and a pointer to a locally allocated
 *              bam_pileup_cd union.  This union will also be present in
 *              each bam_pileup1_t created.
 *              The callback function should have a negative return
 *              value to indicate an error. (Similarly for destructor.)
 */
HTSLIB_EXPORT
void bam_plp_constructor(bam_plp_t plp, int (*func)(void *data, const bam1_t *b,
                                                    bam_pileup_cd *cd));
HTSLIB_EXPORT
void bam_plp_destructor(bam_plp_t plp, int (*func)(void *data, const bam1_t *b,
                                                   bam_pileup_cd *cd));

/// Get pileup padded insertion sequence
/**
 * @param p       pileup data
 * @param ins     the kstring where the insertion sequence will be written
 * @param del_len location for deletion length
 * @return the length of insertion string on success; -1 on failure.
 *
 * Fills out the kstring with the padded insertion sequence for the current
 * location in 'p'.  If this is not an insertion site, the string is blank.
 *
 * If del_len is not NULL, the location pointed to is set to the length of
 * any deletion immediately following the insertion, or zero if none.
 */
HTSLIB_EXPORT
int bam_plp_insertion(const bam_pileup1_t *p, kstring_t *ins,
                      int *del_len) HTS_RESULT_USED;

/*! @typedef
 @abstract An opaque type used for caching base modification state between
 successive calls to bam_mods_* functions.
*/
typedef struct hts_base_mod_state hts_base_mod_state;

/// Get pileup padded insertion sequence, including base modifications
/**
 * @param p       pileup data
 * @param m       state data for the base modification finder
 * @param ins     the kstring where the insertion sequence will be written
 * @param del_len location for deletion length
 * @return the number of insertion string on success, with string length
 *         being accessable via ins->l; -1 on failure.
 *
 * Fills out the kstring with the padded insertion sequence for the current
 * location in 'p'.  If this is not an insertion site, the string is blank.
 *
 * The modification state needs to have been previously initialised using
 * bam_parse_basemod.  It is permitted to be passed in as NULL, in which
 * case this function outputs identically to bam_plp_insertion.
 *
 * If del_len is not NULL, the location pointed to is set to the length of
 * any deletion immediately following the insertion, or zero if none.
 */
HTSLIB_EXPORT
int bam_plp_insertion_mod(const bam_pileup1_t *p, hts_base_mod_state *m,
                          kstring_t *ins, int *del_len) HTS_RESULT_USED;

/// Create a new bam_mplp_t structure
/** The struct returned by a successful call should be freed
 *  via bam_mplp_destroy() when it is no longer needed.
 */
HTSLIB_EXPORT
bam_mplp_t bam_mplp_init(int n, bam_plp_auto_f func, void **data);

/// Set up mpileup overlap detection
/**
 * @param iter    mpileup iterator
 * @return 0 on success; a negative value on error
 *
 *  If called, mpileup will detect overlapping
 *  read pairs and for each base pair set the base quality of the
 *  lower-quality base to zero, thus effectively discarding it from
 *  calling. If the two bases are identical, the quality of the other base
 *  is increased to the sum of their qualities (capped at 200), otherwise
 *  it is multiplied by 0.8.
 */
HTSLIB_EXPORT
int bam_mplp_init_overlaps(bam_mplp_t iter);

HTSLIB_EXPORT
void bam_mplp_destroy(bam_mplp_t iter);

HTSLIB_EXPORT
void bam_mplp_set_maxcnt(bam_mplp_t iter, int maxcnt);

HTSLIB_EXPORT
int bam_mplp_auto(bam_mplp_t iter, int *_tid, int *_pos, int *n_plp,
                  const bam_pileup1_t **plp);

HTSLIB_EXPORT
int bam_mplp64_auto(bam_mplp_t iter, int *_tid, hts_pos_t *_pos, int *n_plp,
                    const bam_pileup1_t **plp);

HTSLIB_EXPORT
void bam_mplp_reset(bam_mplp_t iter);

HTSLIB_EXPORT
void bam_mplp_constructor(bam_mplp_t iter,
                          int (*func)(void *data, const bam1_t *b,
                                      bam_pileup_cd *cd));

HTSLIB_EXPORT
void bam_mplp_destructor(bam_mplp_t iter,
                         int (*func)(void *data, const bam1_t *b,
                                     bam_pileup_cd *cd));

#endif // ~!defined(BAM_NO_PILEUP)

/***********************************
 * BAQ calculation and realignment *
 ***********************************/

HTSLIB_EXPORT
int sam_cap_mapq(bam1_t *b, const char *ref, hts_pos_t ref_len, int thres);

// Used as flag parameter in sam_prob_realn.
enum htsRealnFlags {
  BAQ_APPLY = 1,
  BAQ_EXTEND = 2,
  BAQ_REDO = 4,

  // Platform subfield, in bit position 3 onwards
  BAQ_AUTO = 0 << 3,
  BAQ_ILLUMINA = 1 << 3,
  BAQ_PACBIOCCS = 2 << 3,
  BAQ_PACBIO = 3 << 3,
  BAQ_ONT = 4 << 3,
  BAQ_GENAPSYS = 5 << 3
};

/// Calculate BAQ scores
/** @param b   BAM record
    @param ref     Reference sequence
    @param ref_len Reference sequence length
    @param flag    Flags, see description
    @return 0 on success \n
           -1 if the read was unmapped, zero length, had no quality values, did
not have at least one M, X or = CIGAR operator, or included a reference skip. \n
           -3 if BAQ alignment has already been done and does not need to be
applied, or has already been applied. \n -4 if alignment failed (most likely due
to running out of memory)

This function calculates base alignment quality (BAQ) values using the method
described in "Improving SNP discovery by base alignment quality", Heng Li,
Bioinformatics, Volume 27, Issue 8
(https://doi.org/10.1093/bioinformatics/btr076).

The @param flag value can be generated using the htsRealnFlags enum, but for
backwards compatibilty reasons is retained as an "int".  An example usage
of the enum could be this, equivalent to flag 19:

    sam_prob_realn(b, ref, len, BAQ_APPLY | BAQ_EXTEND | BAQ_PACBIOCCS);

The following @param flag bits can be used:

Bit 0 (BAQ_APPLY): Adjust the quality values using the BAQ values

 If set, the data in the BQ:Z tag is used to adjust the quality values, and
 the BQ:Z tag is renamed to ZQ:Z.

 If clear, and a ZQ:Z tag is present, the quality values are reverted using
 the data in the tag, and the tag is renamed to BQ:Z.

Bit 1 (BAQ_EXTEND): Use "extended" BAQ.

 Changes the BAQ calculation to increase sensitivity at the expense of
 reduced specificity.

Bit 2 (BAQ_REDO): Recalculate BAQ, even if a BQ tag is present.

 Force BAQ to be recalculated.  Note that a ZQ:Z tag will always disable
 recalculation.

Bits 3-10: Choose parameters tailored to a specific instrument type.

 One of BAQ_AUTO, BAQ_ILLUMINA, BAQ_PACBIOCCS, BAQ_PACBIO, BAQ_ONT and
 BAQ_GENAPSYS.  The BAQ parameter tuning are still a work in progress and
 at the time of writing mainly consist of Illumina vs long-read technology
 adjustments.

@bug
If the input read has both BQ:Z and ZQ:Z tags, the ZQ:Z one will be removed.
Depending on what previous processing happened, this may or may not be the
correct thing to do.  It would be wise to avoid this situation if possible.
*/
HTSLIB_EXPORT
int sam_prob_realn(bam1_t *b, const char *ref, hts_pos_t ref_len, int flag);

// ---------------------------
// Base modification retrieval

/*! @typedef
 @abstract Holds a single base modification.
 @field modified_base     The short base code (m, h, etc) or -ChEBI (negative)
 @field canonical_base    The canonical base referred to in the MM tag.
                          One of A, C, G, T or N.  Note this may not be the
                          explicit base recorded in the SEQ column (esp. if N).
 @field strand            0 or 1, indicating + or - strand from MM tag.
 @field qual              Quality code (256*probability), or -1 if unknown

 @discussion
 Note this doesn't hold any location data or information on which other
 modifications may be possible at this site.
*/
typedef struct hts_base_mod {
  int modified_base;
  int canonical_base;
  int strand;
  int qual;
} hts_base_mod;

#define HTS_MOD_UNKNOWN -1   // In MM but not ML
#define HTS_MOD_UNCHECKED -2 // Not in MM and in explicit mode

// Flags for bam_parse_basemod2
#define HTS_MOD_REPORT_UNCHECKED 1

/// Allocates an hts_base_mod_state.
/**
 * @return An hts_base_mod_state pointer on success,
 *         NULL on failure.
 *
 * This just allocates the memory.  The initialisation of the contents is
 * done using bam_parse_basemod.  Successive calls may be made to that
 * without the need to free and allocate a new state.
 *
 * The state be destroyed using the hts_base_mod_state_free function.
 */
HTSLIB_EXPORT
hts_base_mod_state *hts_base_mod_state_alloc(void);

/// Destroys an  hts_base_mod_state.
/**
 * @param state    The base modification state pointer.
 *
 * The should have previously been created by hts_base_mod_state_alloc.
 */
HTSLIB_EXPORT
void hts_base_mod_state_free(hts_base_mod_state *state);

/// Parses the MM and ML tags out of a bam record.
/**
 * @param b        BAM alignment record
 * @param state    The base modification state pointer.
 * @return 0 on success,
 *         -1 on failure.
 *
 * This fills out the contents of the modification state, resetting the
 * iterator location to the first sequence base.
 * (Parses the draft Mm/Ml tags instead if MM and/or ML are not present.)
 */
HTSLIB_EXPORT
int bam_parse_basemod(const bam1_t *b, hts_base_mod_state *state);

/// Parses the MM and ML tags out of a bam record.
/**
 * @param b        BAM alignment record
 * @param state    The base modification state pointer.
 * @param flags    A bit-field controlling base modification processing
 *
 * @return 0 on success,
 *         -1 on failure.
 *
 * This fills out the contents of the modification state, resetting the
 * iterator location to the first sequence base.
 * (Parses the draft Mm/Ml tags instead if MM and/or ML are not present.)
 */
HTSLIB_EXPORT
int bam_parse_basemod2(const bam1_t *b, hts_base_mod_state *state,
                       uint32_t flags);

/// Returns modification status for the next base position in the query seq.
/**
 * @param b        BAM alignment record
 * @param state    The base modification state pointer.
 * @param mods     A supplied array for returning base modifications
 * @param n_mods   The size of the mods array
 * @return The number of modifications found on success,
 *         -1 on failure.
 *
 * This is intended to be used as an iterator, with one call per location
 * along the query sequence.
 *
 * If no modifications are found, the returned value is zero.
 * If more than n_mods modifications are found, the total found is returned.
 * Note this means the caller needs to check whether this is higher than
 * n_mods.
 */
HTSLIB_EXPORT
int bam_mods_at_next_pos(const bam1_t *b, hts_base_mod_state *state,
                         hts_base_mod *mods, int n_mods);

/// Finds the next location containing base modifications and returns them
/**
 * @param b        BAM alignment record
 * @param state    The base modification state pointer.
 * @param mods     A supplied array for returning base modifications
 * @param n_mods   The size of the mods array
 * @param pos      Pointer holding position of modification in sequence
 * @return The number of modifications found on success,
 *         0 if no more modifications are present,
 *         -1 on failure.
 *
 * Unlike bam_mods_at_next_pos this skips ahead to the next site
 * with modifications.
 *
 * If more than n_mods modifications are found, the total found is returned.
 * Note this means the caller needs to check whether this is higher than
 * n_mods.
 */
HTSLIB_EXPORT
int bam_next_basemod(const bam1_t *b, hts_base_mod_state *state,
                     hts_base_mod *mods, int n_mods, int *pos);

/// Returns modification status for a specific query position.
/**
 * @param b        BAM alignment record
 * @param state    The base modification state pointer.
 * @param mods     A supplied array for returning base modifications
 * @param n_mods   The size of the mods array
 * @return The number of modifications found on success,
 *         -1 on failure.
 *
 * Note if called multipled times, qpos must be higher than the previous call.
 * Hence this is suitable for use from a pileup iterator.  If more random
 * access is required, bam_parse_basemod must be called each time to reset
 * the state although this has an efficiency cost.
 *
 * If no modifications are found, the returned value is zero.
 * If more than n_mods modifications are found, the total found is returned.
 * Note this means the caller needs to check whether this is higher than
 * n_mods.
 */
HTSLIB_EXPORT
int bam_mods_at_qpos(const bam1_t *b, int qpos, hts_base_mod_state *state,
                     hts_base_mod *mods, int n_mods);

/// Returns data about a specific modification type for the alignment record.
/**
 * @param b          BAM alignment record
 * @param state      The base modification state pointer.
 * @param code       Modification code.  If positive this is a character code,
 *                   if negative it is a -ChEBI code.
 *
 * @param strand     Boolean for top (0) or bottom (1) strand
 * @param implicit   Boolean for whether unlisted positions should be
 *                   implicitly assumed to be unmodified, or require an
 *                   explicit score and should be considered as unknown.
 *                   Returned.
 * @param canonical  Canonical base type associated with this modification
 *                   Returned.
 *
 * @return 0 on success or -1 if not found.  The strand, implicit and canonical
 * fields are filled out if passed in as non-NULL pointers.
 */
HTSLIB_EXPORT
int bam_mods_query_type(hts_base_mod_state *state, int code, int *strand,
                        int *implicit, char *canonical);

/// Returns data about the i^th modification type for the alignment record.
/**
 * @param b          BAM alignment record
 * @param state      The base modification state pointer.
 * @param i          Modification index, from 0 to ntype-1
 * @param strand     Boolean for top (0) or bottom (1) strand
 * @param implicit   Boolean for whether unlisted positions should be
 *                   implicitly assumed to be unmodified, or require an
 *                   explicit score and should be considered as unknown.
 *                   Returned.
 * @param canonical  Canonical base type associated with this modification
 *                   Returned.
 *
 * @return 0 on success or -1 if not found.  The strand, implicit and canonical
 * fields are filled out if passed in as non-NULL pointers.
 */
HTSLIB_EXPORT
int bam_mods_queryi(hts_base_mod_state *state, int i, int *strand,
                    int *implicit, char *canonical);

/// Returns the list of base modification codes provided for this
/// alignment record as an array of character codes (+ve) or ChEBI numbers
/// (negative).
/*
 * @param b          BAM alignment record
 * @param state      The base modification state pointer.
 * @param ntype      Filled out with the number of array elements returned
 *
 * @return the type array, with *ntype filled out with the size.
 *         The array returned should not be freed.
 *         It is a valid pointer until the state is freed using
 *         hts_base_mod_free().
 */
HTSLIB_EXPORT
int *bam_mods_recorded(hts_base_mod_state *state, int *ntype);

// Sets the header to the file
/**
 * @param fp         File to which header to be set
 * @param h          Header to be set
 * @param dup        Whether to use duplicated header (1) or not (0)
 *
 * @return -1 on error and 0 on success
 * Existing header will be destroyed, thr' sam_hdr_destroy, and new one is set.
 * When header is set directly (dup=0), the reference count is incremented.
 */
HTSLIB_EXPORT
int sam_hdr_set(samFile *fp, sam_hdr_t *h, int dup);

// Get the header from the file pointer
/**
 * @param fp         File pointer from which header to be retrieved
 * @return pointer to header or NULL
 * For a valid file pointer, the returned header could be NULL when the header
 * is not read yet. sam_hdr_incr_ref has to be invoked where ever apropriate.
 */
HTSLIB_EXPORT
sam_hdr_t *sam_hdr_get(samFile *fp);

#ifdef __cplusplus
}
#endif

#ifdef HTSLIB_SSIZE_T
#undef HTSLIB_SSIZE_T
#undef ssize_t
#endif

#endif
