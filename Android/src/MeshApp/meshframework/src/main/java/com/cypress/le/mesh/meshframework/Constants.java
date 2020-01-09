/*
* Copyright 2018, Cypress Semiconductor Corporation or a subsidiary of Cypress Semiconductor
 *  Corporation. All rights reserved. This software, including source code, documentation and  related
 * materials ("Software"), is owned by Cypress Semiconductor  Corporation or one of its
 *  subsidiaries ("Cypress") and is protected by and subject to worldwide patent protection
 * (United States and foreign), United States copyright laws and international treaty provisions.
 * Therefore, you may use this Software only as provided in the license agreement accompanying the
 * software package from which you obtained this Software ("EULA"). If no EULA applies, Cypress
 * hereby grants you a personal, nonexclusive, non-transferable license to  copy, modify, and
 * compile the Software source code solely for use in connection with Cypress's  integrated circuit
 * products. Any reproduction, modification, translation, compilation,  or representation of this
 * Software except as specified above is prohibited without the express written permission of
 * Cypress. Disclaimer: THIS SOFTWARE IS PROVIDED AS-IS, WITH NO  WARRANTY OF ANY KIND, EXPRESS
 * OR IMPLIED, INCLUDING,  BUT NOT LIMITED TO, NONINFRINGEMENT, IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE. Cypress reserves the right to make changes to
 * the Software without notice. Cypress does not assume any liability arising out of the application
 * or use of the Software or any product or circuit  described in the Software. Cypress does
 * not authorize its products for use in any products where a malfunction or failure of the
 * Cypress product may reasonably be expected to result  in significant property damage, injury
 * or death ("High Risk Product"). By including Cypress's product in a High Risk Product, the
 *  manufacturer of such system or application assumes  all risk of such use and in doing so agrees
 * to indemnify Cypress against all liability.
*/
package com.cypress.le.mesh.meshframework;

import java.util.UUID;

class Constants {


    public static final int SMART_MESH_NETWORK_ID_LEN = 8;
    public static final int MESH_TTL_DEFAULT = 7 ;
    public static final byte RELIABLE_MESSAGE = 0x01;
    public static final byte UNRELIABLE_MESSAGE = 0x00;

    public static final byte CONNECT_TYPE_NODE_ID  =   0;     ///< Connect to a just provisioned device advertising Node Identity
    public static final byte CONNECT_TYPE_NET_ID   =   1;      ///< Connect to a proxy using network ID
    public static final byte CONNECT_TYPE_BDADDR   =   2;      ///< In some cases a device may connect to a specific BDADDR
    public static boolean MESH_CONTROLLER = true;
    /* if controller BP_OVL = false
    *     else
    *     BP_OVL = true
    */
    public static Boolean BP_OVL = (MESH_CONTROLLER == true)? false:true;
    public static Boolean HARDCODED_RANDOM = true;
    public static short HARDCODED_SUBS_ADDR = (short)0xc001;
    static final int GATT_MAX_ATTR_LEN = 600;
    public static final int MESH_INVALID_ID = (byte) 0xFF;     //Broadcast ID. TBD: Change to 0?
    public static final short MESH_MIN_NODE_ID = 0x1;     //Valid node IDs are 1 to 254
    public static final int MESH_MAX_NODE_ID = 0xc001;//0xFE;    //Valid node IDs are 1 to 254
    public static final short MESH_MAX_GROUPS_COUNT = 0x12; //Max 18 groups are supported
    //public static final int MTU_SIZE_GATT =512;
    // MTU size is reduced to handle Pixel 1 problem (pixel devices stall when OTA upgrade with higher MTU is performed)
    public static final int MTU_SIZE_GATT =158;
    public static final int MTU_SIZE_REST = 1500;

    // SAR field definitions
    static byte SMART_MESH_SAR_MASK     = (byte)0xc0;
    static byte SMART_MESH_SAR_CONT     = (byte)0x00;
    static byte SMART_MESH_SAR_END      = (byte)0x40;
    static byte SMART_MESH_SAR_START    = (byte)0x80;
    static byte SMART_MESH_SAR_COMPLETE = (byte)(SMART_MESH_SAR_START | SMART_MESH_SAR_END);

    static final int SMART_MESH_HANDLE_SAR_RES_FAILED     = 0;
    static final int SMART_MESH_HANDLE_SAR_RES_PENDING    = 1;
    static final int SMART_MESH_HANDLE_SAR_RES_SUCCEEDED  = 2;
    static final int SMART_MESH_HANDLE_SAR_RES_PROCEED    = 3;
    static final int SMART_MESH_HANDLE_SAR_RES_COMPLETE   = 4;

    static final int SMART_MESH_KEY_LEN                 = 16;
    static final int SMART_MESH_IV_INDEX_LEN            = 4;
    // Smart mesh device ID (address) length
    static final int SMART_MESH_NODE_ID_LEN             = 2;

    static final int SMART_MESH_PROVIS_PUBLIC_KEY_LEN   = 64;
    static final int SMART_MESH_PROVIS_PRIV_KEY_LEN     = 32;
    static final int SMART_MESH_PROVIS_CONFORMATION_LEN = 16;
    static final int SMART_MESH_PROVIS_ECDH_SECRET_LEN  = 32;
    static final int SMART_MESH_PROVIS_RANDOM_LEN       = 16;
    static final int SMART_MESH_PROVIS_DATA_LEN         = SMART_MESH_KEY_LEN + 2 + 1 + SMART_MESH_IV_INDEX_LEN + SMART_MESH_NODE_ID_LEN;
    static final int SMART_MESH_PROVIS_MIC_LEN          = 8;

    /*PROVISION UUIDS*/
    public static final UUID UUID_SERVICE_SMART_MESH_PROVISIONING               = UUID.fromString("00001827-0000-1000-8000-00805f9b34fb");
    public static final UUID UUID_CHARACTERISTIC_MESH_PROVISIONING_DATA_IN      = UUID.fromString("00002ADB-0000-1000-8000-00805f9b34fb");
    public static final UUID UUID_CHARACTERISTIC_MESH_PROVISIONING_DATA_OUT     = UUID.fromString("00002ADC-0000-1000-8000-00805f9b34fb");

    public static final UUID CHARACTERISTIC_UPDATE_NOTIFICATION_DESCRIPTOR_UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb");

    public static final UUID UUID_SERVICE_SMART_MESH_PROXY                      = UUID.fromString("00001828-0000-1000-8000-00805f9b34fb");
    public static final UUID UUID_CHARACTERISTIC_MESH_PROXY_DATA_IN             = UUID.fromString("00002ADD-0000-1000-8000-00805f9b34fb");
    public static final UUID UUID_CHARACTERISTIC_MESH_PROXY_DATA_OUT            = UUID.fromString("00002ADE-0000-1000-8000-00805f9b34fb");

    /**
     * UUID of Upgrade Service
     */
    public static final UUID UUID_UPGRADE_SERVICE                               = UUID.fromString("ae5d1e47-5c13-43a0-8635-82ad38a1381f");

    /**
     * UUID of Secure Upgrade Service
     */
    public static final UUID UUID_SECURE_UPGRADE_SERVICE                        = UUID.fromString("c7261110-f425-447a-a1bd-9d7246768bd8");

    public static final int MAX_PROVISION_DATA_LEN             = 51;
    public static final int MAX_MESH_GROUPS                    = 8;
    public static final int MAX_MESH_NAME	                   = 32;

    // max number of app/net keys
    public static final int SMART_MESH_APP_KEY_MAX_NUM         = 8;
    public static final int SMART_MESH_NET_KEY_MAX_NUM         = 8;
    public static final int SMART_MESH_DEV_KEY_MAX_NUM         = 225;


    public static byte[] HARDCODED_RANDOM_PROVISIONER = {(byte) 0x8b, 0x19, (byte) 0xac, 0x31, (byte) 0xd5, (byte) 0x8b, 0x12, 0x4c, (byte) 0x94, 0x62, 0x09, (byte) 0xb5, (byte) 0xdb, 0x10, 0x21, (byte) 0xb9};
    public static byte[] HARDCODED_RANDOM_DEVICE = {0x55, (byte) 0xa2, (byte) 0xa2, (byte) 0xbc, (byte) 0xa0, 0x4c, (byte) 0xd3, 0x2f, (byte) 0xf6, (byte) 0xf3, 0x46, (byte) 0xbd, 0x0a, 0x0c, 0x1a, 0x3a};
    public static byte[] HARDCODED_APP_KEY = {(byte) 0x11, 0x22, (byte) 0x33, 0x44, (byte) 0x55, (byte) 0x66, 0x77, (byte) 0x88, 0x11, 0x22, (byte) 0x33, (byte) 0x44, 0x55, 0x66, (byte) 0x77, (byte) 0x88};
    public static byte[] HARDCODED_NET_KEY = {(byte)0x7d,(byte)0xd7,(byte)0x36,(byte)0x4c,(byte)0xd8, (byte)0x42,(byte)0xad,(byte)0x18,(byte)0xc1,(byte)0x7c,(byte)0x2b,(byte)0x82,(byte)0x0c,(byte)0x84,(byte)0xc3,(byte)0xd6};
    /* Result codes */
    public static byte SMART_MESH_RESULT_SUCCESS                          = (byte) 0x00;
    public static byte SMART_MESH_RESULT_ILLEGAL_HANDLE                   = (byte) 0x80;
    public static byte SMART_MESH_RESULT_ILLEGAL_CONFIG                   = (byte) 0x81;
    public static byte SMART_MESH_RESULT_UNKNOWN_NODE                     = (byte) 0x82;
    public static byte SMART_MESH_RESULT_ILLEGAL_NODE_ID                  = (byte) 0x83;
    public static byte SMART_MESH_RESULT_INVALID_PKT_LEN                  = (byte) 0x84;
    public static byte SMART_MESH_RESULT_NVRAM_FAILURE                    = (byte) 0x85;
    public static byte SMART_MESH_RESULT_DEVICE_BUSY                      = (byte) 0x86;
    public static byte SMART_MESH_RESULT_GENERIC_ERROR                    = (byte) 0xFF;

    public static byte SMART_MESH_PROVIS_START_ALG_FIPS_P256              = (byte) 0x00;


    public static byte SMART_MESH_PROVIS_FAILED_PDU_ERROR_INVALID_PDU     = 0x01;
    public static byte SMART_MESH_PROVIS_FAILED_PDU_ERROR_WRONG_FORMAT    = 0x02;

    public static int SMART_MESH_AUTH_VALUE_MAX_LEN                       = 16;



    public static final int MESH_ADDR_UNASSIGNED = 0x0000;
    public static final int MESH_ADDR_UNICAST_MIN = 0x0001;
    public static final int MESH_ADDR_UNICAST_MAX = 0x7FFF;

    public static final int MESH_ADDR_VIRT_MIN = 0x8000;
    public static final int MESH_ADDR_VIRT_MAX = 0xBFFF;

    public static final int MESH_ADDR_GROUP_MIN = 0xC000;
    public static final int MESH_ADDR_GROUP_MAX = 0xFFFE;

    public static final int MESH_ADDR_BROADCAST = 0xFFFF;

    public static final int MESH_KEY_INDEX_INVALID = 0xFFFF;
    public static final short MESH_TTL_INVALID = (short)0xFFFF;

    public static final int MESH_NET_IV_INDEX_MIN = 0x0;

    public static final int MESH_NET_IV_LEN = 4;

    public static final byte OTA_UPGRADE_STATUS_CONNECTED                = 0;
    public static final byte OTA_UPGRADE_STATUS_DISCONNECTED             = 1;
    public static final byte OTA_UPGRADE_STATUS_IN_PROGRESS              = 2;
    public static final byte OTA_UPGRADE_STATUS_COMPLETED                = 3;
    public static final byte OTA_UPGRADE_STATUS_ABORTED                  = 4;
    public static final byte OTA_UPGRADE_STATUS_NOT_SUPPORTED            = 5;
    public static final byte OTA_UPGRADE_STATUS_SERVICE_NOT_FOUND        = 6;
    public static final byte OTA_UPGRADE_STATUS_UPGRADE_TO_ALL_STARTED   = 7;

    public static final byte MESH_CLIENT_NODE_WARNING_UNREACHABLE        = 0;
    public static final byte MESH_CLIENT_NODE_CONNECTED                  = 1;
    public static final byte MESH_CLIENT_NODE_ERROR_UNREACHABLE          = 2;

    public static final byte MESH_CLIENT_SUCCESS                 =0;
    public static final byte MESH_CLIENT_ERR_INVALID_STATE       =1;
    public static final byte MESH_CLIENT_ERR_NOT_CONNECTED       =2;
    public static final byte MESH_CLIENT_ERR_DEVICE_NOT_FOUND    =3;
    public static final byte MESH_CLIENT_ERR_NETWORK_CLOSED      =4;
    public static final byte MESH_CLIENT_ERR_NO_MEMORY           =5;
    public static final byte MESH_CLIENT_ERR_METHOD_NOT_AVAIL    =6;
    public static final byte MESH_CLIENT_ERR_NETWORK_DB          =7;
    public static final byte MESH_CLIENT_ERR_INVALID_ARGS        =8;

    public static final byte NETWORK_CONNECTION_STATE_DISCONNECTED       = 0;
    public static final byte NETWORK_CONNECTION_STATE_CONNECTING         = 1;
    public static final byte NETWORK_CONNECTION_STATE_CONNECTED          = 2;

}
