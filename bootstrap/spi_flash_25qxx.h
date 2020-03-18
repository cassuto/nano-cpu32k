#ifndef SPI_FLASH_25QXX_H_
#define SPI_FLASH_25QXX_H_

typedef unsigned int flash_addr_t;

extern void spi_flash_init(void);
extern void spi_flash_read(char *buff, flash_addr_t addr, int len);

#endif // SPI_FLASH_25QXX_H_