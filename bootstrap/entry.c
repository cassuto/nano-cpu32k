#include "log.h"
#include "spi_flash_w25qxx.h"
#include "uart_16550.h"

void bootstrap_entry()
{
	uart_init(115200);
	log_msg("Init SPI Flash\n");
	spi_flash_init();
	spi_flash_dump();
}

