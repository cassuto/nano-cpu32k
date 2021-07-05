#ifndef CRC16_H_
#define CRC16_H_

extern void init_crc16();
extern unsigned short crc16(const unsigned char *buff, int len);

#endif /* CRC16_H_ */
