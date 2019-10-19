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

/*****************************************************************************
**
**  Name:           wiced_bt_pbc_int.h
**
**  Description:    This is the private file for the phone book access
**                  client (PBC).
**
**
*****************************************************************************/
#ifndef WICED_BT_PBC_INT_H
#define WICED_BT_PBC_INT_H

#define WICED_BT_PBAP_1_2_SUPPORTED   FALSE

#include "wiced_bt_obex.h"
#include "wiced_bt_pbc_api.h"
#include "wiced_bt_pbc_co.h"
#include "wiced_bt_sdp.h"
#include "wiced_bt_rfcomm.h"
#include "wiced_bt_trace.h"
#include "wiced_timer.h"


/* The maximum length of authentication challenge realm.*/
#ifndef OBX_MAX_REALM_LEN
#define OBX_MAX_REALM_LEN           30
#endif

#undef  OBX_CMD_POOL_SIZE
#define OBX_CMD_POOL_SIZE           256
#define WICED_BT_PBC_INVALID_FD     (-1)
#define  WICED_BT_PBC_LEN_UNKNOWN   0xFFFFFFFF


//TODO REMOVE
#define BTM_SEC_SERVICE_PBAP        31
#define BTM_SEC_PROTO_RFCOMM        3


/* character used as path separator */
#ifndef wiced_bt_pbc_fs_path_separator
#define wiced_bt_pbc_fs_path_separator   ((char) 0x2f)   /* 0x2f ('/'), or 0x5c ('\') */
#endif

/* maximum path length supported */
#ifndef wiced_bt_pbc_fs_path_len
#define wiced_bt_pbc_fs_path_len         294
#endif

#ifndef wiced_bt_pbc_fs_file_len
#define wiced_bt_pbc_fs_file_len         256
#endif

typedef struct
{
    UINT16  max_file_len;           /* Maximum size file name */
    UINT16  max_path_len;           /* Maximum path length (includes appended file name) */
    char    path_separator;         /* 0x2f ('/'), or 0x5c ('\') */
} wiced_bt_pbc_fs_cfg_t;

extern wiced_bt_pbc_fs_cfg_t * p_wiced_bt_pbc_fs_cfg;





/*****************************************************************************
**  Constants and data types
*****************************************************************************/

/* Set it to TRUE for adding debugging traces */
#ifndef WICED_BT_PBC_DEBUG
#define WICED_BT_PBC_DEBUG TRUE
#endif

#if WICED_BT_PBC_DEBUG == TRUE
#define WICED_BT_PBC_TRACE   WICED_BT_TRACE
#else
#define WICED_BT_PBC_TRACE(...)
#endif

#define WICED_BT_PBC_ERROR   WICED_BT_TRACE

#define WICED_BT_PBC_PB_ACCESS_TARGET_UUID       "\x79\x61\x35\xF0\xF0\xC5\x11\xD8\x09\x66\x08\x00\x20\x0C\x9A\x66"
#define WICED_BT_PBC_UUID_LENGTH                 16
#define WICED_BT_PBC_MAX_AUTH_KEY_SIZE           16  /* Must not be greater than OBX_MAX_AUTH_KEY_SIZE */

#define WICED_BT_PBC_FOLDER_LISTING_TYPE         "x-obex/folder-listing"
#define WICED_BT_PBC_PULL_PB_TYPE                "x-bt/phonebook"
#define WICED_BT_PBC_PULL_VCARD_LISTING_TYPE     "x-bt/vcard-listing"
#define WICED_BT_PBC_PULL_VCARD_ENTRY_TYPE       "x-bt/vcard"
#define WICED_BT_PBC_PULL_PB_SPD_NAME            "telecom/spd.vcf"
#define WICED_BT_PBC_PULL_PB_FAV_NAME            "telecom/fav.vcf"
#define WICED_BT_PBC_PULL_LIST_SPD_NAME          "spd"
#define WICED_BT_PBC_PULL_LIST_FAV_NAME          "fav"

/* Profile supported repositories */
#define WICED_BT_PBC_REPOSIT_LOCAL      0x01    /* Local PhoneBook */
#define WICED_BT_PBC_REPOSIT_SIM        0x02    /* SIM card PhoneBook */
#define WICED_BT_PBC_REPOSIT_SPEED_DIAL 0x04    /* Speed Dial */
#define WICED_BT_PBC_REPOSIT_FAVORITES  0x08    /* Favorites */

typedef UINT8 tWICED_BT_PBC_SUP_REPOSIT_MASK;

#define WICED_BT_PBC_VERSION_1_1         0x0101 /* PBAP 1.1 */
#define WICED_BT_PBC_VERSION_1_2         0x0102 /* PBAP 1.2 */

#define WICED_BT_PBC_REPOSITORIES_1_1    (WICED_BT_PBC_REPOSIT_LOCAL | WICED_BT_PBC_REPOSIT_SIM)
#define WICED_BT_PBC_REPOSITORIES_1_2    (WICED_BT_PBC_REPOSIT_LOCAL | WICED_BT_PBC_REPOSIT_SIM | WICED_BT_PBC_REPOSIT_SPEED_DIAL | WICED_BT_PBC_REPOSIT_FAVORITES)

#if (defined(WICED_BT_PBAP_1_2_SUPPORTED) && WICED_BT_PBAP_1_2_SUPPORTED == TRUE)
#define WICED_BT_PBC_DEFAULT_VERSION         WICED_BT_PBC_VERSION_1_2
#else
#define WICED_BT_PBC_DEFAULT_VERSION         WICED_BT_PBC_VERSION_1_1
#endif

#define WICED_BT_PBC_DEFAULT_REPOSITORIES        WICED_BT_PBC_REPOSITORIES_1_1
#define WICED_BT_PBC_DEFAULT_SUPPORTED_FEATURES  0x00000003  /* Default peer supported features */

/* PBC Active ftp obex operation (Valid in connected state) */
#define PBC_OP_NONE         0
#define PBC_OP_GET_FILE     1
#define PBC_OP_GET_LIST     2
#define PBC_OP_CHDIR        3

enum
{
    WICED_BT_PBC_GET_CARD,   /* PBAP PullvCardEntry */
    WICED_BT_PBC_GET_PB      /* PBAP PullPhoneBook */
};
typedef UINT8 wiced_bt_pbc_get_type_t;//wiced_bt_pbc_get_type_t;

/* Response Timer Operations */
#define PBC_TIMER_OP_STOP   0
#define PBC_TIMER_OP_ABORT  1

/* state machine events */
enum
{
    /* these events are handled by the state machine */
    WICED_BT_PBC_API_DISABLE_EVT,

    WICED_BT_PBC_API_OPEN_EVT,           /* Open a connection request */
    WICED_BT_PBC_API_CLOSE_EVT,          /* Close an open connection request */
    WICED_BT_PBC_API_GETFILE_EVT,        /* Get File request */
    WICED_BT_PBC_API_LISTDIR_EVT,        /* List Directory request */
    WICED_BT_PBC_API_CHDIR_EVT,          /* Change Directory request */
    WICED_BT_PBC_API_AUTHRSP_EVT,        /* Response to password request */
    WICED_BT_PBC_API_ABORT_EVT,          /* Response to an abort request */
    WICED_BT_PBC_SDP_OK_EVT,             /* Service search was successful */
    WICED_BT_PBC_SDP_FAIL_EVT,           /* Service search failed */
    WICED_BT_PBC_CI_WRITE_EVT,           /* Call-in response to Write request */
    WICED_BT_PBC_CI_OPEN_EVT,            /* Call-in response to File Open request */
    WICED_BT_PBC_OBX_CONN_RSP_EVT,       /* OBX Channel Connect Request */
    WICED_BT_PBC_OBX_ABORT_RSP_EVT,      /* OBX_operation aborted */
    WICED_BT_PBC_OBX_TOUT_EVT,           /* OBX Operation Timeout */
    WICED_BT_PBC_OBX_PASSWORD_EVT,       /* OBX password requested */
    WICED_BT_PBC_OBX_CLOSE_EVT,          /* OBX Channel Disconnected (Link Lost) */
    WICED_BT_PBC_OBX_GET_RSP_EVT,        /* Read file data or folder listing */
    WICED_BT_PBC_OBX_SETPATH_RSP_EVT,    /* Make or Change Directory */
    WICED_BT_PBC_OBX_CMPL_EVT,           /* operation has completed */
    WICED_BT_PBC_CLOSE_CMPL_EVT,         /* Finish the closing of the channel */
    WICED_BT_PBC_DISABLE_CMPL_EVT,       /* Finished disabling system */
    WICED_BT_PBC_RSP_TOUT_EVT,           /* Timeout waiting for response from server */

    /* these events are handled outside the state machine */
    WICED_BT_PBC_API_ENABLE_EVT
};

typedef UINT16 wiced_bt_pbc_int_evt_t;

typedef UINT8 wiced_bt_pbc_state_t;

/* Application Parameters Header
Tag IDs used in the Application Parameters header:
*/
                                            /*  Tag ID          Length      Possible Values */
#define WICED_BT_PBC_APH_ORDER           0x01    /* Order            1 bytes     0x0 to 0x2 */
#define WICED_BT_PBC_APH_SEARCH_VALUE    0x02    /* SearchValue      variable    text */
#define WICED_BT_PBC_APH_SEARCH_ATTR     0x03    /* SearchAttribute  1 byte      0x0 to 0x2 */
#define WICED_BT_PBC_APH_MAX_LIST_COUNT  0x04    /* MaxListCount     2 bytes     0x0000 to 0xFFFF */
#define WICED_BT_PBC_APH_LIST_STOFF      0x05    /* ListStartOffset  2 bytes     0x0000 to 0xFFFF */
#define WICED_BT_PBC_APH_PROP_SELECTOR   0x06    /* Property selector        8 bytes     0x00000000 to 0xFFFFFFFF */
#define WICED_BT_PBC_APH_FORMAT          0x07    /* Format           1 byte      0x00(2.1), 0x01(3.0) */
#define WICED_BT_PBC_APH_PB_SIZE         0x08    /* PhoneBookSize    2 byte      0x0000 to 0xFFFF */
#define WICED_BT_PBC_APH_NEW_MISSED_CALL 0x09    /* NewMissedCall    1 bytes     0x00 to 0xFF */
#define WICED_BT_PBC_APH_PRI_VER_COUNTER 0x0A    /* PrimaryVersionCounter    16 bytes    0x00 to 0xFF */
#define WICED_BT_PBC_APH_SEC_VER_COUNTER 0x0B    /* SecondaryVersionCounter  16 bytes    0x00 to 0xFF */
#define WICED_BT_PBC_APH_VCARD_SELE      0x0C    /* VcardSelector            8 bytes     0x00 to 0xFF */
#define WICED_BT_PBC_APH_DB_ID           0x0D    /* DatabaseIdentifier       16 bytes    0x00 to 0xFF */
#define WICED_BT_PBC_APH_VCARD_SELE_OP   0x0E    /* VcardSelectorOperator    1 bytes     0x00 to 0x01 */
#define WICED_BT_PBC_APH_RESET_NMC       0x0F    /* ResetNewMissedCall       1 bytes     0x01 */
#define WICED_BT_PBC_APH_SUP_FEA         0x10    /* PbapSupportedFeatures    4 bytes     */
#define WICED_BT_PBC_APH_MAX_TAG         WICED_BT_PBC_APH_SUP_FEA

/* Power management state for PBC */
#define WICED_BT_PBC_PM_BUSY     0
#define WICED_BT_PBC_PM_IDLE     1

typedef UINT8 tWICED_BT_PBC_PM_STATE;



/* data type for WICED_BT_PBC_API_ENABLE_EVT */
typedef struct
{
    BT_HDR              hdr;
    wiced_bt_pbc_cback_t     *p_cback;
    wiced_bt_pbc_data_cback_t     *p_data_cback;
    UINT8               app_id;
#if (defined(WICED_BT_PBAP_1_2_SUPPORTED) && WICED_BT_PBAP_1_2_SUPPORTED == TRUE)
    wiced_bt_pbc_sup_fea_mask_t   local_features;
#endif
} wiced_bt_pbc_api_enable_t;

/* data type for WICED_BT_PBC_API_OPEN_EVT */
typedef struct
{
    BT_HDR              hdr;
    wiced_bt_device_address_t             bd_addr;
    UINT8               sec_mask;
} wiced_bt_pbc_api_open_t;

typedef struct
{
    wiced_bt_pbc_filter_mask_t      filter;
    UINT16                          max_list_count;
    UINT16                          list_start_offset;
    wiced_bt_pbc_format_t           format;
#if (defined(WICED_BT_PBAP_1_2_SUPPORTED) && WICED_BT_PBAP_1_2_SUPPORTED == TRUE)
    BOOLEAN                 is_reset_miss_calls;
    wiced_bt_pbc_filter_mask_t    selector;
    UINT8                   selector_op;
#endif
} wiced_bt_pbc_get_param_t;

/* data type for WICED_BT_PBC_API_GETFILE_EVT */
typedef struct
{
    BT_HDR                      hdr;
    char                        *p_rem_name; /* UTF-8 name from listing */
    char                        *p_name;
    wiced_bt_pbc_get_param_t    *p_param;
    UINT8                       obj_type;

} wiced_bt_pbc_api_get_t;

/* data type for WICED_BT_PBC_API_CHDIR_EVT */
typedef struct
{
    BT_HDR                    hdr;
    char                      *p_dir;    /* UTF-8 name from listing */
    wiced_bt_pbc_flag_t       flag;
} wiced_bt_pbc_api_chdir_t;

typedef struct
{
    char                        *p_value;
    UINT16                      max_list_count;
    UINT16                      list_start_offset;
    wiced_bt_pbc_order_t        order;
    wiced_bt_pbc_attr_t         attribute;
#if (defined(WICED_BT_PBAP_1_2_SUPPORTED) && WICED_BT_PBAP_1_2_SUPPORTED == TRUE)
    BOOLEAN             is_reset_miss_calls;
    wiced_bt_pbc_filter_mask_t    selector;
    UINT8                   selector_op;
#endif
} wiced_bt_pbc_list_param_t;

/* data type for WICED_BT_PBC_API_LISTDIR_EVT */
typedef struct
{
    BT_HDR                      hdr;
    char                        *p_dir;    /* UTF-8 name from listing */
    wiced_bt_pbc_list_param_t   *p_param;
} wiced_bt_pbc_api_list_t;


/* data type for WICED_BT_PBC_API_AUTHRSP_EVT */
typedef struct
{
    BT_HDR  hdr;
    UINT8   key [WICED_BT_PBC_MAX_AUTH_KEY_SIZE];      /* The authentication key.*/
    UINT8   key_len;
    UINT8   userid [OBX_MAX_REALM_LEN];      /* The authentication user id.*/
    UINT8   userid_len;
} wiced_bt_pbc_api_auth_rsp_t;

/* Open Complete Event */
typedef struct
{
    BT_HDR                      hdr;
    wiced_bt_pbc_co_status_t    status;
    UINT32                      file_size;
    int                         fd;
    const char                  *p_file;
} wiced_bt_pbc_ci_open_evt_t;

/* Write Ready Event */
typedef struct
{
    BT_HDR                      hdr;
    wiced_bt_pbc_co_status_t    status;
    int                         fd;
} wiced_bt_pbc_ci_write_evt_t;



/* data type for WICED_BT_PBC_SDP_OK_EVT */
typedef struct
{
    BT_HDR                          hdr;
    UINT16                          version;
    UINT16                          psm;
    UINT8                           scn;
    BOOLEAN                         is_peer_features_present;/* Whether peer feature present */
    wiced_bt_pbc_sup_fea_mask_t     peer_features;          /* Peer supported features */
    tWICED_BT_PBC_SUP_REPOSIT_MASK  peer_repositories;      /* Peer supported repositories */

} tWICED_BT_PBC_SDP_OK_EVT;

/* data type for all obex events
    hdr.event contains the PBC event
*/
typedef struct
{
    BT_HDR                      hdr;
    wiced_bt_obex_handle_t      handle;
    wiced_bt_obex_evt_param_t   param;
    BT_HDR                      *p_pkt;
    wiced_bt_obex_event_t       obx_event;
    UINT8                       rsp_code;
} wiced_bt_pbc_obx_evt_t;

/* union of all event data types */
typedef union
{
    BT_HDR                        hdr;
    wiced_bt_pbc_api_enable_t     api_enable;
    wiced_bt_pbc_api_open_t       api_open;
    wiced_bt_pbc_api_get_t        api_get;
    wiced_bt_pbc_api_chdir_t      api_chdir;
    wiced_bt_pbc_api_auth_rsp_t   auth_rsp;
    wiced_bt_pbc_api_list_t       api_list;
    tWICED_BT_PBC_SDP_OK_EVT      sdp_ok;
    wiced_bt_pbc_obx_evt_t        obx_evt;
    wiced_bt_pbc_ci_open_evt_t    open_evt;
    wiced_bt_pbc_ci_write_evt_t   write_evt;
} wiced_bt_pbc_data_t;


/* OBX Response Packet Structure - Holds current command/response packet info */
typedef struct
{
    BT_HDR  *p_pkt;             /* (Get/Put) Holds the current OBX header for Put or Get */
    UINT8   *p_start;           /* (Get/Put) Start of the Body of the packet */
    UINT16   offset;            /* (Get/Put) Contains the current offset into the Body (p_start) */
    UINT16   bytes_left;        /* (Get/Put) Holds bytes available left in Obx packet */
    BOOLEAN  final_pkt;         /* (Get)     Holds the final bit of the Put packet */
} wiced_bt_pbc_obx_pkt_t;



typedef void (TIMER_CBACK)(void *p_tle);

typedef struct _tle
{
    wiced_timer_t       wiced_timer;
    TIMER_CBACK        *p_cback;
    INT32               ticks;
    TIMER_PARAM_TYPE    param;
    UINT16              event;
    UINT8               in_use;
} TIMER_LIST_ENT;


typedef UINT32 tWICED_BT_SERVICE_MASK;

#define WICED_BT_PBAP_SERVICE_MASK       0x00200000  /* Phone Book Server */

/* PBC control block */
typedef struct
{
    wiced_bt_pbc_cback_t        *p_cback;       /* pointer to application callback function */
    wiced_bt_pbc_data_cback_t   *p_data_cback;    /* pointer to data callback function */

    char                        *p_name;        /* Holds the local file name */
    wiced_bt_sdp_discovery_db_t *p_db;          /* pointer to discovery database */
    UINT32                      sdp_handle;    /* SDP record handle for PCE */
    wiced_bt_pbc_obx_pkt_t      obx;           /* Holds the current OBX packet information */
    TIMER_LIST_ENT              rsp_timer;     /* response timer */
    tWICED_BT_SERVICE_MASK      services;      /* PBAP */
    int                         fd;            /* File Descriptor of opened file */
    UINT32                      file_size;     /* (Put/Get) length of file */
    UINT16                      peer_mtu;
    UINT16                      sdp_service;
    wiced_bt_device_address_t   bd_addr;
    wiced_bt_obex_handle_t      obx_handle;
    UINT8                       sec_mask;
    wiced_bt_pbc_state_t        state;         /* state machine state */
    UINT8                       obx_oper;      /* current active OBX operation PUT FILE or GET FILE */
    UINT8                       timer_oper;    /* current active response timer action (abort or close) */
    UINT8                       app_id;
    wiced_bt_pbc_get_type_t     obj_type;      /* type of get op */
    BOOLEAN                     first_get_pkt; /* TRUE if retrieving the first packet of GET file */
    BOOLEAN                     cout_active;   /* TRUE if call-out is currently active */
    BOOLEAN                     disabling;     /* TRUE if client is in process of disabling */
    BOOLEAN                     aborting;      /* TRUE if client is in process of aborting */
    BOOLEAN                     is_enabled;    /* TRUE if client is enabled */
    BOOLEAN                     req_pending;   /* TRUE when waiting for an obex response */
    BOOLEAN                     sdp_pending;   /* TRUE when waiting for SDP to complete */
    tWICED_BT_PBC_PM_STATE      pm_state;      /* power management state */
#if (defined(WICED_BT_PBAP_1_2_SUPPORTED) && WICED_BT_PBAP_1_2_SUPPORTED == TRUE)
    wiced_bt_pbc_sup_fea_mask_t   local_features; /* Local supported features */
#endif
    wiced_bt_pbc_sup_fea_mask_t     peer_features;      /* Peer supported features */
    tWICED_BT_PBC_SUP_REPOSIT_MASK  peer_repositories;  /* Peer supported repositories */
} wiced_bt_pbc_cb_t;

/* type for action functions */
typedef void (*wiced_bt_pbc_action_t)(wiced_bt_pbc_cb_t *p_cb, wiced_bt_pbc_data_t *p_data);

/* Configuration structure */
typedef struct
{
    UINT8       realm_charset;          /* Server only */
    BOOLEAN     userid_req;             /* TRUE if user id is required during obex authentication (Server only) */
    char        *pce_name;              /* service name for PBAP PCE SDP record */
    INT32       stopabort_tout;         /* Timeout in milliseconds to wait for abort or close OBEX response (client only) */
} tWICED_BT_PBC_CFG;

/*****************************************************************************
**  Global data
*****************************************************************************/

/* PBC control block */
#if WICED_BT_DYNAMIC_MEMORY == FALSE
extern wiced_bt_pbc_cb_t  wiced_bt_pbc_cb;
#else
extern wiced_bt_pbc_cb_t *wiced_bt_pbc_cb_ptr;
#define wiced_bt_pbc_cb (*wiced_bt_pbc_cb_ptr)
#endif

/* PBC configuration constants */
extern tWICED_BT_PBC_CFG * p_wiced_bt_pbc_cfg;

/*****************************************************************************
**  Function prototypes
*****************************************************************************/

extern BOOLEAN  wiced_bt_pbc_hdl_event(BT_HDR *p_msg);
extern void     wiced_bt_pbc_sm_execute(wiced_bt_pbc_cb_t *p_cb, UINT16 event,
                                   wiced_bt_pbc_data_t *p_data);
extern void     wiced_bt_pbc_obx_cback (wiced_bt_obex_handle_t handle, wiced_bt_obex_event_t event,
                                   UINT8 rsp_code, wiced_bt_obex_evt_param_t param,
                                   UINT8 *p_pkt);

extern void wiced_bt_pbc_init_open(wiced_bt_pbc_cb_t *p_cb, wiced_bt_pbc_data_t *p_data);
extern void wiced_bt_pbc_init_close(wiced_bt_pbc_cb_t *p_cb, wiced_bt_pbc_data_t *p_data);
extern void wiced_bt_pbc_init_getfile(wiced_bt_pbc_cb_t *p_cb, wiced_bt_pbc_data_t *p_data);
extern void wiced_bt_pbc_chdir(wiced_bt_pbc_cb_t *p_cb, wiced_bt_pbc_data_t *p_data);
extern void wiced_bt_pbc_send_authrsp(wiced_bt_pbc_cb_t *p_cb, wiced_bt_pbc_data_t *p_data);
extern void wiced_bt_pbc_abort(wiced_bt_pbc_cb_t *p_cb, wiced_bt_pbc_data_t *p_data);
extern void wiced_bt_pbc_ci_write(wiced_bt_pbc_cb_t *p_cb, wiced_bt_pbc_data_t *p_data);
extern void wiced_bt_pbc_ci_open(wiced_bt_pbc_cb_t *p_cb, wiced_bt_pbc_data_t *p_data);
extern void wiced_bt_pbc_obx_conn_rsp(wiced_bt_pbc_cb_t *p_cb, wiced_bt_pbc_data_t *p_data);
extern void wiced_bt_pbc_obx_abort_rsp(wiced_bt_pbc_cb_t *p_cb, wiced_bt_pbc_data_t *p_data);
extern void wiced_bt_pbc_obx_password(wiced_bt_pbc_cb_t *p_cb, wiced_bt_pbc_data_t *p_data);
extern void wiced_bt_pbc_obx_timeout(wiced_bt_pbc_cb_t *p_cb, wiced_bt_pbc_data_t *p_data);
extern void wiced_bt_pbc_obx_get_rsp(wiced_bt_pbc_cb_t *p_cb, wiced_bt_pbc_data_t *p_data);
extern void wiced_bt_pbc_obx_setpath_rsp(wiced_bt_pbc_cb_t *p_cb, wiced_bt_pbc_data_t *p_data);
extern void wiced_bt_pbc_initialize(wiced_bt_pbc_cb_t *p_cb, wiced_bt_pbc_data_t *p_data);
extern void wiced_bt_pbc_trans_cmpl(wiced_bt_pbc_cb_t *p_cb, wiced_bt_pbc_data_t *p_data);
extern void wiced_bt_pbc_stop_client(wiced_bt_pbc_cb_t *p_cb, wiced_bt_pbc_data_t *p_data);
extern void wiced_bt_pbc_start_client(wiced_bt_pbc_cb_t *p_cb, wiced_bt_pbc_data_t *p_data);
extern void wiced_bt_pbc_free_db(wiced_bt_pbc_cb_t *p_cb, wiced_bt_pbc_data_t *p_data);
extern void wiced_bt_pbc_ignore_obx(wiced_bt_pbc_cb_t *p_cb, wiced_bt_pbc_data_t *p_data);
extern void wiced_bt_pbc_find_service(wiced_bt_pbc_cb_t *p_cb, wiced_bt_pbc_data_t *p_data);
extern void wiced_bt_pbc_close(wiced_bt_pbc_cb_t *p_cb, wiced_bt_pbc_data_t *p_data);
extern void wiced_bt_pbc_close_complete(wiced_bt_pbc_cb_t *p_cb, wiced_bt_pbc_data_t *p_data);
extern void wiced_bt_pbc_set_disable(wiced_bt_pbc_cb_t *p_cb, wiced_bt_pbc_data_t *p_data);
extern void wiced_bt_pbc_rsp_timeout(wiced_bt_pbc_cb_t *p_cb, wiced_bt_pbc_data_t *p_data);
extern void wiced_bt_pbc_listdir(wiced_bt_pbc_cb_t *p_cb, wiced_bt_pbc_data_t *p_data);
extern void wiced_bt_pbc_disable_complete(wiced_bt_pbc_cb_t *p_cb, wiced_bt_pbc_data_t *p_data);

/* miscellaneous functions */
extern UINT8 wiced_bt_pbc_send_get_req(wiced_bt_pbc_cb_t *p_cb);
extern void  wiced_bt_pbc_proc_get_rsp(wiced_bt_pbc_cb_t *p_cb, wiced_bt_pbc_data_t *p_data);
extern void  wiced_bt_pbc_proc_list_data(wiced_bt_pbc_cb_t *p_cb, wiced_bt_pbc_obx_evt_t *p_evt);
extern void  wiced_bt_pbc_get_listing(wiced_bt_pbc_cb_t *p_cb, char *p_name, wiced_bt_pbc_list_param_t *p_param);
extern void  wiced_bt_pbc_listing_err(BT_HDR **p_pkt, wiced_bt_pbc_status_t status);
extern void bdcpy(BD_ADDR a, const BD_ADDR b);
extern void *GKI_getbuf (uint16_t);
extern void GKI_freebuf (void *memPtr);
extern char *utl_strcpy( char *p_dst, char *p_src );
extern void utl_freebuf(void **p);

extern wiced_bt_pbc_status_t wiced_bt_pbc_convert_obx_to_pbc_status(wiced_bt_obex_status_t obx_status);

#endif /* WICED_BT_PBC_INT_H */
