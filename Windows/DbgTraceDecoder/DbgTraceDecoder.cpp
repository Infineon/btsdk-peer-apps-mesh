/*
* Copyright 2020, Cypress Semiconductor Corporation or a subsidiary of
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

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include "fid_app.h"

// represents one element of FID to file-path-name map
typedef struct
{
    unsigned short fid;
    const char* file_rel_path;
}dtd_file_t;

// map of FID to file-path-name
dtd_file_t files[] =
{
    { FID_MESH_APP__MESH_DISCOVERY_C,         "mesh_discovery.c" },
    { FID_MESH_APP__ACESS_LAYER_C,            "access_layer.c" },
    { FID_MESH_APP__CORE_AES_CCM_C,           "core_aes_ccm.c" },
    { FID_MESH_APP__IV_UPDT_C,                "iv_updt.c" },
    { FID_MESH_APP__KEY_REFRESH_C,            "key_refresh.c" },
    { FID_MESH_APP__FOUNDATION_C,             "foundation.c" },
    { FID_MESH_APP__FOUNDATION_CFG_MODEL_C,   "foundation_cfg_model.c" },
    { FID_MESH_APP__FOUNDATION_CRT_MSG_C,     "foundation_crt_msg.c" },
    { FID_MESH_APP__FOUNDATION_HEARTBEAT_C,   "foundation_heartbeat.c" },
    { FID_MESH_APP__FOUNDATION_IDENTITY_C,    "foundation_identity.c" },
    { FID_MESH_APP__FOUNDATION_MSG_HANDLER_C, "foundation_msg_handler.c" },
    { FID_MESH_APP__NETWORK_LAYER_C,          "network_layer.c" },
    { FID_MESH_APP__LOWER_TRANSPORT_LAYER_C,  "lower_transport_layer.c" },
    { FID_MESH_APP__UPPER_TRANSPORT_LAYER_C,  "upper_transport_layer.c" },
    { FID_MESH_APP__PB_TRANSPORT_C,           "pb_transport.c" },
    { FID_MESH_APP__PROVISIONING_C,           "provisioning.c" },
    { FID_MESH_APP__MESH_CORE_C,              "mesh_core.c" },
    { FID_MESH_APP__MESH_UTIL_C,              "mesh_util.c" },
    { FID_MESH_APP__FRIENDSHIP_C,             "friendship.c" },
    { FID_MESH_APP__LOW_POWER_C,              "low_power.c" },
    { FID_MESH_APP__FRIEND_C,                 "friend.c" },
    { FID_MESH_APP__HEALTH_C,                 "health.c" },
    { FID_MESH_APP__MESH_EVENT_C,             "mesh_event.c" },
    { FID_MESH_APP__DIRECTED_FORWARDING_C,          "directed_forwarding.c" },
    { FID_MESH_APP__DIRECTED_FORWARDING_MSG_C,      "directed_forwarding_msg.c" },
    { FID_MESH_APP__DIRECTED_FORWARDING_TIMER_C,    "directed_forwarding_timer.c" },
    { FID_MESH_APP__DIRECTED_FORWARDING_CTRL_MSG_C, "directed_forwarding_ctrl_msg.c" },
    { FID_MESH_APP__REMOTE_PROVISIONING_SERVER_C,      "remote_provision_server.c" },
};

/* Returns file name of the source file with specific source file id.
*  Parameters:
*   fid:    source file id
*  Return:  file name. On error return NULL.
*/
const char *fid_to_file_name(unsigned int fid)
{
    unsigned int i;
    for (i = 0; i < sizeof(files) / sizeof(files[0]); i++)
    {
        if (files[i].fid == fid)
            break;
    }
    return i < sizeof(files) / sizeof(files[0]) ? files[i].file_rel_path : NULL;
}

char trace_line_buf[1024];
unsigned int trace_line_num = 0;

/* Extracts next trace line from the input trace file and parses it. On parsing error prints line to stdout.
*  Parameters:
*   f:      handle of the input trace file.
*   fid:    pointer to variable to receive source file id
*   line:   pointer to variable to receive line number
*   var:    pointer to variable to receive variable value of the trace line
*   time:   pointer to variable to receive time in ms since device start
*  Return:  0 - success; 1 - EOF; 2 - error
*/
int get_next_trace_line(FILE* f, unsigned int *fid, unsigned int *line, unsigned int *var, unsigned int *time)
{
    int n, ret = 1;
    char* p;
    // read lines skiping invalid lines till we get good one
    while (1)
    {
        trace_line_num++;
        // read next line and exit on error or EOF
        if (NULL == fgets(trace_line_buf, sizeof(trace_line_buf), f))
        {
            if (feof(f))
                break;
            ret = 2;
            printf("Decoder: trace file read error 0x%x line:%d\n", errno, trace_line_num);
            break;
        }
        p = trace_line_buf;
        while (1)
        {
            // exit loop if it doesn't contain start signature "~@"
            if (NULL == (p = strstr(p, "~@")))
                break;
            // parse line and exit loop on success
            n = sscanf(p + 2, "%x %x %x %x", fid, line, var, time);
            if (n == 4)
                break;
            else if (n == 3)
            {
                // no time
                *time = 0xffffffff;
                break;
            }
            else
                p += 2;
        }
        // ignore line if it doesn't contain correct trace line but print it to the stdout
        if (p == NULL)
        {
            printf(trace_line_buf);
            continue;
        }
        // we got the line
        ret = 0;
        // if signature isn't at the line start then print signature preceeding string
        if (p != trace_line_buf)
        {
            char c = *p;
            *p = 0;
            printf("%s", trace_line_buf);
            *p = c;
        }
        break;
    }
    return ret;
}

FILE *f_src = NULL;         // Handle of the opened source file
unsigned int fid_prev;      // File ID of the opened source file
char src_file_path[256];    // buffer with path to the source files folder
int src_file_path_len;      // length of the path to the source files folder

/* Returns format string from the TRACE macro on the line line_num of the file fid.
*  In future it can be implemented using pre parsing of all source file to create
*  the file with all format srings of all source files
*   Parameters:
*       fid:            source file id
*       line_num:       line number
*       fmt:            buffer to receive format string
*       fmt_size:       size of the buffer fmt
*       p_params_num:   variable to receive number of parameters in the format string.
*   Return:  0 - success; 1 - error
*/
int get_format_string(unsigned int fid, unsigned int line_num, char* fmt, int fmt_size, unsigned int *p_params_num)
{
    char buf[1024];
    unsigned int line_num_cnt;
    // fid and line_num can not be 0
    if (fid == 0 || line_num == 0)
    {
        printf("Decoder: invalid param. fid:0x%x line_num:%d trace_line_num:%d\n", fid, line_num, trace_line_num);
        return 1;
    }

    if (f_src == NULL           // if it is firs call
        || fid != fid_prev)     // or source file other then previous one
    {
        // open new source file and close previous one
        const char * file_name = fid_to_file_name(fid);
        if (file_name == NULL)
        {
            printf("Decoder: no such fid:0x%x\n", fid);
            return 1;
        }
        strcpy(&src_file_path[src_file_path_len], file_name);
        FILE *f = fopen(src_file_path, "rt");
        if (f == NULL)
        {
            printf("Decoder: failed to read file. errno=0x%x fid:0x%x file:%s", errno, fid, src_file_path);
            return 1;
        }
        if (f_src)
            fclose(f_src);
        f_src = f;
    }
    // read line line_num from opened file
    fseek(f_src, 0, SEEK_SET);
    line_num_cnt = line_num;
    while (line_num_cnt)
    {
        if (NULL == fgets(buf, sizeof(buf), f_src))
        {
            // on error print trace and exit
            if (feof(f_src))
                printf("Decoder: no such line number %d in %s\n", line_num - line_num_cnt, &src_file_path[src_file_path_len]);
            else
                printf("Decoder: fgets failed. errno:0x%x file:%s", errno, &src_file_path[src_file_path_len]);
            break;
        }
        line_num_cnt--;
    }
    // just exit on error
    if (line_num_cnt)
        return 1;
    char *p, *p_end = NULL;
    do
    {
        // find trace macro
        if(NULL == (p = strstr(buf, "TRACE")))
            break;
        p += 5;
        // get parameters number from the trace macro name(it can be TRACE0, TRACE1, TRACE2, TRACE3 or TRACE4)
        *p_params_num = (int)(*p++ - '0');
        if (*p_params_num < 0 || *p_params_num > 4)
            break;
        // skip white space
        while (*p != 0 && (unsigned char)*p <= 0x20) p++;
        if (*p++ != '(')
            break;
        // find start of the format string
        if (NULL == (p = strchr(p, '\"')))
            break;
        p++;
        // find end of the format string
        p_end = p;
        while (p_end)
        {
            p_end = strchr(p_end, '\"');
            // exit loop if no end of string or found quote with escape (\")
            if (p_end == NULL || *p_end != '\\')
                break;
            p_end++;
        }
    } while (0);
    if (p_end == NULL)
    {
        printf("Decoder: no format string. line number:%d file:%s trace_line_num:%d trace_line_buf:%s\n", line_num, &src_file_path[src_file_path_len], trace_line_num, trace_line_buf);
        return 1;
    }
    int len = (int)(p_end - p);
    if (len >= fmt_size)
    {
        printf("Decoder: format string doesn't fit into buffer. line number:%d file:%s\n", line_num, &src_file_path[src_file_path_len]);
        return 1;
    }
    // remove new_line at the end
    if (len > 1 && p[len - 1] == 'n' && p[len - 2] == '\\')
        len -= 2;
    // it can be empty string
    if (len)
        memcpy(fmt, p, len);
    fmt[len] = 0;
    return 0;
}


const char *help =
"command line format:\n"
"    DbgTraceEncoder.exe <trace_file> <sources_folder_path>\n"
"where:\n"
"    <trace_file> - full or relative path file name of the trace file\n"
"    <sources_folder_path> - full or relative path to the sources folder\n"
"example:\n"
"    DbgTraceEncoder.exe C:\\Users\\viako\\Documents\\WICED\\WICED-Studio-4.1\\20735-B0_Bluetooth\\libraries\\mesh_core_lib\n";
int main(int argc, char* argv[])
{
    int ret = 2;
    char fmt[1024];
    FILE *f_trace_in = NULL;
    unsigned int fid, line_num, var, params_num, time;
    do
    {
        // make sure command line has two params
        if (argc != 3)
        {
            printf("Decoder: Invalid command line\n");
            // pring help text
            printf(help);
            break;
        }

        // copy path of the source files folder to the buffer and calculate its length
        strcpy(src_file_path, argv[2]);
        src_file_path_len = (int)strlen(src_file_path);
        if (src_file_path_len == 0)
        {
            printf("Decoder: Invalid folder path\n");
            break;
        }
        // make sure it is terminated with slash
        if (src_file_path[src_file_path_len - 1] != '\\' && src_file_path[src_file_path_len - 1] != '/')
        {
            src_file_path[src_file_path_len++] = '\\';
            src_file_path[src_file_path_len] = 0;
        }
        // open trace file
        if (NULL == (f_trace_in = fopen(argv[1], "rt")))
        {
            printf("Decoder: failed to open trace file. errno:0x%x", errno);
            break;
        }
        // decode trace file printing decoded lines to the stdout
        while (1)
        {
            // get next line and exit on error or EOF
            ret = get_next_trace_line(f_trace_in, &fid, &line_num, &var, &time);
            if (ret)
                break;
            // get format string from the line line_num of the file fid ignorin that trace line on error
            if (get_format_string(fid, line_num, fmt, sizeof(fmt), &params_num))
                continue;
            // print time if it present
            if(time != 0xffffffff)
                printf(" %03d.%03d ", (time / 1000) % 1000, time % 1000);
            // print trace
            switch (params_num)
            {
            case 0:
                if (*fmt)
                    printf(fmt);
                break;
            case 1:
                printf(fmt, var);
                break;
            case 2:
                printf(fmt, (unsigned short)(var >> 16), (unsigned short)var);
                break;
            case 3:
                printf(fmt, (unsigned char)(var >> 24), (unsigned char)(var >> 16), (unsigned short)var);
                break;
            case 4:
                printf(fmt, (unsigned char)(var >> 24), (unsigned char)(var >> 16), (unsigned char)(var >> 8), (unsigned char)var);
                break;
            }
            printf("\n");
        }
        // on EOF return success
        if (ret == 1)
            ret = 0;
    } while (0);
    // close files
    if (f_trace_in)
        fclose(f_trace_in);
    if (f_src)
        fclose(f_src);

    return ret;
}
