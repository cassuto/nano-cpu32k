TOOLCHAIN_PREFIX := /mnt/riscv/riscv64-unknown-elf-toolchain-10.2.0-2020.12.8-x86_64-linux-centos6/bin/riscv64-unknown-elf-

LD := $(TOOLCHAIN_PREFIX)ld
AS := $(TOOLCHAIN_PREFIX)as
OBJCOPY := $(TOOLCHAIN_PREFIX)objcopy

.PHONY: all

all: addi.bin

%.bin: %.o
#	$(LD) $< -o $@ $(LDFLAGS) -Ttext 0x0 -Trodata 0x100 --oformat binary
	$(OBJCOPY) -O binary $^ $@

%.o: %.S
	$(AS) $< -o $@

