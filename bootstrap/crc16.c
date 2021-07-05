#include "config.h"
#include "crc16.h"

#define CRC_POLY 0x1021

#define PTR_TBL ((unsigned short *)CRC16_TBL_ADDRESS) /* Allocated in DRAM area */

void init_crc16()
{
   /* generate CRC16 table */
   /* https://stackoverflow.com/questions/44131951/how-to-generate-16-bit-crc-table-from-a-polynomial */
	unsigned short c;
	int i,j;
	for(i=0; i<256; ++i) {
		c = (i << 8);
		for(j=0; j<8; ++j) {
         if (c & 0x8000)
           c = (c << 1) ^ CRC_POLY;
         else
           c <<= 1;
		}
		PTR_TBL[i] = c;
	}
}

unsigned short crc16(const unsigned char *buf, int len)
{
	unsigned short crc = 0xFFFF; /* CRC-16/CCITT: 0xFFFF; CRC-16/AUG-CCITT: 0x1D0F */
	while(len--) {
      crc = PTR_TBL[((crc >> 8) ^ *buf++) & 0xff] ^ (crc << 8);
	}
	return crc;
}
