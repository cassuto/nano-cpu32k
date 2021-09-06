#ifndef IO_UART_H_
#define IO_UART_H_

extern int virt_uart_init(const char *filename);
extern void virt_uart_putch(char ch);
extern void virt_uart_write(const char *buf);
extern int virt_uart_poll_read(char *buf, int n);

#endif // IO_UART_H_