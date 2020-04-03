AS = ../toolchain/bin/ncpu32k-unknown-elf-as
OBJCOPY = ../toolchain/bin/ncpu32k-unknown-elf-objcopy
PYTHON = python

BIN ?= insn.bin

TARGETS := sim/insn.mem

.PHONY: all clean

all: $(TARGETS)

$(TARGETS): $(BIN)
	$(PYTHON) generate_rams_w.py $< $@

insn.bin: insn.o
	$(OBJCOPY) -O binary -S $< $@
	
%.o: %.S
	$(AS) $< -o $@

clean:
	-rm ./*.o ./insn.bin ./insn.mem sim/insn.mem
