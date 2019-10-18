AS = ../toolchain/bin/ncpu32k-unknown-elf-as
OBJCOPY = ../toolchain/bin/ncpu32k-unknown-elf-objcopy
PYTHON = python

TARGETS := insn.mem ../synthesis/ise/insn.mem

.PHONY: all clean

all: $(TARGETS)

$(TARGETS): insn.bin
	$(PYTHON) generate_rams.py $< $@

insn.bin: insn.o
	$(OBJCOPY) -O binary -S $< $@
	
%.o: %.S
	$(AS) $< -o $@

clean:
	-rm ./*.o ./insn.bin ./insn.mem ../synthesis/ise/insn.mem
