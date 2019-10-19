#include "platform.h"

/**
 * Smart mesh trace functions to increase the code portability
 */
extern void LOG0(int debug, const char *p_str);
extern void LOG1(int debug, const char *fmt_str, uint32_t p1);
extern void LOG2(int debug, const char *fmt_str, uint32_t p1, uint32_t p2);
extern void LOG3(int debug, const char *fmt_str, uint32_t p1, uint32_t p2, uint32_t p3);
extern void LOG4(int debug, const char *fmt_str, uint32_t p1, uint32_t p2, uint32_t p3, uint32_t p4);
extern void LOG5(int debug, const char *fmt_str, uint32_t p1, uint32_t p2, uint32_t p3, uint32_t p4,
                 uint32_t p5);
extern void LOG6(int debug, const char *fmt_str, uint32_t p1, uint32_t p2, uint32_t p3, uint32_t p4,
                 uint32_t p5, uint32_t p6);
extern void LOGN(int debug, char *p_str, uint32_t len);
