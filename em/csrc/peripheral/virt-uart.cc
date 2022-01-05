
#if defined(_WIN32) || defined(__CYGWIN__)
#include <Windows.h>
static HANDLE ser;
#else
#warning virtual UART only supported on win32.
#endif

#include "common.hh"
#include "virt-uart.hh"

static bool inited, in_difftest;
static char dat;
static bool dat_pending_for_difftest;

int virt_uart_init(const char *filename, bool in_difftest_)
{
    in_difftest |= in_difftest_;
    if (inited | in_difftest_)
        return 0;
    inited = true;
    
#if defined(_WIN32) || defined(__CYGWIN__)
    ser = CreateFileA(filename, GENERIC_READ | GENERIC_WRITE, 0, NULL, OPEN_EXISTING, 0, NULL);
    if (ser == INVALID_HANDLE_VALUE)
    {
        fprintf(stderr, "failed to open virtual UART\n");
        return 1;
    }

    DCB dcb;
    if (!GetCommState(ser, &dcb))
    {
        fprintf(stderr, "Failed on %s\n", __func__);
        return 1;
    }

    dcb.BaudRate = 115200;
    dcb.fBinary = TRUE;
    dcb.ByteSize = 8; // 8 data bits
    dcb.StopBits = ONESTOPBIT;
    dcb.fParity = FALSE;
    dcb.Parity = NOPARITY;
    ;
    dcb.fOutxCtsFlow = FALSE;
    dcb.fOutxDsrFlow = FALSE;
    dcb.fDtrControl = DTR_CONTROL_ENABLE; //DTR控制
    dcb.fDsrSensitivity = FALSE;
    dcb.fTXContinueOnXoff = FALSE; //
    dcb.fOutX = FALSE;             //no XON/XOFF
    dcb.fInX = FALSE;              //no XON/XOFF
    dcb.fErrorChar = FALSE;
    dcb.fNull = FALSE;
    dcb.fRtsControl = RTS_CONTROL_ENABLE;
    dcb.fAbortOnError = FALSE;

    if (!SetCommState(ser, &dcb))
    {
        fprintf(stderr, "Failed on %s\n", __func__);
        return 1;
    }
#else
    return 0;
#endif
#ifdef VIRT_UART_SETBK
    virt_uart_write(" \033[2J\033[0m\033[37;40m");
    virt_uart_write("\r\nVirtual UART started.\r\n");
#endif
    return 0;
}

void virt_uart_putch(char ch)
{
#if defined(_WIN32) || defined(__CYGWIN__)
    WriteFile(ser, &ch, 1, NULL, NULL);
#endif
    putchar(ch);
}

void virt_uart_write(const char *buf)
{
    while (*buf)
    {
        virt_uart_putch(*buf++);
    }
}

int virt_uart_poll_read(char *ch)
{
    if (dat_pending_for_difftest)
    {
        *ch = dat;
        dat_pending_for_difftest = false;
        return 1;
    }

#if defined(_WIN32) || defined(__CYGWIN__)
    COMSTAT stat;
    DWORD error;

    if (ClearCommError(ser, &error, &stat) && error > 0)
    {
        PurgeComm(ser, PURGE_RXABORT | PURGE_RXCLEAR);
        fprintf(stderr, "Failed on ClearCommError\n");
        return 0;
    }

    if (stat.cbInQue)
    {
        DWORD len = 0;
        OVERLAPPED overlapped;
        memset(&overlapped, 0, sizeof(OVERLAPPED));

        if (!ReadFile(ser, ch, 1, &len, &overlapped))
        {
            if (GetLastError() == ERROR_IO_PENDING) // End async I/O
            {
                //WaitForSingleObject(overlapped.hEvent, time_wait); // wait for 20ms
                if (!GetOverlappedResult(ser, &overlapped, &len, FALSE))
                {
                    if (GetLastError() != ERROR_IO_INCOMPLETE) // other error
                        return 0;
                }
            }
            else
                return 0;
        }
        if (len && in_difftest)
        {
            dat = *ch;
            dat_pending_for_difftest = true;
        }
        return len;
    }
    return 0;
#else
    return 0;
#endif
}