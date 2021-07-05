#include "config.h"
#include "msr.h"
#ifdef SERIAL_CONSOLE
# include "uart_16550.h"
#endif
#include "log.h"

void log_char(char ch)
{
#ifdef SERIAL_CONSOLE
	if (ch=='\n') {
		uart_putc('\r');
	}
	uart_putc(ch);
#endif
#ifdef MSGPORT_CONSOLE
	wmsr(MSR_DBGR_MSGPORT, (int)ch);
#endif
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

void log_hex(unsigned int n)
{
	unsigned int bas = 0x10000000;
	char flag=0;
	log_char('0'); log_char('x');
	if(!n) {
		log_char('0');
		return;
	}
	while(bas) {
		if(flag || n/bas) {
			char val = (n/bas)%16;
			log_char(val<10 ? val+'0' : val-10+'A');
			flag=1;
		}
		bas /= 16;
	};
}

void log_dump_memory(const unsigned char *buf, int size)
{
	int p=0;
	for(int i=0;i<size;++i) {
		log_hex(buf[i]);
		if(++p==16) {
			p=0;
			log_msg("\n");
		} else {
			log_msg(" ");
		}
	}
}

