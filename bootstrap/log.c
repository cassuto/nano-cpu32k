#include "msr.h"
#include "uart_16550.h"
#include "log.h"

void log_char(char ch)
{
	uart_putc(ch);
	wmsr(MSR_DBGR_MSGPORT, (int)ch);
}

void log_msg(const unsigned char *msg)
{
	while(*msg) {
		log_char(*msg);
		++msg;
	}
}

void log_num(unsigned int n)
{
	unsigned int bas = 1000000000;
	char flag=0;
	while(bas) {
		if(flag || n/bas) {
			log_char((n/bas)%10+'0');
			flag=1;
		}
		bas /= 10;
	};
}

