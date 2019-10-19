#define BE_STREAM_TO_UINT32(u32, p) {u32 = ((uint32_t)(*((p) + 3)) + ((uint32_t)(*((p) + 2)) << 8) + ((uint32_t)(*((p) + 1)) << 16) + ((uint32_t)(*(p)) << 24)); (p) += 4;}
#define UINT16TOBE2(p, ui) (p)[0]=(uint8_t)((ui)>>8); (p)[1]=(uint8_t)(ui)

#include "platform.h"
