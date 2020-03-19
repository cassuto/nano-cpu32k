#include "spi_flash_w25qxx.h"

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
 * @brief SPI phy operations
 */
inline static void w25qxx_set_cs()
{

}
inline static void w25qxx_clr_cs()
{

}
inline static void w25qxx_spi_write(char dat)
{

}
inline static char w25qxx_spi_read()
{

}

/**
 * @brief FLASH register operations
 */
static void
w25qxx_write_disable()
{
  w25qxx_clr_cs();
  w25qxx_spi_write(W25QXX_CMD_WriteDisable);
  w25qxx_set_cs();
}
static void w25qxx_write_enable()
{
  w25qxx_clr_cs();
  w25qxx_spi_write(W25QXX_CMD_WriteEnable);
  w25qxx_set_cs();
}
static inline char w25qxx_read_status_reg()
{
  char byte = 0;
  w25qxx_clr_cs();
  w25qxx_spi_write(W25QXX_CMD_ReadStatusReg);
  byte = w25qxx_spi_read();
  w25qxx_set_cs();
  return byte;
}
static inline void w25qxx_write_status_reg(char dat)
{
  w25qxx_clr_cs();
  w25qxx_spi_write(W25QXX_CMD_WriteStatusReg);
  w25qxx_spi_write(dat);
  w25qxx_set_cs();
}
static inline void w25qxx_wait_busy()
{
  /* 0x03: WEL & Busy bit */
  while (w25qxx_read_status_reg() & 0x03 == 0x03)
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
  w25qxx_clr_cs();
  w25qxx_spi_write(W25QXX_CMD_ReadData);
  w25qxx_spi_write((addr >> 16) & 0xff);
  w25qxx_spi_write((addr >> 8) & 0xff);
  w25qxx_spi_write(addr & 0xff);
  for (i = 0; i < len; i++) {
      buff[i] = w25qxx_spi_read(); // address 80H - FFH
  }
  w25qxx_set_cs();
}
