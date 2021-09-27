#ifndef IO_UART_H_
#define IO_UART_H_

extern int virt_uart_init(const char *filename, bool in_difftest_);
extern void virt_uart_putch(char ch);
extern void virt_uart_write(const char *buf);
extern int virt_uart_poll_read(char *ch);

#endif // IO_UART_H_