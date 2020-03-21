#ifndef UART_16550_H_
#define UART_16550_H_

extern void uart_init(int baudrate);
extern void uart_putc(char ch);
extern char uart_getc();

#endif //UART_16550_H_
