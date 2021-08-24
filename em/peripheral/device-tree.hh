#ifndef DEVICE_TREE_H_
#define DEVICE_TREE_H_

#include "common.hh"

class DevicePbUart;

class DeviceTree
{
public:
    DeviceTree(CPU *cpu, Memory *mem_, phy_addr_t mmio_phy_base);
    void step();

public:
    CPU *cpu;
    Memory *mem;
    DevicePbUart *pb_uart;
};

#endif /* DEVICE_TREE_H_ */
