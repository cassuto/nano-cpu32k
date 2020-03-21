#include "log.h"
#include "spi_flash_w25qxx.h"

void bootstrap_entry()
{
	log_msg("Init SPI Flash\n");
	spi_flash_init();
	spi_flash_dump();
}

