#ifndef FLASH_H_
#define FLASH_H_

#include "common.hh"
#include "memory.hh"

class Flash : public MMIOCallback
{
public:
    Flash(DeviceTree *tree_, phy_addr_t mmio_base, size_t size);

    void reset();
    void step();

protected:
    void writem8(phy_addr_t addr, uint8_t val, void *opaque);
    uint8_t readm8(phy_addr_t addr, void *opaque);

private:
    DeviceTree *tree;
};

#endif