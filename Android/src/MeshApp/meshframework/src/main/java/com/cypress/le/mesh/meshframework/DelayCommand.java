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

import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGatt;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothGattServer;
import android.bluetooth.BluetoothGattService;
import android.util.Log;

import java.util.UUID;

class DelayCommand extends BluetoothCommand {
    private static final String TAG = "DelayCommand";
    byte[] data;
    BluetoothDevice remoteDevice;

    public DelayCommand(byte[] data,BluetoothDevice device) {
        this.data = data;
        this.remoteDevice = device;
    }

    public void executeCommand(BluetoothGatt gatt, UUID service){
        Log.e(TAG, "executeCommand");
        if (gatt == null) {
            Log.e(TAG, "lost connection");
            return;
        }

        BluetoothGattService Service = gatt.getService(service);

        if (Service == null) {
            Log.e(TAG, "service not found!");
            return;
        }
        BluetoothGattCharacteristic charac1 = null;
        boolean status1 = false;

       try {
            Thread.sleep(30);
        } catch (InterruptedException e) {
            e.printStackTrace();
        }

        if(service == Constants.UUID_SERVICE_SMART_MESH_PROXY)
            charac1 = Service.getCharacteristic(Constants.UUID_CHARACTERISTIC_MESH_PROXY_DATA_IN);
        else if(service == Constants.UUID_SERVICE_SMART_MESH_PROVISIONING)
            charac1 = Service.getCharacteristic(Constants.UUID_CHARACTERISTIC_MESH_PROVISIONING_DATA_IN);
        else {
            Log.d(TAG, "unknown service !!");
            return;
        }


        charac1.setValue(data);
        charac1.setWriteType(BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE);
        Log.d(TAG,"Writing char uuid: "+charac1.getUuid());
        status1 = gatt.writeCharacteristic(charac1);
        Log.d(TAG,"Writing char status: "+status1);
        if(!status1) {

            retry(gatt, charac1);

            status1 = gatt.writeCharacteristic(charac1);
            Log.d(TAG,"--- Writing char proxy status attempt 2: "+status1);
        }
    }

    private void retry(BluetoothGatt gatt, BluetoothGattCharacteristic charac1) {
        int i = 0;
        Log.d(TAG,"Retry Gatt write");
        for (i = 0; i < 3; i++)
        {
            if (gatt.writeCharacteristic(charac1) == true)
            {
                Log.d(TAG,"Write success");
                break;
            }
            if (i != 3)
            {
                Log.d(TAG,"Sleep 200ms");
                sleep(200);
            }
        }
        if (i == 3) {
            Log.d(TAG,"Disconnect");
            gatt.disconnect();
        }

    }

    private void sleep(long milliseconds) {
        try {
            Thread.sleep(milliseconds);
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
    }

}
