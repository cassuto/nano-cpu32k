#include "config.h"
#include "msr.h"
#ifdef SERIAL_CONSOLE
# include "uart_16550.h"
#endif
#include "log.h"

void log_char(char ch)
{
#ifdef SERIAL_CONSOLE
	uart_putc(ch);
#endif
	wmsr(MSR_DBGR_MSGPORT, (int)ch);
}

void log_msg(const char *msg)
{
	while(*msg) {
		log_char(*((const unsigned char *)msg));
		++msg;
	}
}

void log_num(unsigned int n)
{
	unsigned int bas = 1000000000;
	char flag=0;
	if(!n) {
		log_char('0');
		return;
	}
	while(bas) {
		if(flag || n/bas) {
			log_char((n/bas)%10+'0');
			flag=1;
		}
		bas /= 10;
	};
}

