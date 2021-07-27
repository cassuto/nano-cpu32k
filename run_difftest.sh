#!/bin/sh
make -C difftest clean
make -C difftest -j8 emu EMU_TRACE=1
./cpu/build/emu -b 0 -e 2000 --dump-wave -i ./testcase/addi.bin
