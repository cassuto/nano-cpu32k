#ifndef CONFIG_H_
#define CONFIG_H_

#define SERIAL_CONSOLE
//#define MSGPORT_CONSOLE
#define BAUD_RATE 115200

#define MEMTEST
#define MAIN_MEM_START_ADDRESS (0x0)
#define MAIN_MEM_SIZE (32*1024*1024)

#define STACK_SIZE (1024)

#define CHECKSUM_KERNEL

#define KERNEL_LOAD_ADDRESS 0x0
#define KERNEL_FILE_OFFSET 0x0
#define KERNEL_SIZE (8*1024*1024) // 0x1000000-2 /* 16MB - 2B CRC*/
#define CRC16_FILE_OFFSET 0xfffffe /* last 2 bytes of flash */

/* Indicate where to store the CRC16 table (must not be overlapped by kernel image)*/
#define CRC16_TBL_ADDRESS  (KERNEL_LOAD_ADDRESS + KERNEL_SIZE + 0x104)

#endif /* CONFIG_H_ */
