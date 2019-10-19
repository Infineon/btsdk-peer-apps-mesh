/*
* Copyright 2019, Cypress Semiconductor Corporation or a subsidiary of
* Cypress Semiconductor Corporation. All Rights Reserved.
*
* This software, including source code, documentation and related
* materials ("Software"), is owned by Cypress Semiconductor Corporation
* or one of its subsidiaries ("Cypress") and is protected by and subject to
* worldwide patent protection (United States and foreign),
* United States copyright laws and international treaty provisions.
* Therefore, you may use this Software only as provided in the license
* agreement accompanying the software package from which you
* obtained this Software ("EULA").
* If no EULA applies, Cypress hereby grants you a personal, non-exclusive,
* non-transferable license to copy, modify, and compile the Software
* source code solely for use in connection with Cypress's
* integrated circuit products. Any reproduction, modification, translation,
* compilation, or representation of this Software except as specified
* above is prohibited without the express written permission of Cypress.
*
* Disclaimer: THIS SOFTWARE IS PROVIDED AS-IS, WITH NO WARRANTY OF ANY KIND,
* EXPRESS OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, NONINFRINGEMENT, IMPLIED
* WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. Cypress
* reserves the right to make changes to the Software without notice. Cypress
* does not assume any liability arising out of the application or use of the
* Software or any product or circuit described in the Software. Cypress does
* not authorize its products for use in any products where a malfunction or
* failure of the Cypress product may reasonably be expected to result in
* significant property damage, injury or death ("High Risk Product"). By
* including Cypress's product in a High Risk Product, the manufacturer
* of such system or application assumes all risk of such use and in doing
* so agrees to indemnify Cypress against all liability.
*/

/** @file
*
* Mesh Main implementation.
*/

#define _CRT_RAND_S

#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdlib.h>

#include "platform.h"

#include "wiced_result.h"

//#include "ccm.h"
#include "aes_cmac.h"

#include "mesh_main.h"
#include "mesh_core.h"
#include "core_aes_ccm.h"
#include "mesh_util.h"
#include "provisioning_int.h"
#include "ecdh.h"
#include "lower_transport_layer.h"
#include "key_refresh.h"
#include "network_layer.h"
#include "access_layer.h"
#include "foundation.h"
#include "pb_transport.h"
#include "low_power.h"
#include "friend.h"
#include "wiced_timer.h"
#include "wiced_bt_mesh_models.h"
#include "mesh_discovery.h"
#include "clock_timer.h"
#include "health.h"
#include "hci_control_api.h"
#include "wiced_bt_trace.h"
#include "wiced_bt_ble.h"
#include "wiced_bt_gatt.h"


typedef void (TIMER_CBACK)(void *p_tle);
#define TIMER_PARAM_TYPE    void *
extern void execute_timer_callback(TIMER_CBACK *p_callback, TIMER_PARAM_TYPE arg);

#define TIMER_ACTIVE          0x0001

typedef struct _tle
{
    struct _tle  *p_next;
    TIMER_CBACK  *p_cback;
    UINT16        flags;                /* Flags for timer*/
    UINT16        type;
    UINT32        interval;             /* Periodical time out inteval, in 1 us unit */
    TIMER_PARAM_TYPE arg;               /* parameter for expiration function */
    UINT64        target_time;          /* Target time for timer expire, in us */
} TIMER_LIST_ENT;

static TIMER_LIST_ENT *pOsTimerHead = NULL;
static UINT64       absTimeHi = 0;
static void timerThread(void *arg);
static HANDLE   sleepHandle;

extern void wiced_bt_ble_set_scan_mode(uint8_t is_active);
extern wiced_bool_t mesh_adv_scan_start(void);
extern wiced_bool_t mesh_bt_gatt_le_connect(wiced_bt_device_address_t bd_addr, wiced_bt_ble_address_type_t bd_addr_type,
    wiced_bt_ble_conn_mode_t conn_mode, wiced_bool_t is_direct);
extern wiced_bool_t mesh_bt_gatt_le_disconnect(uint32_t conn_id);

extern CRITICAL_SECTION cs;

void ods(char * fmt_str, ...)
{
    char buf[1000] = { 0 };
    va_list marker = NULL;

    va_start(marker, fmt_str);

    SYSTEMTIME st;
    GetLocalTime(&st);

    int len = sprintf_s(buf, sizeof(buf), "%02d:%02d:%02d.%03d ", st.wHour, st.wMinute, st.wSecond, st.wMilliseconds);
    vsnprintf_s(&buf[len], sizeof(buf) - len, _TRUNCATE, fmt_str, marker);
    va_end(marker);

    if(buf[strlen(buf) - 1] != '\n')
        strcat_s(buf, sizeof(buf), "\n");
    OutputDebugStringA(buf);
}

int wiced_printf(char * buffer, int len, char * fmt_str, ...)
{
    char buf[2048];
    va_list va;
    va_start(va, fmt_str);
    vsprintf_s(buf, sizeof(buf), fmt_str, va);
    ods(buf);
    va_end(va);
    return 0;
}
/**
* mesh trace functions.
* These are just wrapper function for WICED trace function call. We use these
* wrapper functions to make the mesh code easier to port on different platforms.
*/
void ble_trace0(const char *p_str)
{
    ods((char *)p_str);
}

void ble_trace1(const char *fmt_str, UINT32 p1)
{
    ods((char *)fmt_str, p1);
}

void ble_trace2(const char *fmt_str, UINT32 p1, UINT32 p2)
{
    ods((char *)fmt_str, p1, p2);
}

void ble_trace3(const char *fmt_str, UINT32 p1, UINT32 p2, UINT32 p3)
{
    ods((char *)fmt_str, p1, p2, p3);
}

void ble_trace4(const char *fmt_str, UINT32 p1, UINT32 p2, UINT32 p3, UINT32 p4)
{
    ods((char *)fmt_str, p1, p2, p3, p4);
}

void ble_tracen(const char *p_str, UINT32 len)
{
    char buf[100];
    memset(buf, 0, sizeof(buf));
    unsigned int i;
    while (len)
    {
        for (i = 0; i < len && i < 16; i++)
            sprintf_s(&buf[3 * i], 100 - (3 * i), "%02x ", (UINT8)p_str[i]);
        buf[3 * i] = 0;
        ods(buf);
        len -= i;
        p_str += i;
    }
}

void* wiced_memory_permanent_allocate(UINT32 length)
{
    return malloc(length);
}
void wiced_memory_free(void *memoryBlock)
{
    free(memoryBlock);
}

void *wiced_bt_get_buffer(uint16_t len)
{
    return malloc(len);
}
void wiced_bt_free_buffer(void* buffer)
{
    free(buffer);
}

#if 0
/**
* Application should implement this function and return milliseconds passed since start or any other moment.
*
* Parameters:   None
*
*   Return:     Milliseconds passed since start or any other moment
*/
uint64_t wiced_bt_mesh_core_get_tick_count()
{
    return GetTickCount64();
}
#endif

uint64_t clock_SystemTimeMicroseconds64(void)
{
    return GetTickCount64() * 1000;
}

static wiced_timer_t *wiced_timer_first = NULL;

wiced_result_t wiced_init_timer(wiced_timer_t* p_timer, wiced_timer_callback_fp TimerCb, TIMER_PARAM_TYPE cBackparam, wiced_timer_type_t type)
{
    TIMER_LIST_ENT *p = (TIMER_LIST_ENT *)p_timer;

    ods("wiced_init_timer p_timer:%x\n", p_timer);

    memset(p_timer, 0, sizeof(TIMER_LIST_ENT));
    p->p_cback  = TimerCb;
    p->arg      = cBackparam;
    p->type     = type;
    p->interval = 0;

    return WICED_BT_SUCCESS;
}

wiced_result_t wiced_deinit_timer(wiced_timer_t* p)
{
    ods("wiced_deinit_timer:%x\n", p);
    return WICED_BT_SUCCESS;
}

wiced_result_t wiced_start_timer(wiced_timer_t* wt, uint32_t timeout)
{
    TIMER_LIST_ENT *p_timer = (TIMER_LIST_ENT *)wt;
    TIMER_LIST_ENT  *p_cur, *p_prev;
    UINT32          cur_tc, expire_tc;

    // This could be done more elegantly in a final product...
    static BOOL threadStarted = FALSE;
    if (!threadStarted)
    {
        DWORD   thread_address;
        threadStarted = TRUE;

        sleepHandle = CreateEvent (NULL, FALSE, FALSE, NULL);

        CreateThread(0, 0, (LPTHREAD_START_ROUTINE)timerThread, (LPVOID)1, 0, &thread_address);
    }
    EnterCriticalSection(&cs);

    // ods("wiced_start_timer:%x timeout:%d\n", p_timer, timeout);

    // Make sure that we are not starting the same timer twice.
    wiced_stop_timer(wt);

    p_timer->interval = timeout;

    if (p_timer->type == WICED_SECONDS_TIMER || p_timer->type == WICED_SECONDS_PERIODIC_TIMER)
        timeout *= 1000;

    cur_tc = GetTickCount();
    expire_tc = cur_tc + timeout;   // interval is in milliseconds, convert to ms

    p_timer->target_time = absTimeHi + expire_tc;

    // Check for rollover of the 32-bit tick count
    if (expire_tc < cur_tc)
        p_timer->target_time += 0x100000000;

    // Put the timer in the appropriate place
    if ((pOsTimerHead == NULL) || (pOsTimerHead->target_time > p_timer->target_time))
    {
        // New timer goes at start of list
        p_timer->p_next = pOsTimerHead;
        pOsTimerHead = p_timer;
    }
    else
    {
        p_prev = pOsTimerHead;
        p_cur = p_prev->p_next;

        for (; ; )
        {
            if (p_cur == NULL)
            {
                // New timer goes at end of list
                p_prev->p_next = p_timer;
                p_timer->p_next = NULL;
                break;
            }
            if (p_cur->target_time > p_timer->target_time)
            {
                // New timer goes in the middle of the list
                p_prev->p_next  = p_timer;
                p_timer->p_next = p_cur;
                break;
            }
            p_prev = p_cur;
            p_cur = p_prev->p_next;
        }
    }

    p_timer->flags |= TIMER_ACTIVE;

    LeaveCriticalSection(&cs);

    SetEvent (sleepHandle);

    return WICED_BT_SUCCESS;
}

wiced_result_t wiced_stop_timer(wiced_timer_t* wt)
{
    TIMER_LIST_ENT *p_timer = (TIMER_LIST_ENT *)wt;
    TIMER_LIST_ENT *pt;

    // ods("wiced_stop_timer:%x\n", p_timer);

    EnterCriticalSection(&cs);

    p_timer->flags &= ~TIMER_ACTIVE;

    if (p_timer == pOsTimerHead)
    {
        pOsTimerHead = pOsTimerHead->p_next;
        LeaveCriticalSection(&cs);
        SetEvent (sleepHandle);
        return (0);
    }

    /* Find timer in the queue */
    for (pt = pOsTimerHead; pt != NULL; pt = pt->p_next)
        if (pt->p_next == p_timer)
            break;

    if (pt != NULL)
        pt->p_next = p_timer->p_next;

    LeaveCriticalSection(&cs);

    SetEvent (sleepHandle);

    return WICED_BT_SUCCESS;
}

wiced_bool_t wiced_is_timer_in_use(wiced_timer_t *p)
{
    TIMER_LIST_ENT *p_timer = (TIMER_LIST_ENT *)p;
    if (p_timer->flags & TIMER_ACTIVE)
        return WICED_TRUE;
    else
        return WICED_FALSE;
}

void wiced_release_timer(wiced_bt_mesh_event_t *p_event)
{
    TIMER_LIST_ENT *p_timer = (TIMER_LIST_ENT *)&p_event->timer;
    ods("!!!wiced_release_timer:%x\n", p_timer);
    wiced_stop_timer((wiced_timer_t *)p_timer);
}

static void timerThread(void *arg)
{
    UINT32          last_tc, cur_tc, sleep_time;
    UINT64          cur_absTime;
    TIMER_LIST_ENT  *pTimer;

    SetThreadPriority(GetCurrentThread(), THREAD_PRIORITY_TIME_CRITICAL);

    for ( ; ; )
    {
        last_tc = GetTickCount();
        cur_absTime = absTimeHi + last_tc;

        if (pOsTimerHead != NULL)
        {
            if (pOsTimerHead->target_time < cur_absTime)
                sleep_time = 0;
            else
                sleep_time = (UINT32)(pOsTimerHead->target_time - cur_absTime);
        }
        else
            sleep_time = 60000;        // 1 minute is small enough to detect rollovers

        if (sleep_time != 0)
            WaitForSingleObject (sleepHandle, sleep_time);

        EnterCriticalSection(&cs);

        cur_tc = GetTickCount();

        // Check for rollover - this assumes no timer is more than 49 days
        if (cur_tc < last_tc)
            absTimeHi += 0x100000000;

        cur_absTime = absTimeHi + cur_tc;

        // Check if the first timer on the list has expired
        if ((pOsTimerHead != NULL) && (pOsTimerHead->target_time <= cur_absTime))
        {
            pTimer = pOsTimerHead;

            // Check for periodic timer
            if ((pTimer->type == WICED_SECONDS_PERIODIC_TIMER) || (pTimer->type == WICED_MILLI_SECONDS_PERIODIC_TIMER))
                wiced_start_timer ((wiced_timer_t *)pTimer, pTimer->interval);
            else
                wiced_stop_timer ((wiced_timer_t *)pTimer);

            LeaveCriticalSection(&cs);

            execute_timer_callback(pTimer->p_cback, pTimer->arg);
        }
        else
        {
            LeaveCriticalSection(&cs);
        }
    }
}

// empty functions not needed in MeshController

// ------------------- advertisements functions - not needed for now --------------------
// it should be defined somewhere else
typedef struct
{
    uint16_t    opcode;
    uint16_t    param_len;
    uint8_t     *p_param_buf;
} tBTM_VSC_CMPL;
typedef void (tBTM_VSC_CMPL_CB)(tBTM_VSC_CMPL *p1);
typedef uint8_t tBTM_STATUS;
tBTM_STATUS BTM_VendorSpecificCommand(UINT16 opcode, uint8_t param_len, uint8_t *p_param_buf, tBTM_VSC_CMPL_CB *p_cb)
{
    return 1;
}
//--------------------- end of advertisements functions --------------------

void mesh_discovery_start(void)
{
}

void mesh_update_beacon(void)
{
}

void wiced_hal_wdog_reset_system(void)
{
}

void mesh_discovery_stop(void)
{
}

void provision_gatt_send(uint16_t conn_id, const uint8_t *packet, uint32_t packet_len)
{
}

void mesh_provisioner_hci_event_scan_report_send(wiced_bt_mesh_event_t *p_event, wiced_bt_mesh_provision_scan_report_data_t *p_scan_report_data)
{

}

/*
* Send Proxy Device Network Data event over transport
*/
void mesh_provisioner_hci_event_proxy_device_send(wiced_bt_mesh_proxy_device_network_data_t *p_data)
{

}

wiced_bt_dev_status_t wiced_bt_ble_observe(wiced_bool_t start, uint8_t duration, wiced_bt_ble_scan_result_cback_t *p_scan_result_cback)
{
    if (start)
    {
//        mesh_adv_publish_start();
        mesh_adv_scan_start();
    }
    else
    {
//        mesh_adv_publish_stop();
        mesh_adv_scan_stop();
    }

    return WICED_SUCCESS;
}

wiced_bt_gatt_status_t wiced_bt_gatt_register(wiced_bt_gatt_cback_t *p_gatt_cback)
{
    return WICED_TRUE;
}

wiced_bool_t wiced_bt_gatt_le_connect(wiced_bt_device_address_t bd_addr,
    wiced_bt_ble_address_type_t bd_addr_type,
    wiced_bt_ble_conn_mode_t conn_mode,
    wiced_bool_t is_direct)
{
    ods("wiced_bt_gatt_le_connect\n");
    return mesh_bt_gatt_le_connect(bd_addr, bd_addr_type, conn_mode, is_direct);
}

wiced_bool_t wiced_bt_gatt_cancel_connect(wiced_bt_device_address_t bd_addr, wiced_bool_t is_direct)
{
    return WICED_TRUE;
}


wiced_bt_gatt_status_t wiced_bt_gatt_disconnect(uint16_t conn_id)
{
    return mesh_bt_gatt_le_disconnect(conn_id);
}

wiced_bt_gatt_status_t wiced_bt_gatt_configure_mtu(uint16_t conn_id, uint16_t mtu)
{
    return WICED_BT_GATT_SUCCESS;
}

wiced_bt_gatt_status_t wiced_bt_util_send_gatt_discover(uint16_t conn_id, wiced_bt_gatt_discovery_type_t type, uint16_t uuid, uint16_t s_handle, uint16_t e_handle)
{
    return WICED_BT_GATT_SUCCESS;
}

wiced_bt_gatt_status_t wiced_bt_util_set_gatt_client_config_descriptor(uint16_t conn_id, uint16_t handle, uint16_t value)
{
    return WICED_BT_GATT_SUCCESS;
}
