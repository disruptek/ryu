version = "0.0.1"
author = "disruptek"
description = "ryu for nim"
license = "MIT"
requires "nim >= 1.0.0"

proc execCmd(cmd: string) =
  echo "execCmd:" & cmd
  exec cmd

proc execTest(test: string) =
  execCmd "nim c           -f --path=. -r " & test
  #execCmd "nim c   -d:release --path=. -r " & test
  #execCmd "nim c   -d:danger  --path=. -r " & test
  #execCmd "nim cpp            --path=. -r " & test
  #execCmd "nim cpp -d:danger  --path=. -r " & test
  #when NimMajor >= 1 and NimMinor >= 1:
  #  execCmd "nim c   --gc:arc --path=. -r " & test
  #  execCmd "nim cpp --gc:arc --path=. -r " & test

task test, "run tests for travis":
  #execTest("tests/tcommon.nim")
  execTest("tests/tf2s.nim")
  #execTest("tests/td2s_table.nim")
