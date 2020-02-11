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

import std/unittest

import ryu

proc int32Bits2Float(bits: uint32): float32 =
  copyMem(addr result, unsafeAddr bits, sizeof(float32))

# i got lazy
template ASSERT_F2S(s: string; f: float | float32 | float64) =
  check f2s(f) == s

suite "float to string":
  test "really basic":
    check f2s(0.0'f32) == "0E0"
    check f2s(-0.0'f32) == "-0E0"
    check f2s(0.0 / 0.0) == "NaN"
    check f2s(0.3 / 0.0) == "Infinity"
    check f2s(-0.3 / 0.0) == "-Infinity"
    ASSERT_F2S("0E0", 0.0)
    ASSERT_F2S("-0E0", -0.0)

  test "basically broken":
    ASSERT_F2S("1E0", 1.0)

  test "basic":
    ASSERT_F2S("-1E0", -1.0)
    ASSERT_F2S("NaN", NAN)
    ASSERT_F2S("Infinity", 0.3 / 0.0)
    ASSERT_F2S("-Infinity", -0.3 / 0.0)


  test "switch to subnormal":
    check f2s(1.1754944E-38'f32) == "1.1754944E-38"
    ASSERT_F2S("1.1754944E-38", 1.1754944E-38f)

  test "min and max":
    check int32Bits2Float(0x7f7fffff).f2s == "3.4028235E38"
    check int32Bits2Float(1).f2s == "1E-45"
    ASSERT_F2S("3.4028235E38", int32Bits2Float(0x7f7fffff))
    ASSERT_F2S("1E-45", int32Bits2Float(1))

  # Check that we return the exact boundary if it is the shortest
  # representation, but only if the original floating point number is even.
  test "boundary round even":
    check f2s(3.355445E7) == "3.355445E7"
    check f2s(8.999999E9) == "9E9"
    check f2s(3.4366717E10) == "3.436672E10"
    ASSERT_F2S("3.355445E7", 3.355445E7f)
    ASSERT_F2S("9E9", 8.999999E9f)
    ASSERT_F2S("3.436672E10", 3.4366717E10f)

  # If the exact value is exactly halfway between two shortest representations,
  # then we round to even. It seems like this only makes a difference if the
  # last two digits are ...2|5 or ...7|5, and we cut off the 5.
  test "extract value round even":
    check f2s(3.0540412E5) == "3.0540412E5"
    check f2s(8.0990312E3) == "8.0990312E3"
    ASSERT_F2S("3.0540412E5", 3.0540412E5f)
    ASSERT_F2S("8.0990312E3", 8.0990312E3f)

  test "lots of trailing zeros":
    # Pattern for the first test: 00111001100000000000000000000000
    check f2s(2.4414062E-4) == "2.4414062E-4"
    check f2s(2.4414062E-3) == "2.4414062E-3"
    check f2s(4.3945312E-3) == "4.3945312E-3"
    check f2s(6.3476562E-3) == "6.3476562E-3"
    ASSERT_F2S("2.4414062E-4", 2.4414062E-4f)
    ASSERT_F2S("2.4414062E-3", 2.4414062E-3f)
    ASSERT_F2S("4.3945312E-3", 4.3945312E-3f)
    ASSERT_F2S("6.3476562E-3", 6.3476562E-3f)

  test "regression":
    ASSERT_F2S("4.7223665E21", 4.7223665E21f)
    ASSERT_F2S("8.388608E6", 8388608.0f)
    ASSERT_F2S("1.6777216E7", 1.6777216E7f)
    ASSERT_F2S("3.3554436E7", 3.3554436E7f)
    ASSERT_F2S("6.7131496E7", 6.7131496E7f)
    ASSERT_F2S("1.9310392E-38", 1.9310392E-38f)
    ASSERT_F2S("-2.47E-43", -2.47E-43f)
    ASSERT_F2S("1.993244E-38", 1.993244E-38f)
    ASSERT_F2S("4.1039004E3", 4103.9003f)
    ASSERT_F2S("5.3399997E9", 5.3399997E9f)
    ASSERT_F2S("6.0898E-39", 6.0898E-39f)
    ASSERT_F2S("1.0310042E-3", 0.0010310042f)
    ASSERT_F2S("2.882326E17", 2.8823261E17f)

  test "looks like pow5":
    ## These numbers have a mantissa that is the largest power of 5 that fits,
    ## and an exponent that causes the computation for q to result in 10,
    ## which is a corner case for Ryu.
    ASSERT_F2S("6.7108864E17", int32Bits2Float(0x5D1502F9))
    ASSERT_F2S("1.3421773E18", int32Bits2Float(0x5D9502F9))
    ASSERT_F2S("2.6843546E18", int32Bits2Float(0x5E1502F9))

  test "output length":
    ASSERT_F2S("1E0", 1.0f) # already tested in Basic
    ASSERT_F2S("1.2E0", 1.2f)
    ASSERT_F2S("1.23E0", 1.23f)
    ASSERT_F2S("1.234E0", 1.234f)
    ASSERT_F2S("1.2345E0", 1.2345f)
    ASSERT_F2S("1.23456E0", 1.23456f)
    ASSERT_F2S("1.234567E0", 1.234567f)
    ASSERT_F2S("1.2345678E0", 1.2345678f)
    ASSERT_F2S("1.23456735E-36", 1.23456735E-36f)
