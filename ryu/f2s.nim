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
##
## Runtime compiler options:
## -DRYU_DEBUG Generate verbose debugging output to stdout.

import std/strutils

import ryu/common
import ryu/digit_table

when defined(ryuFloatFullTable):
  include ryu/f2s_full_table
else:
  when defined(ryuOptimizeSize):
    include ryu/d2s_small_table
  else:
    include ryu/d2s_full_table
  const
    ryuFloatPow5InvBitCount* = ryuDoublePow5InvBitCount - 64
    ryuFloatPow5BitCount* = ryuDoublePow5BitCount - 64

const
  ryuFloatMantissaBits* = 23
  ryuFloatMantissaBitMask* = 0b00000000011111111111111111111111
  ryuFloatExponentBits* = 8
  ryuFloatExponentBitMask* = 0b011111111
  ryuFloatBias* = 127

type
  ## A floating decimal representing m * 10^e.
  FloatingDecimal32 = object
    mantissa: uint32
    ## Decimal exponent's range is -45 to 38
    ## inclusive, and can fit in a short if needed.
    exponent: int32

proc pow5Factor32*(value: uint32): uint32 {.inline.} =
  var
    value = value
  while true:
    assert value != 0'u32
    let
      q = value div 5
      r = value mod 5
    if r != 0:
      break
    value = q
    result.inc

proc multipleOfPowerOf5_32*(value: uint32; p: uint32): bool {.inline.} =
  ## Returns true if value is divisible by 5^p.
  result = pow5Factor32(value) >= p

proc multipleOfPowerOf2_32*(value: uint32; p: uint32): bool {.inline.} =
  ## Returns true if value is divisible by 2^p.
  # __builtin_ctz doesn't appear to be faster here.
  result = (value and ((1'u32 shl p) - 1)) == 0

proc mulShift32*(m: uint32; factor: uint64; shift: int32): uint32 {.inline.} =
  ## It seems to be slightly faster to avoid uint128_t here, although the
  ## generated code for uint128_t looks slightly nicer.
  assert shift > 32

  ## The casts here help MSVC to avoid calls to the __allmul library
  ## function.
  let
    factorLo: uint32 = uint32(factor)
    factorHi: uint32 = uint32(factor shr 32)
    bits0: uint64 = m.uint64 * factorLo
    bits1: uint64 = m.uint64 * factorHi
  when defined(ryuDebug):
    echo "m: $# factor: $# shift: $#" % [$m, $factor, $shift]
    echo "factorLo $# factorHi $# bits0 $# bits1 $# " % [$factorLo, $factorHi, $bits0, $bits1]

  when defined(ryu32BitPlatform):
    # On 32-bit platforms we can avoid a 64-bit shift-right since we only
    # need the upper 32 bits of the result and the shift value is > 32.
    let
      s: int32 = shift - 32
      bits0Hi: uint32 = uint32(bits0 shr 32)
    var
      bits1Lo: uint32 = uint32(bits1)
      bits1Hi: uint32 = uint32(bits1 shr 32)
    bits1Lo += bits0Hi
    if bits1Lo < bits0Hi:
      bits1Hi.inc
    result = (bits1Hi shl (32 - s)) or (bits1Lo shr s)
  else:
    # This is a 64-bit platform...
    let
      sum: uint64 = (bits0 shr 32) + bits1
      shiftedSum: uint64 = sum shr (shift - 32)
    assert shiftedSum <= uint32.high
    result = shiftedSum.uint32

proc mulPow5InvDivPow2*(m: uint32; q: uint32; j: int32): uint32 {.inline.} =
  when defined(ryuFloatFullTable):
    result = mulShift32(m, ryuFloatPow5InvSplit[q], j)
  elif defined(ryuOptimizeSize):
    # The inverse multipliers are defined as [2^x / 5^y] + 1; the upper 64
    # bits from the double lookup table are the correct bits for [2^x /
    # 5^y], so we have to add 1 here. Note that we rely on the fact that
    # the added 1 that's already stored in the table never overflows into
    # the upper 64 bits.
    var
      pow5: DubDub64
    doubleComputeInvPow5(q, pow5)
    result = mulShift32(m, pow5[1] + 1, j)
  else:
    result = mulShift32(m, ryuDoublePow5InvSplit[q][1] + 1, j)

proc mulPow5DivPow2*(m: uint32; i: uint32; j: int32): uint32 {.inline.} =
  when defined(ryuFloatFullTable):
    result = mulShift32(m, ryuFloatPow5Split[i], j)
  elif defined(ryuOptimizeSize):
    var
      pow5: DubDub64
    doubleComputePow5(i, pow5)
    result = mulShift32(m, pow5[1], j)
  else:
    when defined(ryuDebug):
      echo "mul m$# i$# t$# j$#" % [ $m, $i, $ryuDoublePow5Split[i][1], $j ]
    result = mulShift32(m, ryuDoublePow5Split[i][1], j)

proc f2d*(ieeeMantissa: uint32; ieeeExponent: uint32): FloatingDecimal32
  {.inline.} =
  var
    e2: int32
    m2: uint32
  when defined(ryuDebug):
    echo "EXP $# MANTISSA $#" % [$ieeeExponent, $ieeeMantissa]
  if ieeeExponent == 0:
    # We subtract 2 so that the bounds computation has 2 additional bits.
    e2 = 1 - ryuFloatBias - ryuFloatMantissaBits - 2
    m2 = ieeeMantissa
  else:
    e2 = ieeeExponent.int32 - ryuFloatBias - ryuFloatMantissaBits - 2
    m2 = (1'u32 shl ryuFloatMantissaBits) or ieeeMantissa
  let
    even = (m2 and 1) == 0
    acceptBounds = even

  when defined(ryuDebug):
    echo "-> $# * 2^$#" % [$m2, $(e2 + 2)]

  # Step 2: Determine the interval of valid decimal representations.
  let
    mv: uint32 = m2 * 4
    mp: uint32 = m2 * 4 + 2
  #[
    // Implicit bool -> int conversion. True is 1, false is 0.

    obviously, the nim impl is no longer implicit
  ]#
  let
    mmShift: uint32 = block:
      if ieeeMantissa != 0 or ieeeExponent <= 1:
        1
      else:
        0
    mm: uint32 = m2 * 4 - 1 - mmShift

  # Step 3: Convert to a decimal power base using 64-bit arithmetic.
  var
    vr, vp, vm: uint32
    e10: int32
    vmIsTrailingZeros = false
    vrIsTrailingZeros = false
    lastRemovedDigit: uint8 = 0
  if e2 >= 0:
    let
      q: uint32 = log10Pow2(e2)
    e10 = q.int32
    let
      k: int32 = ryuFloatPow5InvBitCount.int32 + pow5bits(q.int32) - 1
      i: int32 = -e2 + q.int32 + k
    when defined(ryuDebug):
      echo "MP+=$#\nMV =$#\nMM-=$#" % [$mp, $mv, $mm]
    # mp -> vp
    vp = mulPow5InvDivPow2(mp, q, i)
    # mv -> vr
    vr = mulPow5InvDivPow2(mv, q, i)
    # mm -> vm
    vm = mulPow5InvDivPow2(mm, q, i)

    when defined(ryuDebug):
      echo "$# * 2^$# / 10^$#" % [$mv, $e2, $q]
      echo "VP+=$#\nVR =$#\nVM-=$#" % [$vp, $vr, $vm]

    if q != 0 and (vp - 1) div 10'u32 <= vm div 10'u32:
      # We need to know one removed digit even if we are not going to loop
      # below. We could use q = X - 1 above, except that would require 33 bits
      # for the result, and we've found that 32-bit arithmetic is faster even
      # on 64-bit machines.
      let
        l: int32 = ryuFloatPow5InvBitCount.int32 + pow5bits(int32(q - 1)) - 1
      lastRemovedDigit = uint8(mulPow5InvDivPow2(mv, q - 1,
                                                 -e2 + q.int32 - 1 + l) mod 10)

    if q <= 9:
      # The largest power of 5 that fits in 24 bits is 5^10, but q <= 9 seems
      # to be safe as well.
      # Only one of mp, mv, and mm can be a multiple of 5, if any.
      if mv mod 5 == 0:
        vrIsTrailingZeros = multipleOfPowerOf5_32(mv, q)
      elif acceptBounds:
        vmIsTrailingZeros = multipleOfPowerOf5_32(mm, q)
      elif multipleOfPowerOf5_32(mp, q):
        vp.dec
  else:
    let
      q = log10Pow5(-e2)
    e10 = q.int32 + e2
    let
      i: int32 = -e2 - q.int32
      k: int32 = pow5bits(i) - ryuFloatPow5BitCount.int32
    var
      j: int32 = q.int32 - k
    vr = mulPow5divPow2(mv, i.uint32, j)
    vp = mulPow5divPow2(mp, i.uint32, j)
    vm = mulPow5divPow2(mm, i.uint32, j)
    when defined(ryuDebug):
      echo "$# * 5^$# / 10^$#" % [$mv, $(-e2), $q]
      echo "q$# i$# k$# j$#" % [$q, $i, $k, $j]
      echo "V+=$#\nV =$#\nV-=$#" % [$vp, $vr, $vm]

    if q != 0 and (vp - 1) div 10 <= vm div 10:
      j = int32(q - 1 - (pow5bits(i + 1) - ryuFloatPow5BitCount).uint32)
      lastRemovedDigit = uint8(mulPow5divPow2(mv, uint32(i + 1), j) mod 10)

    if q <= 1:
      # {vr,vp,vm} is trailing zeros if {mv,mp,mm} has at least q trailing 0
      # bits.  mv = 4 * m2, so it always has at least two trailing 0 bits.
      vrIsTrailingZeros = true
      if acceptBounds:
        # mm = mv - 1 - mmShift, so it has 1 trailing 0 bit iff mmShift == 1.
        vmIsTrailingZeros = mmShift == 1
      else:
        # mp = mv + 2, so it always has at least one trailing 0 bit.
        vp.dec
    elif q < 31: # TODO(ulfjack): Use a tighter bound here.
      vrIsTrailingZeros = multipleOfPowerOf2_32(mv, q - 1)
      when defined(ryuDebug):
        echo "vr is trailing zeros=", vrIsTrailingZeros

  when defined(ryuDebug):
    echo "e10=", e10
    echo "V+=$#\nV =$#\nV-=$#" % [$vp, $vr, $vm]
    echo "vm is trailing zeros=", vmIsTrailingZeros
    echo "vr is trailing zeros=", vrIsTrailingZeros

  # Step 4: Find the shortest decimal representation in the interval of valid
  # representations.
  var
    removed: int32 = 0
    output: uint32
  if vmIsTrailingZeros or vrIsTrailingZeros:
    # General case, which happens rarely (~4.0%).
    while vp div 10 > vm div 10:
      when defined(ryuClangWorkarounds):
      #[

      #ifdef __clang__ // https://bugs.llvm.org/show_bug.cgi?id=23106

      The compiler does not realize that vm % 10 can be computed from vm / 10
      as vm - (vm / 10) * 10.

      ]#
        vmIsTrailingZeros = vmIsTrailingZeros and vm - (vm div 10) * 10 == 0
      else:
        vmIsTrailingZeros = vmIsTrailingZeros and vm mod 10 == 0

      vrIsTrailingZeros = vrIsTrailingZeros and lastRemovedDigit == 0
      lastRemovedDigit = uint8(vr mod 10)
      vr = vr div 10
      vp = vp div 10
      vm = vm div 10
      removed.inc

    when defined(ryuDebug):
      echo "V+=$#\nV =$#\nV-=$#" % [$vp, $vr, $vm]
      echo "d-10=", vmIsTrailingZeros

    if vmIsTrailingZeros:
      while vm mod 10 == 0:
        vrIsTrailingZeros = vrIsTrailingZeros and lastRemovedDigit == 0
        lastRemovedDigit = uint8(vr mod 10)
        vr = vr div 10
        vp = vp div 10
        vm = vm div 10
        removed.inc

    when defined(ryuDebug):
      echo vr, " ", lastRemovedDigit
      echo "vr is trailing zeros=", vrIsTrailingZeros

    if vrIsTrailingZeros and lastRemovedDigit == 5 and vr mod 2 == 0:
      # Round even if the exact number is .....50..0.
      lastRemovedDigit = 4

    # We need to take vr + 1 if vr is outside bounds or we need to round up.
    if (vr == vm and (not acceptBounds or not vmIsTrailingZeros)) or lastRemovedDigit >= 5'u8:
      output = vr + 1
    else:
      output = vr
  else:
    # Specialized for the common case (~96.0%). Percentages below are relative
    # to this.
    # Loop iterations below (approximately):
    # 0: 13.6%, 1: 70.7%, 2: 14.1%, 3: 1.39%, 4: 0.14%, 5+: 0.01%
    while vp div 10 > vm div 10:
      lastRemovedDigit = uint8(vr mod 10)
      vr = vr div 10
      vp = vp div 10
      vm = vm div 10
      removed.inc

    when defined(ryuDebug):
      echo vr, " ", lastRemovedDigit
      echo "vr is trailing zeros=", vrIsTrailingZeros

    # We need to take vr + 1 if vr is outside bounds or we need to round up.
    if vr == vm or lastRemovedDigit >= 5'u8:
      output = vr + 1
    else:
      output = vr

  let
    exp: int32 = e10 + removed

  when defined(ryuDebug):
    echo "V+=$#\nV =$#\nV-=$#" % [$vp, $vr, $vm]
    echo "O=", output
    echo "EXP=", exp

  result = FloatingDecimal32(exponent: exp, mantissa: output)

proc toChars*(v: FloatingDecimal32; sign: bool): string {.inline.} =
  # Step 5: Print the decimal representation.
  var
    index = 0
    output: uint32 = v.mantissa

  # it is what it is
  result = newString(16)

  let
    olength: uint32 = decimalLength9(output)
  if sign:
    result[index] = '-'
    index.inc

  when defined(ryuDebug):
    echo "DIGITS=", v.mantissa
    echo "OLEN=", olength
    echo "EXP=", v.exponent

  ## Print the decimal digits.
  ## The following code is equivalent to:
  ## for (uint32_t i = 0; i < olength - 1; ++i) {
  ##   const uint32_t c = output % 10; output /= 10
  ##   result[index + olength - i] = (char) ('0' + c)
  ## }
  ## result[index] = '0' + output % 10
  var
    i: uint32 = 0
  while output >= 10_000'u32:
    let c: uint32 = when defined(ryuClangWorkarounds):
      #[

      #ifdef __clang__ // https://bugs.llvm.org/show_bug.cgi?id=38217

      ]#
      output - 10_000 * (output div 10_000)
    else:
      output mod 10_000
    output = output div 10_000
    let
      c0: uint32 = (c mod 100) shl 1
      c1: uint32 = (c div 100) shl 1
    result[index + olength.int - i.int - 1] = ryuDigitTable[c0 + 0]
    result[index + olength.int - i.int - 0] = ryuDigitTable[c0 + 1]
    result[index + olength.int - i.int - 3] = ryuDigitTable[c1 + 0]
    result[index + olength.int - i.int - 2] = ryuDigitTable[c1 + 1]
    i += 4

  if output >= 100'u32:
    let c: uint32 = (output mod 100) shl 1
    output = output div 100
    result[index + olength.int - i.int - 1] = ryuDigitTable[c + 0]
    result[index + olength.int - i.int - 0] = ryuDigitTable[c + 1]
    i += 2

  if output >= 10'u32:
    let c: uint32 = output shl 1
    # We can't use memcpy here: the decimal dot goes between these two
    # digits.
    result[index + olength.int - i.int] = ryuDigitTable[c + 1]
    result[index] = ryuDigitTable[c]
  else:
    result[index] = chr('0'.ord + output.int)

  # Print decimal point if needed.
  if olength > 1'u32:
    result[index + 1] = '.'
    index += olength.int + 1
  else:
    index.inc

  # Print the exponent.
  result[index] = 'E'
  index.inc

  var
    exp: int32 = v.exponent + olength.int32 - 1
  if exp < 0:
    result[index] = '-'
    index.inc
    exp = -exp

  if exp >= 10:
    # digit table is an array[200, char] that looks like this:
    #    '0', '0'
    #    '0', '1'
    #    '0', '2'
    result[index + 0] = ryuDigitTable[2 * exp + 0]
    result[index + 1] = ryuDigitTable[2 * exp + 1]
    index += 2
  else:
    result[index] = chr('0'.ord + exp)
    index.inc

  # set the result length
  result.setLen index

proc f2s*(f: float): string =
  # Step 1: Decode the floating-point number, and unify normalized and
  # subnormal cases.
  let
    bits: uint32 = floatToBits(f)

  # Decode bits into sign, mantissa, and exponent.
  let
    ieeeSign: bool = ((bits shr (ryuFloatMantissaBits + ryuFloatExponentBits)) and 1) != 0
    ieeeMantissa: uint32 = bits and ryuFloatMantissaBitMask.uint32
    ieeeExponent: uint32 = (bits shr ryuFloatMantissaBits) and ryuFloatExponentBitMask

  # Case distinction; exit early for the easy cases.
  if ieeeExponent == ryuFloatExponentBitMask or (ieeeExponent == 0 and ieeeMantissa == 0):
    result = specialStr(ieeeSign, ieeeExponent != 0, ieeeMantissa != 0)
  else:
    let
      v = f2d(ieeeMantissa, ieeeExponent)
    result = toChars(v, ieeeSign)
  when defined(ryuDebug):
    echo "---> F2S OUTPUT --->", result, "<---"
