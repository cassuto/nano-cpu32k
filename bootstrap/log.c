#include "msr.h"
#include "log.h"

void log_msg(const unsigned char *msg)
{
	while(*msg) {
		wmsr(MSR_DBGR_MSGPORT, (int)*msg);
		++msg;
	}
}

void log_num(unsigned int n)
{
	wmsr(MSR_DBGR_NUMPORT, n);
}
