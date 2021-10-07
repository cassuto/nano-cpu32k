
#include "cpu.hh"
#include "pb-uart.hh"
#include "virt-uart.hh"
#include "device-tree.hh"
#include "cpu.hh"

const phy_addr_t pb_uart_mmio_size = 0x8;

DevicePbUart::DevicePbUart(DeviceTree *tree_, phy_addr_t mmio_base, int irq_, const char *virt_uart_file)
{
    tree = tree_;
    irq = irq_;

    reset();
    /* Startup virtual UART */
    virt_uart_init(virt_uart_file, tree->in_difftest());

    /*
     * Register it on MMIO
     */
    tree->mem->mmio_register_writem8(mmio_base, mmio_base + pb_uart_mmio_size - 1, this, this);
    tree->mem->mmio_register_readm8(mmio_base, mmio_base + pb_uart_mmio_size - 1, this, this);
}

void DevicePbUart::reset()
{
    RBR =
        DLR =
            IER =
                FCR =
                    LCR_DLAB =
                        MCR =
                            LSR =
                                IIR =
                                    rdy =
                                        tx_full =
                                            dout_overun =
                                                dat_ready =
                                                    RBR_written = 0;

    DLR = 0xa0;
    IIR = 0x1;
    rdy = 1;
}

void DevicePbUart::writem8(phy_addr_t addr, uint8_t val, void *opaque)
{
    printf("w %#x =%#x\n", addr, val);
    addr &= (pb_uart_mmio_size - 1);

    // Accept/clear IRQ
    if ((IIR & 0x1) == 0)
    {
        uint8_t IIR_sel = (IIR >> 1) & 0x3;
        if ((IIR_sel == 0x1) && ((addr == 0x0) && !LCR_DLAB)) // Write IER
        {
            IIR |= 0x1; // no IRQ pending
            if (!tree->in_difftest())
                tree->cpu->irqc_set_interrupt(irq, 0);
        }
    }

    switch (addr)
    {
    case 0:
    {
        if (LCR_DLAB)
            DLR = (((DLR >> 8) & 0xff) << 8) | val;
        else
        {
            if (!tree->in_difftest())
                virt_uart_putch(val);
            RBR_written = 1;
            step();
        }
        break;
    }
    case 1:
    {
        if (LCR_DLAB)
            DLR = (DLR & 0xff) | (val << 8);
        else
            IER = val & 0x0f;
        break;
    }
    case 3:
        LCR_DLAB = val & (1 << 7);
        break;
    }

    step();
}

uint8_t DevicePbUart::readm8(phy_addr_t addr, void *opaque)
{
    //printf("%d %x %s() %x\n", ++cnt, cpu_pc, __func__, addr);
    addr &= (pb_uart_mmio_size - 1);

    uint8_t ret;

    switch (addr)
    {
    // RBR (DLAB = 0)
    // DLL (DLAB = 1)
    case 0:
        ret = LCR_DLAB ? DLR & 0xff : RBR;
        break;
    // IER (DLAB = 0) TODO: EM EL
    // DLM (DLAB = 1)
    case 1:
        ret = LCR_DLAB ? (DLR >> 8) & 0xff : IER;
        break;
    // FCR TODO
    case 2:
        ret = IIR;
        break;
    // LCR TODO: Data bits / Stop bit/ parity / set break
    case 3:
        ret = (LCR_DLAB << 7) | 0x3;
        break;
    // MCR TODO: DTR RTS OUT1 OUT2 LOOP
    case 4:
        ret = 0;
        break;
    // LSR TODO: Parity and errors
    case 5:
        ret = (rdy << 6) | (!tx_full << 5) | (dout_overun << 1) | dat_ready;
        break;
    // MSR TODO
    case 6:
        ret = 0x80;
        break;
    // SCR TODO
    case 7:
        ret = 0;
        break;
    }

    // Accept/clear IRQ
    if ((IIR & 0x1) == 0)
    {
        uint8_t IIR_sel = (IIR >> 1) & 0x3;
        if (((IIR_sel == 0x2) && (addr == 0x0) && !LCR_DLAB) || // read RBR
            ((IIR_sel == 0x1) && ((addr == 0x2) && !LCR_DLAB))) // write FCR
        {
            dat_ready = 0; /* fixme RX queue */
            IIR |= 0x1;    // no IRQ pending
            if (!tree->in_difftest())
                tree->cpu->irqc_set_interrupt(irq, 0);
        }
    }

    step();
    return ret;
}

void DevicePbUart::step()
{
    // Updating IRQs if no previous IRQ
    if ((IIR)&0x1)
    {
        if (virt_uart_poll_read((char *)&RBR))
        {
            fprintf(stderr, "input: %c(%d)\n", RBR, RBR);
            dat_ready = 1;
        }
        if (dat_ready && (IER & 0x1))
        {
            // Raise RX buffer full IRQ
            IIR = 0x4; // b100
            if (!tree->in_difftest())
                tree->cpu->irqc_set_interrupt(irq, 1);
        }
        else if (!tx_full && RBR_written && (IER & 0x2))
        {
            // Raise TX buffer empty IRQ
            RBR_written = 0;
            IIR = 0x2; // b010
            if (!tree->in_difftest())
                tree->cpu->irqc_set_interrupt(irq, 1);
        }
    }
}
