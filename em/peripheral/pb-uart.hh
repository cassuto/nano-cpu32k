#ifndef DEVICE_PB_UART_H_
#define DEVICE_PB_UART_H_

#include "common.hh"
#include "memory.hh"

class DevicePbUart : public MMIOCallback
{
public:
    DevicePbUart(DeviceTree *tree_, phy_addr_t mmio_base, int irq_);

    void reset();
    void step();

protected:
    void writem8(phy_addr_t addr, uint8_t val, void *opaque);
    uint8_t readm8(phy_addr_t addr, void *opaque);

private:
    uint8_t RBR;
    uint8_t DLR;
    uint8_t IER;
    uint8_t FCR;
    uint8_t LCR_DLAB;
    uint8_t MCR;
    uint8_t LSR;
    uint8_t IIR;

    uint8_t rdy;
    uint8_t tx_full;
    uint8_t dout_overun;
    uint8_t dat_ready;
    uint8_t RBR_written;
    int irq;

    DeviceTree *tree;
};

#endif /* DEVICE_PB_UART_H_ */
