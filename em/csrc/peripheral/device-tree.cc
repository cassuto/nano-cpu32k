
#include "cpu.hh"
#include "pb-uart.hh"
#include "device-tree.hh"

DeviceTree::DeviceTree(CPU *cpu_, Memory *mem_, phy_addr_t mmio_phy_base, const char *virt_uart_file)
    : cpu(cpu_),
      mem(mem_)
{
    pb_uart = new DevicePbUart(this, mmio_phy_base + 0x10000000, 2, virt_uart_file);
}

void DeviceTree::step(void)
{
    pb_uart->step();
}
