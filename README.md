# nano-cpu32k

`nano-cpu32k` is a high-performance RISC processor core.

|  Feature  | `nano-cpu32k` |
|:------:|:------:|
| Superscalar   | √ |
| Out-of-order issue/execution   | √ |
| Boot Linux | √ |
| L1 Cache & MMU | √ |
| AXI4 Memory interface  | √ |
| Instruction fetch width | 4 (Configurable) |
| Issue width     | 2 (Configurable) |
| Dynamic branch prediction   | √ |
| Synthesizable Verilog  | √ |
| FPGA Verified  | √ |
| Clock frequency on FPGA  | >100MHz @Kintex-7 |

The micro-architecture overview is shown below.

![micro-arch](https://github.com/cassuto/nano-cpu32k/raw/v0.2-asic/doc/microarch.svg)

## Generate Verilog
* Install `python3`.
* Run `make build` to generate the Verilog file `build/ysyx_210479.v`

## Run Linux with simulator

* Install Verilog simulator `Verilator`.
* Run `make build_sim` to generate the simulation program `build/emu`.
* Run `build/emu --help` for a overview of supported options.

Run the prebuilt Linux:
```bash
./build/emu --mode=standalone -b ./prebuilt/vmlinux.bin --flash-image=./prebuilt/bsp/program/flash/trampoline-flash.bin --reset-pc=0x30000000
```

Alternatively, using the `--mode=difftest` option, you can do **differential test** between hardware implementation and C++ reference model.

## Regression testing

* Run `run-test.sh` to test hardware design.

## Run Linux on Xilinx Kintex-7 FPGA

A DDR3-based minimum **SoC** is provided on `fpga\ddr3_alpha_soc` in the form of Vivado project.

* See `fpga\ddr3_alpha_soc\PINs.xlsx` for hardware connections.
* Program SPI flash with binary file `prebuilt\bsp\program\loader\vmlinux-loader.bin` starting at address 0x0.
* Connect the RS232 serial port to your PC, set baud rate as 115200 bps.
* Download the bitstream to FPGA.

## Software resources
* [Patches for GNU Toolchain (Binutils+GCC)](https://github.com/cassuto/nano-cpu32k-toolchain)
* [[Patches for Linux Kernel](https://github.com/cassuto/nano-cpu32k-linux-4.20.8)

