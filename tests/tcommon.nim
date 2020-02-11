## Copyright 2019 Ulf Adams
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

import std/unittest

import ryu/common

suite "common test":
  test "decimal_length9":
    check 1'u == decimalLength9(0)
    check 1'u == decimalLength9(1)
    check 1'u == decimalLength9(9)
    check 2'u == decimalLength9(10)
    check 2'u == decimalLength9(99)
    check 3'u == decimalLength9(100)
    check 3'u == decimalLength9(999)
    check 9'u == decimalLength9(999_999_999)

  test "ceil_log2pow5":
    check 1 == ceil_log2pow5(0)
    check 3 == ceil_log2pow5(1)
    check 5 == ceil_log2pow5(2)
    check 7 == ceil_log2pow5(3)
    check 10 == ceil_log2pow5(4)
    check 8192 == ceil_log2pow5(3528)

  test "log10pow2":
    check 0'u == log10Pow2(0)
    check 0'u == log10Pow2(1)
    check 0'u == log10Pow2(2)
    check 0'u == log10Pow2(3)
    check 1'u == log10Pow2(4)
    check 496'u == log10Pow2(1650)

  test "log10pow5":
    check 0'u == log10Pow5(0)
    check 0'u == log10Pow5(1)
    check 1'u == log10Pow5(2)
    check 2'u == log10Pow5(3)
    check 2'u == log10Pow5(4)
    check 1831'u == log10Pow5(2620)

  test "copy_special_str":
    var
      buffer: string
    check 3 == copySpecialStr(buffer, false, false, true)
    check "NaN" == buffer
    buffer = ""

    check 8 == copySpecialStr(buffer, false, true, false)
    check "Infinity" == buffer
    buffer = ""

    check 9 == copySpecialStr(buffer, true, true, false)
    check "-Infinity" == buffer
    buffer = ""

    check 4 == copySpecialStr(buffer, true, false, false)
    check "-0E0" == buffer
    buffer = ""

  test "float_to_bits":
    check 0'u32 == floatToBits(0.0'f32)
    check 0x40490fda'u32 == floatToBits(3.1415926'f32)

  test "double_to_bits":
    check 0'u64 == doubleToBits(0.0'f64)
    check 0x400921FB54442D18'u64 == doubleToBits(3.1415926535897932384626433'f64)
