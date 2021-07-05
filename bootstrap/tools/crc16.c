#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

#define KERNEL_SIZE (8*1024*1024) // 0x1000000-2 /* 16MB - 2B CRC*/

#define CRC_POLY 0x1021

unsigned short PTR_TBL[256];

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


int main(int argc, char *argv[]) {
	if (argc < 2) {
		return 1;
	}
  FILE *fp = fopen(argv[1], "rb");
	if (!fp) {
		perror("fopen");
		return 1;
	}
	fseek(fp, 0, SEEK_END);
	long int sz = ftell(fp);
	fseek(fp, 0, SEEK_SET);
	assert(sz <= KERNEL_SIZE);
	char *buf = (char*)malloc(KERNEL_SIZE);
	memset(buf, 0xff, KERNEL_SIZE);
	fread(buf, 1, sz, fp);
	fclose(fp);
  
  init_crc16();
  unsigned short crc = crc16(buf, KERNEL_SIZE);
  printf("checksum=0x%x\n", crc);
  return 0;
}
