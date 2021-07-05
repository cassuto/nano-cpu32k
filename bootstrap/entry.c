#include "config.h"
#include "log.h"
#include "spi_flash_w25qxx.h"
#include "memtest.h"
#include "crc16.h"
#include "uart_16550.h"

void abort()
{
	log_msg("abort!\n");
	while(1);
}

#include "msr.h"
void bootstrap_entry()
{
#ifdef SERIAL_CONSOLE
	uart_init(BAUD_RATE);
#endif
	log_msg("\nBOOTROM v0.1\n");
	spi_flash_init();
	spi_flash_dump();
	
#ifdef CHECKSUM_KERNEL
	/* Read CRC16 */
	unsigned short crc16_expected;
	char buff[2];
	spi_flash_read(buff, CRC16_FILE_OFFSET, 2);
	crc16_expected = (buff[0]&0xff) | ((unsigned short)buff[1]<<8);
	log_msg("CRC=");
	log_hex(crc16_expected);
	log_msg("\n");
#endif
	
#ifdef MEMTEST
	log_msg("Test mem\n");
   /* Don't overwrite my stack! */
	if (test_mem(MAIN_MEM_START_ADDRESS, MAIN_MEM_SIZE-STACK_SIZE)) {
		return;
	}
	wmsr(MSR_DBGR_NUMPORT, 123);
#endif
	
	/* Move kernel binary from FLASH to DRAM */
	log_msg("Loading...\n");
	spi_flash_read(KERNEL_LOAD_ADDRESS, KERNEL_FILE_OFFSET, KERNEL_SIZE);
	
	/* Checksum */
#ifdef CHECKSUM_KERNEL
	log_msg("checksum...\n");
   init_crc16();
	unsigned short crc16_cur = crc16(KERNEL_LOAD_ADDRESS, KERNEL_SIZE);
	if(crc16_cur != crc16_expected) {
		log_msg("broken ");
		log_hex(crc16_cur);
		log_msg("\n");
	}
#endif
	
	/* log_dump_memory(0x496e70, 1024); */

	log_msg("Boot...\n");
	/* Jmp to kernel */
	typedef void (*pfn_entry)(void *fdt);
	pfn_entry entry = (pfn_entry)KERNEL_LOAD_ADDRESS;
	entry(0);
}

