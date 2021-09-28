
#include "device-tree.hh"
#include "flash.hh"

Flash::Flash(DeviceTree *tree_, phy_addr_t mmio_base_, size_t size, FILE *image_fp)
    : tree(tree_),
      mem(new uint8_t[size]),
      mmio_base(mmio_base_)
{
    tree->mem->mmio_register_writem8(mmio_base, mmio_base + size - 1, this, this);
    tree->mem->mmio_register_readm8(mmio_base, mmio_base + size - 1, this, this);
    tree->mem->mmio_register_writem16(mmio_base, mmio_base + size - 1, this, this);
    tree->mem->mmio_register_readm16(mmio_base, mmio_base + size - 1, this, this);
    tree->mem->mmio_register_writem32(mmio_base, mmio_base + size - 1, this, this);
    tree->mem->mmio_register_readm32(mmio_base, mmio_base + size - 1, this, this);

    /* Load flash image */
    if (image_fp)
    {
        fseek(image_fp, 0, SEEK_SET);
        size_t actual_size = fread(mem, 1, size, image_fp);
        fprintf(stderr, "Flash image loaded (%lu bytes)\n", actual_size);
    }
}

Flash::~Flash()
{
    delete[] mem;
}

void Flash::writem8(phy_addr_t addr, uint8_t val, void *opaque)
{
    addr -= mmio_base;
    mem[addr] = val;
}

void Flash::writem16(phy_addr_t addr, uint16_t val, void *opaque)
{
    addr -= mmio_base;
    mem[addr++] = uint8_t(val);
    mem[addr] = uint8_t(val>>8);
}

void Flash::writem32(phy_addr_t addr, uint32_t val, void *opaque)
{
    addr -= mmio_base;
    mem[addr++] = uint8_t(val);
    mem[addr++] = uint8_t(val>>8);
    mem[addr++] = uint8_t(val>>16);
    mem[addr] = uint8_t(val>>24);
}

uint8_t Flash::readm8(phy_addr_t addr, void *opaque)
{
    addr -= mmio_base;
    return mem[addr];
}

uint16_t Flash::readm16(phy_addr_t addr, void *opaque)
{
    addr -= mmio_base;
    uint16_t ret = 0;
    ret |= mem[addr++];
    ret |= uint16_t(mem[addr]) << 8;
    return ret;
}

uint32_t Flash::readm32(phy_addr_t addr, void *opaque)
{
    addr -= mmio_base;
    uint32_t ret = 0;
    ret |= mem[addr++];
    ret |= uint32_t(mem[addr++]) << 8;
    ret |= uint32_t(mem[addr++]) << 16;
    ret |= uint32_t(mem[addr]) << 24;
    return ret;
}
