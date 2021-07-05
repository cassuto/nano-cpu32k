#ifndef LOG_H_
#define LOG_H_

extern void log_char(char ch);
extern void log_msg(const char *msg);
extern void log_num(unsigned int n);
extern void log_hex(unsigned int n);
extern void log_dump_memory(const unsigned char *buf, int size);

#endif // LOG_H_
