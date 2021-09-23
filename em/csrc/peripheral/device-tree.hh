#ifndef DEVICE_TREE_H_
#define DEVICE_TREE_H_

#include "common.hh"

class DevicePbUart;
class Flash;

class DeviceTree
{
public:
    DeviceTree(CPU *cpu, Memory *mem_, phy_addr_t mmio_phy_base,
               const char *virt_uart_file,
               size_t flash_size,
               FILE *flash_image_fp);
    ~DeviceTree();
    void step();

    inline bool in_difftest() const { return !cpu; }

public:
    CPU *cpu;
    Memory *mem;
    DevicePbUart *pb_uart;
    Flash *flash;
};

#endif /* DEVICE_TREE_H_ */
