#include <stdarg.h>
#include "coremark.h"
#include "msr.h"

#if VALIDATION_RUN
	volatile ee_s32 seed1_volatile=0x3415;
	volatile ee_s32 seed2_volatile=0x3415;
	volatile ee_s32 seed3_volatile=0x66;
#endif

#if PERFORMANCE_RUN
	volatile ee_s32 seed1_volatile=0x0;
	volatile ee_s32 seed2_volatile=0x0;
	volatile ee_s32 seed3_volatile=0x66;
#endif

#if PROFILE_RUN
	volatile ee_s32 seed1_volatile=0x8;
	volatile ee_s32 seed2_volatile=0x8;
	volatile ee_s32 seed3_volatile=0x8;
#endif

volatile ee_s32 seed4_volatile=ITERATIONS;
volatile ee_s32 seed5_volatile=0;

static CORE_TICKS t0, t1;

static inline unsigned long get_timer_freq(void)
{
  return 250000000; /* 250MHz */
}

static inline unsigned long get_cycle_value(void)
{
  return rmsr(MSR_TSR);
}

void start_time(void)
{
  t0 = get_cycle_value();
}

void stop_time(void)
{
  t1 = get_cycle_value();
}

CORE_TICKS get_time(void)
{
  return t1 - t0;
}

secs_ret time_in_secs(CORE_TICKS ticks)
{
  int scale = 256;
  uint32_t delta = ticks / scale;
  uint32_t freq = get_timer_freq() / scale;
  return delta / (double)freq;
}

void abort(void)
{
  while(1); /* noreturn */
}

#define _USE_LONGLONG   0   /* 1: Enable long long integer in type "ll". */
#define _LONGLONG_t     long long   /* Platform dependent long long integer type */

#define _USE_XFUNC_IN   1   /* 1: Use input function */
#define _LINE_ECHO      1   /* 1: Echo back input chars in xgets function */

#define DW_CHAR     sizeof(char)
#define DW_SHORT    sizeof(short)
#define DW_LONG     sizeof(long)

/** Put a character to MSGPORT */
static void
ncpu32k_putc(char c)
{
  wmsr(MSR_DBGR_MSGPORT, c);
}
static void
ncpu32k_puts (const char *str)
{
  while (*str)
    {
      ncpu32k_putc(*str++);
    }
}

static
void
ncpu32k_xvprintf( const char* fmt, va_list arp )
{
  unsigned int r, i, j, w, f;
  char s[24], c, d, *p;
#if _USE_LONGLONG
  _LONGLONG_t v;
  unsigned _LONGLONG_t vs;
#else
  long v;
  unsigned long vs;
#endif

  for (;;)
    {
      c = *fmt++;                 /* Get a format character */
      if (!c) break;              /* End of format? */
      if (c != '%')               /* Pass it through if not a % sequense */
        {
          ncpu32k_putc(c);
          continue;
        }
      f = 0;                      /* Clear flags */
      c = *fmt++;                 /* Get first char of the sequense */
      if (c == '0')               /* Flag: left '0' padded */
        {
          f = 1; c = *fmt++;
        }
      else
        {
          if (c == '-')           /* Flag: left justified */
            {
              f = 2; c = *fmt++;
            }
        }
      for (w = 0; c >= '0' && c <= '9'; c = *fmt++)  /* Minimum width */
        {
          w = w * 10 + c - '0';
        }
      if (c == 'l' || c == 'L')   /* Prefix: Size is long */
        {
          f |= 4; c = *fmt++;
#if _USE_LONGLONG
          if (c == 'l' || c == 'L')   /* Prefix: Size is long long */
            {
              f |= 8; c = *fmt++;
            }
#endif
        }
      if (!c) break;              /* End of format? */
      d = c;
      if (d >= 'a') d -= 0x20;
      switch (d)                  /* Type is... */
      {
      case 'S' :                  /* String */
        {
          p = va_arg(arp, char*);
          for (j = 0; p[j]; j++) ;
          while (!(f & 2) && j++ < w) ncpu32k_putc(' ');
          ncpu32k_puts(p);
          while (j++ < w) ncpu32k_putc(' ');
          continue;
        }
      case 'C' :                  /* Character */
          ncpu32k_putc((char)va_arg(arp, int)); continue;
      case 'B' :                  /* Binary */
          r = 2; break;
      case 'O' :                  /* Octal */
          r = 8; break;
      case 'D' :                  /* Signed decimal */
      case 'U' :                  /* Unsigned decimal */
          r = 10; break;
      case 'X' :                  /* Hexdecimal */
          r = 16; break;
      default:                    /* Unknown type (passthrough) */
          ncpu32k_putc(c); continue;
      }

      /* Get an argument and put it in numeral */
#if _USE_LONGLONG
      if (f & 8)      /* long long argument? */
        {
          v = va_arg(arp, _LONGLONG_t);
        }
      else
        {
          if (f & 4)      /* long argument? */
            {
              v = (d == 'D') ? (long)va_arg(arp, long) : (long)va_arg(arp, unsigned long);
            }
          else          /* int/short/char argument */
            {
              v = (d == 'D') ? (long)va_arg(arp, int) : (long)va_arg(arp, unsigned int);
            }
        }
#else
      if (f & 4)      /* long argument? */
        {
          v = va_arg(arp, long);
        }
      else          /* int/short/char argument */
        {
          v = (d == 'D') ? (long)va_arg(arp, int) : (long)va_arg(arp, unsigned int);
        }
#endif
      if (d == 'D' && v < 0)      /* Negative value? */
        {
          v = 0 - v; f |= 16;
        }
      i = 0; vs = v;
      do
        {
          d = (char)(vs % r); vs /= r;
          if (d > 9) d += (c == 'x') ? 0x27 : 0x07;
          s[i++] = d + '0';
        }
      while (vs != 0 && i < sizeof s);

      if (f & 16) s[i++] = '-';
      j = i; d = (f & 1) ? '0' : ' ';
      while (!(f & 2) && j++ < w) ncpu32k_putc(d);
      do ncpu32k_putc(s[--i]); while (i != 0);
      while (j++ < w) ncpu32k_putc(' ');
    }
}

/** Put a formatted string to the default device
 * @param fmt Pointer to the format string.
 * @param ... Optional arguments
 */
void
ncpu32k_printf( const char* fmt, ... )
{
  va_list arp;

  va_start(arp, fmt);
  ncpu32k_xvprintf(fmt, arp);
  va_end(arp);
}


