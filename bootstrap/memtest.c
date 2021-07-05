#include "memtest.h"
#include "log.h"
#include "config.h"

int test_mem(unsigned int offset, unsigned int size)
{
	for(int i=offset;i<offset+size;i+=4) {
		*((volatile int*)i) = i;
	}
	for(int i=offset;i<offset+size;i+=4) {
	retry:
		if(*((volatile int*)i) != i) {
			log_msg("FAIL ");
			log_num(i);
			log_msg(":");
			log_num(*((volatile int*)i));
			log_msg("\n");
			goto retry;
			return 1;
		}
	}
	return 0;
}

