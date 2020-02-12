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
  test "basic":
    ASSERT_F2S("0e0", 0.0)
    ASSERT_F2S("-0e0", -0.0)
    ASSERT_F2S("1e0", 1.0)
    ASSERT_F2S("-1e0", -1.0)
    ASSERT_F2S("nan", NAN)
    ASSERT_F2S("inf", 0.3 / 0.0)
    ASSERT_F2S("-inf", -0.3 / 0.0)


  test "switch to subnormal":
    ASSERT_F2S("1.1754944e-38", 1.1754944e-38f)

  test "min and max":
    ASSERT_F2S("3.4028235e38", int32Bits2Float(0x7f7fffff))
    ASSERT_F2S("1e-45", int32Bits2Float(1))

  # Check that we return the exact boundary if it is the shortest
  # representation, but only if the original floating point number is even.
  test "boundary round even":
    ASSERT_F2S("3.355445e7", 3.355445e7f)
    ASSERT_F2S("9e9", 8.999999e9f)
    ASSERT_F2S("3.436672e10", 3.4366717e10f)

  # If the exact value is exactly halfway between two shortest representations,
  # then we round to even. It seems like this only makes a difference if the
  # last two digits are ...2|5 or ...7|5, and we cut off the 5.
  test "extract value round even":
    ASSERT_F2S("3.0540412e5", 3.0540412e5f)
    ASSERT_F2S("8.0990312e3", 8.0990312e3f)

  test "lots of trailing zeros":
    # Pattern for the first test: 00111001100000000000000000000000
    ASSERT_F2S("2.4414062e-4", 2.4414062e-4f)
    ASSERT_F2S("2.4414062e-3", 2.4414062e-3f)
    ASSERT_F2S("4.3945312e-3", 4.3945312e-3f)
    ASSERT_F2S("6.3476562e-3", 6.3476562e-3f)

  test "regression":
    ASSERT_F2S("4.7223665e21", 4.7223665e21f)
    ASSERT_F2S("8.388608e6", 8388608.0f)
    ASSERT_F2S("1.6777216e7", 1.6777216e7f)
    ASSERT_F2S("3.3554436e7", 3.3554436e7f)
    ASSERT_F2S("6.7131496e7", 6.7131496e7f)
    ASSERT_F2S("1.9310392e-38", 1.9310392e-38f)
    ASSERT_F2S("-2.47e-43", -2.47e-43f)
    ASSERT_F2S("1.993244e-38", 1.993244e-38f)
    ASSERT_F2S("4.1039004e3", 4103.9003f)
    ASSERT_F2S("5.3399997e9", 5.3399997e9f)
    ASSERT_F2S("6.0898e-39", 6.0898e-39f)
    ASSERT_F2S("1.0310042e-3", 0.0010310042f)
    ASSERT_F2S("2.882326e17", 2.8823261e17f)

  test "looks like pow5":
    ## These numbers have a mantissa that is the largest power of 5 that fits,
    ## and an exponent that causes the computation for q to result in 10,
    ## which is a corner case for Ryu.
    ASSERT_F2S("6.7108864e17", int32Bits2Float(0x5D1502F9))
    ASSERT_F2S("1.3421773e18", int32Bits2Float(0x5D9502F9))
    ASSERT_F2S("2.6843546e18", int32Bits2Float(0x5E1502F9))

  test "output length":
    ASSERT_F2S("1e0", 1.0f) # already tested in Basic
    ASSERT_F2S("1.2e0", 1.2f)
    ASSERT_F2S("1.23e0", 1.23f)
    ASSERT_F2S("1.234e0", 1.234f)
    ASSERT_F2S("1.2345e0", 1.2345f)
    ASSERT_F2S("1.23456e0", 1.23456f)
    ASSERT_F2S("1.234567e0", 1.234567f)
    ASSERT_F2S("1.2345678e0", 1.2345678f)
    ASSERT_F2S("1.23456735e-36", 1.23456735e-36f)

  test "multiple f2s on same output string":
    var ret: string
    ret.f2s 1.0
    ret.add "|"
    ret.f2s 2.0
    check ret == "1e0|2e0"
