
AS = ../../out/bin/ncpu32k-unknown-elf-as
LD = ../../out/bin/ncpu32k-unknown-elf-ld
OBJCOPY = ../../out/bin/ncpu32k-unknown-elf-objcopy
OBJDUMP = ../../out/bin/ncpu32k-unknown-elf-objdump
MAKE = make
GCC =../../out/bin/ncpu32k-unknown-elf-gcc
CFLAGS :=
LDFLAGS = -L/home/ain/nano-cpu32k/out/lib/gcc/ncpu32k-unknown-elf/5.4.0/ -lgcc

TARGETS = bootstrap.o entry.o log.o spi_flash_w25qxx.o
HEADERS = log.h msr.h spi_flash_w25qxx.h

.PHONY: all dis clean

all: bootrom.bin bootrom

dis: bootrom.bin
	$(OBJDUMP) -D -b binary -m ncpu32k bootrom.bin

bootrom: $(TARGETS)
	$(LD) $^ -o bootrom $(LDFLAGS) -Ttext 0x0 -Trodata 0x100
bootrom.bin: $(TARGETS)
	$(LD) $^ -o $@ $(LDFLAGS) -Ttext 0x0 -Trodata 0x100 --oformat binary

%.o: %.S
	$(AS) $< -o $@

%.o: %.c
	$(GCC) -c $(CFLAGS) $< -o $@

%.c: $(HEADERS)

clean:
	-rm ./rom.S ./bootrom.bin ./*.o

