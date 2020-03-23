#include "spi_flash_w25qxx.h"
#include "log.h"

#define SPI_REG_BASE 0x81000000
#define SPI_REG_DR() *((volatile char *)SPI_REG_BASE)
#define SPI_REG_CR() *((volatile short *)SPI_REG_BASE)

/**
 * @brief SPI phy operations
 */
inline static void spi_cs_enable()
{
	SPI_REG_CR() = (1<<8); /* CS */
}
inline static void spi_cs_disable()
{
	SPI_REG_CR() = 0; /* ~CS */
}
inline static void spi_write(char dat)
{
	int i=8;
	while(i--) {
		SPI_REG_DR() = dat; /* bit7 = dat */
		dat <<= 1;
	}
}
inline static char spi_read()
{
	int i=8;
	while(i--) {
		SPI_REG_DR() = 0x0;
	}
	return SPI_REG_DR();
}

static void sys_delay(int cyc)
{
	while(cyc--)
		__asm__ __volatile__("nop");
}

// W25QXX flash Commands
#define W25QXX_CMD_WriteEnable        0x06
#define W25QXX_CMD_WriteDisable       0x04
#define W25QXX_CMD_ReadStatusReg      0x05
#define W25QXX_CMD_WriteStatusReg     0x01
#define W25QXX_CMD_ReadData           0x03
#define W25QXX_CMD_FastReadData       0x0B
#define W25QXX_CMD_FastReadDual       0x3B
#define W25QXX_CMD_PageProgram        0x02
#define W25QXX_CMD_BlockErase         0xD8
#define W25QXX_CMD_SectorErase        0x20
#define W25QXX_CMD_ChipErase          0xC7
#define W25QXX_CMD_PowerDown          0xB9
#define W25QXX_CMD_ReleasePowerDown   0xAB
#define W25QXX_CMD_DeviceID           0xAB
#define W25QXX_CMD_ManufactDeviceID   0x90
#define W25QXX_CMD_JEDECDeviceID      0x9F

/**
 * @brief FLASH register operations
 */
static void
w25qxx_write_disable()
{
	spi_cs_enable();
	spi_write(W25QXX_CMD_WriteDisable);
	spi_cs_disable();
}
static void w25qxx_write_enable()
{
	spi_cs_enable();
	spi_write(W25QXX_CMD_WriteEnable);
	spi_cs_disable();
}
static inline char w25qxx_read_status_reg()
{
	char byte = 0;
	spi_cs_enable();
	spi_write(W25QXX_CMD_ReadStatusReg);
	byte = spi_read();
	spi_cs_disable();
	return byte;
}
static inline void w25qxx_write_status_reg(char dat)
{
	spi_cs_enable();
	spi_write(W25QXX_CMD_WriteStatusReg);
	spi_write(dat);
	spi_cs_disable();
}
static inline void w25qxx_wait_busy()
{
	/* 0x03: WEL & Busy bit */
	while ((w25qxx_read_status_reg() & 0x03) == 0x03)
		__asm__ __volatile__("nop");
}

void
spi_flash_init(void)
{
	w25qxx_write_disable();
}

void
spi_flash_read(char *buff, flash_addr_t addr, int len)
{
	int i;
	spi_cs_enable();
	spi_write(W25QXX_CMD_ReadData);
	spi_write((addr >> 16) & 0xff);
	spi_write((addr >> 8) & 0xff);
	spi_write(addr & 0xff);
	for (i = 0; i < len; i++) {
		buff[i] = spi_read(); // address 80H - FFH
	}
	spi_cs_disable();
}

void
spi_flash_dump()
{
	unsigned char man_id;
	unsigned char mem_type_id;
	unsigned char capacity_id;
	
	/* Read out JEDEC ID */  
	spi_cs_enable();
	spi_write(W25QXX_CMD_JEDECDeviceID);

	man_id = spi_read();        //  receive Manufacturer or Device ID byte   
	mem_type_id = spi_read();   //  receive Memory Type ID byte   
	capacity_id = spi_read();   // receive capacity id byte
	
	spi_cs_disable();
	log_msg("Vendor: ");
	log_num(man_id);
	log_msg("\n");
	log_msg("Type: ");
	log_num(mem_type_id);
	log_msg("\n");
	log_msg("Capacity: ");
	log_num(1<<(capacity_id-10));
	log_msg("KiB\n");
}

