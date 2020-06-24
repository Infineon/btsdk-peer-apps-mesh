/*
 * Copyright 2016-2020, Cypress Semiconductor Corporation or a subsidiary of
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
// WicedHciBridge.cpp : Defines the entry point for the console application.
//

#include "stdafx.h"
#define _WINSOCK_DEPRECATED_NO_WARNINGS TRUE

#include <WinSock2.h>
#include "ControlComm.h"

ComHelper *m_ComHelper;

static void TraceHciPkt(BYTE type, BYTE *buffer, USHORT length);
DWORD WINAPI UdpReceiveThread(LPVOID Context);

#define APP_UDP_PORT 9877
#define SPY_UDP_PORT 9876

#define HCI_CONTROL_GROUP_DEVICE                              0x00
#define HCI_CONTROL_EVENT_WICED_TRACE                       ( ( HCI_CONTROL_GROUP_DEVICE << 8 ) | 0x02 )    /* WICED trace packet */
#define HCI_CONTROL_EVENT_HCI_TRACE                         ( ( HCI_CONTROL_GROUP_DEVICE << 8 ) | 0x03 )    /* Bluetooth protocol trace */

SOCKADDR_IN log_socket_addr;
SOCKADDR_IN app_socket_addr;

SOCKET log_sock = INVALID_SOCKET;
SOCKET app_sock = INVALID_SOCKET;

static char *mesh_opcode_string(unsigned short opcode, unsigned int is_command);
static void DumpData(UINT8 *p_data, UINT32 length, UINT32 max_lines);
static HANDLE m_hMutex;

int main(int argc, char* argv[])
{
    if (argc != 4)
    {
        printf("usage WicedHciBridge <COM port number> <baud_rate> <app IPv4 addr\n");
        return -1;
    }
    long com_port_number = atol(argv[1]);
    long baud_rate = atol(argv[2]);
    int ip[4];
    int i = sscanf_s(argv[3], "%d.%d.%d.%d", &ip[0], &ip[1], &ip[2], &ip[3]);
    if (i != 4)
    {
        printf("usage WicedHciBridge <COM port number> <baud_rate> <app IPv4 addr\n");
        return -1;
    }
    m_ComHelper = new ComHelper();
    if (!m_ComHelper->OpenPort(com_port_number, baud_rate))
    {
        printf("failed to open COM%d\n", com_port_number);
        return -2;
    }

    WSADATA wsaData;
    int err = WSAStartup(MAKEWORD(2, 0), &wsaData);
    if (err != 0)
        return -3;

    log_sock = socket(AF_INET, SOCK_DGRAM, 0);
    if (log_sock == INVALID_SOCKET)
        return -4;

    SOCKADDR_IN socket_addr;

    memset(&socket_addr, 0, sizeof(socket_addr));
    socket_addr.sin_family = AF_INET;
    socket_addr.sin_addr.s_addr = ADDR_ANY;
    socket_addr.sin_port = 0;

    err = bind(log_sock, (SOCKADDR *)&socket_addr, sizeof(socket_addr));
    if (err != 0)
    {
        closesocket(log_sock);
        log_sock = INVALID_SOCKET;
        return -5;
    }

    memset(&log_socket_addr, 0, sizeof(log_socket_addr));
    log_socket_addr.sin_family = AF_INET;
    log_socket_addr.sin_addr.s_addr = ntohl(0x7f000001);
    log_socket_addr.sin_port = SPY_UDP_PORT;

    memset(&app_socket_addr, 0, sizeof(app_socket_addr));
    app_socket_addr.sin_family = AF_INET;
    app_socket_addr.sin_addr.s_addr = (ip[3] << 24) + (ip[2] << 16) + (ip[1] << 8) + ip[0];
    app_socket_addr.sin_port = htons(APP_UDP_PORT);

    SOCKADDR_IN saExt;
//    SOCKET      app_sock;

    /* Open the read and write sockets */
    app_sock = socket(AF_INET, SOCK_DGRAM, 0);
    if (app_sock == INVALID_SOCKET)
    {
        printf("Create UDP recieve socket failed\n");
        return (0);
    }

    // Set socket receive buffer size
    int  buf_size = 1500;
    err = setsockopt(app_sock, SOL_SOCKET, SO_RCVBUF, (CHAR *)&buf_size, sizeof(int));
    if (err == SOCKET_ERROR)
    {
        printf("Set UDP App socket rcv buff size failed.");
        return (0);
    }

    memset(&saExt, 0, sizeof(SOCKADDR_IN));
#if 0
    saExt.sin_family = AF_INET;
    saExt.sin_addr.s_addr = ADDR_ANY;
    saExt.sin_port = APP_UDP_PORT;
#else
    hostent* localHost;
    char* localIP;
    // Get the local host information
    localHost = gethostbyname("");
    localIP = inet_ntoa(*(struct in_addr *)*localHost->h_addr_list);

    // Set up the sockaddr structure
    saExt.sin_family = AF_INET;
    saExt.sin_addr.s_addr = inet_addr(localIP);
    saExt.sin_port = htons(APP_UDP_PORT);
#endif

    err = bind(app_sock, (SOCKADDR *)&saExt, sizeof(SOCKADDR_IN));
    if (err == SOCKET_ERROR)
    {
        printf("UDP App socket bind failed. WSAGetLastError() gets %d.", WSAGetLastError());
        return (0);
    }
    printf("Listening on UDP port: %d\n", APP_UDP_PORT);

    for (; ;)
    {
        int         bytes_rcvd;
        BYTE        buff[1500];
        char          descr[30];

        memset(buff, 0, sizeof(buff));

        bytes_rcvd = recv(app_sock, (char *)buff, 1500, 0);
       // printf("Bytes received: %d\n", bytes_rcvd);
        sprintf_s(descr, sizeof(descr), "Xmit %3u bytes: ", bytes_rcvd);
        if (bytes_rcvd > 0)
        {
            WaitForSingleObject(m_hMutex, INFINITE);
            printf("%s %3d bytes\n", mesh_opcode_string(buff[1] | (buff[2] << 8), 1), bytes_rcvd);
            DumpData(buff + 5, bytes_rcvd - 5, 4);
            m_ComHelper->Write(buff, bytes_rcvd);
            ReleaseMutex(m_hMutex);
        }
    }
    return 0;
}

void HandleWicedEvent(BYTE *p_data, DWORD len)
{
    BYTE *p_data_ori = p_data;
    DWORD lenori = len;

    unsigned short opcode = p_data[1] | (p_data[2] << 8);
    unsigned short len1 = p_data[3] | (p_data[4] << 8);

    WaitForSingleObject(m_hMutex, INFINITE);
    printf("%s %3u bytes\n", mesh_opcode_string(opcode, 0), len - 5);
    DumpData(p_data + 5, len - 5, 4);
    ReleaseMutex(m_hMutex);

    if (opcode == HCI_CONTROL_EVENT_WICED_TRACE)
    {
        p_data += 5;
        len -= 5;

        if (len >= 2)
        {
            if ((len > 2) && (p_data[len - 2] == '\n'))
            {
                p_data[len - 2] = 0;
                len--;
            }
            TraceHciPkt(0, p_data, (USHORT)len);
        }
        return;
    }
    else if (opcode == HCI_CONTROL_EVENT_HCI_TRACE)
    {
        p_data += 5;
        len -= 5;
        TraceHciPkt(p_data[0] + 1, &p_data[1], (USHORT)(len - 1));
        return;
    }

    // Forward the entire packet to the application.
    int length = sendto(app_sock, (const char *)p_data_ori, lenori , 0, (SOCKADDR *)&app_socket_addr, sizeof(SOCKADDR_IN));
}

void HandleHciEvent(BYTE *p_data, DWORD len)
{
}

// mapping between wiced trace types and spy trace types (evt, cmd, rx data, tx data)
static int wiced_trace_to_spy_trace[] = { 0, 4, 3, 6, 7 };

void TraceHciPkt(BYTE type, BYTE *buffer, USHORT length)
{
    static int initialized = FALSE;
    BYTE buf[1100];
    USHORT offset = 0;
    USHORT *p = (USHORT*)buf;

    if (!initialized)
    {
        initialized = TRUE;

        WSADATA wsaData;
        int err = WSAStartup(MAKEWORD(2, 0), &wsaData);
        if (err != 0)
            return;
    }
    if (log_sock == INVALID_SOCKET)
        return;

    if (length > 1024)
        length = 1024;

    *p++ = wiced_trace_to_spy_trace[type];
    *p++ = length;
    *p++ = 0;
    *p++ = 1;
    memcpy(p, buffer, length);

    length = sendto(log_sock, (const char *)buf, length + 8, 0, (SOCKADDR *)&log_socket_addr, sizeof(SOCKADDR_IN));
}

#include "hci_control_api.h"

typedef struct
{
    unsigned short opcode;
    char            *p_name;
} wiced_bt_mesh_opcode_name_t;

wiced_bt_mesh_opcode_name_t command_opcode_name[] = {
    { HCI_CONTROL_MESH_COMMAND_SCAN_UNPROVISIONED                         , "WICED HCI Command Scan unprovisioned" },
    { HCI_CONTROL_MESH_COMMAND_PROVISION_CONNECT                          , "WICED HCI Command Provision connect" },
    { HCI_CONTROL_MESH_COMMAND_PROVISION_DISCONNECT                       , "WICED HCI Command Provision disconnect" },
    { HCI_CONTROL_MESH_COMMAND_PROVISION_START                            , "WICED HCI Command Provision start" },
    { HCI_CONTROL_MESH_COMMAND_PROVISION_OOB_CONFIGURE                    , "WICED HCI Command Provision OOB configure" },
    { HCI_CONTROL_MESH_COMMAND_PROVISION_OOB_VALUE                        , "WICED HCI Command Provision OOB value" },
    { HCI_CONTROL_MESH_COMMAND_SEARCH_PROXY                               , "WICED HCI Command Search proxy" },
    { HCI_CONTROL_MESH_COMMAND_PROXY_CONNECT                              , "WICED HCI Command Proxy connect" },
    { HCI_CONTROL_MESH_COMMAND_PROXY_DISCONNECT                           , "WICED HCI Command Proxy disconnect" },
    { HCI_CONTROL_MESH_COMMAND_PROXY_FILTER_TYPE_SET                      , "WICED HCI Command Proxy filter type set" },
    { HCI_CONTROL_MESH_COMMAND_PROXY_FILTER_ADDRESSES_ADD                 , "WICED HCI Command Proxy filter addresses add" },
    { HCI_CONTROL_MESH_COMMAND_PROXY_FILTER_ADDRESSES_DELETE              , "WICED HCI Command Proxy filter addresses delete" },
    { HCI_CONTROL_MESH_COMMAND_ONOFF_GET                                  , "WICED HCI Command OnOff Get" },
    { HCI_CONTROL_MESH_COMMAND_ONOFF_SET                                  , "WICED HCI Command OnOff Set" },
    { HCI_CONTROL_MESH_COMMAND_LEVEL_GET                                  , "WICED HCI Command Level Get" },
    { HCI_CONTROL_MESH_COMMAND_LEVEL_SET                                  , "WICED HCI Command Level Set" },
    { HCI_CONTROL_MESH_COMMAND_LEVEL_DELTA_SET                            , "WICED HCI Command Level Delta Set" },
    { HCI_CONTROL_MESH_COMMAND_LEVEL_MOVE_SET                             , "WICED HCI Command Level Move Set" },
    { HCI_CONTROL_MESH_COMMAND_DEF_TRANS_TIME_GET                         , "WICED HCI Command Default trans time get" },
    { HCI_CONTROL_MESH_COMMAND_DEF_TRANS_TIME_SET                         , "WICED HCI Command Default trans time set" },
    { HCI_CONTROL_MESH_COMMAND_ONPOWERUP_GET                              , "WICED HCI Command On Power Up get" },
    { HCI_CONTROL_MESH_COMMAND_ONPOWERUP_SET                              , "WICED HCI Command On Power Up get" },
    { HCI_CONTROL_MESH_COMMAND_POWER_LEVEL_GET                            , "WICED HCI Command Power level get" },
    { HCI_CONTROL_MESH_COMMAND_POWER_LEVEL_SET                            , "WICED HCI Command Power level set" },
    { HCI_CONTROL_MESH_COMMAND_POWER_LEVEL_LAST_GET                       , "WICED HCI Command Power level last get" },
    { HCI_CONTROL_MESH_COMMAND_POWER_LEVEL_DEFAULT_GET                    , "WICED HCI Command Power level default get" },
    { HCI_CONTROL_MESH_COMMAND_POWER_LEVEL_DEFAULT_SET                    , "WICED HCI Command Power level default set" },
    { HCI_CONTROL_MESH_COMMAND_POWER_LEVEL_RANGE_GET                      , "WICED HCI Command Power level range get" },
    { HCI_CONTROL_MESH_COMMAND_POWER_LEVEL_RANGE_SET                      , "WICED HCI Command Power level range set" },
    { HCI_CONTROL_MESH_COMMAND_LOCATION_GLOBAL_SET                        , "WICED HCI Command Location global set" },
    { HCI_CONTROL_MESH_COMMAND_LOCATION_LOCAL_SET                         , "WICED HCI Command Location local set" },
    { HCI_CONTROL_MESH_COMMAND_LOCATION_GLOBAL_GET                        , "WICED HCI Command Location global get" },
    { HCI_CONTROL_MESH_COMMAND_LOCATION_LOCAL_GET                         , "WICED HCI Command Location local get" },
    { HCI_CONTROL_MESH_COMMAND_BATTERY_GET                                , "WICED HCI Command Battery get" },
    { HCI_CONTROL_MESH_COMMAND_BATTERY_SET                                , "WICED HCI Command Battery set" },
    { HCI_CONTROL_MESH_COMMAND_PROPERTIES_GET                             , "WICED HCI Command Properties get" },
    { HCI_CONTROL_MESH_COMMAND_PROPERTY_GET                               , "WICED HCI Command Property get" },
    { HCI_CONTROL_MESH_COMMAND_PROPERTY_SET                               , "WICED HCI Command Property set" },
    { HCI_CONTROL_MESH_COMMAND_LIGHT_LIGHTNESS_GET                        , "WICED HCI Command Light Lightness get" },
    { HCI_CONTROL_MESH_COMMAND_LIGHT_LIGHTNESS_SET                        , "WICED HCI Command Light Lightness set" },
    { HCI_CONTROL_MESH_COMMAND_LIGHT_LIGHTNESS_LINEAR_GET                 , "WICED HCI Command Light Lightness linear get" },
    { HCI_CONTROL_MESH_COMMAND_LIGHT_LIGHTNESS_LINEAR_SET                 , "WICED HCI Command Light Lightness linear set" },
    { HCI_CONTROL_MESH_COMMAND_LIGHT_LIGHTNESS_LAST_GET                   , "WICED HCI Command Light Lightness last get" },
    { HCI_CONTROL_MESH_COMMAND_LIGHT_LIGHTNESS_DEFAULT_GET                , "WICED HCI Command Light Lightness default get" },
    { HCI_CONTROL_MESH_COMMAND_LIGHT_LIGHTNESS_DEFAULT_SET                , "WICED HCI Command Light Lightness default set" },
    { HCI_CONTROL_MESH_COMMAND_LIGHT_LIGHTNESS_RANGE_GET                  , "WICED HCI Command Light Lightness range get" },
    { HCI_CONTROL_MESH_COMMAND_LIGHT_LIGHTNESS_RANGE_SET                  , "WICED HCI Command Light Lightness range set" },
    { HCI_CONTROL_MESH_COMMAND_LIGHT_CTL_GET                              , "WICED HCI Command Light CTL get" },
    { HCI_CONTROL_MESH_COMMAND_LIGHT_CTL_SET                              , "WICED HCI Command Light CTL set" },
    { HCI_CONTROL_MESH_COMMAND_LIGHT_CTL_TEMPERATURE_GET                  , "WICED HCI Command Light CTL temperature get" },
    { HCI_CONTROL_MESH_COMMAND_LIGHT_CTL_TEMPERATURE_SET                  , "WICED HCI Command Light CTL temperature set" },
    { HCI_CONTROL_MESH_COMMAND_LIGHT_CTL_TEMPERATURE_RANGE_GET            , "WICED HCI Command Light CTL temperature range get" },
    { HCI_CONTROL_MESH_COMMAND_LIGHT_CTL_TEMPERATURE_RANGE_SET            , "WICED HCI Command Light CTL temperature range set" },
    { HCI_CONTROL_MESH_COMMAND_LIGHT_CTL_DEFAULT_GET                      , "WICED HCI Command Light CTL default get" },
    { HCI_CONTROL_MESH_COMMAND_LIGHT_CTL_DEFAULT_SET                      , "WICED HCI Command Light CTL default set" },
    { HCI_CONTROL_MESH_COMMAND_LIGHT_HSL_GET                              , "WICED HCI Command Light HSL get" },
    { HCI_CONTROL_MESH_COMMAND_LIGHT_HSL_SET                              , "WICED HCI Command Light HSL set" },
    { HCI_CONTROL_MESH_COMMAND_LIGHT_HSL_TARGET_GET                       , "WICED HCI Command Light HSL target get" },
    { HCI_CONTROL_MESH_COMMAND_LIGHT_HSL_RANGE_GET                        , "WICED HCI Command Light HSL range get" },
    { HCI_CONTROL_MESH_COMMAND_LIGHT_HSL_RANGE_SET                        , "WICED HCI Command Light HSL range set" },
    { HCI_CONTROL_MESH_COMMAND_LIGHT_HSL_DEFAULT_GET                      , "WICED HCI Command Light HSL default get" },
    { HCI_CONTROL_MESH_COMMAND_LIGHT_HSL_DEFAULT_SET                      , "WICED HCI Command Light HSL default set" },
    { HCI_CONTROL_MESH_COMMAND_LIGHT_HSL_HUE_GET                          , "WICED HCI Command Light HSL hue get" },
    { HCI_CONTROL_MESH_COMMAND_LIGHT_HSL_HUE_SET                          , "WICED HCI Command Light HSL hue set" },
    { HCI_CONTROL_MESH_COMMAND_LIGHT_HSL_SATURATION_GET                   , "WICED HCI Command Light HSL saturation get" },
    { HCI_CONTROL_MESH_COMMAND_LIGHT_HSL_SATURATION_SET                   , "WICED HCI Command Light HSL saturation set" },
    { HCI_CONTROL_MESH_COMMAND_LIGHT_XYL_GET                              , "WICED HCI Command Light XYL get" },
    { HCI_CONTROL_MESH_COMMAND_LIGHT_XYL_SET                              , "WICED HCI Command Light XYL set" },
    { HCI_CONTROL_MESH_COMMAND_LIGHT_XYL_RANGE_GET                        , "WICED HCI Command Light XYL range get" },
    { HCI_CONTROL_MESH_COMMAND_LIGHT_XYL_RANGE_SET                        , "WICED HCI Command Light XYL range set" },
    { HCI_CONTROL_MESH_COMMAND_LIGHT_XYL_TARGET_GET                       , "WICED HCI Command Light XYL target get" },
    { HCI_CONTROL_MESH_COMMAND_LIGHT_XYL_DEFAULT_GET                      , "WICED HCI Command Light XYL default get" },
    { HCI_CONTROL_MESH_COMMAND_LIGHT_XYL_DEFAULT_SET                      , "WICED HCI Command Light XYL default set" },
    { HCI_CONTROL_MESH_COMMAND_LIGHT_LC_MODE_GET                          , "WICED HCI Command Light LC mode get" },
    { HCI_CONTROL_MESH_COMMAND_LIGHT_LC_MODE_SET                          , "WICED HCI Command Light LC mode set" },
    { HCI_CONTROL_MESH_COMMAND_LIGHT_LC_OCCUPANCY_MODE_GET                , "WICED HCI Command Light LC occupancy mode get" },
    { HCI_CONTROL_MESH_COMMAND_LIGHT_LC_OCCUPANCY_MODE_SET                , "WICED HCI Command Light LC occupance mode set" },
    { HCI_CONTROL_MESH_COMMAND_LIGHT_LC_ONOFF_GET                         , "WICED HCI Command Light LC onoff get" },
    { HCI_CONTROL_MESH_COMMAND_LIGHT_LC_ONOFF_SET                         , "WICED HCI Command Light LC onoff set" },
    { HCI_CONTROL_MESH_COMMAND_LIGHT_LC_PROPERTY_GET                      , "WICED HCI Command Light LC property get" },
    { HCI_CONTROL_MESH_COMMAND_LIGHT_LC_PROPERTY_SET                      , "WICED HCI Command Light LC property set" },
    { HCI_CONTROL_MESH_COMMAND_LIGHT_LC_OCCUPANCY_SET                     , "WICED HCI Command Light LC occupancy set" },
    { HCI_CONTROL_MESH_COMMAND_SENSOR_DESCRIPTOR_GET                      , "WICED HCI Command Sensor description get" },
    { HCI_CONTROL_MESH_COMMAND_SENSOR_CADENCE_GET                         , "WICED HCI Command Sensor cadence get" },
    { HCI_CONTROL_MESH_COMMAND_SENSOR_CADENCE_SET                         , "WICED HCI Command Sensor cadence get" },
    { HCI_CONTROL_MESH_COMMAND_SENSOR_SETTINGS_GET                        , "WICED HCI Command Sensor settings get" },
    { HCI_CONTROL_MESH_COMMAND_SENSOR_SETTING_GET                         , "WICED HCI Command Sensor setting set" },
    { HCI_CONTROL_MESH_COMMAND_SENSOR_GET                                 , "WICED HCI Command Sensor get" },
    { HCI_CONTROL_MESH_COMMAND_SENSOR_COLUMN_GET                          , "WICED HCI Command Sensor column get" },
    { HCI_CONTROL_MESH_COMMAND_SENSOR_SERIES_GET                          , "WICED HCI Command Sensor series get" },
    { HCI_CONTROL_MESH_COMMAND_SENSOR_SETTING_SET                         , "WICED HCI Command Sensor setting set" },
    { HCI_CONTROL_MESH_COMMAND_SENSOR_SET                                 , "WICED HCI Command Sensor set" },
    { HCI_CONTROL_MESH_COMMAND_SENSOR_COLUMN_SET                          , "WICED HCI Command Sensor column set" },
    { HCI_CONTROL_MESH_COMMAND_SENSOR_SERIES_SET                          , "WICED HCI Command Sensor series set" },
    { HCI_CONTROL_MESH_COMMAND_SCENE_STORE                                , "WICED HCI Command scene store" },
    { HCI_CONTROL_MESH_COMMAND_SCENE_RECALL                               , "WICED HCI Command scene recall" },
    { HCI_CONTROL_MESH_COMMAND_SCENE_GET                                  , "WICED HCI Command scene get" },
    { HCI_CONTROL_MESH_COMMAND_SCENE_REGISTER_GET                         , "WICED HCI Command scene register get" },
    { HCI_CONTROL_MESH_COMMAND_SCENE_DELETE                               , "WICED HCI Command scene delete" },
    { HCI_CONTROL_MESH_COMMAND_SCHEDULER_GET                              , "WICED HCI Command scheduler get" },
    { HCI_CONTROL_MESH_COMMAND_SCHEDULER_ACTION_GET                       , "WICED HCI Command scheduler attention get" },
    { HCI_CONTROL_MESH_COMMAND_SCHEDULER_ACTION_SET                       , "WICED HCI Command scheduler attention set" },
    { HCI_CONTROL_MESH_COMMAND_TIME_GET                                   , "WICED HCI Command time get" },
    { HCI_CONTROL_MESH_COMMAND_TIME_SET                                   , "WICED HCI Command time set" },
    { HCI_CONTROL_MESH_COMMAND_TIME_ZONE_GET                              , "WICED HCI Command time zone get" },
    { HCI_CONTROL_MESH_COMMAND_TIME_ZONE_SET                              , "WICED HCI Command time zone set" },
    { HCI_CONTROL_MESH_COMMAND_TIME_TAI_UTC_DELTA_GET                     , "WICED HCI Command time TAI UTC delta get" },
    { HCI_CONTROL_MESH_COMMAND_TIME_TAI_UTC_DELTA_SET                     , "WICED HCI Command time TAI UTC delta set" },
    { HCI_CONTROL_MESH_COMMAND_TIME_ROLE_GET                              , "WICED HCI Command time role get" },
    { HCI_CONTROL_MESH_COMMAND_TIME_ROLE_SET                              , "WICED HCI Command time role set" },
    { HCI_CONTROL_MESH_COMMAND_CONFIG_NODE_RESET                          , "WICED HCI Command Config node reset" },
    { HCI_CONTROL_MESH_COMMAND_CONFIG_BEACON_GET                          , "WICED HCI Command Config beacon get" },
    { HCI_CONTROL_MESH_COMMAND_CONFIG_BEACON_SET                          , "WICED HCI Command Config beacon set" },
    { HCI_CONTROL_MESH_COMMAND_CONFIG_COMPOSITION_DATA_GET                , "WICED HCI Command Config composition data get" },
    { HCI_CONTROL_MESH_COMMAND_CONFIG_DEFAULT_TTL_GET                     , "WICED HCI Command Config default ttl get" },
    { HCI_CONTROL_MESH_COMMAND_CONFIG_DEFAULT_TTL_SET                     , "WICED HCI Command Config default ttl set" },
    { HCI_CONTROL_MESH_COMMAND_CONFIG_GATT_PROXY_GET                      , "WICED HCI Command Config proxy get" },
    { HCI_CONTROL_MESH_COMMAND_CONFIG_GATT_PROXY_SET                      , "WICED HCI Command Config proxy set" },
    { HCI_CONTROL_MESH_COMMAND_CONFIG_RELAY_GET                           , "WICED HCI Command Config relay get" },
    { HCI_CONTROL_MESH_COMMAND_CONFIG_RELAY_SET                           , "WICED HCI Command Config relay set" },
    { HCI_CONTROL_MESH_COMMAND_CONFIG_FRIEND_GET                          , "WICED HCI Command Config friend get" },
    { HCI_CONTROL_MESH_COMMAND_CONFIG_FRIEND_SET                          , "WICED HCI Command Config friend set" },
    { HCI_CONTROL_MESH_COMMAND_CONFIG_HEARBEAT_SUBSCRIPTION_GET           , "WICED HCI Command Config heartbeat subsceription get" },
    { HCI_CONTROL_MESH_COMMAND_CONFIG_HEARBEAT_SUBSCRIPTION_SET           , "WICED HCI Command Config heartbeat subsceription set" },
    { HCI_CONTROL_MESH_COMMAND_CONFIG_HEARBEAT_PUBLICATION_GET            , "WICED HCI Command Config heartbeat publication get" },
    { HCI_CONTROL_MESH_COMMAND_CONFIG_HEARBEAT_PUBLICATION_SET            , "WICED HCI Command Config heartbeat publication set" },
    { HCI_CONTROL_MESH_COMMAND_CONFIG_NETWORK_TRANSMIT_GET                , "WICED HCI Command Config network transmit get" },
    { HCI_CONTROL_MESH_COMMAND_CONFIG_NETWORK_TRANSMIT_SET                , "WICED HCI Command Config network transmit set" },
    { HCI_CONTROL_MESH_COMMAND_CONFIG_MODEL_PUBLICATION_GET               , "WICED HCI Command Config publication get" },
    { HCI_CONTROL_MESH_COMMAND_CONFIG_MODEL_PUBLICATION_SET               , "WICED HCI Command Config publication set" },
    { HCI_CONTROL_MESH_COMMAND_CONFIG_MODEL_SUBSCRIPTION_ADD              , "WICED HCI Command Config subscription add" },
    { HCI_CONTROL_MESH_COMMAND_CONFIG_MODEL_SUBSCRIPTION_DELETE           , "WICED HCI Command Config subscription delete" },
    { HCI_CONTROL_MESH_COMMAND_CONFIG_MODEL_SUBSCRIPTION_OVERWRITE        , "WICED HCI Command Config subscription overwrite" },
    { HCI_CONTROL_MESH_COMMAND_CONFIG_MODEL_SUBSCRIPTION_DELETE_ALL       , "WICED HCI Command Config subscription delete all" },
    { HCI_CONTROL_MESH_COMMAND_CONFIG_MODEL_SUBSCRIPTION_GET              , "WICED HCI Command Config subscription get" },
    { HCI_CONTROL_MESH_COMMAND_CONFIG_NET_KEY_ADD                         , "WICED HCI Command Config net key add" },
    { HCI_CONTROL_MESH_COMMAND_CONFIG_NET_KEY_DELETE                      , "WICED HCI Command Config net key delete" },
    { HCI_CONTROL_MESH_COMMAND_CONFIG_NET_KEY_UPDATE                      , "WICED HCI Command Config net key update" },
    { HCI_CONTROL_MESH_COMMAND_CONFIG_NET_KEY_GET                         , "WICED HCI Command Config net key get" },
    { HCI_CONTROL_MESH_COMMAND_CONFIG_APP_KEY_ADD                         , "WICED HCI Command Config app key add" },
    { HCI_CONTROL_MESH_COMMAND_CONFIG_APP_KEY_DELETE                      , "WICED HCI Command Config app key delete" },
    { HCI_CONTROL_MESH_COMMAND_CONFIG_APP_KEY_UPDATE                      , "WICED HCI Command Config app key update" },
    { HCI_CONTROL_MESH_COMMAND_CONFIG_APP_KEY_GET                         , "WICED HCI Command Config app key overwrite" },
    { HCI_CONTROL_MESH_COMMAND_CONFIG_MODEL_APP_BIND                      , "WICED HCI Command Config model app bind" },
    { HCI_CONTROL_MESH_COMMAND_CONFIG_MODEL_APP_UNBIND                    , "WICED HCI Command Config model app unbind" },
    { HCI_CONTROL_MESH_COMMAND_CONFIG_MODEL_APP_GET                       , "WICED HCI Command Config model app get" },
    { HCI_CONTROL_MESH_COMMAND_CONFIG_NODE_IDENTITY_GET                   , "WICED HCI Command Config node identity get" },
    { HCI_CONTROL_MESH_COMMAND_CONFIG_NODE_IDENTITY_SET                   , "WICED HCI Command Config node identity set" },
    { HCI_CONTROL_MESH_COMMAND_CONFIG_LPN_POLL_TIMEOUT_GET                , "WICED HCI Command Config LPN timeout get" },
    { HCI_CONTROL_MESH_COMMAND_CONFIG_KEY_REFRESH_PHASE_GET               , "WICED HCI Command Config key refresh phase get" },
    { HCI_CONTROL_MESH_COMMAND_CONFIG_KEY_REFRESH_PHASE_SET               , "WICED HCI Command Config key refresh phase set" },
    { HCI_CONTROL_MESH_COMMAND_HEALTH_FAULT_GET                           , "WICED HCI Command Config health fault get" },
    { HCI_CONTROL_MESH_COMMAND_HEALTH_FAULT_CLEAR                         , "WICED HCI Command Config health fault clear" },
    { HCI_CONTROL_MESH_COMMAND_HEALTH_FAULT_TEST                          , "WICED HCI Command Config get" },
    { HCI_CONTROL_MESH_COMMAND_HEALTH_PERIOD_GET                          , "WICED HCI Command Config health period get" },
    { HCI_CONTROL_MESH_COMMAND_HEALTH_PERIOD_SET                          , "WICED HCI Command Config health period set" },
    { HCI_CONTROL_MESH_COMMAND_HEALTH_ATTENTION_GET                       , "WICED HCI Command Config health attention get" },
    { HCI_CONTROL_MESH_COMMAND_HEALTH_ATTENTION_SET                       , "WICED HCI Command Config health attention set" },
    { HCI_CONTROL_MESH_COMMAND_SET_LOCAL_DEVICE                           , "WICED HCI Command Set Local Device" },
    { HCI_CONTROL_MESH_COMMAND_SET_DEVICE_KEY                             , "WICED HCI Command Set Device Key" },
    { HCI_CONTROL_MESH_COMMAND_VENDOR_DATA                                , "WICED HCI Command Vendor Data" },
};

wiced_bt_mesh_opcode_name_t event_opcode_name[] = {
    { HCI_CONTROL_MESH_EVENT_COMMAND_STATUS                               , "WICED HCI Event Command Status" },
    { HCI_CONTROL_MESH_EVENT_ONOFF_SET                                    , "WICED HCI Event OnOff set" },
    { HCI_CONTROL_MESH_EVENT_ONOFF_STATUS                                 , "WICED HCI Event OnOff status" },
    { HCI_CONTROL_MESH_EVENT_LEVEL_SET                                    , "WICED HCI Event Level set" },
    { HCI_CONTROL_MESH_EVENT_LEVEL_STATUS                                 , "WICED HCI Event Level status" },
    { HCI_CONTROL_MESH_EVENT_LOCATION_GLOBAL_SET                          , "WICED HCI Event Location global set" },
    { HCI_CONTROL_MESH_EVENT_LOCATION_LOCAL_SET                           , "WICED HCI Event Location local set" },
    { HCI_CONTROL_MESH_EVENT_LOCATION_GLOBAL_STATUS                       , "WICED HCI Event Location global status" },
    { HCI_CONTROL_MESH_EVENT_LOCATION_LOCAL_STATUS                        , "WICED HCI Event Location local status" },
    { HCI_CONTROL_MESH_EVENT_BATTERY_STATUS                               , "WICED HCI Event Battery status" },
    { HCI_CONTROL_MESH_EVENT_DEF_TRANS_TIME_STATUS                        , "WICED HCI Event Default trans time status" },
    { HCI_CONTROL_MESH_EVENT_POWER_ONOFF_STATUS                           , "WICED HCI Event Power onoff status" },
    { HCI_CONTROL_MESH_EVENT_POWER_LEVEL_SET                              , "WICED HCI Event Power level set" },
    { HCI_CONTROL_MESH_EVENT_POWER_LEVEL_DEFAULT_SET                      , "WICED HCI Event Power level default set" },
    { HCI_CONTROL_MESH_EVENT_POWER_LEVEL_RANGE_SET                        , "WICED HCI Event Power level range set" },
    { HCI_CONTROL_MESH_EVENT_POWER_LEVEL_STATUS                           , "WICED HCI Event Power level status" },
    { HCI_CONTROL_MESH_EVENT_POWER_LEVEL_LAST_STATUS                      , "WICED HCI Event Power level last status" },
    { HCI_CONTROL_MESH_EVENT_POWER_LEVEL_DEFAULT_STATUS                   , "WICED HCI Event Power level default status" },
    { HCI_CONTROL_MESH_EVENT_POWER_LEVEL_RANGE_STATUS                     , "WICED HCI Event Power level range status" },
    { HCI_CONTROL_MESH_EVENT_PROPERTY_SET                                 , "WICED HCI Event Property set" },
    { HCI_CONTROL_MESH_EVENT_PROPERTIES_STATUS                            , "WICED HCI Event Properties status" },
    { HCI_CONTROL_MESH_EVENT_PROPERTY_STATUS                              , "WICED HCI Event Property status" },
    { HCI_CONTROL_MESH_EVENT_LIGHT_LIGHTNESS_SET                          , "WICED HCI Event Light lightness set" },
    { HCI_CONTROL_MESH_EVENT_LIGHT_LIGHTNESS_STATUS                       , "WICED HCI Event Light lightness status" },
    { HCI_CONTROL_MESH_EVENT_LIGHT_LIGHTNESS_LINEAR_STATUS                , "WICED HCI Event Light lightness linear status" },
    { HCI_CONTROL_MESH_EVENT_LIGHT_LIGHTNESS_LAST_STATUS                  , "WICED HCI Event Light lightness last status" },
    { HCI_CONTROL_MESH_EVENT_LIGHT_LIGHTNESS_DEFAULT_STATUS               , "WICED HCI Event Light lightness default status" },
    { HCI_CONTROL_MESH_EVENT_LIGHT_LIGHTNESS_RANGE_STATUS                 , "WICED HCI Event Light lightness range status" },
    { HCI_CONTROL_MESH_EVENT_LIGHT_LIGHTNESS_RANGE_SET                    , "WICED HCI Event Light lightness range set" },
    { HCI_CONTROL_MESH_EVENT_LIGHT_CTL_STATUS                             , "WICED HCI Event Light CTL status" },
    { HCI_CONTROL_MESH_EVENT_LIGHT_CTL_TEMPERATURE_STATUS                 , "WICED HCI Event Light CTL temperature status" },
    { HCI_CONTROL_MESH_EVENT_LIGHT_CTL_TEMPERATURE_RANGE_STATUS           , "WICED HCI Event Light CTL temperature range status" },
    { HCI_CONTROL_MESH_EVENT_LIGHT_CTL_DEFAULT_STATUS                     , "WICED HCI Event Light CTL default status" },
    { HCI_CONTROL_MESH_EVENT_LIGHT_CTL_SET                                , "WICED HCI Event Light CTL set" },
    { HCI_CONTROL_MESH_EVENT_LIGHT_CTL_TEMPERATURE_SET                    , "WICED HCI Event Light CTL temperature set" },
    { HCI_CONTROL_MESH_EVENT_LIGHT_CTL_TEMPERATURE_RANGE_SET              , "WICED HCI Event Light CTL temperature range set" },
    { HCI_CONTROL_MESH_EVENT_LIGHT_CTL_DEFAULT_SET                        , "WICED HCI Event Light CTL default ste" },
    { HCI_CONTROL_MESH_EVENT_LIGHT_HSL_SET                                , "WICED HCI Event Light HSL set" },
    { HCI_CONTROL_MESH_EVENT_LIGHT_HSL_STATUS                             , "WICED HCI Event Light HSL status" },
    { HCI_CONTROL_MESH_EVENT_LIGHT_HSL_TARGET_STATUS                      , "WICED HCI Event Light HSL target status" },
    { HCI_CONTROL_MESH_EVENT_LIGHT_HSL_RANGE_SET                          , "WICED HCI Event Light HSL range set" },
    { HCI_CONTROL_MESH_EVENT_LIGHT_HSL_RANGE_STATUS                       , "WICED HCI Event Light HSL range status" },
    { HCI_CONTROL_MESH_EVENT_LIGHT_HSL_DEFAULT_SET                        , "WICED HCI Event Light HSL default set" },
    { HCI_CONTROL_MESH_EVENT_LIGHT_HSL_DEFAULT_STATUS                     , "WICED HCI Event Light HSL default status" },
    { HCI_CONTROL_MESH_EVENT_LIGHT_HSL_HUE_SET                            , "WICED HCI Event Light HSL hue set" },
    { HCI_CONTROL_MESH_EVENT_LIGHT_HSL_HUE_STATUS                         , "WICED HCI Event Light HSL hue status" },
    { HCI_CONTROL_MESH_EVENT_LIGHT_HSL_SATURATION_SET                     , "WICED HCI Event Light HSL saturation set" },
    { HCI_CONTROL_MESH_EVENT_LIGHT_HSL_SATURATION_STATUS                  , "WICED HCI Event Light HSL saturation status" },
    { HCI_CONTROL_MESH_EVENT_LIGHT_XYL_SET                                , "WICED HCI Event Light XYL set" },
    { HCI_CONTROL_MESH_EVENT_LIGHT_XYL_STATUS                             , "WICED HCI Event Light XYL status" },
    { HCI_CONTROL_MESH_EVENT_LIGHT_XYL_TARGET_STATUS                      , "WICED HCI Event Light XYL target status" },
    { HCI_CONTROL_MESH_EVENT_LIGHT_XYL_RANGE_SET                          , "WICED HCI Event Light XYL range set" },
    { HCI_CONTROL_MESH_EVENT_LIGHT_XYL_RANGE_STATUS                       , "WICED HCI Event Light XYL range status" },
    { HCI_CONTROL_MESH_EVENT_LIGHT_XYL_DEFAULT_SET                        , "WICED HCI Event Light XYL default set" },
    { HCI_CONTROL_MESH_EVENT_LIGHT_XYL_DEFAULT_STATUS                     , "WICED HCI Event Light XYL default status" },
    { HCI_CONTROL_MESH_EVENT_LIGHT_LC_MODE_SERVER_SET                     , "WICED HCI Event Light LC mode set" },
    { HCI_CONTROL_MESH_EVENT_LIGHT_LC_MODE_CLIENT_STATUS                  , "WICED HCI Event Light LC mode status" },
    { HCI_CONTROL_MESH_EVENT_LIGHT_LC_OCCUPANCY_MODE_SERVER_SET           , "WICED HCI Event Light LC occupancy mode set" },
    { HCI_CONTROL_MESH_EVENT_LIGHT_LC_OCCUPANCY_MODE_CLIENT_STATUS        , "WICED HCI Event Light LC occupancy mode status" },
    { HCI_CONTROL_MESH_EVENT_LIGHT_LC_ONOFF_SERVER_SET                    , "WICED HCI Event Light LC onoff set" },
    { HCI_CONTROL_MESH_EVENT_LIGHT_LC_ONOFF_CLIENT_STATUS                 , "WICED HCI Event Light LC onoff status" },
    { HCI_CONTROL_MESH_EVENT_LIGHT_LC_PROPERTY_SERVER_SET                 , "WICED HCI Event Light LC property set" },
    { HCI_CONTROL_MESH_EVENT_LIGHT_LC_PROPERTY_CLIENT_STATUS              , "WICED HCI Event Light LC property status" },
    { HCI_CONTROL_MESH_EVENT_SENSOR_DESCRIPTOR_STATUS                     , "WICED HCI Event Sensor descriptor status" },
    { HCI_CONTROL_MESH_EVENT_SENSOR_STATUS                                , "WICED HCI Event Sensor status" },
    { HCI_CONTROL_MESH_EVENT_SENSOR_COLUMN_STATUS                         , "WICED HCI Event Sensor column status" },
    { HCI_CONTROL_MESH_EVENT_SENSOR_SERIES_STATUS                         , "WICED HCI Event Sensor series status" },
    { HCI_CONTROL_MESH_EVENT_SENSOR_CADENCE_STATUS                        , "WICED HCI Event Sensor cadence status" },
    { HCI_CONTROL_MESH_EVENT_SENSOR_SETTING_STATUS                        , "WICED HCI Event Sensor setting status" },
    { HCI_CONTROL_MESH_EVENT_SENSOR_SETTINGS_STATUS                       , "WICED HCI Event Sensor settings status" },
    { HCI_CONTROL_MESH_EVENT_SENSOR_CADENCE_GET                           , "WICED HCI Event Sensor cadence get" },
    { HCI_CONTROL_MESH_EVENT_SENSOR_CADENCE_SET                           , "WICED HCI Event Sensor cadence set" },
    { HCI_CONTROL_MESH_EVENT_SENSOR_SETTING_GET                           , "WICED HCI Event Sensor setting get" },
    { HCI_CONTROL_MESH_EVENT_SENSOR_GET                                   , "WICED HCI Event Sensor get" },
    { HCI_CONTROL_MESH_EVENT_SENSOR_COLUMN_GET                            , "WICED HCI Event Sensor column get" },
    { HCI_CONTROL_MESH_EVENT_SENSOR_SERIES_GET                            , "WICED HCI Event Sensor series get" },
    { HCI_CONTROL_MESH_EVENT_SENSOR_SETTING_SET                           , "WICED HCI Event Sensor setting set" },
    { HCI_CONTROL_MESH_EVENT_SCENE_STATUS                                 , "WICED HCI Event Scene status" },
    { HCI_CONTROL_MESH_EVENT_SCENE_REGISTER_STATUS                        , "WICED HCI Event Scene register status" },
    { HCI_CONTROL_MESH_EVENT_SCHEDULER_STATUS                             , "WICED HCI Event Scheduler status" },
    { HCI_CONTROL_MESH_EVENT_SCHEDULER_ACTION_STATUS                      , "WICED HCI Event Scheduler action status" },
    { HCI_CONTROL_MESH_EVENT_TIME_STATUS                                  , "WICED HCI Event Time status" },
    { HCI_CONTROL_MESH_EVENT_TIME_ZONE_STATUS                             , "WICED HCI Event Time zone status" },
    { HCI_CONTROL_MESH_EVENT_TIME_TAI_UTC_DELTA_STATUS                    , "WICED HCI Event Time TAI UTC delta status" },
    { HCI_CONTROL_MESH_EVENT_TIME_ROLE_STATUS                             , "WICED HCI Event Time role status" },
    { HCI_CONTROL_MESH_EVENT_TIME_SET                                     , "WICED HCI Event Time time set" },
    { HCI_CONTROL_MESH_EVENT_UNPROVISIONED_DEVICE                         , "WICED HCI Event Unprovisioned Device" },
    { HCI_CONTROL_MESH_EVENT_PROVISION_LINK_STATUS                        , "WICED HCI Event Provision link status" },
    { HCI_CONTROL_MESH_EVENT_PROVISION_END                                , "WICED HCI Event Provision end" },
    { HCI_CONTROL_MESH_EVENT_PROVISION_DEVICE_CAPABITIES                  , "WICED HCI Event Provision device capabilities" },
    { HCI_CONTROL_MESH_EVENT_PROVISION_OOB_DATA                           , "WICED HCI Event Provision OOB data" },
    { HCI_CONTROL_MESH_EVENT_PROXY_DEVICE_NETWORK_DATA                    , "WICED HCI Event Proxy device network data" },
    { HCI_CONTROL_MESH_EVENT_NODE_RESET_STATUS                            , "WICED HCI Event Node reset status" },
    { HCI_CONTROL_MESH_EVENT_COMPOSITION_DATA_STATUS                      , "WICED HCI Event Config composition data status" },
    { HCI_CONTROL_MESH_EVENT_FRIEND_STATUS                                , "WICED HCI Event Config friend" },
    { HCI_CONTROL_MESH_EVENT_GATT_PROXY_STATUS                            , "WICED HCI Event Config GATT proxy status" },
    { HCI_CONTROL_MESH_EVENT_RELAY_STATUS                                 , "WICED HCI Event Config relay status" },
    { HCI_CONTROL_MESH_EVENT_DEFAULT_TTL_STATUS                           , "WICED HCI Event Config default TTL status" },
    { HCI_CONTROL_MESH_EVENT_BEACON_STATUS                                , "WICED HCI Event Config beacon status" },
    { HCI_CONTROL_MESH_EVENT_NODE_IDENTITY_STATUS                         , "WICED HCI Event Config node identity status" },
    { HCI_CONTROL_MESH_EVENT_MODEL_PUBLICATION_STATUS                     , "WICED HCI Event Config model publication status" },
    { HCI_CONTROL_MESH_EVENT_MODEL_SUBSCRIPTION_STATUS                    , "WICED HCI Event Config model subscription status" },
    { HCI_CONTROL_MESH_EVENT_MODEL_SUBSCRIPTION_LIST                      , "WICED HCI Event Config subscription list" },
    { HCI_CONTROL_MESH_EVENT_NETKEY_STATUS                                , "WICED HCI Event Config netkey status" },
    { HCI_CONTROL_MESH_EVENT_NETKEY_LIST                                  , "WICED HCI Event Config netkey list" },
    { HCI_CONTROL_MESH_EVENT_APPKEY_STATUS                                , "WICED HCI Event Config appkey status" },
    { HCI_CONTROL_MESH_EVENT_APPKEY_LIST                                  , "WICED HCI Event Config appkey list" },
    { HCI_CONTROL_MESH_EVENT_MODEL_APP_BIND_STATUS                        , "WICED HCI Event Config app bind status" },
    { HCI_CONTROL_MESH_EVENT_MODEL_APP_LIST                               , "WICED HCI Event Config app list" },
    { HCI_CONTROL_MESH_EVENT_HEARTBEAT_SUBSCRIPTION_STATUS                , "WICED HCI Event Config hearbeat subcription status" },
    { HCI_CONTROL_MESH_EVENT_HEARTBEAT_PUBLICATION_STATUS                 , "WICED HCI Event Config hearbeat publication status" },
    { HCI_CONTROL_MESH_EVENT_NETWORK_TRANSMIT_PARAMS_STATUS               , "WICED HCI Event Config network transmit params status" },
    { HCI_CONTROL_MESH_EVENT_HEALTH_CURRENT_STATUS                        , "WICED HCI Event Config health current status" },
    { HCI_CONTROL_MESH_EVENT_HEALTH_FAULT_STATUS                          , "WICED HCI Event Config health fault status" },
    { HCI_CONTROL_MESH_EVENT_HEALTH_PERIOD_STATUS                         , "WICED HCI Event Config health period status" },
    { HCI_CONTROL_MESH_EVENT_HEALTH_ATTENTION_STATUS                      , "WICED HCI Event Config health attention status" },
    { HCI_CONTROL_MESH_EVENT_LPN_POLL_TIMEOUT_STATUS                      , "WICED HCI Event Config LPN poll timeout status" },
    { HCI_CONTROL_MESH_EVENT_KEY_REFRESH_PHASE_STATUS                     , "WICED HCI Event Config key refresh phase status" },
    { HCI_CONTROL_MESH_EVENT_PROXY_FILTER_STATUS                          , "WICED HCI Event Config proxy filter status" },
    { HCI_CONTROL_MESH_EVENT_VENDOR_DATA                                  , "WICED HCI Event Vendor data" },
};

char *mesh_opcode_string(unsigned short opcode, unsigned int is_command)
{
    int i;
    if (is_command)
    {
        for (i = 0; i < sizeof(command_opcode_name) / sizeof(wiced_bt_mesh_opcode_name_t); i++)
        {
            if (command_opcode_name[i].opcode == opcode)
            {
                return command_opcode_name[i].p_name;
            }
        }
    }
    else
    {
        for (i = 0; i < sizeof(event_opcode_name) / sizeof(wiced_bt_mesh_opcode_name_t); i++)
        {
            if (event_opcode_name[i].opcode == opcode)
            {
                return event_opcode_name[i].p_name;
            }
        }

    }
    return "???";
}

// prints data in ascii format to the std out
void DumpData(UINT8 *p, UINT32 length, UINT32 max_lines)
{
    char    buff[100];
    UINT    i, j;

    if (p != NULL)
    {
        for (j = 0; j < max_lines && (16 * j) < length; j++)
        {
            for (i = 0; (i < 16) && ((i + (16 * j)) < length); i++)
            {
                sprintf_s(&buff[3 * i], sizeof(buff) - 3 * i, "%02x \n", ((UINT8*)p)[i + (j * 16)]);
            }
            printf("%s", buff);
        }
    }
}
