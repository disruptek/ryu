## Copyright 2018 Ulf Adams
##
## The contents of this file may be used under the terms of the Apache License,
## Version 2.0.
##
##    (See accompanying file LICENSE-Apache or copy at
##     http://www.apache.org/licenses/LICENSE-2.0)
##
## Alternatively, the contents of this file may be used under the terms of
## the Boost Software License, Version 1.0.
##    (See accompanying file LICENSE-Boost or copy at
##     https://www.boost.org/LICENSE_1_0.txt)
##
## Unless required by applicable law or agreed to in writing, this software
## is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
## KIND, either express or implied.

import std/strutils

#[

FIXME: define this if'en we needs it

#if defined(_M_IX86) || defined(_M_ARM)
#define RYU_32_BIT_PLATFORM
#endif

]#

proc decimalLength9*(v: uint32): uint32 {.inline.} =
  ## Returns the number of decimal digits in v,
  ## which must not contain more than 9 digits.
  ## Function precondition: v is not a 10-digit number.
  # (f2s: 9 digits are sufficient for round-tripping.)
  # (d2fixed: We print 9-digit blocks.)
  assert v < 1_000_000_000'u32
  if (v >= 100_000_000'u32): return 9
  if (v >= 10_000_000'u32): return 8
  if (v >= 1_000_000'u32): return 7
  if (v >= 100_000'u32): return 6
  if (v >= 10_000'u32): return 5
  if (v >= 1_000'u32): return 4
  if (v >= 100'u32): return 3
  if (v >= 10'u32): return 2
  return 1'u32

proc log2Pow5*(e: int32): int32 {.inline.} =
  ## Returns e == 0 ? 1 : [log_2(5^e)]; requires 0 <= e <= 3528.
  ## This approximation works up to the point that the multiplication
  ## overflows at e = 3529.  If the multiplication were done in 64 bits,
  ## it would fail at 5^4004 which is just greater than 2^9297.
  assert e >= 0
  assert e <= 3_528
  return ((e.uint32 * 1_217_359'u32) shr 19).int32

proc pow5Bits*(e: int32): int32 {.inline.} =
  ## Returns e == 0 ? 1 : ceil(log_2(5^e)); requires 0 <= e <= 3528.
  ## This approximation works up to the point that the multiplication
  ## overflows at e = 3529.  If the multiplication were done in 64 bits,
  ## it would fail at 5^4004 which is just greater than 2^9297.
  assert e >= 0
  assert e <= 3_528
  return int32((e.uint32 * 1_217_359) shr 19) + 1

proc ceilLog2Pow5*(e: int32): int32 {.inline.} =
  ## Returns e == 0 ? 1 : ceil(log_2(5^e)); requires 0 <= e <= 3528.
  return log2Pow5(e) + 1

proc log10Pow2*(e: int32): uint32 {.inline.} =
  ## Returns floor(log_10(2^e)); requires 0 <= e <= 1650.
  ## The first value this approximation fails for is 2^1651
  ## which is just greater than 10^297.
  assert e >= 0
  assert e <= 1650
  return (e.uint32 * 78913) shr 18

proc log10Pow5*(e: int32): uint32 {.inline.} =
  ## Returns floor(log_10(5^e)); requires 0 <= e <= 2620.
  ## The first value this approximation fails for is 5^2621
  ## which is just greater than 10^1832.
  assert e >= 0
  assert e <= 2620
  return (e.uint32 * 732923) shr 20

proc specialStr*(sign, exponent, mantissa: bool): string {.inline.} =
  if mantissa:
    result = "NaN"
  elif exponent:
    result = if sign: "-Infinity" else: "Infinity"
  else:
    result = if sign: "-0E0" else: "0E0"

proc copySpecialStr*(buff: var string; sign, exponent, mantissa: bool): int =
  buff = specialStr(sign, exponent, mantissa)
  result = buff.len

proc floatToBits*(f: float32): uint32 {.inline.} =
  copyMem(addr result, unsafeAddr f, sizeof(float32))
  when defined(ryuDebug):
    echo f, " floatToBits ", result.BiggestInt.toBin(32)

proc doubleToBits*(f: float64): uint64 {.inline.} =
  copyMem(addr result, unsafeAddr f, sizeof(float64))
  when defined(ryuDebug):
    echo f, " doubleToBits ", result.BiggestInt.toBin(64)
