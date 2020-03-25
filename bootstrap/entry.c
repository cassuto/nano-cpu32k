#include "config.h"
#include "log.h"
#include "spi_flash_w25qxx.h"
#include "uart_16550.h"

void bootstrap_entry()
{
#ifdef SERIAL_CONSOLE
	uart_init(BAUD_RATE);
#endif
	log_msg("Init SPI Flash\n");
	spi_flash_init();
	spi_flash_dump();
#ifdef MEMTEST
	log_msg("Test mem\n");
	if (test_mem(MAIN_MEM_OFFSET, MAIN_MEM_SIZE)) {
		return;
	}
#endif
	log_msg("done\n");
}

