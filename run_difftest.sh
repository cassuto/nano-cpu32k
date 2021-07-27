#!/bin/sh
./build.sh -e cpu_diff -d -b -s -a "-i ../../../testcase/addi.bin --dump-wave" -m "EMU_TRACE=1"
