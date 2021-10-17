
#include "cpu.hh"
#include "pb-uart.hh"
#include "flash.hh"
#include "device-tree.hh"

DeviceTree::DeviceTree(CPU *cpu_, Memory *mem_, phy_addr_t mmio_phy_base,
                       const char *virt_uart_file,
                       FILE *flash_image_fp)
    : cpu(cpu_),
      mem(mem_)
{
    pb_uart = new DevicePbUart(this, mmio_phy_base + 0x10000000, 1, virt_uart_file);
    flash = new Flash(this, mmio_phy_base + 0x30000000, 0x10000000, flash_image_fp);
}

DeviceTree::~DeviceTree()
{
    delete pb_uart;
    delete flash;
}

void DeviceTree::step(void)
{
    pb_uart->step();
}
