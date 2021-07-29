#!/bin/sh
#./build.sh -e cpu_diff -d -b -s -a "-i ../../../testcase/addi.bin --dump-wave" -m "EMU_TRACE=1" -w

./build.sh -e cpu_diff -d -b
if [ $? -ne 0 ]; then
   exit 1
fi

for fn in `ls /mnt/oscpu/am-kernels/tests/cpu-tests/build/*.bin`; do
   echo ============================
   echo Running $fn
   echo ============================
   ./build.sh -e cpu_diff -d -s -a "-i $fn --dump-wave" -m "EMU_TRACE=1" -m "VM_TRACE=1"
   if [ $? -ne 0 ]; then
      exit 1
   fi
done
