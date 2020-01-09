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

import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGatt;
import android.bluetooth.BluetoothGattCallback;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothGattDescriptor;
import android.bluetooth.BluetoothGattService;
import android.bluetooth.BluetoothManager;
import android.bluetooth.BluetoothProfile;
import android.bluetooth.le.BluetoothLeScanner;
import android.bluetooth.le.ScanCallback;
import android.bluetooth.le.ScanFilter;
import android.bluetooth.le.ScanResult;
import android.bluetooth.le.ScanSettings;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.Message;
import android.os.ParcelUuid;
import android.util.Log;

import com.cypress.le.mesh.meshcore.MeshNativeHelper;

import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.Executor;
import java.util.concurrent.Executors;
import java.util.concurrent.Semaphore;

 class MeshGattClient {

    private static final String TAG = "MeshGattClient";


     public static final UUID CHARACTERISTIC_UPDATE_NOTIFICATION_DESCRIPTOR_UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb");
     private static final long MTU_REQUEST_TIMEOUT = 5000;
     private static final int MSG_REQUEST_MTU = 1;
     private static BluetoothLeScanner    mLeScanner = null;
     private BluetoothManager mBluetoothManager = null;
     private BluetoothAdapter mBluetoothAdapter = null;
     private Context mCtx = null;
     private MeshNativeHelper mMeshNativeHelper = null;
     private static BluetoothGatt mGatt = null;
     private static BluetoothGattService        mGattService = null;
     private static BluetoothGattCharacteristic mGattChar    = null;
     private static BluetoothGattCharacteristic mGattCharNotify = null;
     static LinkedList<BluetoothCommand> mCommandQueue = new LinkedList<BluetoothCommand>();
     static Executor mCommandExecutor = Executors.newSingleThreadExecutor();
     static Semaphore mCommandLock = new Semaphore(1,true);
     private int mMtuSize = 0;
     private static BluetoothDevice mCurrentDev = null;

     private String mComponentName;
     private String mFileName;
     private String mMetadata;
     private byte   mDfuMethod;
     private boolean mOtaSupported = false;

     private static IMeshGattClientCallback mCallback = null;
     private static OTAUpgrade otaUpgrade = null;

     private static MeshGattClient ourInstance = new MeshGattClient();
     private final GattUtils.RequestQueue mRequestQueue = GattUtils.createRequestQueue();

     private  BroadcastReceiver mBroadcastReceiver = new BroadcastReceiver() {
         @Override
         public void onReceive(Context context, Intent intent) {
             switch (intent.getAction()) {
                 case BluetoothAdapter.ACTION_STATE_CHANGED:
                     if(intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, -1) == BluetoothAdapter.STATE_OFF) {
                     mMeshNativeHelper.meshClientConnectionStateChanged((short)0, (short)0);
                 } break;
             }

         }
     };

    //return our provision client instance
    static MeshGattClient getInstance(IMeshGattClientCallback callback)
    {
        mCallback = callback;
        return ourInstance;
    }

    public boolean init(Context ctx) {
        infoLog("MeshGattClient init , mGatt = " + mGatt);
        mCtx = ctx;
        mMeshNativeHelper = MeshNativeHelper.getInstance();
        if (mBluetoothManager == null) {
            mBluetoothManager = (BluetoothManager) mCtx.getSystemService(Context.BLUETOOTH_SERVICE);
            if (mBluetoothManager == null)
                return false;
        }
        if (mBluetoothAdapter == null) {
            mBluetoothAdapter = mBluetoothManager.getAdapter();
            if (mBluetoothAdapter == null)
                return false;
        }
        IntentFilter filter = new IntentFilter();
        filter.addAction(BluetoothAdapter.ACTION_STATE_CHANGED);
        mCtx.registerReceiver(mBroadcastReceiver, filter);
        return true;

    }

    private BluetoothGattCallback mGattCallbacks = new BluetoothGattCallback() {
        @Override
        public void onConnectionStateChange(final BluetoothGatt gatt, int status, int newState) {
            Log.i(TAG, "onConnectionStateChange: status = " + status
                    + ", newState = " + newState);

            if (status != 0 && newState != BluetoothProfile.STATE_DISCONNECTED) {
                gatt.disconnect();
                mMeshNativeHelper.meshClientConnectionStateChanged((short)0, (short) mMtuSize);
            }
            else if (newState == BluetoothProfile.STATE_CONNECTED) {
                new Handler(Looper.getMainLooper()).postDelayed(new Runnable() {
                    @Override
                    public void run() {
                        Message msg = new Message();
                        msg.what = MSG_REQUEST_MTU;
                        mHandler.sendMessageDelayed(msg, MTU_REQUEST_TIMEOUT);
                        boolean res = mGatt.requestMtu(Constants.MTU_SIZE_GATT);
                        infoLog("result of request MTU = "+res);
                    }
                }, 100);
                mCurrentDev = gatt.getDevice();

            }
            else if (newState == BluetoothProfile.STATE_DISCONNECTED) {

                gatt.close();

                Log.e(TAG, "setting mGatt,mGattService,mGattNotify as NULL");
                mGatt           = null;
                mGattService    = null;
                mGattCharNotify = null;
                mCurrentDev = null;
                mMeshNativeHelper.meshClientConnectionStateChanged((short)0, (short) mMtuSize);
                //mCallback.onNetworkConnectionStateChange();
            }

        }


        @Override
        public void onMtuChanged(final BluetoothGatt gatt, int mtu, int status) {
            Log.d(TAG, "onMtuChanged " + mtu);
            mHandler.removeMessages(MSG_REQUEST_MTU);
            mMeshNativeHelper.meshClientSetGattMtu(mtu);
            mMtuSize = mtu;

            new Handler(Looper.getMainLooper()).postDelayed(new Runnable() {
                @Override
                public void run() {
                    infoLog("Starting discovery services in LEMesh Proxy");
                    mCurrentDev = gatt.getDevice();
                    if (!gatt.discoverServices()) {
                        gatt.disconnect();
                    }
                }
            }, 100);

        }

        @Override
        public void onDescriptorRead(BluetoothGatt gatt, BluetoothGattDescriptor descriptor, int status) {

            if(descriptor.getCharacteristic().getUuid().equals(OTAUpgradeConstants.UPGRADE_CHARACTERISTIC_CONTROL_POINT_UUID) ||
                    descriptor.getCharacteristic().getUuid().equals(OTAUpgradeConstants.UPGRADE_CHARACTERISTIC_CONTROL_POINT_UUID_2)) {
                otaUpgrade.onOTADescriptorRead(gatt,descriptor,status);
            }

        }

        @Override
        public void onDescriptorWrite(BluetoothGatt gatt, BluetoothGattDescriptor descriptor, int status) {
            if(descriptor.getCharacteristic().getUuid().equals(OTAUpgradeConstants.UPGRADE_CHARACTERISTIC_CONTROL_POINT_UUID) ||
                    descriptor.getCharacteristic().getUuid().equals(OTAUpgradeConstants.UPGRADE_CHARACTERISTIC_CONTROL_POINT_UUID_2)) {
                otaUpgrade.onOTADescriptorWrite(gatt,descriptor,status);
            }
        }

        @Override
        public void onServicesDiscovered(BluetoothGatt gatt, int status) {
            Log.i(TAG, "onServicesDiscovered: status = " + status);
            if (status != 0) {
                gatt.disconnect();
                return;
            }

            boolean connectProvisioning = mMeshNativeHelper.meshClientIsConnectingProvisioning();
            Log.i(TAG, "onServicesDiscovered: connectProvisioning = " + connectProvisioning);
            if(connectProvisioning) //connecting to provisioning
            {
                mGattService = gatt.getService(Constants.UUID_SERVICE_SMART_MESH_PROVISIONING);
                if (mGattService == null) {
                    Log.e(TAG, "onServicesDiscovered: SIG Mesh Service ("
                            + Constants.UUID_SERVICE_SMART_MESH_PROVISIONING + ") not found");
                    mGatt.disconnect();
                    return;
                }

                ArrayList<BluetoothGattCharacteristic> array = (ArrayList<BluetoothGattCharacteristic>)
                        mGattService.getCharacteristics();

                for(int i =0;i<array.size();i++)
                    Log.d(TAG," list array > "+array.get(i).getUuid());

                mGattChar = mGattService.getCharacteristic(
                        Constants.UUID_CHARACTERISTIC_MESH_PROVISIONING_DATA_IN);
                if (mGattChar == null) {
                    Log.e(TAG, "onServicesDiscovered: SIG MESH Characteristic (" +
                            Constants.UUID_CHARACTERISTIC_MESH_PROVISIONING_DATA_IN + ") not found");
                    mGatt.disconnect();
                    return;
                }

                mGattCharNotify = mGattService.getCharacteristic(
                        Constants.UUID_CHARACTERISTIC_MESH_PROVISIONING_DATA_OUT);
                if(mGattCharNotify == null) {
                    Log.e(TAG, "onServicesDiscovered: SIG MESH Characteristic notify (" +
                            Constants.UUID_CHARACTERISTIC_MESH_PROVISIONING_DATA_OUT + ") not found");
                }

            } else { //connecting to proxy

                mOtaSupported = false;
                mGattService = gatt.getService(Constants.UUID_UPGRADE_SERVICE);
                if (mGattService != null) {
                    Log.i(TAG, "onServicesDiscovered: Proxy device supports Cypress OTA Service");
                    mOtaSupported = true;
                }
                mGattService = gatt.getService(Constants.UUID_SECURE_UPGRADE_SERVICE);
                if (mGattService != null) {
                    Log.i(TAG, "onServicesDiscovered: Proxy device supports Cypress Secure OTA Service");
                    mOtaSupported = true;
                }

                mGattService = gatt.getService(Constants.UUID_SERVICE_SMART_MESH_PROXY);
                if (mGattService == null) {
                    Log.e(TAG, "onServicesDiscovered:  Mesh Service ("
                            + Constants.UUID_SERVICE_SMART_MESH_PROXY + ") not found");
                    gatt.disconnect();
                    return;
                }

                ArrayList<BluetoothGattCharacteristic> array = (ArrayList<BluetoothGattCharacteristic>)
                        mGattService.getCharacteristics();

                for(int i =0;i<array.size();i++)
                    Log.d(TAG," list array > "+array.get(i).getUuid());


                mGattChar = mGattService.getCharacteristic(Constants.UUID_CHARACTERISTIC_MESH_PROXY_DATA_IN);
                if (mGattChar == null) {
                    Log.e(TAG, "onServicesDiscovered: Mesh Characteristic ("
                            + Constants.UUID_CHARACTERISTIC_MESH_PROXY_DATA_IN + ") not found");
                    gatt.disconnect();
                    return;
                }

                mGattCharNotify = mGattService.getCharacteristic(Constants.UUID_CHARACTERISTIC_MESH_PROXY_DATA_OUT);
                if (mGattCharNotify == null) {
                    Log.e(TAG, "onServicesDiscovered: mesh Characteristic (" + Constants.UUID_CHARACTERISTIC_MESH_PROXY_DATA_OUT + ") not found");
                    gatt.disconnect();
                    return;
                }
            }

            gatt.setCharacteristicNotification(mGattCharNotify, true);
            BluetoothGattDescriptor descriptor = mGattCharNotify.getDescriptor(CHARACTERISTIC_UPDATE_NOTIFICATION_DESCRIPTOR_UUID);
            descriptor.setValue(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE);

            if(gatt.writeDescriptor(descriptor)==true) {
                Log.d(TAG, "write true" );
            } else {
                Log.d(TAG, "write false" );
            }
            sleep(100);
            //send a broadcast to MeshService_old that proxy is connected
            Log.e(TAG,"Gatt connection is Successful");
            if (mGatt == null || mGattService == null || mGattChar == null) {
                // TBD: better to use an error message pop-up
                Log.e(TAG, "send: mGatt = " + mGatt + ", mGattService = " + mGattService
                        + ", mGattChar = " + mGattChar);
            } else {
                Log.e(TAG,"All the required fields are good ");
            }

            new Handler(Looper.getMainLooper()).postDelayed(new Runnable() {
                @Override
                public void run() {


                    if(mGattService.getUuid().equals(Constants.UUID_SERVICE_SMART_MESH_PROXY)) {
                        Log.d(TAG, "Proxy GATT connection/discovery/Enabling notification/MTU exchange successful");

                    } else {
                        Log.d(TAG, "Provision GATT connection/discovery/Enabling notification/MTU exchange successful");
                    }
                    mMeshNativeHelper.meshClientConnectionStateChanged((short)1, (short) mMtuSize);
                    mMeshNativeHelper.meshClientSetGattMtu(mMtuSize);
                }
            }, 100);
            mCurrentDev = gatt.getDevice();

        }

        @Override
        public void onCharacteristicWrite(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic, int status) {
            Log.i(TAG, "onCharacteristicWrite: status = " + status
                    + " char:" + characteristic.getUuid());
            if(characteristic.getUuid().equals(OTAUpgradeConstants.UPGRADE_CHARACTERISTIC_CONTROL_POINT_UUID) ||
                    characteristic.getUuid().equals(OTAUpgradeConstants.UPGRADE_CHARACTERISTIC_DATA_UUID) ||
                    characteristic.getUuid().equals(OTAUpgradeConstants.UPGRADE_CHARACTERISTIC_CONTROL_POINT_UUID_2) ||
                    characteristic.getUuid().equals(OTAUpgradeConstants.UPGRADE_CHARACTERISTIC_DATA_UUID_2)) {
                otaUpgrade.onOtaCharacteristicWrite(gatt,characteristic,status);
            } else {
                //dequeueCommand();
                mRequestQueue.next();
            }
        }

        /**
         * Callback invoked by Android framework when a characteristic
         * notification occurs
         */
        @Override
        public void onCharacteristicChanged(BluetoothGatt gatt,
                                            BluetoothGattCharacteristic characteristic) {
              if(characteristic.getUuid().equals(OTAUpgradeConstants.UPGRADE_CHARACTERISTIC_CONTROL_POINT_UUID)
                    || characteristic.getUuid().equals(OTAUpgradeConstants.UPGRADE_CHARACTERISTIC_DATA_UUID) ||
            characteristic.getUuid().equals(OTAUpgradeConstants.UPGRADE_CHARACTERISTIC_CONTROL_POINT_UUID_2)
                    || characteristic.getUuid().equals(OTAUpgradeConstants.UPGRADE_CHARACTERISTIC_DATA_UUID_2)) {
                Log.d(TAG, "recieved notification during OTA upgrade");
                otaUpgrade.onOtaCharacteristicChanged(gatt, characteristic);
            } else {
                byte[] charData = characteristic.getValue();
                int adv_len = charData.length;
                Log.d(TAG, "recieved notification "+characteristic.getService().getUuid().toString());
                  if(characteristic.getService().getUuid().equals(Constants.UUID_SERVICE_SMART_MESH_PROVISIONING)){
                    Log.e(TAG, "recieved provis packet from remote device : len = " + charData.length + " val = " + toHexString(charData));
                    Log.e(TAG, "notification uuid = " + characteristic.getUuid());
                    mMeshNativeHelper.SendRxProvisPktToCore(charData, adv_len);
                } else if(characteristic.getService().getUuid().equals(Constants.UUID_SERVICE_SMART_MESH_PROXY)){
                    Log.e(TAG, "recieved proxy packet from the remote device: len = " + charData.length + " val = " + toHexString(charData));
                    Log.e(TAG, "notification uuid = " + characteristic.getUuid());
                    mMeshNativeHelper.SendRxProxyPktToCore(charData, adv_len);
                }
            }
        }
    };

    boolean connect(byte[] bdaddr) {
        Log.e(TAG, "connect: 1");
        if (mGatt != null) {
            Log.e(TAG, "connect: GATT is busy...");
            mGatt.close();
        }
        //clearCommandQueue();
        mRequestQueue.clear();

        BluetoothDevice device = mBluetoothAdapter.getRemoteDevice(bdaddr);
        //API 23(Android-M) introduced connectGatt with Transport
        if (Build.VERSION.SDK_INT >= 23)
            mGatt = device.connectGatt(mCtx, false, mGattCallbacks, BluetoothDevice.TRANSPORT_LE);
        else
            mGatt = device.connectGatt(mCtx, false, mGattCallbacks);

        if (mGatt != null) return true;
        Log.e(TAG, "connect: Failed to connect device " + device);
        return false;
    }

    private void clearCommandQueue() {
        infoLog("clearCommandQueue");
        mCommandQueue.clear();
        mCommandQueue = null;
        mCommandQueue = new LinkedList<BluetoothCommand>();
        mCommandLock = new Semaphore(1,true);
        mCommandExecutor = null;
        mCommandExecutor = Executors.newSingleThreadExecutor();
    }

    boolean connect(BluetoothDevice device) {
        Log.e(TAG, "connect: 2");
        if (mGatt != null) {
            Log.e(TAG, "connect: GATT is busy...");
            return false;
        }
        mCommandQueue.clear();
        mCommandQueue = null;
        mCommandQueue = new LinkedList<BluetoothCommand>();
        mCommandLock = new Semaphore(1,true);

        //API 23(Android-M) introduced connectGatt with Transport
        if (Build.VERSION.SDK_INT >= 23)
            mGatt = device.connectGatt(mCtx, false, mGattCallbacks, BluetoothDevice.TRANSPORT_LE);
        else
            mGatt = device.connectGatt(mCtx, false, mGattCallbacks);

        if (mGatt != null) return true;
        Log.e(TAG, "connect: Failed to connect device " + device);
        return false;
    }

    private boolean refreshDeviceCache(BluetoothGatt gatt){
        Log.i(TAG, "refreshDeviceCache");
        try {
            BluetoothGatt localBluetoothGatt = gatt;
            Method localMethod = localBluetoothGatt.getClass().getMethod("refresh", new Class[0]);
            if (localMethod != null) {
                Log.i(TAG, "refreshDeviceCache : invoking local method");
                boolean bool = ((Boolean) localMethod.invoke(localBluetoothGatt, new Object[0])).booleanValue();
                return bool;
            }
        }
        catch (Exception localException) {
            Log.e(TAG, "An exception occured while refreshing device");
            localException.printStackTrace();
        }
        return false;
    }

    public boolean connectProxy(BluetoothDevice device){
        connect(device);
        return true;
    }

    public boolean disconnectDevice(){
        boolean ret = false ;
        Log.e(TAG, "Disconnecting the current proxy device");
        if(mGatt != null){
            mGatt.disconnect();
            ret = true;
            mGatt = null;
        } else {
            Log.e(TAG,"Error : mGatt interface is null");
        }
        return ret;
    }

    public boolean meshAdvScan(boolean start) {
        Log.e(TAG,"meshAdvScan , start =" + start);
        ScanSettings setting;

        if(mLeScanner != null && start) {
            Log.e(TAG,"meshAdvScan already running , start =" + start);
            return false;
        }

        if (mBluetoothAdapter == null) {
            mBluetoothAdapter = BluetoothAdapter.getDefaultAdapter();
            if (mBluetoothAdapter == null)
                return false;
        }

        if (mLeScanner == null) {
            Log.e(TAG,"mLeScaner is null");
            mLeScanner = mBluetoothAdapter.getBluetoothLeScanner();
            if (mLeScanner == null)
                return false;
        }

        // Stop scan
        if(start == false) {
            Log.d(TAG,"Stop scanning");
            mLeScanner.stopScan(mScanCallback);
            mLeScanner = null;
            return true;
        }

        setting = new ScanSettings.Builder()
                .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).build();
        ScanFilter scanFilterprov =
                new ScanFilter.Builder()
                        .setServiceUuid(new ParcelUuid(Constants.UUID_SERVICE_SMART_MESH_PROVISIONING))
                        .build();
        ScanFilter scanFilterproxy =
                new ScanFilter.Builder()
                        .setServiceUuid(new ParcelUuid(Constants.UUID_SERVICE_SMART_MESH_PROXY))
                        .build();
        List<ScanFilter> scanFilters = new ArrayList<ScanFilter>();
        scanFilters.add(scanFilterprov);
        scanFilters.add(scanFilterproxy);
        mLeScanner.startScan(scanFilters,setting,mScanCallback);
        return true;
    }

    /* Send Provisioning Packet from JNI to gattClient and write to device */
    public void sendProvisionPacket(byte[] packet, int len){
        infoLog("sendProvisionPacket");
        infoLog("DATA : " + toHexString(packet));
        writeData(packet,Constants.UUID_SERVICE_SMART_MESH_PROVISIONING);
    }

    /* Send Provisioning Packet from JNI to gattClient and write to device */
    public void sendProxyPacket(byte[] packet, int len){
        infoLog("sendProxyPacket");
        infoLog("DATA : " + toHexString(packet));
        writeData(packet,Constants.UUID_SERVICE_SMART_MESH_PROXY);
    }

    /* Send OTA Packet from OTAUpgrade to gattClient and write to device */
    public void sendOTAPacket(byte[] packet, int len){
        infoLog("sendOTAPacket");
        infoLog("DATA : " + toHexString(packet));
        writeData(packet, OTAUpgradeConstants.UPGRADE_SERVICE_UUID);
    }

    /* Write Data to Device */
    public boolean writeData(byte value[], UUID uuid){

        //check mBluetoothGatt is available
        if (mGatt == null) {
            Log.e(TAG, "lost connection");

            return false;
        }
        BluetoothGattService Service = mGatt.getService(uuid);
        if (Service == null) {
            Log.e(TAG, "service not found!");
            return false;
        }
        BluetoothGattCharacteristic charac1 = null;
        if(uuid == Constants.UUID_SERVICE_SMART_MESH_PROXY)
            charac1 = Service.getCharacteristic(Constants.UUID_CHARACTERISTIC_MESH_PROXY_DATA_IN);
        else if(uuid == Constants.UUID_SERVICE_SMART_MESH_PROVISIONING)
            charac1 = Service.getCharacteristic(Constants.UUID_CHARACTERISTIC_MESH_PROVISIONING_DATA_IN);
     //   sendQueuedCommand(value, service);
        mRequestQueue.addWriteCharacteristic(mGatt, charac1, value);
        mRequestQueue.execute();
        return true;
    }

    public static void queueCommand(BluetoothCommand command, UUID service){
        Log.d(TAG,"queueCommand");
        synchronized (mCommandQueue) {

            mCommandQueue.add(command);  //Add to end of stack

            //Schedule a new runnable to process that command (one command at a time executed only)
            ExecuteCommandRunnable runnable = new ExecuteCommandRunnable(command, service);
            mCommandExecutor.execute(runnable);
        }
    }

    //Remove the current command from the queue, and release the cs
    //signalling the next queued command (if any) that it can start
    protected void dequeueCommand(){
//        if(!mCommandQueue.isEmpty()) {
//            mCommandQueue.pop();
//            mCommandLock.release();
//        }
        Log.e(TAG, "dequeueCommand");
        mCommandQueue.pop();
        mCommandLock.release();
    }

    public void connectProxy(String bdaddr) {
        BluetoothDevice device = mBluetoothAdapter.getRemoteDevice(bdaddr);
        connectProxy(device);
    }

    public void disconnect(short connId) {
        disconnectDevice();
    }

    public int startOtaUpgrade(String componentName, String fileName, String metadata, byte dfuMethod) {
        Log.d(TAG,"startOtaUpgrade mGatt:"+mGatt);
        Log.i(TAG, "startOtaUpgrade: componentName = " + componentName + ", dfuMethod = " + dfuMethod + ", otaSupported = " + mOtaSupported);
        Log.i(TAG, "startOtaUpgrade: fileName = " + fileName + ", metadata = " + metadata);

        mComponentName = componentName;
        mFileName      = fileName;
        mMetadata      = metadata;
        mDfuMethod     = dfuMethod;

        if(dfuMethod == MeshController.DFU_METHOD_PROXY_TO_ALL || dfuMethod == MeshController.DFU_METHOD_APP_TO_ALL){
            Log.d(TAG,"send dfu start command");
            return mMeshNativeHelper.meshClientDfuStart(dfuMethod, mOtaSupported, componentName);
        }
        else if (dfuMethod == MeshController.DFU_METHOD_APP_TO_DEVICE){
            if(otaUpgrade == null)
            {
                Log.d(TAG,"otaupgrade is null creating new object");
                otaUpgrade = new OTAUpgrade();
            }

            // MTU size is to accomodate extra bytes added from encryption
            otaUpgrade.start(componentName, mCallback, fileName, dfuMethod,mOtaSupported, metadata, mGatt, mCurrentDev, (mMtuSize - 17), mRequestQueue);
            return 0;
        }
        else {
            return 1;
        }





//        if(otaUpgrade == null)
//        {
//            Log.d(TAG,"otaupgrade is null creating new object");
//            otaUpgrade = new OTAUpgrade();
//        }
//
//        // MTU size is to accomodate extra bytes added from encryption
//        otaUpgrade.start(componentName, mCallback, fileName, dfuMethod, metadata, mGatt, mCurrentDev, (mMtuSize - 17), mRequestQueue);
    }

    public int stopOtaUpgrade() {
        if(otaUpgrade != null) {
            return otaUpgrade.stop();
        } else {
            return MeshController.MESH_CLIENT_ERR_INVALID_ARGS;
        }
    }

    public void startOta() {
        Log.i(TAG, "startOta");
        if (otaUpgrade == null) {
            otaUpgrade = new OTAUpgrade();
        }

        // MTU size is to accomodate extra bytes added from encryption
        otaUpgrade.start(mComponentName, mCallback, mFileName, mDfuMethod, mOtaSupported, mMetadata, mGatt, mCurrentDev, (mMtuSize - 17), mRequestQueue);
    }

    public void otaUpgradeApply() {
        if(otaUpgrade == null) {
            otaUpgrade = new OTAUpgrade();
        }
        otaUpgrade.apply(mCallback, mGatt, mRequestQueue);

    }

    //Runnable to execute a command from the queue
    static class ExecuteCommandRunnable implements Runnable{

        BluetoothCommand mCommand;
        UUID mService;

        public ExecuteCommandRunnable(BluetoothCommand command, UUID service) {
            mCommand = command;
            mService = service;
        }

        @Override
        public void run() {
            Log.d(TAG,"sendQueuedCommand : run");
            //Acquire semaphore cs to ensure no other operations can run until this one completed
            mCommandLock.acquireUninterruptibly();
            //Tell the command to start itself.
            mCommand.executeCommand(mGatt, mService);
        }
    }

    final ScanCallback mScanCallback = new ScanCallback() {

        @Override
        public void onScanResult(int callbackType, ScanResult result) {
            infoLog("onScanResultStart");
            infoLog("bytes = "+toHexString(result.getScanRecord().getBytes())+ " length"+result.getScanRecord().getBytes().length);
            if(result.getDevice() != null)
                infoLog("device = " + result.getDevice().getAddress().toString() + "  rssi = " + result.getRssi());
            byte[] scandata = result.getScanRecord().getBytes();
            BluetoothDevice device = result.getDevice();
            String name = result.getScanRecord().getDeviceName();
            infoLog("NAME = "+name);
            Map<ParcelUuid, byte[]> data = ( Map<ParcelUuid, byte[]>) result.getScanRecord().getServiceData();

            byte[] identity = new byte[result.getScanRecord().getBytes().length];
            System.arraycopy(result.getScanRecord().getBytes(), 0, identity, 0, result.getScanRecord().getBytes().length);
            String[] dev = device.getAddress().split(":");
            byte[] devAddress = new byte[6];        // mac.length == 6 bytes
            for(int j = 0; j < dev.length; j++) {
                devAddress[j] = Integer.decode("0x" + dev[j]).byteValue();
            }
            Log.d(TAG,"bdaddr = "+toHexString(devAddress));
            mMeshNativeHelper.meshClientAdvertReport(devAddress, (byte)0, (byte)result.getRssi(), identity, identity.length);

        }
    };

    private static void sendQueuedCommand(byte[] data, UUID service){
        //Use a sample command with a delay in it to demonstarted
        Log.d(TAG,"sendQueuedCommand "+toHexString(data));
        BluetoothCommand command = new DelayCommand(data, mCurrentDev);
        queueCommand(command, service);
    }

    public static String toHexString(byte[] bytes) {
        int len = bytes.length;
        if (len == 0)
            return null;

        char[] buffer = new char[len * 3 - 1];

        for (int i = 0, index = 0; i < len; i++) {
            if (i > 0) {
                buffer[index++] = ' ';
            }

            int data = bytes[i];
            if (data < 0) {
                data += 256;
            }

            byte n = (byte) (data >>> 4);
            if (n < 10) {
                buffer[index++] = (char) ('0' + n);
            } else {
                buffer[index++] = (char) ('A' + n - 10);
            }

            n = (byte) (data & 0x0F);
            if (n < 10) {
                buffer[index++] = (char) ('0' + n);
            } else {
                buffer[index++] = (char) ('A' + n - 10);
            }
        }
        return new String(buffer);
    }

    private  Handler mHandler = new Handler() {
        @Override
        public void handleMessage(Message msg) {
            switch (msg.what) {
                case MSG_REQUEST_MTU :
                    Log.d(TAG,"Request MTU timeout disconnecting gatt");
                    if(mGatt != null)
                        mGatt.disconnect();
            };
        }
    };

    private void infoLog(String msg) {
        if (DebugUtils.VDBG) Log.i(TAG, msg);
    }

    private void debugLog(String msg) {
        if (DebugUtils.DBG) Log.d(TAG, msg);
    }

    private void errorLog(String msg) {
        if (DebugUtils.ERR) infoLog(msg);
    }

    private void sleep(long milliseconds) {
        try {
            Thread.sleep(milliseconds);
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
    }
}
