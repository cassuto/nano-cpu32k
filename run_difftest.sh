#!/bin/sh
#./build.sh -e cpu_diff -d -b -s -a "-i ../../../testcase/addi.bin --dump-wave" -m "EMU_TRACE=1" -w
./build.sh -e cpu_diff -d -b -s -a "-i /mnt/oscpu/am-kernels/tests/cpu-tests/build/hello-str-riscv64-mycpu.bin --dump-wave" -m "EMU_TRACE=1" -w
exit 0

#./build.sh -e cpu_diff -d -b
if [ $? -ne 0 ]; then
   exit 1
fi

list="/mnt/oscpu/am-kernels/tests/cpu-tests/build/add-longlong-riscv64-mycpu.bin
/mnt/oscpu/am-kernels/tests/cpu-tests/build/add-riscv64-mycpu.bin
/mnt/oscpu/am-kernels/tests/cpu-tests/build/bit-riscv64-mycpu.bin
/mnt/oscpu/am-kernels/tests/cpu-tests/build/bubble-sort-riscv64-mycpu.bin
/mnt/oscpu/am-kernels/tests/cpu-tests/build/div-riscv64-mycpu.bin
/mnt/oscpu/am-kernels/tests/cpu-tests/build/dummy-riscv64-mycpu.bin
/mnt/oscpu/am-kernels/tests/cpu-tests/build/fact-riscv64-mycpu.bin
/mnt/oscpu/am-kernels/tests/cpu-tests/build/fib-riscv64-mycpu.bin
/mnt/oscpu/am-kernels/tests/cpu-tests/build/goldbach-riscv64-mycpu.bin
/mnt/oscpu/am-kernels/tests/cpu-tests/build/hello-str-riscv64-mycpu.bin
/mnt/oscpu/am-kernels/tests/cpu-tests/build/if-else-riscv64-mycpu.bin
/mnt/oscpu/am-kernels/tests/cpu-tests/build/leap-year-riscv64-mycpu.bin
/mnt/oscpu/am-kernels/tests/cpu-tests/build/load-store-riscv64-mycpu.bin
/mnt/oscpu/am-kernels/tests/cpu-tests/build/matrix-mul-riscv64-mycpu.bin
/mnt/oscpu/am-kernels/tests/cpu-tests/build/max-riscv64-mycpu.bin
/mnt/oscpu/am-kernels/tests/cpu-tests/build/min3-riscv64-mycpu.bin
/mnt/oscpu/am-kernels/tests/cpu-tests/build/mov-c-riscv64-mycpu.bin
/mnt/oscpu/am-kernels/tests/cpu-tests/build/movsx-riscv64-mycpu.bin
/mnt/oscpu/am-kernels/tests/cpu-tests/build/mul-longlong-riscv64-mycpu.bin
/mnt/oscpu/am-kernels/tests/cpu-tests/build/pascal-riscv64-mycpu.bin
/mnt/oscpu/am-kernels/tests/cpu-tests/build/prime-riscv64-mycpu.bin
/mnt/oscpu/am-kernels/tests/cpu-tests/build/quick-sort-riscv64-mycpu.bin
/mnt/oscpu/am-kernels/tests/cpu-tests/build/recursion-riscv64-mycpu.bin
/mnt/oscpu/am-kernels/tests/cpu-tests/build/select-sort-riscv64-mycpu.bin
/mnt/oscpu/am-kernels/tests/cpu-tests/build/shift-riscv64-mycpu.bin
/mnt/oscpu/am-kernels/tests/cpu-tests/build/shuixianhua-riscv64-mycpu.bin
/mnt/oscpu/am-kernels/tests/cpu-tests/build/string-riscv64-mycpu.bin
/mnt/oscpu/am-kernels/tests/cpu-tests/build/sub-longlong-riscv64-mycpu.bin
/mnt/oscpu/am-kernels/tests/cpu-tests/build/sum-riscv64-mycpu.bin
/mnt/oscpu/am-kernels/tests/cpu-tests/build/switch-riscv64-mycpu.bin
/mnt/oscpu/am-kernels/tests/cpu-tests/build/to-lower-case-riscv64-mycpu.bin
/mnt/oscpu/am-kernels/tests/cpu-tests/build/unalign-riscv64-mycpu.bin
/mnt/oscpu/am-kernels/tests/cpu-tests/build/wanshu-riscv64-mycpu.bin"
# `ls /mnt/oscpu/am-kernels/tests/cpu-tests/build/*.bin`

for fn in $list; do
   echo ============================
   echo Running $fn
   echo ============================
   ./build.sh -e cpu_diff -d -s -a "-i $fn --dump-wave" -m "EMU_TRACE=1"
   if [ $? -ne 0 ]; then
      exit 1
   fi
done
