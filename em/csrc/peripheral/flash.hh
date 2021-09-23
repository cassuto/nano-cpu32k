#ifndef FLASH_H_
#define FLASH_H_

#include "common.hh"
#include "memory.hh"

class Flash : public MMIOCallback
{
public:
    Flash(DeviceTree *tree_, phy_addr_t mmio_base_, size_t size, FILE *image_fp);
    ~Flash();

protected:
    void writem8(phy_addr_t addr, uint8_t val, void *opaque);
    void writem16(phy_addr_t addr, uint16_t val, void *opaque);
    void writem32(phy_addr_t addr, uint32_t val, void *opaque);
    uint8_t readm8(phy_addr_t addr, void *opaque);
    uint16_t readm16(phy_addr_t addr, void *opaque);
    uint32_t readm32(phy_addr_t addr, void *opaque);

private:
    DeviceTree *tree;
    uint8_t *mem;
    phy_addr_t mmio_base;
};

#endif
