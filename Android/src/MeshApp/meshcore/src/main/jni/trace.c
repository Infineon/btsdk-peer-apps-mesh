#include <android/log.h>
#include <platform.h>
#include <stdio.h>

#ifndef MESHAPP_TRACE_H
#define MESHAPP_TRACE_H

#define  Log(...)  __android_log_print(ANDROID_LOG_ERROR,LOG_TAG,__VA_ARGS__)
#define LOG_TAG "MeshJni"
#endif //MESHAPP_TRACE_H

void LOG0(int debug, const char *p_str)
{
    //Log(0,p_str);
}

void LOG1(int debug, const char *fmt_str, uint32_t p1)
{
    //Log(fmt_str, p1);
}

void LOG2(int debug, const char *fmt_str, uint32_t p1, uint32_t p2)
{
   // Log(fmt_str, p1, p2);
}

void LOG3(int debug, const char *fmt_str, uint32_t p1, uint32_t p2, uint32_t p3)
{
    //Log(fmt_str, p1, p2, p3);
}

void LOG4(int debug, const char *fmt_str, uint32_t p1, uint32_t p2, uint32_t p3, uint32_t p4)
{
    //Log(fmt_str, p1, p2, p3, p4);
}

void LOG5(int debug, const char *fmt_str, uint32_t p1, uint32_t p2, uint32_t p3, uint32_t p4, uint32_t p5)
{
   // Log(fmt_str, p1, p2, p3, p4, p5);
}

void LOG6(int debug, const char *fmt_str, uint32_t p1, uint32_t p2, uint32_t p3, uint32_t p4, uint32_t p5,
          uint32_t p6)
{
   // Log(fmt_str, p1, p2, p3, p4, p5, p6);
}

void LOGN(int debug, char *p_str, uint32_t len)
{
//    int i;
//    for( i=0; i<len; i++){
//        Log("%x",*p_str);
//        p_str++;
//    }
}

#if 0
int WICED_BT_TRACE(char * buffer, int len, char * fmt_str, ...)
{
    char buf[2048];
    va_list va;
    va_start(va, fmt_str);
    LOG(buf, sizeof(buf), fmt_str, va);
    va_end(va);
    return 0;
}
#endif