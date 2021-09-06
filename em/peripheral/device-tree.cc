
#include "cpu.hh"
#include "pb-uart.hh"
#include "device-tree.hh"

DeviceTree::DeviceTree(CPU *cpu_, Memory *mem_, phy_addr_t mmio_phy_base)
    : cpu(cpu_),
      mem(mem_)
{
    pb_uart = new DevicePbUart(this,mmio_phy_base + 0x10000000, 2);
}

void DeviceTree::step(void)
{
    pb_uart->step();
}
