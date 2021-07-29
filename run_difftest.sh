#!/bin/sh
./build.sh -e cpu_diff -d -b -s -a "-i ../../../testcase/addi.bin --dump-wave" -m "EMU_TRACE=1" -w
#./build.sh -e cpu_diff -d -b -s -a "-i /mnt/oscpu/am-kernels/tests/cpu-tests/build/add-riscv64-mycpu.bin --dump-wave" -m "EMU_TRACE=1" -w

