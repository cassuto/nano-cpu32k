AS = ../toolchain/bin/ncpu32k-unknown-elf-as
OBJCOPY = ../toolchain/bin/ncpu32k-unknown-elf-objcopy
LD = ../toolchain/bin/ncpu32k-unknown-elf-ld
PYTHON = python

BIN ?= insn.bin

TARGETS := sim/insn.mem

.PHONY: all clean

all: $(TARGETS)

$(TARGETS): $(BIN)
	$(PYTHON) generate_rams_w.py $< $@

insn.bin: insn.o
#	$(OBJCOPY) -O binary -S $< $@
	$(LD) $< -o insn $(LDFLAGS) -Ttext 0x0 -Trodata 0x100
	$(LD) $< -o $@ $(LDFLAGS) -Ttext 0x0 -Trodata 0x100 --oformat binary
	
%.o: %.S
	$(AS) $< -o $@

clean:
	-rm ./*.o ./insn.bin ./insn.mem sim/insn.mem
