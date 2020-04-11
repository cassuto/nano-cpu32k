TARGET := coremark

TEXT_SECTION_ADDR = 0x00000000

OBJS := \
	bootstrap.o \
	core_list_join.o \
	core_main.o \
	core_matrix.o \
	core_state.o \
	core_util.o \
	core_portme.o

HEADERS := \
	coremark.h \
	core_portme.h \
	msr.h

CFLAGS := -O2 -fno-common -funroll-loops -finline-functions --param max-inline-insns-auto=20 -falign-functions=4 -falign-jumps=4 -falign-loops=4
CFLAGS += -DFLAGS_STR=\""$(CFLAGS)"\"
CFLAGS += -DITERATIONS=10000 -DPERFORMANCE_RUN=1
CFLAGS += -I/mnt/home/ain/nano-cpu32k/out/ncpu32k-linux-uclibc/usr/include

LDFLAGS = -L/mnt/home/ain/nano-cpu32k/out/lib/gcc/ncpu32k-unknown-elf/5.4.0/ -lgcc

CC =../../out/bin/ncpu32k-unknown-elf-gcc
AS = ../../out/bin/ncpu32k-unknown-elf-as
LD = ../../out/bin/ncpu32k-unknown-elf-ld
OBJCOPY = ../../out/bin/ncpu32k-unknown-elf-objcopy
OBJDUMP = ../../out/bin/ncpu32k-unknown-elf-objdump


.PHONY: all dis clean

all: $(TARGET).bin $(TARGET)

dis: $(TARGET).bin
	$(OBJDUMP) -D -b binary -m ncpu32k $<

$(TARGET): $(OBJS)
	$(LD) $^ -o $@ $(LDFLAGS) -Ttext $(TEXT_SECTION_ADDR)
$(TARGET).bin: $(OBJS)
	$(LD) $^ -s -o $@ $(LDFLAGS) -Ttext $(TEXT_SECTION_ADDR) --oformat binary

%.o: %.S
	$(AS) $< -o $@

%.o: %.c $(HEADERS)
	$(CC) -c $(CFLAGS) $< -o $@

clean:
	-rm ./$(TARGET) ./$(TARGET).bin ./*.o


