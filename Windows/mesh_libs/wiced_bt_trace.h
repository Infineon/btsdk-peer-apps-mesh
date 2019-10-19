#ifdef __cplusplus
extern "C"
{
#endif

void ods(char * fmt_str, ...);
void ble_tracen(const char *p_str, UINT32 len);

#ifdef __cplusplus
}
#endif

#define WICED_BT_TRACE ods
#define WICED_BT_TRACE_ARRAY(p_str, len, s) ble_tracen(p_str, len)
