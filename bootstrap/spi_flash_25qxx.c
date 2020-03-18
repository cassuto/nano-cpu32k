#include "spi_flash_25qxx.h"

// 25QXX flash Commands
#define 25QXX_CMD_WriteEnable        0x06
#define 25QXX_CMD_WriteDisable       0x04
#define 25QXX_CMD_ReadStatusReg      0x05
#define 25QXX_CMD_WriteStatusReg     0x01
#define 25QXX_CMD_ReadData           0x03
#define 25QXX_CMD_FastReadData       0x0B
#define 25QXX_CMD_FastReadDual       0x3B
#define 25QXX_CMD_PageProgram        0x02
#define 25QXX_CMD_BlockErase         0xD8
#define 25QXX_CMD_SectorErase        0x20
#define 25QXX_CMD_ChipErase          0xC7
#define 25QXX_CMD_PowerDown          0xB9
#define 25QXX_CMD_ReleasePowerDown   0xAB
#define 25QXX_CMD_DeviceID           0xAB
#define 25QXX_CMD_ManufactDeviceID   0x90
#define 25QXX_CMD_JEDECDeviceID      0x9F

/**
 * @brief SPI phy operations
 */
inline static void 25qxx_set_cs()
{

}
inline static void 25qxx_clr_cs()
{

}
inline static void 25qxx_spi_write(char dat)
{

}
inline static char 25qxx_spi_read()
{

}

/**
 * @brief FLASH register operations
 */
static void
25qxx_write_disable()
{
  25qxx_clr_cs();
  25qxx_spi_write(25QXX_CMD_WriteDisable);
  25qxx_set_cs();
}
static void 25qxx_write_enable()
{
  25qxx_clr_cs();
  25qxx_spi_write(25QXX_CMD_WriteEnable);
  25qxx_set_cs();
}
static inline char 25qxx_read_status_reg()
{
  char byte = 0;
  25qxx_clr_cs();
  25qxx_spi_write(25QXX_CMD_ReadStatusReg);
  byte = 25qxx_spi_read();
  25qxx_set_cs();
  return byte;
}
static inline void 25qxx_write_status_reg(char dat)
{
  25qxx_clr_cs();
  25qxx_spi_write(25QXX_CMD_WriteStatusReg);
  25qxx_spi_write(dat);
  25qxx_set_cs();
}
static inline void 25qxx_wait_busy()
{
  /* 0x03: WEL & Busy bit */
  while (25qxx_read_status_reg() & 0x03 == 0x03)
    __asm__ __volatile__("nop");
}

void
spi_flash_init(void)
{
  25qxx_write_disable();
}

void
spi_flash_read(char *buff, flash_addr_t addr, int len)
{
  int i;
  25qxx_clr_cs();
  25qxx_spi_write(25QXX_CMD_ReadData);
  25qxx_spi_write((addr >> 16) & 0xff);
  25qxx_spi_write((addr >> 8) & 0xff);
  25qxx_spi_write(addr & 0xff);
  for (i = 0; i < len; i++) {
      buff[i] = 25qxx_spi_read(); // address 80H - FFH
  }
  25qxx_set_cs();
}
