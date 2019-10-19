/*
 * Copyright Cypress Semiconductor
 */

/** @file
 *
 * This file implements the MeshNativeHelper class which wraps all mesh libraries and fucntions.
 */

#import "stdio.h"
#import "stdlib.h"
#import "time.h"
#import "MeshNativeHelper.h"
#import "IMeshNativeCallback.h"
#import "mesh_main.h"
#import "wiced_timer.h"
#import "wiced_bt_ble.h"
#import "wiced_bt_mesh_model_defs.h"
#import "wiced_bt_mesh_models.h"
#import "wiced_bt_mesh_event.h"
#import "wiced_bt_mesh_core.h"
#import "wiced_bt_mesh_provision.h"
#import "wiced_bt_mesh_db.h"
#import "wiced_mesh_client.h"
#import <CommonCrypto/CommonDigest.h>

extern void mesh_application_init(void);
extern void mesh_client_advert_report(uint8_t *bd_addr, uint8_t addr_type, int8_t rssi, uint8_t *adv_data);
extern wiced_bool_t initTimer(void);
extern void setDfuFilePath(char* dfuFilepath);
extern char *getDfuFilePath(void);


@implementation MeshNativeHelper
{
    // define instance variables.
}


// define class variables.
static id nativeCallbackDelegate;   // Object instance that obeys IMeshNativeHelper protocol
static MeshNativeHelper *_instance;
static char provisioner_uuid[40];  // Used to store provisioner UUID string.
static dispatch_once_t onceToken;
static dispatch_once_t zoneOnceToken;

// siglone instance of DFW metadata data.
static uint8_t dfuFwId[WICED_BT_MESH_MAX_FIRMWARE_ID_LEN];
static uint32_t dfuFwIdLen;
static uint8_t dfuValidationData[WICED_BT_MESH_MAX_VALIDATION_DATA_LEN];
static uint32_t dfuValidationDataLen;
void mesh_dfu_metadata_init()
{
    dfuFwIdLen = 0;
    memset(dfuFwId, 0, WICED_BT_MESH_MAX_FIRMWARE_ID_LEN);
    dfuFwIdLen = 0;
    memset(dfuValidationData, 0, WICED_BT_MESH_MAX_VALIDATION_DATA_LEN);
}

/*
 * Implementation of APIs that required by wiced mesh core stack library for event and data callback.
 */

void meshClientUnprovisionedDeviceFoundCb(uint8_t *uuid, uint16_t oob, uint8_t *name, uint8_t name_len)
{
    NSString *deviceName = nil;
    if (uuid == NULL) {
        NSLog(@"[MeshNativeHelper, meshClientFoundUnprovisionedDeviceCb] error: invalid parameters, uuid=0x%p, name_len=%d", uuid, name_len);
        return;
    }
    if (name != NULL && name_len > 0) {
        deviceName = [[NSString alloc] initWithBytes:name length:name_len encoding:NSUTF8StringEncoding];
    }
    NSLog(@"[MeshNativeHelper meshClientFoundUnprovisionedDeviceCb] found device name: %@, oob: 0x%04x, uuid: ", deviceName, oob); dumpHexBytes(uuid, MAX_UUID_SIZE);
    [nativeCallbackDelegate onDeviceFound:[[NSUUID alloc] initWithUUIDBytes:uuid]
                                      oob:oob
                                  uriHash:0
                                     name:deviceName];
}

void meshClientProvisionCompleted(uint8_t status, uint8_t *p_uuid)
{
    if (p_uuid == NULL) {
        NSLog(@"[MeshNativeHelper meshClientProvisionCompleted] error: invalid parameters, uuid=0x%p", p_uuid);
        return;
    }
    NSLog(@"[MeshNativeHelper meshClientProvisionCompleted] status: %u", status);
    [nativeCallbackDelegate meshClientProvisionCompletedCb:status uuid:[[NSUUID alloc] initWithUUIDBytes:p_uuid]];
}

// called when mesh network connection status changed.
void linkStatus(uint8_t is_connected, uint32_t connId, uint16_t addr, uint8_t is_over_gatt)
{
    NSLog(@"[MeshNativeHelper linkStatus] is_connected: %u, connId: 0x%08x, addr: 0x%04x, is_over_gatt: %u", is_connected, connId, addr, is_over_gatt);
    [nativeCallbackDelegate onLinkStatus:is_connected connId:connId addr:addr isOverGatt:is_over_gatt];
}

// callback for meshClientConnect API.
void meshClientNodeConnectionState(uint8_t status, char *p_name)
{
    if (p_name == NULL || *p_name == '\0') {
        NSLog(@"[MeshNativeHelper meshClientNodeConnectionState] error: invalid parameters, p_name=0x%p", p_name);
        return;
    }
    NSLog(@"[MeshNativeHelper meshClientNodeConnectionState] status: 0x%02x, device_name: %s", status, p_name);
    [nativeCallbackDelegate meshClientNodeConnectStateCb:status componentName:[NSString stringWithUTF8String:(const char *)p_name]];
}

void resetStatus(uint8_t status, char *device_name)
{
    if (device_name == NULL || *device_name == '\0') {
        NSLog(@"[MeshNativeHelper resetStatus] error: invalid parameters, device_name=0x%p", device_name);
        return;
    }
    NSLog(@"[MeshNativeHelper resetStatus] status: 0x%02x, device_name: %s", status, device_name);
    [nativeCallbackDelegate onResetStatus:status devName:[NSString stringWithUTF8String:(const char *)device_name]];
}

void meshClientOnOffState(const char *device_name, uint8_t target, uint8_t present, uint32_t remaining_time)
{
    if (device_name == NULL || *device_name == '\0') {
        NSLog(@"[MeshNativeHelper meshClientOnOffState] error: invalid parameters, device_name=0x%p", device_name);
        return;
    }
    NSLog(@"[MeshNativeHelper meshClientOnOffState] device_name: %s, target: %u, present: %u, remaining_time: %u", device_name, target, present, remaining_time);
    [nativeCallbackDelegate meshClientOnOffStateCb:[NSString stringWithUTF8String:(const char *)device_name] target:target present:present remainingTime:remaining_time];
}

void meshClientLevelState(const char *device_name, int16_t target, int16_t present, uint32_t remaining_time)
{
    if (device_name == NULL || *device_name == '\0') {
        NSLog(@"[MeshNativeHelper meshClientLevelState] error: invalid parameters, device_name=0x%p", device_name);
        return;
    }
    NSLog(@"[MeshNativeHelper meshClientLevelState] device_name: %s, target: %u, present: %u, remaining_time: %u", device_name, target, present, remaining_time);
    [nativeCallbackDelegate meshClientLevelStateCb:[NSString stringWithUTF8String:(const char *)device_name]
                                            target:target
                                           present:present
                                    remainingTime:remaining_time];
}

void meshClientLightnessState(const char *device_name, uint16_t target, uint16_t present, uint32_t remaining_time)
{
    if (device_name == NULL || *device_name == '\0') {
        NSLog(@"[MeshNativeHelper meshClientLightnessState] error: invalid parameters, device_name=0x%p", device_name);
        return;
    }
    NSLog(@"[MeshNativeHelper meshClientLightnessState] device_name: %s, target: %u, present: %u, remaining_time: %u", device_name, target, present, remaining_time);
    [nativeCallbackDelegate meshClientLightnessStateCb:[NSString stringWithUTF8String:(const char *)device_name]
                                                target:target
                                               present:present
                                         remainingTime:remaining_time];
}

void meshClientHslState(const char *device_name, uint16_t lightness, uint16_t hue, uint16_t saturation, uint32_t remaining_time)
{
    if (device_name == NULL || *device_name == '\0') {
        NSLog(@"[MeshNativeHelper meshClientHslState] error: invalid parameters, device_name=0x%p", device_name);
        return;
    }
    NSLog(@"[MeshNativeHelper meshClientHslState] device_name: %s, lightness: %u, hue: %u, saturation: %u, remaining_time: %u",
          device_name, lightness, hue, saturation, remaining_time);
    [nativeCallbackDelegate meshClientHslStateCb:[NSString stringWithUTF8String:(const char *)device_name]
                                       lightness:lightness hue:hue saturation:saturation];
}

void meshClientCtlState(const char *device_name, uint16_t present_lightness, uint16_t present_temperature, uint16_t target_lightness, uint16_t target_temperature, uint32_t remaining_time)
{
    if (device_name == NULL || *device_name == '\0') {
        NSLog(@"[MeshNativeHelper meshClientCtlState] error: invalid parameters, device_name=0x%p", device_name);
        return;
    }
    NSLog(@"[MeshNativeHelper meshClientCtlState] device_name: %s, present_lightness: %u, present_temperature: %u, target_lightness: %u, target_temperature: %u, remaining_time: %u", device_name, present_lightness, present_temperature, target_lightness, target_temperature, remaining_time);
    [nativeCallbackDelegate meshClientCtlStateCb:[NSString stringWithUTF8String:(const char *)device_name]
                                presentLightness:present_lightness
                              presentTemperature:present_temperature
                                 targetLightness:target_lightness
                               targetTemperature:target_temperature
                                   remainingTime:remaining_time];
}

void meshClientDbChangedState(char *mesh_name)
{
    if (mesh_name == NULL || *mesh_name == '\0') {
        NSLog(@"[MeshNativeHelper meshClientDbChangedState] error: invalid parameters, mesh_name=0x%p", mesh_name);
        return;
    }
    NSLog(@"[MeshNativeHelper meshClientDbChangedState] mesh_name: %s", mesh_name);
    [nativeCallbackDelegate onDatabaseChangedCb:[NSString stringWithUTF8String:mesh_name]];
}

void meshClientSensorStatusChangedCb(const char *device_name, int property_id, uint8_t length, uint8_t *value)
{
    if (device_name == NULL || *device_name == '\0') {
        NSLog(@"[MeshNativeHelper meshClientSensorStatusChangedCb] error: invalid device_name:%s or property_id:%d, length=%d", device_name, property_id, length);
        return;
    }
    NSLog(@"[MeshNativeHelper meshClientSensorStatusChangedCb] device_name:%s, property_id:%d, value lenght:%d", device_name, property_id, length);
    [nativeCallbackDelegate onMeshClientSensorStatusChanged:[NSString stringWithUTF8String:device_name]
                                                 propertyId:(uint32_t)property_id
                                                       data:[NSData dataWithBytes:value length:length]];
}

void meshClientVendorSpecificDataCb(const char *device_name, uint16_t company_id, uint16_t model_id, uint8_t opcode, uint8_t *p_data, uint16_t data_len)
{
    if (device_name == NULL || *device_name == '\0') {
        NSLog(@"[MeshNativeHelper meshClientVendorSpecificDataCb] error: invalid device_name NULL");
        return;
    }
    NSLog(@"[MeshNativeHelper meshClientVendorSpecificDataCb] device_name:%s, company_id:%d, model_id:%d, opcode:%d, data_len:%d",
          device_name, company_id, model_id, opcode, data_len);
    [nativeCallbackDelegate onMeshClientVendorSpecificDataChanged:[NSString stringWithUTF8String:device_name]
                                                        companyId:company_id modelId:model_id opcode:opcode
                                                             data:[NSData dataWithBytes:p_data length:data_len]];
}

mesh_client_init_t mesh_client_init_callback = {
    .unprovisioned_device_callback = meshClientUnprovisionedDeviceFoundCb,
    .provision_status_callback = meshClientProvisionCompleted,
    .connect_status_callback = linkStatus,
    .node_connect_status_callback = meshClientNodeConnectionState,
    .database_changed_callback = meshClientDbChangedState,
    .on_off_changed_callback = meshClientOnOffState,
    .level_changed_callback = meshClientLevelState,
    .lightness_changed_callback = meshClientLightnessState,
    .hsl_changed_callback = meshClientHslState,
    .ctl_changed_callback = meshClientCtlState,
    .sensor_changed_callback = meshClientSensorStatusChangedCb,
    .vendor_specific_data_callback = meshClientVendorSpecificDataCb,
};

// timer based iOS platform.
static uint32_t gMeshTimerId = 1;       // always > 0; 1 is the first and the app whole life second pediodic timer; other values can be reused.
static NSMutableDictionary *gMeshTimersDict = nil;

-(void) meshTimerInit
{
    if (gMeshTimersDict == nil) {
        EnterCriticalSection();
        if (gMeshTimersDict == nil) {
            gMeshTimersDict = [[NSMutableDictionary alloc] initWithCapacity:5];
        }
        LeaveCriticalSection();
    }
}

-(uint32_t) allocateMeshTimerId
{
    uint32_t timerId = 0;   // default set to invalid timerId
    EnterCriticalSection();
    do {
        timerId = gMeshTimerId++;
        if (timerId == 0) { // the gMeshTimerid must be round back.
            continue;
        }
        // avoid the same timerId was used, because some timer running for long time or  presistent.
        if ([gMeshTimersDict valueForKey:[NSString stringWithFormat:@"%u", timerId]] == nil) {
            break;  // return new not used timerId.
        }
    } while (true);
    LeaveCriticalSection();
    return timerId;
}

-(void) timerFiredMethod:(NSTimer *)timer
{
    NSString * timerKey = timer.userInfo;
    uint32_t timerId = 0;
    if (timerKey != nil) {
        timerId = (uint32_t)timerKey.longLongValue;
    }

    //NSLog(@"[MeshNativeHelper timerFiredMethod] timerId:%u", timerId);
    MeshTimerFunc((long)timerId);
}

/*
 * @param timeout   Timer trigger interval, uint: milliseconds.
 * @param type      The timer type.
 *                  When the timer type is WICED_SECONDS_TIMER or WICED_MILLI_SECONDS_TIMER,
 *                      the timer will be invalidated after it fires.
 *                  When the timer type is WICED_SECONDS_PERIODIC_TIMER or WICED_MILLI_SECONDS_PERIODIC_TIMER,
 *                      the timer will repeatedly reschedule itself until stopped.
 * @return          A non-zero timerId will be returned when started on success. Otherwize, 0 will be return on failure.
 */
-(uint32_t) meshStartTimer:(uint32_t)timeout type:(uint16_t)type
{
    [MeshNativeHelper.getSharedInstance meshTimerInit];
    uint32_t timerId = [MeshNativeHelper.getSharedInstance allocateMeshTimerId];
    Boolean repeats = (type == WICED_SECONDS_PERIODIC_TIMER || type == WICED_MILLI_SECONDS_PERIODIC_TIMER) ? true : false;
    NSTimeInterval interval = (NSTimeInterval)timeout;
    interval /= (NSTimeInterval)1000;
    NSString * timerKey = [NSString stringWithFormat:@"%u", timerId];
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:interval
                                                      target:MeshNativeHelper.getSharedInstance
                                                    selector:@selector(timerFiredMethod:)
                                                    userInfo:timerKey
                                                     repeats:repeats];
    if (timer == nil) {
        NSLog(@"[MeshNativeHelper meshStartTimer] error: failed to create and init the timer");
        return 0;
    }

    NSArray *timerInfo = [[NSArray alloc] initWithObjects:[NSNumber numberWithUnsignedInt:timerId], [NSNumber numberWithUnsignedShort:type], timer, nil];
    [gMeshTimersDict setObject:timerInfo forKey:timerKey];
    //NSLog(@"[MeshNativeHelper meshStartTimer] timerId:%u started, type=%u, interval=%f", timerId, type, interval);
    return timerId;
}
uint32_t start_timer(uint32_t timeout, uint16_t type) {
    return [MeshNativeHelper.getSharedInstance meshStartTimer:timeout type:type];
}

-(void) meshStopTimer:(uint32_t)timerId
{
    [MeshNativeHelper.getSharedInstance meshTimerInit];
    NSString *timerKey = [NSString stringWithFormat:@"%u", timerId];
    NSArray *timerInfo = [gMeshTimersDict valueForKey:timerKey];
    if (timerInfo != nil && [timerInfo count] == 3) {
        NSTimer *timer = timerInfo[2];
        if (timer != nil) {
            [timer invalidate];
        }
    }
    [gMeshTimersDict removeObjectForKey:timerKey];
    //NSLog(@"[MeshNativeHelper meshStopTimer] timerId:%u stopped", timerId);
}
void stop_timer(uint32_t timerId)
{
    [MeshNativeHelper.getSharedInstance meshStopTimer:timerId];
}

/*
 * @param timeout   Timer trigger interval, uint: milliseconds.
 * @param type      The timer type.
 *                  When the timer type is WICED_SECONDS_TIMER or WICED_MILLI_SECONDS_TIMER,
 *                      the timer will be invalidated after it fires.
 *                  When the timer type is WICED_SECONDS_PERIODIC_TIMER or WICED_MILLI_SECONDS_PERIODIC_TIMER,
 *                      the timer will repeatedly reschedule itself until stopped.
 * @return          The same non-zero timerId will be returned when restarted on success. Otherwize, 0 will be return on failure.
 */
-(uint32_t) meshRestartTimer:(uint32_t)timeout timerId:(uint32_t)timerId
{
    [MeshNativeHelper.getSharedInstance meshTimerInit];
    NSString *timerKey = [NSString stringWithFormat:@"%u", timerId];
    NSArray *timerInfo = [gMeshTimersDict valueForKey:timerKey];
    NSNumber *numType = timerInfo[1];
    NSTimer *timer = timerInfo[2];
    uint16_t type;

    if (timerInfo == nil || [timerInfo count] != 3 || timer == nil || numType == nil) {
        NSLog(@"[MeshNativeHelper meshRestartTimer] error: failed to fetch the timer with timerId=%u", timerId);
        return 0;
    }

    type = [numType unsignedShortValue];
    [timer invalidate];

    Boolean repeats = (type == WICED_SECONDS_PERIODIC_TIMER || type == WICED_MILLI_SECONDS_PERIODIC_TIMER) ? true : false;
    NSTimeInterval interval = (NSTimeInterval)timeout;
    interval /= (NSTimeInterval)1000;
    timer = [NSTimer scheduledTimerWithTimeInterval:interval
                                             target:MeshNativeHelper.getSharedInstance
                                           selector:@selector(timerFiredMethod:)
                                           userInfo:timerKey
                                            repeats:repeats];
    if (timer == nil) {
        NSLog(@"[MeshNativeHelper meshRestartTimer] error: failed to create and init the timer");
        return 0;
    }

    timerInfo = [[NSArray alloc] initWithObjects:[NSNumber numberWithUnsignedInt:timerId], [NSNumber numberWithUnsignedShort:type], timer, nil];
    [gMeshTimersDict setObject:timerInfo forKey:timerKey];
    //NSLog(@"%s timerId:%u restarted, type=%u, interval=%f", __FUNCTION__, timerId, type, interval);
    return timerId;
}
uint32_t restart_timer(uint32_t timeout, uint32_t timerId ) {
    return [MeshNativeHelper.getSharedInstance meshRestartTimer:timeout timerId:timerId];
}

void mesh_provision_gatt_send(uint16_t connId, uint8_t *packet, uint32_t packet_len)
{
    if (packet == NULL || packet_len == 0) {
        NSLog(@"[MeshNativeHelper mesh_provision_gatt_send] error: connId=%d packet=0x%p, packet_len=%u", connId, packet, packet_len);
        return;
    }
    NSData *data = [[NSData alloc] initWithBytes:packet length:packet_len];
    [nativeCallbackDelegate onProvGattPktReceivedCallback:connId data:data];
}

void proxy_gatt_send_cb(uint32_t connId, uint32_t ref_data, const uint8_t *packet, uint32_t packet_len)
{
    if (packet == NULL || packet_len == 0) {
        NSLog(@"[MeshNativeHelper proxy_gatt_send_cb] error: invalid parameters, packet=0x%p, packet_len=%u", packet, packet_len);
        return;
    }
    NSData *data = [[NSData alloc] initWithBytes:packet length:packet_len];
    [nativeCallbackDelegate onProxyGattPktReceivedCallback:connId data:data];
}

wiced_bool_t mesh_bt_gatt_le_disconnect(uint32_t connId)
{
    return [nativeCallbackDelegate meshClientDisconnect:(uint16_t)connId];
}

wiced_bool_t mesh_bt_gatt_le_connect(wiced_bt_device_address_t bd_addr, wiced_bt_ble_address_type_t bd_addr_type,
                                     wiced_bt_ble_conn_mode_t conn_mode, wiced_bool_t is_direct)
{
    if (bd_addr == NULL) {
        NSLog(@"[MeshNativeHelper mesh_bt_gatt_le_connect] invalid parameters, bd_addr=0x%p", bd_addr);
        return false;
    }
    NSData *bdAddr = [[NSData alloc] initWithBytes:bd_addr length:BD_ADDR_LEN];
    return [nativeCallbackDelegate meshClientConnect:bdAddr];
}

wiced_bool_t mesh_set_scan_type(uint8_t is_active)
{
    return [nativeCallbackDelegate meshClientSetScanTypeCb:is_active];
}

wiced_bool_t mesh_adv_scan_start(void)
{
    return [nativeCallbackDelegate meshClientAdvScanStartCb];
}

void mesh_adv_scan_stop(void)
{
    [nativeCallbackDelegate meshClientAdvScanStopCb];
}

/*
 * Only one instance of the MeshNativeHelper class can be created all the time.
 */
+(MeshNativeHelper *) getSharedInstance
{
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
}

+(instancetype) allocWithZone:(struct _NSZone *)zone
{
    //static dispatch_once_t onceToken;
    dispatch_once(&zoneOnceToken, ^{
        _instance = [super allocWithZone:zone];
        [_instance instanceInit];
    });
    return _instance;
}

-(id)copyWithZone:(NSZone *)zone {
    return _instance;
}

/* Do all necessory initializations for the shared class instance. */
-(void) instanceInit
{
    [self meshTimerInit];
    [self meshBdAddrDictInit];
    mesh_dfu_metadata_init();
}

+(NSString *) getProvisionerUuidFileName
{
    return @"prov_uuid.bin";
}

+(int) setFileStorageAtPath:(NSString *)path
{
    return [MeshNativeHelper setFileStorageAtPath:path provisionerUuid:nil];
}

+(int) setFileStorageAtPath:(NSString *)path provisionerUuid: (NSUUID *)provisionerUuid
{
    Boolean bRet = true;
    NSFileManager *fileManager = [NSFileManager defaultManager];

    // check if the provisioner_uuid has been read from or has been created and written to the storage file.
    if (strlen(provisioner_uuid) == 32) {
        return 0;
    }

    if (![fileManager fileExistsAtPath:path]) {
        bRet = [fileManager createDirectoryAtPath:path withIntermediateDirectories:true attributes:nil error:nil];
        NSLog(@"[MeshNativeHelper setFileStorageAtPath] create direcotry \"%@\" %s", path, bRet ? "success" : "failed");
    }
    if (!bRet || ![fileManager isWritableFileAtPath:path]) {
        NSLog(@"[MeshNativeHelper setFileStorageAtPath] error: cannot wirte at path:\"%@\", bRet=%u", path, bRet);
        return -1;
    }

    // set this file directory to be current working directory
    const char *cwd = [path cStringUsingEncoding:NSASCIIStringEncoding];
    int cwdStatus = chdir(cwd);
    if (cwdStatus != 0) {
        NSLog(@"[MeshNativeHelper setFileStorageAtPath] error: unable to change current working directory to \"%s\" ", cwd);
        return -2;
    } else {
        NSLog(@"[MeshNativeHelper setFileStorageAtPath] Done, change current working directory to \"%@\"", path);
    }

    // create the prov_uuid.bin to stote the UUID string value or read the stored UUID string if existing.
    NSFileHandle *handle;
    NSData *data;
    NSString *filePath = [path stringByAppendingPathComponent: [MeshNativeHelper getProvisionerUuidFileName]];
    if ([fileManager fileExistsAtPath:filePath]) {
        handle = [NSFileHandle fileHandleForReadingAtPath:filePath];
        if (handle == nil) {
            NSLog(@"[MeshNativeHelper setFileStorageAtPath] error: unable to open file \"%@\" for reading", filePath);
            return -3;
        }

        // read back the stored provisoner uuid string from prov_uuid.bin file.
        data = [handle readDataOfLength:32];
        [data getBytes:provisioner_uuid length:(NSUInteger)32];
        provisioner_uuid[32] = '\0';  // always set the terminate character for the provisioner uuid string.
        NSLog(@"[MeshNativeHelper setFileStorageAtPath] read provisioner_uuid: %s from prov_uuid.bin", provisioner_uuid);
    } else {
        bRet = [fileManager createFileAtPath:filePath contents:nil attributes:nil];
        handle = [NSFileHandle fileHandleForWritingAtPath:filePath];
        if (!bRet || handle == nil) {
            if (handle) {
                [handle closeFile];
            }
            NSLog(@"[MeshNativeHelper setFileStorageAtPath] error: unable to create file \"%@\" for writing", filePath);
            return -4;
        }

        // Create a new UUID string for the provisoner and stored to the prov_uuid.bin file.
        // Based on UUID with RFC 4122 version 4, the format is XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX. It's 36 characters.
        // but the UUID format required in the provision_uuid should not including the '-' character,
        // so the UUID string stored in provision_uuid should be 32 characters, it must be conveted here.
        int j = 0;
        char *rfcuuid = NULL;
        if (provisionerUuid == nil) {
            rfcuuid = (char *)NSUUID.UUID.UUIDString.UTF8String;
        } else {
            rfcuuid = (char *)provisionerUuid.UUIDString.UTF8String;
        }
        for (int i = 0; i < strlen(rfcuuid); i++) {
            if (rfcuuid[i] == '-') {
                continue;
            }
            provisioner_uuid[j++] = rfcuuid[i];
        }
        provisioner_uuid[j] = '\0';
        data = [NSData dataWithBytes:provisioner_uuid length:strlen(provisioner_uuid)];
        [handle writeData:data];    // write 32 bytes.
        NSLog(@"[MeshNativeHelper setFileStorageAtPath] create provisioner_uuid: %s, and stored to prov_uuid.bin", provisioner_uuid);
    }
    [handle closeFile];
    return 0;
}

/*
 * MeshNativeHelper class functions.
 */

-(void) registerNativeCallback: (id)delegate
{
    NSLog(@"%s", __FUNCTION__);
    nativeCallbackDelegate = delegate;
}

+(int) meshClientNetworkExists:(NSString *) meshName
{
    NSLog(@"%s, meshName: %@", __FUNCTION__, meshName);
    return mesh_client_network_exists((char *)[meshName UTF8String]);
}

+(int) meshClientNetworkCreate:(NSString *)provisionerName meshName:(NSString *)meshName
{
    NSLog(@"%s, provisionerName: %@, meshName: %@", __FUNCTION__, provisionerName, meshName);
    int ret;
    EnterCriticalSection();
    ret = mesh_client_network_create(provisionerName.UTF8String, provisioner_uuid, (char *)meshName.UTF8String);
    LeaveCriticalSection();
    return ret;
}

void mesh_client_network_opened(uint8_t status) {
    NSLog(@"%s, status: %u", __FUNCTION__, status);
    [nativeCallbackDelegate meshClientNetworkOpenCb:status];
}
+(int) meshClientNetworkOpen:(NSString *)provisionerName meshName:(NSString *)meshName
{
    NSLog(@"%s, provisionerName: %@, meshName: %@", __FUNCTION__, provisionerName, meshName);
    int ret;
    EnterCriticalSection();
    ret = mesh_client_network_open(provisionerName.UTF8String, provisioner_uuid, (char *)meshName.UTF8String, mesh_client_network_opened);
    LeaveCriticalSection();
    return ret;
}

+(int) meshClientNetworkDelete:(NSString*)provisionerName meshName:(NSString *)meshName
{
    NSLog(@"%s, provisionerName: %@, meshName: %@", __FUNCTION__, provisionerName, meshName);
    int ret;
    EnterCriticalSection();
    ret = mesh_client_network_delete(provisionerName.UTF8String, provisioner_uuid, (char *)meshName.UTF8String);
    LeaveCriticalSection();
    return ret;
}

+(void) meshClientNetworkClose
{
    NSLog(@"%s", __FUNCTION__);
    EnterCriticalSection();
    mesh_client_network_close();
    LeaveCriticalSection();
}

+(NSString *) meshClientNetworkExport:(NSString *)meshName
{
    NSLog(@"%s, meshName=%@", __FUNCTION__, meshName);
    char *jsonString = NULL;
    EnterCriticalSection();
    jsonString = mesh_client_network_export((char *)meshName.UTF8String);
    LeaveCriticalSection();
    if (jsonString == NULL) {
        return nil;
    }
    return [[NSString alloc] initWithUTF8String:jsonString];
}

+(NSString *) meshClientNetworkImport:(NSString *)provisionerName jsonString:(NSString *)jsonString
{
    NSLog(@"%s, provisionerName: %@, jsonString: %@", __FUNCTION__, provisionerName, jsonString);
    char *networkName = NULL;
    EnterCriticalSection();
    networkName = mesh_client_network_import(provisionerName.UTF8String, provisioner_uuid, (char *)jsonString.UTF8String, mesh_client_network_opened);
    LeaveCriticalSection();

    if (networkName == NULL) {
        return nil;
    }
    return [[NSString alloc] initWithUTF8String:networkName];
}


+(int) meshClientGroupCreate:(NSString *)groupName parentGroupName:(NSString *)parentGroupName
{
    NSLog(@"%s, groupName: %@, parentGroupName: %@", __FUNCTION__, groupName, parentGroupName);
    int ret;
    EnterCriticalSection();
    ret = mesh_client_group_create((char *)groupName.UTF8String, (char *)parentGroupName.UTF8String);
    LeaveCriticalSection();
    return ret;
}
+(int) meshClientGroupDelete:(NSString *)groupName
{
    NSLog(@"%s, groupName: %@", __FUNCTION__, groupName);
    int ret;
    EnterCriticalSection();
    ret = mesh_client_group_delete((char *)groupName.UTF8String);
    LeaveCriticalSection();
    return ret;
}

/*
 * This help function will convert the C strings from the input buffer to a NSArray<NSString *> array data,
 * and free C String if required.
 */
NSArray<NSString *> * meshCStringToOCStringArray(const char *cstrings, BOOL freeCString)
{
    NSMutableArray<NSString *> *stringArray = [[NSMutableArray<NSString *> alloc] init];
    char *p_str = (char *)cstrings;

    if (p_str == NULL || *p_str == '\0') {
        return NULL;
    }

    for (int i = 0; p_str != NULL && *p_str != '\0'; p_str += (strlen(p_str) + 1), i++) {
        stringArray[i] = [NSString stringWithUTF8String:p_str];
    }

    if (freeCString) {
        free((void *)cstrings);
    }
    return [NSArray<NSString *> arrayWithArray:stringArray];
}

+(NSArray<NSString *> *) meshClientGetAllNetworks
{
    NSLog(@"%s", __FUNCTION__);
    char *networks = mesh_client_get_all_networks();
    return meshCStringToOCStringArray(networks, TRUE);
}

+(NSArray<NSString *> *) meshClientGetAllGroups:(NSString *)inGroup
{
    NSLog(@"%s, inGroup: %@", __FUNCTION__, inGroup);
    char *groups = NULL;
    EnterCriticalSection();
    groups = mesh_client_get_all_groups((char *)inGroup.UTF8String);
    LeaveCriticalSection();
    return meshCStringToOCStringArray(groups, TRUE);
}

+(NSArray<NSString *> *) meshClientGetAllProvisioners
{
    NSLog(@"%s", __FUNCTION__);
    char *provisioners = NULL;
    EnterCriticalSection();
    provisioners = mesh_client_get_all_provisioners();
    LeaveCriticalSection();
    return meshCStringToOCStringArray(provisioners, TRUE);
}

+(NSArray<NSString *> *) meshClientGetDeviceComponents:(NSUUID *)uuid
{
    char *components = NULL;
    uint8_t p_uuid[16];
    [uuid getUUIDBytes:p_uuid];
    NSLog(@"%s device uuid: %s", __FUNCTION__, uuid.UUIDString.UTF8String);
    EnterCriticalSection();
    components = mesh_client_get_device_components(p_uuid);
    LeaveCriticalSection();
    return meshCStringToOCStringArray(components, TRUE);
}

+(NSArray<NSString *> *) meshClientGetGroupComponents:(NSString *)groupName
{
    NSLog(@"%s, groupName: %@", __FUNCTION__, groupName);
    char *componetNames = NULL;
    EnterCriticalSection();
    componetNames = mesh_client_get_group_components((char *)groupName.UTF8String);
    LeaveCriticalSection();
    return meshCStringToOCStringArray(componetNames, TRUE);
}

+(NSArray<NSString *> *) meshClientGetTargetMethods:(NSString *)componentName
{
    NSLog(@"%s, componentName: %@", __FUNCTION__, componentName);
    char *targetMethods = NULL;
    EnterCriticalSection();
    targetMethods = mesh_client_get_target_methods(componentName.UTF8String);
    LeaveCriticalSection();
    return meshCStringToOCStringArray(targetMethods, TRUE);
}

+(NSArray<NSString *> *) meshClientGetControlMethods:(NSString *)componentName
{
    NSLog(@"%s, componentName: %@", __FUNCTION__, componentName);
    char *controlMethods = NULL;
    EnterCriticalSection();
    controlMethods = mesh_client_get_control_methods(componentName.UTF8String);
    LeaveCriticalSection();
    return meshCStringToOCStringArray(controlMethods, TRUE);
}

+(uint8_t) meshClientGetComponentType:(NSString *)componentName
{
    NSLog(@"%s, componentName: %@", __FUNCTION__, componentName);
    uint8_t type;
    EnterCriticalSection();
    type = mesh_client_get_component_type((char *)componentName.UTF8String);
    LeaveCriticalSection();
    return type;
}

void meshClientComponentInfoStatusCallback(uint8_t status, char *component_name, char *component_info)
{
    NSLog(@"%s, status:0x%x", __FUNCTION__, status);
    NSString *componentName = nil;
    NSString *componentInfo = nil;
    if (component_name == NULL) {
        NSLog(@"%s, error, invalid parameters, component_name: is NULL", __FUNCTION__);
        return;
    }
    componentName = [NSString stringWithUTF8String:(const char *)component_name];
    if (component_info != NULL) {
        if (strstr(component_info, "Not Available") == NULL) {
            uint8_t firmware_id[8];
            memcpy(firmware_id, &component_info[34], 8);
            component_info[34] = '\0';
            NSLog(@"%s, firmware ID: %02X %02X %02X %02X %02X %02X %02X %02X\n", __FUNCTION__,
                   firmware_id[0], firmware_id[1], firmware_id[2], firmware_id[3],
                   firmware_id[4], firmware_id[5], firmware_id[6], firmware_id[7]);
            uint16_t pid = (uint16_t)(((uint16_t)(firmware_id[0]) << 8) | (uint16_t)(firmware_id[1]));
            uint16_t hwid = (uint16_t)(((uint16_t)(firmware_id[2]) << 8) | (uint16_t)(firmware_id[3]));
            uint8_t fwVerMaj = (uint8_t)firmware_id[4];
            uint8_t fwVerMin = (uint8_t)firmware_id[5];
            uint16_t fwVerRev = (uint16_t)(((uint16_t)(firmware_id[6]) << 8) | (uint16_t)(firmware_id[7]));
            NSLog(@"%s, Product ID:0x%04x (%u), HW Version ID:0x%04x (%u), Firmware Version, %u.%u.%u\n", __FUNCTION__,
                   pid, pid, hwid, hwid, fwVerMaj, fwVerMin, fwVerRev);
            char info[128] = { 0 };
            sprintf(info, "%s%d.%d.%d", component_info, fwVerMaj, fwVerMin, fwVerRev);
            componentInfo = [NSString stringWithUTF8String:(const char *)info];
        } else {
            componentInfo = [NSString stringWithUTF8String:(const char *)component_info];
        }

        NSLog(@"%s, componentInfo:%@", __FUNCTION__, componentInfo);
    } else {
        NSLog(@"%s, component_info string is NULL", __FUNCTION__);
    }
    [nativeCallbackDelegate meshClientComponentInfoStatusCb:status componentName:componentName componentInfo:componentInfo];
}

+(uint8_t) meshClientGetComponentInfo:(NSString *)componentName
{
    NSLog(@"%s, componentName:%@", __FUNCTION__, componentName);
    uint8_t ret;
    EnterCriticalSection();
    ret = mesh_client_get_component_info((char *)componentName.UTF8String, meshClientComponentInfoStatusCallback);
    LeaveCriticalSection();
    return ret;
}

/*
 * When the controlMethod is nil or empty, the library will register to receive messages sent to all type of messages.
 * When the groupName is nil or empty, the library will register to receive messages sent to all the groups.
 */
+(int) meshClientListenForAppGroupBroadcasts:(NSString *)controlMethod groupName:(NSString *)groupName startListen:(BOOL)startListen
{
    NSLog(@"%s, controlMethod:%@, groupName:%@, startListen:%d", __FUNCTION__, controlMethod, groupName, (int)startListen);
    char *listonControlMethod = (controlMethod != nil && controlMethod.length > 0) ? (char *)controlMethod.UTF8String : NULL;
    char *listonGroupName = (groupName != nil && groupName.length > 0) ? (char *)groupName.UTF8String : NULL;
    int ret;

    EnterCriticalSection();
    ret = mesh_client_listen_for_app_group_broadcasts(listonControlMethod, listonGroupName, (wiced_bool_t)startListen);
    LeaveCriticalSection();
    return ret;
}

+(NSString *) meshClientGetPublicationTarget:(NSString *)componentName isClient:(BOOL)isClient method:(NSString *)method
{
    NSLog(@"%s, componentName:%@, isClient:%d, method:%@", __FUNCTION__, componentName, (int)isClient, method);
    const char *targetName;
    EnterCriticalSection();
    targetName = mesh_client_get_publication_target(componentName.UTF8String, (uint8_t)isClient, method.UTF8String);
    LeaveCriticalSection();
    return (targetName == NULL) ? nil : [NSString stringWithUTF8String:targetName];
}

/*
 * Return 0 on failed to to get publication period or encountered any error.
 * Otherwise, return the publish period value on success.
 */
+(int) meshClientGetPublicationPeriod:(NSString *)componentName isClient:(BOOL)isClient method:(NSString *)method
{
    NSLog(@"%s, componentName:%@, isClient:%d, method:%@", __FUNCTION__, componentName, (int)isClient, method);
    int publishPeriod;
    EnterCriticalSection();
    publishPeriod = mesh_client_get_publication_period((char *)componentName.UTF8String, (uint8_t)isClient, method.UTF8String);
    LeaveCriticalSection();
    return publishPeriod;
}



+(int) meshClientRename:(NSString *)oldName newName:(NSString *)newName
{
    NSLog(@"%s oldName:%@, newName:%@", __FUNCTION__, oldName, newName);
    int ret;
    EnterCriticalSection();
    ret = mesh_client_rename((char *)oldName.UTF8String, (char *)newName.UTF8String);
    LeaveCriticalSection();
    return ret;
}

+(int) meshClientMoveComponentToGroup:(NSString *)componentName from:(NSString *)fromGroupName to:(NSString *)toGroupName
{
    NSLog(@"[MeshNativehelper meshClientMoveComponentToGroup] componentName:%@, fromGroupName:%@, toGroupName:%@",
          componentName, fromGroupName, toGroupName);
    int ret;
    EnterCriticalSection();
    ret = mesh_client_move_component_to_group(componentName.UTF8String, fromGroupName.UTF8String, toGroupName.UTF8String);
    LeaveCriticalSection();
    return ret;
}

+(int) meshClientConfigurePublication:(NSString *)componentName isClient:(uint8_t)isClient method:(NSString *)method targetName:(NSString *)targetName publishPeriod:(int)publishPeriod
{
    NSLog(@"[MeshNativehelper meshClientConfigurePublication] componentName:%@, isClient:%d, method:%@, targetName:%@ publishPeriod:%d",
          componentName, isClient, method, targetName, publishPeriod);
    int ret;
    EnterCriticalSection();
    ret = mesh_client_configure_publication(componentName.UTF8String, isClient, method.UTF8String, targetName.UTF8String, publishPeriod);
    LeaveCriticalSection();
    return ret;
}

+(uint8_t) meshClientProvision:(NSString *)deviceName groupName:(NSString *)groupName uuid:(NSUUID *)uuid identifyDuration:(uint8_t)identifyDuration
{
    NSLog(@"[MeshNativehelper meshClientProvision] deviceName:%@, groupName:%@, identifyDuration:%d", deviceName, groupName, identifyDuration);
    uint8_t ret;
    uint8_t p_uuid[16];
    [uuid getUUIDBytes:p_uuid];
    EnterCriticalSection();
    ret = mesh_client_provision(deviceName.UTF8String, groupName.UTF8String, p_uuid, identifyDuration);
    LeaveCriticalSection();
    return ret;
}

+(uint8_t) meshClientConnectNetwork:(uint8_t)useGattProxy scanDuration:(uint8_t)scanDuration
{
    NSLog(@"%s useGattProxy:%d, scanDuration:%d", __FUNCTION__, useGattProxy, scanDuration);
    uint8_t ret;
    EnterCriticalSection();
    ret = mesh_client_connect_network(useGattProxy, scanDuration);
    LeaveCriticalSection();
    return ret;
}

+(uint8_t) meshClientDisconnectNetwork:(uint8_t)useGattProxy
{
    NSLog(@"%s useGattProxy:%d", __FUNCTION__, useGattProxy);
    uint8_t ret;
    EnterCriticalSection();
    ret = mesh_client_disconnect_network();
    LeaveCriticalSection();
    return ret;
}

+(int) meshClientOnOffGet:(NSString *)deviceName
{
    NSLog(@"%s deviceName:%@", __FUNCTION__, deviceName);
    int ret;
    EnterCriticalSection();
    ret = mesh_client_on_off_get(deviceName.UTF8String);
    LeaveCriticalSection();
    return ret;
}

+(int) meshClientOnOffSet:(NSString *)deviceName onoff:(uint8_t)onoff reliable:(Boolean)reliable transitionTime:(uint32_t)transitionTime delay:(uint16_t)delay
{
    NSLog(@"[MeshNativehelper meshClientOnOffSet] deviceName:%@, onoff:%d, reliable:%d, transitionTime:%d, delay:%d",
          deviceName, onoff, reliable, transitionTime, delay);
    int ret;
    EnterCriticalSection();
    ret = mesh_client_on_off_set(deviceName.UTF8String, onoff, reliable, transitionTime, delay);
    LeaveCriticalSection();
    return ret;
}

+(int) meshClientLevelGet:(NSString *)deviceName
{
    NSLog(@"%s deviceName:%@", __FUNCTION__, deviceName);
    int ret;
    EnterCriticalSection();
    ret = mesh_client_level_get(deviceName.UTF8String);
    LeaveCriticalSection();
    return ret;
}

+(int) meshClientLevelSet:(NSString *)deviceName level:(int16_t)level reliable:(Boolean)reliable transitionTime:(uint32_t)transitionTime delay:(uint16_t)delay
{
    NSLog(@"[MeshNativehelper meshClientLevelSet] deviceName:%@, level:%d, reliable:%d, transitionTime:%d, delay:%d",
          deviceName, level, reliable, transitionTime, delay);
    int ret;
    EnterCriticalSection();
    ret = mesh_client_level_set(deviceName.UTF8String, (int16_t)level, reliable, transitionTime, delay);
    LeaveCriticalSection();
    return ret;
}

+(int) meshClientHslGet:(NSString *)deviceName
{
    NSLog(@"%s deviceName:%@", __FUNCTION__, deviceName);
    int ret;
    EnterCriticalSection();
    ret = mesh_client_hsl_get(deviceName.UTF8String);
    LeaveCriticalSection();
    return ret;
}

+(int) meshClientHslSet:(NSString *)deviceName lightness:(uint16_t)lightness hue:(uint16_t)hue saturation:(uint16_t)saturation reliable:(Boolean)reliable transitionTime:(uint32_t)transitionTime delay:(uint16_t)delay
{
    NSLog(@"[MeshNativehelper meshClientHslSet] deviceName:%@, lightness:%d, hue:%d, saturation:%d, reliable:%d, transitionTime:%d, delay:%d",
          deviceName, lightness, hue, saturation, reliable, transitionTime, delay);
    int ret;
    EnterCriticalSection();
    ret = mesh_client_hsl_set(deviceName.UTF8String, lightness, hue, saturation, reliable, transitionTime, delay);
    LeaveCriticalSection();
    return ret;
}

+(void) meshClientInit
{
    NSLog(@"[MeshNativehelper meshClientInit]");
    @synchronized (MeshNativeHelper.getSharedInstance) {
        srand((unsigned int)time(NULL));    // Set the seed value to avoid same pseudo-random intergers are generated.
        if (!initTimer()) {                 // The the global shared recurive mutex lock 'cs' befer using it.
            NSLog(@"[MeshNativehelper meshClientInit] error: failed to initiaze timer and shared recurive mutex lock. Stopped");
            return;
        }
        mesh_client_init(&mesh_client_init_callback);
    }
}

+(int) meshClientSetDeviceConfig:(NSString *)deviceName
                     isGattProxy:(int)isGattProxy
                        isFriend:(int)isFriend
                         isRelay:(int)isRelay
                          beacon:(int)beacon
                  relayXmitCount:(int)relayXmitCount
               relayXmitInterval:(int)relayXmitInterval
                      defaultTtl:(int)defaultTtl
                    netXmitCount:(int)netXmitCount
                 netXmitInterval:(int)netXmitInterval
{
    NSLog(@"[MeshNativehelper meshClientSetDeviceConfig] deviceName:%@, isGattProxy:%d, isFriend:%d, isRelay:%d, beacon:%d, relayXmitCount:%d, relayXmitInterval:%d, defaultTtl:%d, netXmitCount:%d, netXmitInterval%d",
          deviceName, isGattProxy, isFriend, isRelay, beacon, relayXmitCount, relayXmitInterval, defaultTtl, netXmitCount, netXmitInterval);
    int ret;
    char *device_name = NULL;
    if (deviceName != NULL && deviceName.length > 0) {
        device_name = (char *)deviceName.UTF8String;
    }
    EnterCriticalSection();
    ret = mesh_client_set_device_config(device_name,
                                        isGattProxy,
                                        isFriend,
                                        isRelay,
                                        beacon,
                                        relayXmitCount,
                                        relayXmitInterval,
                                        defaultTtl,
                                        netXmitCount,
                                        netXmitInterval);
    LeaveCriticalSection();
    return ret;
}

+(int) meshClientSetPublicationConfig:(int)publishCredentialFlag
               publishRetransmitCount:(int)publishRetransmitCount
            publishRetransmitInterval:(int)publishRetransmitInterval
                           publishTtl:(int)publishTtl
{
    NSLog(@"[MeshNativehelper meshClientSetPublicationConfig] publishCredentialFlag:%d, publishRetransmitCount:%d, publishRetransmitInterval:%d, publishTtl:%d",
          publishCredentialFlag, publishRetransmitCount, publishRetransmitInterval, publishTtl);
    int ret;
    EnterCriticalSection();
    ret = mesh_client_set_publication_config(publishCredentialFlag,
                                             publishRetransmitCount,
                                             publishRetransmitInterval,
                                             publishTtl);
    LeaveCriticalSection();
    return ret;
}

+(int) meshClientResetDevice:(NSString *)componentName
{
    NSLog(@"%s componentName:%@", __FUNCTION__, componentName);
    int ret;
    EnterCriticalSection();
    ret = mesh_client_reset_device((char *)componentName.UTF8String);
    LeaveCriticalSection();
    return ret;
}

+(int) meshClientVendorDataSet:(NSString *)deviceName companyId:(uint16_t)companyId modelId:(uint16_t)modelId opcode:(uint8_t)opcode data:(NSData *)data
{
    NSLog(@"%s deviceName:%@", __FUNCTION__, deviceName);
    int ret;
    EnterCriticalSection();
    ret = mesh_client_vendor_data_set(deviceName.UTF8String, companyId, modelId, opcode, (uint8_t *)data.bytes, data.length);
    LeaveCriticalSection();
    return ret;
}

+(int) meshClientIdentify:(NSString *)name duration:(uint8_t)duration
{
    NSLog(@"%s name:%@, duration:%d", __FUNCTION__, name, duration);
    int ret;
    EnterCriticalSection();
    ret = mesh_client_identify(name.UTF8String, duration);
    LeaveCriticalSection();
    return ret;
}

+(int) meshClientLightnessGet:(NSString *)deviceName
{
    NSLog(@"%s deviceName:%@", __FUNCTION__, deviceName);
    int ret;
    EnterCriticalSection();
    ret = mesh_client_lightness_get(deviceName.UTF8String);
    LeaveCriticalSection();
    return ret;
}

+(int) meshClientLightnessSet:(NSString *)deviceName lightness:(uint16_t)lightness reliable:(Boolean)reliable transitionTime:(uint32_t)transitionTime delay:(uint16_t)delay
{
    NSLog(@"[MeshNativehelper meshClientLightnessSet] deviceName:%@, lightness:%d, reliable:%d, transitionTime:%d, delay:%d",
          deviceName, lightness, reliable, transitionTime, delay);
    int ret;
    EnterCriticalSection();
    ret = mesh_client_lightness_set(deviceName.UTF8String, lightness, reliable, transitionTime, delay);
    LeaveCriticalSection();
    return ret;
}

+(int) meshClientCtlGet:(NSString *)deviceName
{
    NSLog(@"%s deviceName:%@", __FUNCTION__, deviceName);
    int ret;
    EnterCriticalSection();
    ret = mesh_client_ctl_get(deviceName.UTF8String);
    LeaveCriticalSection();
    return ret;
}

+(int) meshClientCtlSet:(NSString *)deviceName lightness:(uint16_t)lightness temperature:(uint16_t)temperature deltaUv:(uint16_t)deltaUv
               reliable:(Boolean)reliable transitionTime:(uint32_t)transitionTime delay:(uint16_t)delay
{
    NSLog(@"[MeshNativeHelper meshClientCtlSet] deviceName: %@, lightness: %d, temperature: %d, deltaUv: %d, reliable: %d, transitionTime: %d, delay: %d",
          deviceName, lightness, temperature, deltaUv, reliable, transitionTime, delay);
    int ret;
    EnterCriticalSection();
    ret = mesh_client_ctl_set(deviceName.UTF8String, lightness, temperature, deltaUv, reliable, transitionTime, delay);
    LeaveCriticalSection();
    return ret;
}

//MESH CLIENT GATT APIS
+(void) meshClientScanUnprovisioned:(int)start uuid:(NSData *)uuid
{
    NSLog(@"%s start:%d", __FUNCTION__, start);
    EnterCriticalSection();
    mesh_client_scan_unprovisioned(start, (uuid != nil && uuid.length == MESH_DEVICE_UUID_LEN) ? (uint8_t *)uuid.bytes : NULL);
    LeaveCriticalSection();
}

+(Boolean) meshClientIsConnectingProvisioning
{
    NSLog(@"%s", __FUNCTION__);
    Boolean is_connecting_provisioning;
    EnterCriticalSection();
    is_connecting_provisioning = mesh_client_is_connecting_provisioning();
    LeaveCriticalSection();
    return is_connecting_provisioning;
}

+(void) meshClientConnectionStateChanged:(uint16_t)connId mtu:(uint16_t)mtu
{
    NSLog(@"[MeshNativeHelper meshClientConnectionStateChanged] connId:0x%04x, mtu:%d", connId, mtu);
    mesh_client_connection_state_changed(connId, mtu);
}

+(void) meshClientAdvertReport:(NSData *)bdaddr addrType:(uint8_t)addrType rssi:(int8_t)rssi advData:(NSData *) advData
{
    NSLog(@"[MeshNativeHelper meshClientAdvertReport] advData.length:%lu, rssi:%d", (unsigned long)advData.length, rssi);
    if (bdaddr.length == 6 && advData.length > 0) {
        mesh_client_advert_report((uint8_t *)bdaddr.bytes, addrType, rssi, (uint8_t *)advData.bytes);
    } else {
        NSLog(@"[MeshNativeHelper meshClientAdvertReport] error: invalid bdaddr or advdata, bdaddr.length=%lu, advData.length=%lu",
              (unsigned long)bdaddr.length, (unsigned long)advData.length);
    }
}

+(uint8_t) meshConnectComponent:(NSString *)componentName useProxy:(uint8_t)useProxy scanDuration:(uint8_t)scanDuration
{
    uint8_t ret;
    EnterCriticalSection();
    ret = mesh_client_connect_component((char *)componentName.UTF8String, useProxy, scanDuration);
    NSLog(@"[MeshNativehelper meshConnectComponent] componentName: %@, useProxy: %d, scanDuration: %d, error: %d", componentName, useProxy, scanDuration, ret);
    if (ret != MESH_CLIENT_SUCCESS) {
        meshClientNodeConnectionState(MESH_CLIENT_NODE_WARNING_UNREACHABLE, (char *)componentName.UTF8String);
    }
    LeaveCriticalSection();
    return ret;
}

+(void) sendRxProxyPktToCore:(NSData *)data
{
    NSLog(@"%s data.length: %lu", __FUNCTION__, (unsigned long)data.length);
    EnterCriticalSection();
    mesh_client_proxy_data((uint8_t *)data.bytes, data.length);
    LeaveCriticalSection();
}

+(void) sendRxProvisPktToCore:(NSData *)data
{
    NSLog(@"%s data.length: %lu", __FUNCTION__, (unsigned long)data.length);
    EnterCriticalSection();
    mesh_client_provisioning_data(WICED_TRUE, (uint8_t *)data.bytes, data.length);
    LeaveCriticalSection();
}

+(Boolean) isMeshProvisioningServiceAdvertisementData:(NSDictionary<NSString *,id> *)advertisementData
{
    CBUUID *provUuid = [CBUUID UUIDWithString:@"1827"];

    NSNumber *conntable = advertisementData[CBAdvertisementDataIsConnectable];
    if (conntable == nil || [conntable isEqual: [NSNumber numberWithUnsignedInteger:0]]) {
        return false;
    }

    NSArray *srvUuids = advertisementData[CBAdvertisementDataServiceUUIDsKey];
    if (srvUuids == nil || srvUuids.count == 0) {
        return false;
    }

    for (CBUUID *uuid in srvUuids) {
        if ([uuid isEqual: provUuid]) {
            NSDictionary *srvData = advertisementData[CBAdvertisementDataServiceDataKey];
            if (srvData != nil && srvData.count > 0) {
                NSArray *allKeys = [srvData allKeys];
                for (CBUUID *key in allKeys) {
                    if (![key isEqual:provUuid]) {
                        continue;
                    }
                    NSData *data = srvData[key];
                    if (data != nil && data.length > 0) {
                        return true;
                    }
                }
            }
        }
    }
    return false;
}

+(Boolean) isMeshProxyServiceAdvertisementData:(NSDictionary<NSString *,id> *)advertisementData
{
    CBUUID *proxyUuid = [CBUUID UUIDWithString:@"1828"];

    NSNumber *conntable = advertisementData[CBAdvertisementDataIsConnectable];
    if (conntable == nil || [conntable isEqual: [NSNumber numberWithUnsignedInteger:0]]) {
        return false;
    }

    NSArray *srvUuids = advertisementData[CBAdvertisementDataServiceUUIDsKey];
    if (srvUuids == nil || srvUuids.count == 0) {
        return false;
    }

    for (CBUUID *uuid in srvUuids) {
        if ([uuid isEqual: proxyUuid]) {
            NSDictionary *srvData = advertisementData[CBAdvertisementDataServiceDataKey];
            if (srvData != nil && srvData.count > 0) {
                NSArray *allKeys = [srvData allKeys];
                for (CBUUID *key in allKeys) {
                    if (![key isEqual:proxyUuid]) {
                        continue;
                    }
                    NSData *data = srvData[key];
                    if (data != nil && data.length > 0) {
                        return true;
                    }
                }
            }
        }
    }
    return false;
}

+(Boolean) isMeshAdvertisementData:(NSDictionary<NSString *,id> *)advertisementData
{
    CBUUID *provUuid = [CBUUID UUIDWithString:@"1827"];
    CBUUID *proxyUuid = [CBUUID UUIDWithString:@"1828"];

    NSNumber *conntable = advertisementData[CBAdvertisementDataIsConnectable];
    if (conntable == nil || [conntable isEqual: [NSNumber numberWithUnsignedInteger:0]]) {
        return false;
    }

    NSArray *srvUuids = advertisementData[CBAdvertisementDataServiceUUIDsKey];
    if (srvUuids == nil || srvUuids.count == 0) {
        return false;
    }

    for (CBUUID *uuid in srvUuids) {
        if ([uuid isEqual: provUuid] || [uuid isEqual: proxyUuid]) {
            NSDictionary *srvData = advertisementData[CBAdvertisementDataServiceDataKey];
            if (srvData != nil && srvData.count > 0) {
                NSArray *allKeys = [srvData allKeys];
                for (CBUUID *key in allKeys) {
                    if (![key isEqual:provUuid] && ![key isEqual:proxyUuid]) {
                        continue;
                    }
                    NSData *data = srvData[key];
                    if (data != nil && data.length > 0) {
                        return true;
                    }
                }
            }
        }
    }
    return false;
}

static NSMutableDictionary *gMeshBdAddrDict = nil;
-(void) meshBdAddrDictInit
{
    if (gMeshBdAddrDict == nil) {
        EnterCriticalSection();
        if (gMeshBdAddrDict == nil) {
            gMeshBdAddrDict = [[NSMutableDictionary alloc] init];
        }
        LeaveCriticalSection();
    }
}

- (void)destoryMeshClient
{
    [self deleteAllFiles];
    onceToken = 0;
    zoneOnceToken = 0;
    [gMeshBdAddrDict removeAllObjects];
    gMeshBdAddrDict = nil;
    for (NSString *key in [gMeshTimersDict allKeys]) {
        NSArray *timerInfo = [gMeshTimersDict valueForKey:key];
        if (timerInfo != nil && [timerInfo count] == 3) {
            NSTimer *timer = timerInfo[2];
            if (timer != nil) {
                [timer invalidate];
            }
        }
    }
    [gMeshTimersDict removeAllObjects];
    gMeshTimersDict = nil;
    strcpy(provisioner_uuid, "");
    _instance = nil;
}

+(void) meshBdAddrDictAppend:(NSData *)bdAddr peripheral:(CBPeripheral *)peripheral
{
    if (bdAddr == nil || bdAddr.length != BD_ADDR_LEN || peripheral == nil) {
        return;
    }
    [gMeshBdAddrDict setObject:peripheral forKey:bdAddr.description];
}

+(CBPeripheral *) meshBdAddrDictGetCBPeripheral:(NSData *)bdAddr
{
    if (bdAddr == nil || bdAddr.length != BD_ADDR_LEN) {
        return nil;
    }
    return [gMeshBdAddrDict valueForKey:bdAddr.description];
}

+(void) meshBdAddrDictDelete:(NSData *)bdAddr
{
    if (bdAddr == nil || bdAddr.length != BD_ADDR_LEN) {
        return;
    }
    [gMeshBdAddrDict removeObjectForKey:bdAddr.description];
}

+(void) meshBdAddrDictDeleteByCBPeripheral:(CBPeripheral *)peripheral
{
    if (peripheral == nil) {
        return;
    }
    for (NSData *bdAddr in [gMeshBdAddrDict allKeys]) {
        CBPeripheral *cachedPeripheral = [gMeshBdAddrDict valueForKey:bdAddr.description];
        if (peripheral == cachedPeripheral) {
            [gMeshBdAddrDict removeObjectForKey:bdAddr.description];
            break;
        }
    }
}

+(void) meshBdAddrDictClear
{
    [gMeshBdAddrDict removeAllObjects];
}

+(NSData *) MD5:(NSData *)data
{
    unsigned char md5Data[CC_MD5_DIGEST_LENGTH];
    memset(md5Data, 0, CC_MD5_DIGEST_LENGTH);
    CC_MD5(data.bytes, (unsigned int)data.length, md5Data);
    return [[NSData alloc] initWithBytes:md5Data length:CC_MD5_DIGEST_LENGTH];
}

+(NSData *)peripheralIdentifyToBdAddr:(CBPeripheral *)peripheral
{
    const char *uuid = peripheral.identifier.UUIDString.UTF8String;
    unsigned char md5Data[CC_MD5_DIGEST_LENGTH];
    CC_MD5(uuid, (unsigned int)strlen(uuid), md5Data);
    return [[NSData alloc] initWithBytes:md5Data length:BD_ADDR_LEN];
}

+(NSData *) getMeshPeripheralMappedBdAddr:(CBPeripheral *)peripheral
{
    const char *uuid = peripheral.identifier.UUIDString.UTF8String;
    unsigned char md5Data[CC_MD5_DIGEST_LENGTH];
    CC_MD5(uuid, (unsigned int)strlen(uuid), md5Data);
    NSData * bdAddr = [[NSData alloc] initWithBytes:md5Data length:BD_ADDR_LEN];
    [MeshNativeHelper meshBdAddrDictAppend:bdAddr peripheral:peripheral];
    return bdAddr;
}

#define MESH_MAX_RAW_ADVERTISEMENT_DATA_SIZE    62          /* max is 31 advertisement data combined with 31 scan response data */
+(NSData *) getConvertedRawMeshAdvertisementData:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData rssi:(NSNumber *)rssi
{
    BOOL isConntable = false;
    BOOL isMeshServiceFound = false;
    CBUUID *provUuid = [CBUUID UUIDWithString:@"1827"];
    CBUUID *proxyUuid = [CBUUID UUIDWithString:@"1828"];
    /* assume the advertisementData was combined with max 31 bytes advertisement data and max 31 bytes scan response data. */
    unsigned char rawAdvData[MESH_MAX_RAW_ADVERTISEMENT_DATA_SIZE];
    int rawAdvDataSize = 0;
    unsigned char *p;

    NSNumber *conntable = advertisementData[CBAdvertisementDataIsConnectable];
    if (conntable != nil && [conntable isEqual: [NSNumber numberWithUnsignedInteger:1]]) {
        isConntable = true;
        if ((rawAdvDataSize + 1 + 2) <= MESH_MAX_RAW_ADVERTISEMENT_DATA_SIZE) {
            rawAdvData[rawAdvDataSize++] = 2;                           // length
            rawAdvData[rawAdvDataSize++] = BTM_BLE_ADVERT_TYPE_FLAG;    // flag type
            rawAdvData[rawAdvDataSize++] = 0x06;                        // Flags value
        }
    }

    NSArray *srvUuids = advertisementData[CBAdvertisementDataServiceUUIDsKey];
    if (srvUuids != nil && srvUuids.count > 0) {
        for (CBUUID *uuid in srvUuids) {
            if ([uuid isEqual: provUuid] || [uuid isEqual: proxyUuid]) {
                isMeshServiceFound = true;
                if ((rawAdvDataSize + uuid.data.length + 2) <= MESH_MAX_RAW_ADVERTISEMENT_DATA_SIZE) {
                    rawAdvData[rawAdvDataSize++] = uuid.data.length + 1;                    // length
                    rawAdvData[rawAdvDataSize++] = BTM_BLE_ADVERT_TYPE_16SRV_COMPLETE;      // flag type
                    /* UUID data bytes is in big-endia format, but raw adv data wants in little-endian format. */
                    p = (unsigned char *)uuid.data.bytes;
                    p += (uuid.data.length - 1);
                    for (int i = 0; i < uuid.data.length; i++) {
                        rawAdvData[rawAdvDataSize++] = *p--;                                // little-endian UUID data
                    }
                }
            }
        }
    }

    /* Not mesh device/proxy advertisement data, return nil. */
    if (!isConntable || !isMeshServiceFound) {
        return nil;
    }

    NSDictionary *srvData = advertisementData[CBAdvertisementDataServiceDataKey];
    if (srvData != nil && srvData.count > 0) {
        NSArray *allKeys = [srvData allKeys];
        for (CBUUID *key in allKeys) {
            if (![key isEqual:provUuid] && ![key isEqual:proxyUuid]) {
                continue;
            }

            NSData *data = srvData[key];
            if (data != nil && data.length > 0) {
                if ((rawAdvDataSize + key.data.length + data.length + 2) <= MESH_MAX_RAW_ADVERTISEMENT_DATA_SIZE) {
                    rawAdvData[rawAdvDataSize++] = key.data.length + data.length + 1;   // length
                    rawAdvData[rawAdvDataSize++] = BTM_BLE_ADVERT_TYPE_SERVICE_DATA;    // flag type
                    p = (unsigned char *)key.data.bytes;                                // data: service UUID.
                    p += (key.data.length - 1);
                    for (int i = 0; i < key.data.length; i++) {
                        rawAdvData[rawAdvDataSize++] = *p--;
                    }
                    memcpy(&rawAdvData[rawAdvDataSize], data.bytes, data.length);       // data: service UUID data.
                    rawAdvDataSize += data.length;
                }
            }
        }
    }

    /* Add local name of the peripheral if exsiting. */
    NSString *localName = advertisementData[CBAdvertisementDataLocalNameKey];
    if (localName == nil || strlen(localName.UTF8String) == 0) {
        localName = peripheral.name;
    }
    if (localName != nil && strlen(localName.UTF8String) > 0) {
        unsigned long nameLen = strlen(localName.UTF8String);
        if ((rawAdvDataSize + nameLen + 2) <= MESH_MAX_RAW_ADVERTISEMENT_DATA_SIZE) {
            rawAdvData[rawAdvDataSize++] = nameLen + 1;                            // length
            rawAdvData[rawAdvDataSize++] = BTM_BLE_ADVERT_TYPE_NAME_COMPLETE;      // flag type
            memcpy(&rawAdvData[rawAdvDataSize], localName.UTF8String, nameLen);    // Name data
            rawAdvDataSize += nameLen;
        }
    }

    // Add 2 ending bytes, 0 length with 0 flag.
    rawAdvData[rawAdvDataSize++] = 0;
    rawAdvData[rawAdvDataSize++] = 0;

    return [[NSData alloc] initWithBytes:rawAdvData length:rawAdvDataSize];
}

void dumpHexBytes(const void *data, unsigned long size)
{
    const unsigned char *p = data;
    for (int i = 0; i < size; i++) {
        printf("%02X ", p[i]);
        if ((i + 1) % 16 == 0) {
            printf("\n");
        }
    }
    printf("\n");
}


+(void) meshClientSetGattMtu:(int)mtu
{
    NSLog(@"%s, mtu: %d", __FUNCTION__, mtu);
    EnterCriticalSection();
    wiced_bt_mesh_core_set_gatt_mtu((uint16_t)mtu);
    LeaveCriticalSection();
}
+(Boolean) meshClientIsConnectedToNetwork
{
    NSLog(@"%s", __FUNCTION__);
    Boolean is_proxy_connected;
    EnterCriticalSection();
    is_proxy_connected = mesh_client_is_proxy_connected();
    LeaveCriticalSection();
    return is_proxy_connected;
}

+(int) meshClientAddComponent:(NSString *)componentName toGorup:(NSString *)groupName
{
    NSLog(@"[MeshNativeHelper meshClientAddComponent] componentName: %@, groupName: %@", componentName, groupName);
    int ret;
    EnterCriticalSection();
    ret = mesh_client_add_component_to_group(componentName.UTF8String, groupName.UTF8String);
    LeaveCriticalSection();
    return ret;
}

+(NSData *) meshClientOTADataEncrypt:(NSString *)componentName data:(NSData *)data
{
    //NSLog(@"[MeshNativeHelper meshClientOTADataEncrypt] componentName: %@, length: %lu", componentName, (unsigned long)[data length]);
    /* The output buffer should be at least 17 bytes larger than input buffer */
    uint8_t *pOutBuffer = (uint8_t *)malloc(data.length + 17);
    uint16_t outBufferLen = 0;
    NSData *outData = nil;

    if (pOutBuffer) {
        EnterCriticalSection();
        outBufferLen = mesh_client_ota_data_encrypt(componentName.UTF8String, data.bytes, data.length, pOutBuffer, data.length + 17);
        LeaveCriticalSection();
        if (outBufferLen > 0) {
            outData = [[NSData alloc] initWithBytes:pOutBuffer length:outBufferLen];
        }
    }
    free(pOutBuffer);
    return outData;
}

+(NSData *) meshClientOTADataDecrypt:(NSString *)componentName data:(NSData *)data
{
    //NSLog(@"[MeshNativeHelper meshClientOTADataDecrypt] componentName: %@, length: %lu", componentName, (unsigned long)[data length]);
    /* The output buffer should be at least 17 bytes larger than input buffer */
    uint8_t *pOutBuffer = (uint8_t *)malloc(data.length + 17);
    uint16_t outBufferLen = 0;
    NSData *outData = nil;

    if (pOutBuffer) {
        EnterCriticalSection();
        outBufferLen = mesh_client_ota_data_decrypt(componentName.UTF8String, data.bytes, data.length, pOutBuffer, data.length + 17);
        LeaveCriticalSection();
        if (outBufferLen > 0) {
            outData = [[NSData alloc] initWithBytes:pOutBuffer length:outBufferLen];
        }
    }
    free(pOutBuffer);
    return outData;
}

+(NSArray<NSString *> *) meshClientGetComponentGroupList:(NSString *)componentName
{
    NSLog(@"[MeshNativeHelper meshClientGetComponentGroupList] componentName: %@", componentName);
    char *groupList = NULL;
    EnterCriticalSection();
    groupList = mesh_client_get_component_group_list((char *)componentName.UTF8String);
    LeaveCriticalSection();
    return meshCStringToOCStringArray(groupList, TRUE);
}

+(int) meshClientRemoveComponent:(NSString *)componentName from:(NSString *)groupName
{
    NSLog(@"[MeshNativeHelper meshClientRemoveComponent] componentName:%@, groupName:%@", componentName, groupName);
    int ret;
    EnterCriticalSection();
    ret = mesh_client_remove_component_from_group(componentName.UTF8String, groupName.UTF8String);
    LeaveCriticalSection();
    return ret;
}

-(NSString *) getJsonFilePath {

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *list = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true);
    NSString *homeDirectory = list[0];
    NSString *fileDirectory = [homeDirectory stringByAppendingPathComponent:@"mesh"];
    NSLog(@"%s current fileDirectory \"%@\"", __FUNCTION__, fileDirectory);

    NSString *fileContent;
    NSArray  *contents = [fileManager contentsOfDirectoryAtPath:fileDirectory error:nil];
    NSString *filePathString;

    for (fileContent in contents){
        if([[fileContent pathExtension]isEqualToString:@"json"]){
            NSLog(@"%@ file Name",fileContent);
            filePathString = fileContent;
            break;
        }
    }

    NSString *filePath = [fileDirectory stringByAppendingPathComponent:filePathString];
    return filePath;
}

-(void) deleteAllFiles {

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *list = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true);
    NSString *homeDirectory = list[0];
    NSString *fileDirectory = [homeDirectory stringByAppendingPathComponent:@"mesh"];
    NSLog(@"%s current fileDirectory \"%@\"", __FUNCTION__, fileDirectory);

    NSString *fileContent;
    NSArray  *contents = [fileManager contentsOfDirectoryAtPath:fileDirectory error:nil];

    for (fileContent in contents){
        NSString *fullFilePath = [fileDirectory stringByAppendingPathComponent:fileContent];
        NSLog(@"%@", fullFilePath);
        [fileManager removeItemAtPath:fullFilePath error: NULL];
    }
}


static CBPeripheral *currentConnectedPeripheral = nil;

+(void) setCurrentConnectedPeripheral:(CBPeripheral *)peripheral
{
    @synchronized (MeshNativeHelper.getSharedInstance) {
        currentConnectedPeripheral = peripheral;
    }
}

+(CBPeripheral *) getCurrentConnectedPeripheral
{
    CBPeripheral *peripheral = nil;
    @synchronized (MeshNativeHelper.getSharedInstance) {
        peripheral = currentConnectedPeripheral;
    }
    return peripheral;
}

// DFU APIs
void mesh_client_dfu_status_cb(uint8_t status, uint8_t progress)
{
    NSLog(@"[MeshNativeHelper mesh_client_dfu_status_cb] status:0x%02x, progress:%u", status, progress);
    [nativeCallbackDelegate meshClientDfuStatusCb:status progress:progress];
}

+(int) meshClientDfuGetStatus:(NSString *)componentName
{
    NSLog(@"[MeshNativeHelper meshClientDfuGetStatus] componentName:%@", componentName);
    int ret;
    EnterCriticalSection();
    ret = mesh_client_dfu_get_status((char *)componentName.UTF8String, mesh_client_dfu_status_cb);
    LeaveCriticalSection();
    return ret;
}

+(int) meshClientDfuStart:(int)dfuMethod  componentName:(NSString *)componentName firmwareId:(NSData *)firmwareId validationData:(NSData *)validationData
{
    NSLog(@"[MeshNativeHelper meshClientDfuStart] dfuMethod:%d, componentName:%@", dfuMethod, componentName);
    int ret;
    EnterCriticalSection();
    ret = mesh_client_dfu_start((uint8_t)dfuMethod, (char *)componentName.UTF8String, (uint8_t *)firmwareId.bytes, (uint8_t)firmwareId.length, (uint8_t *)validationData.bytes, (uint8_t)validationData.length);
    LeaveCriticalSection();
    return ret;
}

+(int) meshClientDfuStop
{
    NSLog(@"[MeshNativeHelper meshClientDfuStop]");
    int ret;
    EnterCriticalSection();
    ret = mesh_client_dfu_stop();
    LeaveCriticalSection();
    return ret;
}

// Sensor APIs
+(int) meshClientSensorCadenceGet:(NSString *)deviceName
                       propertyId:(int)propertyId
         fastCadencePeriodDivisor:(int *)fastCadencePeriodDivisor
                      triggerType:(int *)triggerType
                 triggerDeltaDown:(int *)triggerDeltaDown
                   triggerDeltaUp:(int *)triggerDeltaUp
                      minInterval:(int *)minInterval
                   fastCadenceLow:(int *)fastCadenceLow
                  fastCadenceHigh:(int *)fastCadenceHigh
{
    NSLog(@"[MeshNativeHelper meshClientSensorCadenceGet] deviceName:%@, propertyId:0x%04x", deviceName, propertyId);
    uint16_t fast_cadence_period_divisor = 0;
    wiced_bool_t trigger_type = 0;
    uint32_t trigger_delta_down = 0;
    uint32_t trigger_delta_up = 0;
    uint32_t min_interval = 0;
    uint32_t fast_cadence_low = 0;
    uint32_t fast_cadence_high = 0;
    int ret;

    EnterCriticalSection();
    ret = mesh_client_sensor_cadence_get(deviceName.UTF8String, propertyId,
                                         &fast_cadence_period_divisor,
                                         &trigger_type,
                                         &trigger_delta_down,
                                         &trigger_delta_up,
                                         &min_interval,
                                         &fast_cadence_low,
                                         &fast_cadence_high);
    LeaveCriticalSection();

    if (ret == MESH_CLIENT_SUCCESS) {
        *fastCadencePeriodDivisor = (int)fast_cadence_period_divisor;
        *triggerType = (int)trigger_type;
        *triggerDeltaDown = (int)trigger_delta_down;
        *triggerDeltaUp = (int)trigger_delta_up;
        *minInterval = (int)min_interval;
        *fastCadenceLow = (int)fast_cadence_low;
        *fastCadenceHigh = (int)fast_cadence_high;
    }
    return ret;
}

+(int) meshClientSensorCadenceSet:(NSString *)deviceName
                       propertyId:(int)propertyId
         fastCadencePeriodDivisor:(int)fastCadencePeriodDivisor
                      triggerType:(int)triggerType
                 triggerDeltaDown:(int)triggerDeltaDown
                   triggerDeltaUp:(int)triggerDeltaUp
                      minInterval:(int)minInterval
                   fastCadenceLow:(int)fastCadenceLow
                  fastCadenceHigh:(int)fastCadenceHigh
{
    NSLog(@"[MeshNativeHelper meshClientSensorCadenceSet] deviceName:%@, propertyId:0x%04x, %u, %u, %u, %u, %u, %u, %u",
          deviceName, propertyId, fastCadencePeriodDivisor, triggerType, triggerDeltaDown, triggerDeltaUp, minInterval, fastCadenceLow, fastCadenceHigh);
    int ret;
    EnterCriticalSection();
    ret = mesh_client_sensor_cadence_set(deviceName.UTF8String, propertyId,
                                         (uint16_t)fastCadencePeriodDivisor,
                                         (wiced_bool_t)triggerType,
                                         (uint32_t)triggerDeltaDown,
                                         (uint32_t)triggerDeltaUp,
                                         (uint32_t)minInterval,
                                         (uint32_t)fastCadenceLow,
                                         (uint32_t)fastCadenceHigh);
    LeaveCriticalSection();
    return ret;
}

+(NSData *) meshClientSensorSettingGetPropertyIds:(NSString *)componentName
                                               propertyId:(int)propertyId
{
    NSLog(@"[MeshNativeHelper meshClientSensorSettingGetPropertyIds] componentName:%@, propertyId:0x%04x", componentName, propertyId);
    NSData *settingPropertyIdsData = nil;
    int *settingPropertyIds = NULL;
    int count = 0;

    EnterCriticalSection();
    settingPropertyIds = mesh_client_sensor_setting_property_ids_get(componentName.UTF8String, propertyId);
    LeaveCriticalSection();

    if (settingPropertyIds != NULL) {
        while (settingPropertyIds[count] != WICED_BT_MESH_PROPERTY_UNKNOWN) {
            count += 1;
        }
        settingPropertyIdsData = [NSData dataWithBytes:(void *)settingPropertyIds length:(count * sizeof(int))];
        free(settingPropertyIds);
    }
    return settingPropertyIdsData;
}

+(NSData *) meshClientSensorPropertyListGet:(NSString *)componentName
{
    NSLog(@"[MeshNativeHelper meshClientSensorPropertyListGet] componentName:%@", componentName);
    NSData *propertyListData = nil;
    int *propertyList = NULL;
    int count = 0;

    EnterCriticalSection();
    propertyList = mesh_client_sensor_property_list_get(componentName.UTF8String);
    LeaveCriticalSection();

    if (propertyList != NULL) {
        while (propertyList[count] != WICED_BT_MESH_PROPERTY_UNKNOWN) {
            count += 1;
        }
        propertyListData = [NSData dataWithBytes:(void *)propertyList length:(count * sizeof(int))];
        free(propertyList);
    }
    return propertyListData;
}

+(int) meshClientSensorSettingSet:(NSString *)componentName
                       propertyId:(int)propertyId
                settingPropertyId:(int)settingPropertyId
                            value:(NSData *)value
{
    NSLog(@"[MeshNativeHelper meshClientSensorSettingSet] componentName:%@, propertyId:0x%04x, settingPropertyId:0x%04x", componentName, propertyId, settingPropertyId);
    int ret;
    EnterCriticalSection();
    ret = mesh_client_sensor_setting_set(componentName.UTF8String, propertyId, settingPropertyId, (uint8_t *)value.bytes);
    LeaveCriticalSection();
    return ret;
}

+(int) meshClientSensorGet:(NSString *)componentName propertyId:(int)propertyId
{
    NSLog(@"[MeshNativeHelper meshClientSensorGet] componentName:%@, propertyId:0x%04x", componentName, propertyId);
    int ret;
    EnterCriticalSection();
    ret = mesh_client_sensor_get(componentName.UTF8String, propertyId);
    LeaveCriticalSection();
    return ret;
}

+(BOOL) meshClientIsLightController:(NSString *)componentName
{
    NSLog(@"[MeshNativeHelper meshClientIsLightController] componentName:%@", componentName);
    int ret;
    EnterCriticalSection();
    ret = mesh_client_is_light_controller((char *)componentName.UTF8String);
    LeaveCriticalSection();
    return (ret == 0) ? FALSE : TRUE;
}

void meshClientLightLcModeStatusCb(const char *device_name, int mode)
{
    if (device_name == NULL || *device_name == '\0') {
        NSLog(@"[MeshNativeHelper meshClientLightLcModeStatusCb] error: invalid parameters, device_name=0x%p", device_name);
        return;
    }
    [nativeCallbackDelegate onLightLcModeStatusCb:[NSString stringWithUTF8String:(const char *)device_name]
                                             mode:mode];
}

+(int) meshClientGetLightLcMode:(NSString *)componentName
{
    NSLog(@"[MeshNativeHelper meshClientGetLightLcMode] componentName:%@", componentName);
    int ret;
    EnterCriticalSection();
    ret = mesh_client_light_lc_mode_get(componentName.UTF8String, meshClientLightLcModeStatusCb);
    LeaveCriticalSection();
    return ret;
}

+(int) meshClientSetLightLcMode:(NSString *)componentName mode:(int)mode
{
    NSLog(@"[MeshNativeHelper meshClientGetLightLcMode] componentName:%@, mode:%d", componentName, mode);
    int ret;
    EnterCriticalSection();
    ret = mesh_client_light_lc_mode_set(componentName.UTF8String, mode, meshClientLightLcModeStatusCb);
    LeaveCriticalSection();
    return ret;
}

void meshClientLightLcOccupancyModeStatusCb(const char *device_name, int mode)
{
    if (device_name == NULL || *device_name == '\0') {
        NSLog(@"[MeshNativeHelper meshClientLightLcOccupancyModeStatusCb] error: invalid parameters, device_name=0x%p", device_name);
        return;
    }
    [nativeCallbackDelegate onLightLcOccupancyModeStatusCb:[NSString stringWithUTF8String:(const char *)device_name]
                                                      mode:mode];
}

+(int) meshClientGetLightLcOccupancyMode:(NSString *)componentName
{
    NSLog(@"[MeshNativeHelper meshClientGetLightLcOccupancyMode] componentName:%@", componentName);
    int ret;
    EnterCriticalSection();
    ret = mesh_client_light_lc_occupancy_mode_get(componentName.UTF8String, meshClientLightLcOccupancyModeStatusCb);
    LeaveCriticalSection();
    return ret;
}

+(int) meshClientSetLightLcOccupancyMode:(NSString *)componentName mode:(int)mode
{
    NSLog(@"[MeshNativeHelper meshClientSetLightLcOccupancyMode] componentName:%@, mode:%d", componentName, mode);
    int ret;
    EnterCriticalSection();
    ret = mesh_client_light_lc_occupancy_mode_set(componentName.UTF8String, mode, meshClientLightLcOccupancyModeStatusCb);
    LeaveCriticalSection();
    return ret;
}


void meshClientLightLcPropertyStatusCb(const char *device_name, int property_id, int value)
{
    if (device_name == NULL || *device_name == '\0') {
        NSLog(@"[MeshNativeHelper meshClientLightLcPropertyStatusCb] error: invalid parameters, device_name=0x%p", device_name);
        return;
    }
    [nativeCallbackDelegate onLightLcPropertyStatusCb:[NSString stringWithUTF8String:(const char *)device_name]
                                           propertyId:property_id
                                                value:value];
}

+(int) meshClientGetLightLcProperty:(NSString *)componentName propertyId:(int)propertyId
{
    NSLog(@"[MeshNativeHelper meshClientGetLightLcProperty] componentName:%@, propertyId:0x%X", componentName, propertyId);
    int ret;
    EnterCriticalSection();
    ret = mesh_client_light_lc_property_get(componentName.UTF8String, propertyId, meshClientLightLcPropertyStatusCb);
    LeaveCriticalSection();
    return ret;
}

+(int) meshClientSetLightLcProperty:(NSString *)componentName propertyId:(int)propertyId value:(int)value
{
    NSLog(@"[MeshNativeHelper meshClientSetLightLcProperty] componentName:%@, propertyId:0x%X, value:0x%X", componentName, propertyId, value);
    int ret;
    EnterCriticalSection();
    ret = mesh_client_light_lc_property_set(componentName.UTF8String, propertyId, value, meshClientLightLcPropertyStatusCb);
    LeaveCriticalSection();
    return ret;
}

+(int) meshClientSetLightLcOnOffSet:(NSString *)componentName onoff:(uint8_t)onoff reliable:(BOOL)reliable transitionTime:(uint32_t)transitionTime delay:(uint16_t)delay
{
    NSLog(@"[MeshNativeHelper meshClientSetLightLcOnOffSet] componentName:%@, onoff:%d, reliable:%d", componentName, onoff, reliable);
    int ret;
    EnterCriticalSection();
    ret = mesh_client_light_lc_on_off_set(componentName.UTF8String, onoff, reliable, transitionTime, delay);
    LeaveCriticalSection();
    return ret;
}

+(BOOL) meshClientIsSameNodeElements:(NSString *)networkName elementName:(NSString *)elementName anotherElementName:(NSString *)anotherElementName
{
    BOOL isSameNode = FALSE;
    wiced_bt_mesh_db_mesh_t *pMeshDb = wiced_bt_mesh_db_init(networkName.UTF8String);
    if (pMeshDb == NULL) {
        return isSameNode;
    }

    wiced_bt_mesh_db_node_t *pMeshNode1 = wiced_bt_mesh_db_node_get_by_element_name(pMeshDb, elementName.UTF8String);
    wiced_bt_mesh_db_node_t *pMeshNode2 = wiced_bt_mesh_db_node_get_by_element_name(pMeshDb, anotherElementName.UTF8String);
    if ((pMeshNode1 == pMeshNode2) && (pMeshNode1 != NULL)) {
        isSameNode = TRUE;
    }

    wiced_bt_mesh_db_deinit(pMeshDb);
    return isSameNode;
}

+(int) meshClientGetNodeElements:(NSString *)networkName elementName:(NSString *)elementName
{
    int elements = 0;
    wiced_bt_mesh_db_mesh_t *pMeshDb = wiced_bt_mesh_db_init(networkName.UTF8String);
    if (pMeshDb == NULL) {
        return -ENFILE;
    }

    wiced_bt_mesh_db_node_t *pMeshNode = wiced_bt_mesh_db_node_get_by_element_name(pMeshDb, elementName.UTF8String);
    if (pMeshNode == NULL) {
        wiced_bt_mesh_db_deinit(pMeshDb);
        return -ENOENT;
    }
    elements = pMeshNode->num_elements;

    wiced_bt_mesh_db_deinit(pMeshDb);
    return elements;
}

static const uint32_t crc32Table[256] = {
    0x00000000, 0x77073096, 0xee0e612c, 0x990951ba, 0x076dc419, 0x706af48f, 0xe963a535, 0x9e6495a3,
    0x0edb8832, 0x79dcb8a4, 0xe0d5e91e, 0x97d2d988, 0x09b64c2b, 0x7eb17cbd, 0xe7b82d07, 0x90bf1d91,
    0x1db71064, 0x6ab020f2, 0xf3b97148, 0x84be41de, 0x1adad47d, 0x6ddde4eb, 0xf4d4b551, 0x83d385c7,
    0x136c9856, 0x646ba8c0, 0xfd62f97a, 0x8a65c9ec, 0x14015c4f, 0x63066cd9, 0xfa0f3d63, 0x8d080df5,
    0x3b6e20c8, 0x4c69105e, 0xd56041e4, 0xa2677172, 0x3c03e4d1, 0x4b04d447, 0xd20d85fd, 0xa50ab56b,
    0x35b5a8fa, 0x42b2986c, 0xdbbbc9d6, 0xacbcf940, 0x32d86ce3, 0x45df5c75, 0xdcd60dcf, 0xabd13d59,
    0x26d930ac, 0x51de003a, 0xc8d75180, 0xbfd06116, 0x21b4f4b5, 0x56b3c423, 0xcfba9599, 0xb8bda50f,
    0x2802b89e, 0x5f058808, 0xc60cd9b2, 0xb10be924, 0x2f6f7c87, 0x58684c11, 0xc1611dab, 0xb6662d3d,
    0x76dc4190, 0x01db7106, 0x98d220bc, 0xefd5102a, 0x71b18589, 0x06b6b51f, 0x9fbfe4a5, 0xe8b8d433,
    0x7807c9a2, 0x0f00f934, 0x9609a88e, 0xe10e9818, 0x7f6a0dbb, 0x086d3d2d, 0x91646c97, 0xe6635c01,
    0x6b6b51f4, 0x1c6c6162, 0x856530d8, 0xf262004e, 0x6c0695ed, 0x1b01a57b, 0x8208f4c1, 0xf50fc457,
    0x65b0d9c6, 0x12b7e950, 0x8bbeb8ea, 0xfcb9887c, 0x62dd1ddf, 0x15da2d49, 0x8cd37cf3, 0xfbd44c65,
    0x4db26158, 0x3ab551ce, 0xa3bc0074, 0xd4bb30e2, 0x4adfa541, 0x3dd895d7, 0xa4d1c46d, 0xd3d6f4fb,
    0x4369e96a, 0x346ed9fc, 0xad678846, 0xda60b8d0, 0x44042d73, 0x33031de5, 0xaa0a4c5f, 0xdd0d7cc9,
    0x5005713c, 0x270241aa, 0xbe0b1010, 0xc90c2086, 0x5768b525, 0x206f85b3, 0xb966d409, 0xce61e49f,
    0x5edef90e, 0x29d9c998, 0xb0d09822, 0xc7d7a8b4, 0x59b33d17, 0x2eb40d81, 0xb7bd5c3b, 0xc0ba6cad,
    0xedb88320, 0x9abfb3b6, 0x03b6e20c, 0x74b1d29a, 0xead54739, 0x9dd277af, 0x04db2615, 0x73dc1683,
    0xe3630b12, 0x94643b84, 0x0d6d6a3e, 0x7a6a5aa8, 0xe40ecf0b, 0x9309ff9d, 0x0a00ae27, 0x7d079eb1,
    0xf00f9344, 0x8708a3d2, 0x1e01f268, 0x6906c2fe, 0xf762575d, 0x806567cb, 0x196c3671, 0x6e6b06e7,
    0xfed41b76, 0x89d32be0, 0x10da7a5a, 0x67dd4acc, 0xf9b9df6f, 0x8ebeeff9, 0x17b7be43, 0x60b08ed5,
    0xd6d6a3e8, 0xa1d1937e, 0x38d8c2c4, 0x4fdff252, 0xd1bb67f1, 0xa6bc5767, 0x3fb506dd, 0x48b2364b,
    0xd80d2bda, 0xaf0a1b4c, 0x36034af6, 0x41047a60, 0xdf60efc3, 0xa867df55, 0x316e8eef, 0x4669be79,
    0xcb61b38c, 0xbc66831a, 0x256fd2a0, 0x5268e236, 0xcc0c7795, 0xbb0b4703, 0x220216b9, 0x5505262f,
    0xc5ba3bbe, 0xb2bd0b28, 0x2bb45a92, 0x5cb36a04, 0xc2d7ffa7, 0xb5d0cf31, 0x2cd99e8b, 0x5bdeae1d,
    0x9b64c2b0, 0xec63f226, 0x756aa39c, 0x026d930a, 0x9c0906a9, 0xeb0e363f, 0x72076785, 0x05005713,
    0x95bf4a82, 0xe2b87a14, 0x7bb12bae, 0x0cb61b38, 0x92d28e9b, 0xe5d5be0d, 0x7cdcefb7, 0x0bdbdf21,
    0x86d3d2d4, 0xf1d4e242, 0x68ddb3f8, 0x1fda836e, 0x81be16cd, 0xf6b9265b, 0x6fb077e1, 0x18b74777,
    0x88085ae6, 0xff0f6a70, 0x66063bca, 0x11010b5c, 0x8f659eff, 0xf862ae69, 0x616bffd3, 0x166ccf45,
    0xa00ae278, 0xd70dd2ee, 0x4e048354, 0x3903b3c2, 0xa7672661, 0xd06016f7, 0x4969474d, 0x3e6e77db,
    0xaed16a4a, 0xd9d65adc, 0x40df0b66, 0x37d83bf0, 0xa9bcae53, 0xdebb9ec5, 0x47b2cf7f, 0x30b5ffe9,
    0xbdbdf21c, 0xcabac28a, 0x53b39330, 0x24b4a3a6, 0xbad03605, 0xcdd70693, 0x54de5729, 0x23d967bf,
    0xb3667a2e, 0xc4614ab8, 0x5d681b02, 0x2a6f2b94, 0xb40bbe37, 0xc30c8ea1, 0x5a05df1b, 0x2d02ef8d
};

/*
 * Help function to calculate CRC32 checksum for specific data.
 * Required by the mesh libraries which exists as a builtin function in the ROM.
 *
 * @param crc32     CRC32 value for calculating.
 *                  The initalize CRC value must be CRC32_INIT_VALUE.
 * @param data      Data required to calculate CRC32 checksum.
 *
 * @return          Calculated CRC32 checksum value.
 *
 * Note, after the latest data has been calculated, the final CRC32 checksum value must be calculuated as below as last step:
 *      crc32 ^= CRC32_INIT_VALUE
 */
uint32_t update_crc32(uint32_t crc, uint8_t *buf, uint32_t len)
{
    uint32_t newCrc = crc;
    uint32_t n;

    for (n = 0; n < len; n++) {
        newCrc = crc32Table[(newCrc ^ buf[n]) & 0xFF] ^ (newCrc >> 8);
    }

    return newCrc;
}
+(uint32_t) updateCrc32:(uint32_t)crc data:(NSData *)data
{
    return update_crc32(crc, (uint8_t *)data.bytes, (uint32_t)data.length);
}

+(void) meshClientSetDfuFwMetadata:(NSData *)fwId validationData:(NSData *)validationData
{
    dfuFwIdLen = (uint32_t)fwId.length;
    memcpy(dfuFwId, fwId.bytes, dfuFwIdLen);
    dfuValidationDataLen = (uint32_t)validationData.length;
    memcpy(dfuValidationData, validationData.bytes, dfuValidationDataLen);
}

+(void) meshClientClearDfuFwMetadata
{
    mesh_dfu_metadata_init();
}

+(void) meshClientSetDfuFilePath:(NSString *)filePath
{
    char *dfuFilePath = (filePath == nil || filePath.length == 0) ? NULL : (char *)[[NSFileManager defaultManager] fileSystemRepresentationWithPath:filePath];
    setDfuFilePath(dfuFilePath);
}

+(NSString *) meshClientGetDfuFilePath
{
    char *filePath = getDfuFilePath();
    if (filePath == NULL) {
        return nil;
    }
    return [NSString stringWithUTF8String:(const char *)filePath];
}

void mesh_native_helper_read_dfu_meta_data(uint8_t *p_fw_id, uint32_t *p_fw_id_len, uint8_t *p_validation_data, uint32_t *p_validation_data_len)
{
    *p_fw_id_len = dfuFwIdLen;
    *p_validation_data_len = dfuValidationDataLen;
    if (dfuFwIdLen) {
        memcpy(p_fw_id, dfuFwId, dfuFwIdLen);
    }
    if (dfuValidationDataLen) {
        memcpy(p_validation_data_len, dfuValidationData, dfuValidationDataLen);
    }
}

uint32_t mesh_native_helper_read_file_size(const char *p_path)
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *filePath = nil;
    unsigned long long fileSize = 0;

    if (p_path == NULL || !strlen(p_path)) {
        NSLog(@"[MeshNativeHelper mesh_native_helper_read_file_size] error: input file path is NULL");
        return 0;
    }

    filePath = [NSString stringWithUTF8String:(const char *)p_path];
    if (![fileManager fileExistsAtPath:filePath] || ![fileManager isReadableFileAtPath:filePath]) {
        NSLog(@"[MeshNativeHelper mesh_native_helper_read_file_size] error: file \"%@\" not exists or not readable", filePath);
        return 0;
    }

    fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil] fileSize];
    return (uint32_t)fileSize;
}

void mesh_native_helper_read_file_chunk(const char *p_path, uint8_t *p_data, uint32_t offset, uint16_t data_len)
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *filePath = nil;
    NSFileHandle *handle = nil;
    NSData *data = nil;

    if (p_path == NULL || !strlen(p_path)) {
        NSLog(@"[MeshNativeHelper mesh_native_helper_read_file_chunk] error: input file path is NULL");
        return;
    }

    filePath = [NSString stringWithUTF8String:(const char *)p_path];
    if (![fileManager fileExistsAtPath:filePath] || ![fileManager isReadableFileAtPath:filePath]) {
        NSLog(@"[MeshNativeHelper mesh_native_helper_read_file_chunk] error: file \"%@\" not exists or not readable", filePath);
        return;
    }

    handle = [NSFileHandle fileHandleForReadingAtPath:filePath];
    if (handle == nil) {
        NSLog(@"[MeshNativeHelper mesh_native_helper_read_file_chunk] error: unable to open file \"%@\" for reading", filePath);
        return;
    }

    @try {
        [handle seekToFileOffset:(unsigned long long)offset];
        data = [handle readDataOfLength:data_len];
        [data getBytes:p_data length:data.length];
    } @catch (NSException *exception) {
        NSLog(@"[MeshNativeHelper mesh_native_helper_read_file_chunk] error: unable exception: %@", [exception description]);
    } @finally {
        [handle closeFile];
    }
}

@end
