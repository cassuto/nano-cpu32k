#include "memtest.h"
#include "log.h"

int test_mem(unsigned int offset, unsigned int size)
{
	for(int i=offset;i<offset+size;i+=4) {
		*((volatile int*)i) = i;
	}
	for(int i=offset;i<offset+size;i+=4) {
		if(*((volatile int*)i) != i) {
			log_msg("FAIL ");
			log_num(i);
			log_msg(":");
			log_num(*((volatile int*)i));
			log_msg("\n");
			return 1;
		}
	}
	return 0;
}

