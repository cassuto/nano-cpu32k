#include "uart_16550.h"

/* CLK frequency of UART (Hz) */
#define UART_FCLK 14745600L

/* 16550 registers */
#define UART_REG_BASE 0x81000000
#define UART_REG_RBR_DLL() *((volatile char *)(UART_REG_BASE+0x00))
#define UART_REG_IER_DLM() *((volatile char *)(UART_REG_BASE+0x01))
#define UART_REG_FCR() *((volatile char *)(UART_REG_BASE+0x02))
#define UART_REG_LCR() *((volatile char *)(UART_REG_BASE+0x03))
#define UART_REG_MCR() *((volatile char *)(UART_REG_BASE+0x04))
#define UART_REG_LSR() *((volatile char *)(UART_REG_BASE+0x05))
#define UART_REG_MSR() *((volatile char *)(UART_REG_BASE+0x06))
#define UART_REG_SCR() *((volatile char *)(UART_REG_BASE+0x07))

void uart_init(int baudrate)
{
	unsigned short div_factor = UART_FCLK/(baudrate*16);
	/* Config baudrate generator */
	UART_REG_LCR() = (1<<7); /* set DLAB */
	UART_REG_RBR_DLL() = div_factor & 0xff;
	UART_REG_IER_DLM() = (div_factor>>8) & 0xff;
	/* Config line */
	UART_REG_LCR() = 0x3; /* clr DLAB, data bits = 8, no stop bit/ no parity / no set break */
}


void uart_putc(char ch)
{
	/* Wait till THR is not full */
	while((UART_REG_LSR() & (1<<5)) ==0)
		__asm__ __volatile__("nop");

	UART_REG_RBR_DLL() = ch;
}

char uart_getc(void)
{
	/* Wait till data ready */
	while((UART_REG_LSR() & (1<<0)) ==0)
		__asm__ __volatile__("nop");

	return UART_REG_RBR_DLL();
}

