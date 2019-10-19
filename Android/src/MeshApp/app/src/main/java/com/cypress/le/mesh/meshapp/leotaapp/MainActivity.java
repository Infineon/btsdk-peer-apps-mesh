/*
 * Copyright 2017, Cypress Semiconductor Corporation or a subsidiary of Cypress Semiconductor
 * Corporation. All rights reserved. This software, including source code, documentation and
 * related materials ("Software"), is owned by Cypress Semiconductor  Corporation or one of its
 * subsidiaries ("Cypress") and is protected by and subject to worldwide patent protection
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
 * manufacturer of such system or application assumes  all risk of such use and in doing so agrees
 * to indemnify Cypress against all liability.
 */
package  com.cypress.le.mesh.meshapp.leotaapp;

import java.text.SimpleDateFormat;
import java.util.Calendar;
import java.util.Random;
import java.util.UUID;
import java.util.List;

import com.cypress.le.mesh.meshapp.ActivityGroup;
import com.cypress.le.mesh.meshapp.R;
import com.cypress.le.mesh.meshapp.ledevicepicker.DeviceListFragment.Callback;
import com.cypress.le.mesh.meshapp.ledevicepicker.DevicePickerFragment;
import com.cypress.le.mesh.meshapp.leotaapp.GattUtils.RequestQueue;

import android.app.ActionBar;
import android.app.Activity;
import android.app.AlertDialog;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGatt;
import android.bluetooth.BluetoothGattCallback;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothGattDescriptor;
import android.bluetooth.BluetoothGattService;
import android.bluetooth.BluetoothManager;
import android.content.Context;
import android.content.DialogInterface;
import android.os.Bundle;
import android.os.Environment;
import android.support.v7.app.AppCompatActivity;
import android.text.Layout;
import android.text.method.ScrollingMovementMethod;
import android.util.Log;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.AdapterView;
import android.widget.AdapterView.OnItemSelectedListener;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.Toast;

import org.w3c.dom.Text;

import java.io.File;
import java.io.FileFilter;

import java.io.InputStream;
import java.io.FileInputStream;

class ota_state_t {
    short   peer_mtu;               // negotiated MTU
}

/**
 * Main activity for the the OTA Client application
 */
public class MainActivity extends AppCompatActivity implements OnClickListener, Callback,
        OnItemSelectedListener {
    private static final String TAG = Constants.TAG_PREFIX + "OTAUpgrade";
    private static final String FRAGMENT_DEVICE_PICKER = "DevicePickerDialog";

    private static final int SERIAL_GATT_DEFAULT_MTU                = 23;
    // MTU size is reduced from 259 to 158 to handle Pixel 1 problem (pixel devices stall when OTA upgrade with higher MTU is performed)
    private static final int SERIAL_GATT_REQUEST_MTU                = 158;
    private int mtuUsed  = SERIAL_GATT_DEFAULT_MTU;

    private boolean m_bConnected;
    private int m_offset;
    private byte[] m_Patch = null;
    private int m_PatchSize;
    private int m_crc32;

    private boolean m_bInTransfer = false;
    private static boolean OTAUpgradeTestRun = false;
    private static int OTACount = 1;
    private static int OTAMaxCount = 0;
    private static boolean OTAVerified = false;
    private static File OTAFile = null;
    private static String OTADevName = null;
    private static Toast mToast = null;

    // size is 256
    private static final int crc32_table[] = {
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

    private static final int    WS_UPGRADE_CONNECTED                                = 0x0;
    private static final int    WS_UPGRADE_RESPONSE_OK                              = 0x1;
    private static final int    WS_UPGRADE_CONTINUE                                 = 0x2;
    private static final int    WS_UPGRADE_START_VERIFICATION                       = 0x3;
    private static final int    WS_UPGRADE_RESPONSE_FAILED                          = 0x4;
    private static final int    WS_UPGRADE_ABORT                                    = 0x5;

    private int m_event;

    private static final int    WS_UPGRADE_STATE_IDLE                               = 0x0;
    private static final int    WS_UPGRADE_STATE_WAIT_FOR_READY_FOR_DOWNLOAD        = 0x1;
    private static final int    WS_UPGRADE_STATE_DATA_TRANSFER                      = 0x2;
    private static final int    WS_UPGRADE_STATE_VERIFICATION                       = 0x3;
    private static final int    WS_UPGRADE_STATE_VERIFIED                           = 0x4;
    private static final int    WS_UPGRADE_STATE_ABORTED                            = 0x5;
    private int m_state;
    private long m_time;

    // command definitions for the OTA FW upgrade
    private static final int WICED_OTA_UPGRADE_COMMAND_PREPARE_DOWNLOAD               = 1;
    private static final int WICED_OTA_UPGRADE_COMMAND_DOWNLOAD                       = 2;
    private static final int WICED_OTA_UPGRADE_COMMAND_VERIFY                         = 3;
    private static final int WICED_OTA_UPGRADE_COMMAND_FINISH                         = 4;
    private static final int WICED_OTA_UPGRADE_COMMAND_GET_STATUS                     = 5;
    private static final int WICED_OTA_UPGRADE_COMMAND_CLEAR_STATUS                   = 6;
    private static final int WICED_OTA_UPGRADE_COMMAND_ABORT                          = 7;

    // event definitions for the OTA FW upgrade
    private static final int WICED_OTA_UPGRADE_STATUS_OK                              = 0;
    private static final int WICED_OTA_UPGRADE_STATUS_UNSUPPORTED_COMMAND             = 1;
    private static final int WICED_OTA_UPGRADE_STATUS_ILLEGAL_STATE                   = 2;
    private static final int WICED_OTA_UPGRADE_STATUS_VERIFICATION_FAILED             = 3;
    private static final int WICED_OTA_UPGRADE_STATUS_INVALID_IMAGE                   = 4;
    private static final int WICED_OTA_UPGRADE_STATUS_INVALID_IMAGE_SIZE              = 5;
    private static final int WICED_OTA_UPGRADE_STATUS_MORE_DATA                       = 6;
    private static final int WICED_OTA_UPGRADE_STATUS_INVALID_APPID                   = 7;
    private static final int WICED_OTA_UPGRADE_STATUS_INVALID_VERSION                 = 8;
    private static final int WICED_OTA_UPGRADE_STATUS_CONTINUE                        = 9;


    ota_state_t ota_state = new ota_state_t();

    char[] serial_gatt_dump_hex_string(byte[] data)
    {
        char[] hexArray = "0123456789ABCDEF".toCharArray();
        char[] hexChars = new char[data.length * 2];
        for ( int j = 0; j < data.length; j++ ) {
            int v = data[j] & 0xFF;
            hexChars[j * 2] = hexArray[v >>> 4];
            hexChars[j * 2 + 1] = hexArray[v & 0x0F];
        }

        return hexChars;
    }

    /**
     * Callback object that the LE Gatt service calls to report callback events
     * that occur
     *
     * @author fredc
     *
     */
    private class GattCallback extends BluetoothGattCallback {

        /**
         * Callback invoked by Android framework and a LE connection state
         * change occurs
         */
        @Override
        public void onConnectionStateChange(BluetoothGatt gatt, int status, int newState) {
            Log.d(MainActivity.TAG, "onConnectionStateChange(): address=="
                    + gatt.getDevice().getAddress() + ", status = " + status + ", state="
                    + newState);
            boolean isConnected = (newState == BluetoothAdapter.STATE_CONNECTED);

            boolean isOk = (status == 0);
            if (isConnected && isOk) {
                Log.d(TAG, "Request MTU");
                gatt.requestMtu(SERIAL_GATT_REQUEST_MTU); //SERIAL_GATT_DEFAULT_MTU
            }
            // If we got here, this is a disconnect with or without error
            // close gatt connection
            if (!isConnected) {
                Log.d(MainActivity.TAG, "onConnectionStateChange(): Connection and GATT closed");
                closeDevice();
                gatt.close();
                processConnectionStateChanged(false, false);

                if((status == 8|| status == 133)&& OTAVerified && OTAUpgradeTestRun) {
                    //Next iteration
                    if(OTACount <= OTAMaxCount) {
                        try {
                            Thread.sleep(8000);
                        } catch (InterruptedException e) {
                            e.printStackTrace();
                        }
                        Log.d(TAG, "ProcessProgress verified OTAUpgradeTestRun true OTA count :"+ OTACount);
                        OTAUpgradeTestRun = true;
                        runOnUiThread(new Runnable() {
                            @Override
                            public void run() {
                                mLabelcount.setText("Loop Count :"+OTACount);
                            }
                        });
                        continueOTAUpgrade();

                    }
                } else if(status == 22){
                    show("LMP response timeout (22)!!", Toast.LENGTH_SHORT);
                }
            }
        }

        /**
         * Callback invoked by Android framework when LE service discovery
         * completes
         */
        @Override
        public void onServicesDiscovered(BluetoothGatt gatt, int status) {

            Log.d(TAG, "onServicesDiscovered status:" + status);
            if (status != 0) {
                // Error occurred. close the connection and return a
                // disconnected status
                gatt.close();
                try {
                    processConnectionStateChanged(false, true);
                } catch (Throwable t) {
                    Log.e(TAG, "error", t);
                }
            } else {
                try {
                    List<BluetoothGattService> serviceList = gatt.getServices();
                    Log.e(TAG, "List " + serviceList.size());

                    // Loops through available Characteristics.
                    for (BluetoothGattService service : serviceList) {
                        // Log.e(TAG, "service " + service.getUuid().toString() + " " + OTAUpgradeConstants.SECURE_UPGRADE_SERVICE_UUID.toString());

                        if (Constants.SECURE_UPGRADE_SERVICE_UUID.equals(service.getUuid())) {
                            // Log.d(TAG, "secure");
                            mSecureService = true;
                            break;
                        }
                    }
                    // mSecureService = serviceList.contains(new BluetoothGattService(SECURE_UPGRADE_SERVICE_UUID, SERVICE_TYPE_PRIMARY));
                    Log.e(TAG, "Secure " + mSecureService);

                    processConnectionStateChanged(true, false);

                    RegisterOTANotification(true);

                } catch (Throwable t) {
                    Log.e(TAG, "error", t);
                }
            }
        }

        /**
         * Callback invoked by Android framework when a characteristic read
         * completes
         */
        @Override
        public void onCharacteristicRead(BluetoothGatt gatt,
                                         BluetoothGattCharacteristic characteristic, int status) {
            if (status == 0) {
                try {
                    processCharacteristicRead(characteristic);
                } catch (Throwable t) {
                    Log.e(TAG, "error", t);
                }
            }
            Log.e(TAG, "onCharacteristicRead mRequestQueue next");
            mRequestQueue.next();// Execute the next queued request, if
        }

        /**
         * Callback invoked by Android framework when a descriptor read
         * completes
         */
        @Override
        public void onDescriptorRead(BluetoothGatt gatt, BluetoothGattDescriptor descriptor,
                                     int status) {
            if (status == 0) {
                try {
                    processDescriptorRead(gatt, descriptor);
                } catch (Throwable t) {
                    Log.e(TAG, "error", t);
                }
            }
            Log.e(TAG, "onDescriptorRead mRequestQueue next");
            mRequestQueue.next();// Execute the next queued request, if any
        }

        /**
         * Callback invoked by Android framework when a characteristic
         * notification occurs
         */
        @Override
        public void onCharacteristicChanged(BluetoothGatt gatt,
                                            BluetoothGattCharacteristic characteristic) {
            Log.d(TAG, "onCharacteristicChanged UUID:"+ characteristic.getUuid().toString());
            try {
                processCharacteristicNotification(characteristic);
            } catch (Throwable t) {
                Log.e(TAG, "error", t);
            }
        }

        /**
         * Callback invoked by Android framework when a descriptor write
         * completes
         */
        @Override
        public void onDescriptorWrite(BluetoothGatt gatt, BluetoothGattDescriptor descriptor,
                                      int status) {
            if (status == 0) {
                try {
                    processDescriptorWrite(gatt, descriptor);
                } catch (Throwable t) {
                    Log.e(TAG, "error", t);
                }
            }
            Log.e(TAG, "onDescriptorWrite mRequestQueue next");
            mRequestQueue.next();// Execute the next queued request, if any
        }

        /**
         * Callback invoked by Android framework when a descriptor write
         * completes
         */
        @Override
        public void onMtuChanged(BluetoothGatt gatt, int mtu, int status) {
            Log.d(TAG, "onMtuChanged  mtu = " + mtu);

            mtuUsed = mtu;

            if (status == 0) {
                try {
                    ota_state.peer_mtu = (short) mtu;

                } catch (Throwable t) {
                    Log.e(TAG, "error", t);
                }
                // Discover services, and return connection state = connected
                // after services discovered
                boolean isOk = gatt.discoverServices();

                if (isOk) {
                    return;
                }
                else {
                    gatt.close();
                    processConnectionStateChanged(false, false);
                }
            }
            Log.e(TAG, "onMtuChanged mRequestQueue next");
            mRequestQueue.next();// Execute the next queued request, if any

        }

        /**
         * Callback invoked by Android framework when a characteristic write
         * completes
         */
        @Override
        public void onCharacteristicWrite(BluetoothGatt gatt,
                                          BluetoothGattCharacteristic characteristic, int status) {
            super.onCharacteristicWrite(gatt, characteristic, status);
            if (status == 0) {
                try {
                    processCharacteristicWrite(characteristic);
                } catch (Throwable t) {
                    Log.e(TAG, "error", t);
                }
            }
            Log.e(TAG, "onCharacteristicWrite mRequestQueue next");
            mRequestQueue.next();// Execute the next queued request, if any
        }
    }

    // UI Components
    // Device picker components
    private LinearLayout mButtonSelectDevice; // Button to start device picker
    private DevicePickerFragment mDevicePicker;
    private TextView mTextDeviceName; // Displays device's name
    private TextView mTextDeviceAddress; // Displays device's address

    private TextView mTextOTAImageName;

    // Connection components
    private Button mButtonConnect; // Button to connect to a device
    private Button mButtonDisconnect; // Button to connect from a device
    private TextView mTextConnectionState; // Displays current connection state
    private Button mButtonTestOta;
    private TextView mLabelcount;

    // OTA service components
    private LinearLayout mButtonSelectOTAImage; // Button to select OTA Image file
    private Button mButtonOTAUpdate;
    private TextView mLabelOTAStatus;

    private final GattCallback mGattCallback = new GattCallback();
    private final RequestQueue mRequestQueue = GattUtils.createRequestQueue();
    private BluetoothAdapter mBtAdapter;
    private BluetoothDevice mPickedDevice;
    private BluetoothGatt mPickedDeviceGatt;
    private boolean mPickedDeviceIsConnected;
    private boolean mSyncNotificationSetting;
    private boolean mSecureService;

    /**
     * Helper function to show a toast notification message
     *
     * @param msg
     */
    private void showMessage(String msg) {
       // Toast.makeText(this, msg, Toast.LENGTH_SHORT).show();
    }

    /**
     * Initialize the device picker
     *
     * @return
     */
    private void initDevicePicker() {
        mDevicePicker = DevicePickerFragment.createDialog(this, null, true);
    }

    /**
     * Cleanup the device picker
     */
    private void cleanupDevicePicker() {
        if (mDevicePicker != null) {
            mDevicePicker = null;
        }
    }

    private void closeDevice() {
        if (mPickedDeviceGatt != null) {
            mPickedDeviceGatt.close();
            mPickedDeviceGatt = null;
        }
    }

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        mBtAdapter = BluetoothAdapter.getDefaultAdapter();

        // Initialize the UI components, and register a listeners
        setContentView(R.layout.main);

        // Load device picker components
        mButtonSelectDevice = (LinearLayout) findViewById(R.id.btn_selectdevice);
        mButtonSelectDevice.setOnClickListener(this);
        mTextDeviceName = (TextView) findViewById(R.id.deviceName);
        mTextDeviceAddress = (TextView) findViewById(R.id.deviceAddress);

        // Load connection components
        mButtonConnect = (Button) findViewById(R.id.btn_connect);
        mButtonConnect.setOnClickListener(this);
        mButtonDisconnect = (Button) findViewById(R.id.btn_disconnect);
        mButtonDisconnect.setOnClickListener(this);
        mTextConnectionState = (TextView) findViewById(R.id.connectionState);
        mButtonTestOta = (Button) findViewById(R.id.btn_test_ota);

        // Load ota service components
        mButtonSelectOTAImage = (LinearLayout) findViewById(R.id.btn_select_ota_image);
        mButtonSelectOTAImage.setOnClickListener(this);

        mTextOTAImageName = (TextView) findViewById(R.id.otaImageName);

        mButtonOTAUpdate = (Button) findViewById(R.id.btn_ota_update);
        mButtonOTAUpdate.setOnClickListener(this);

        mLabelcount = (TextView) findViewById(R.id.label_count);

        mLabelOTAStatus = (TextView) findViewById(R.id.label_ota_configuration);
        mLabelOTAStatus.setText(getString(R.string.label_ota_configuration, Constants.UPGRADE_CHARACTERISTIC_CONTROL_POINT_UUID));

        // Initialize the device picker UI fragment
        initDevicePicker();

        // refresh the UI component states
        updateWidgets();

        mButtonTestOta.setOnClickListener(new OnClickListener() {
            @Override
            public void onClick(View v) {
                Log.d(TAG, "mButtonTestOta clicked");

                if (OTADevName == null || OTAFile == null)
                {
                    show("Please select device and OTA file", Toast.LENGTH_SHORT);
                    return;
                }
                View editView = View.inflate(MainActivity.this, R.layout.pop_up_num_iter, null);
                popupNumIteration(editView);

            }
        });
    }

    private void popupNumIteration(View editView) {
        AlertDialog.Builder builder = new AlertDialog.Builder(MainActivity.this, R.style.AlertDialogCustom);
        final EditText text = (EditText) editView.findViewById(R.id.editText);
        builder.setView(editView);

        builder.setPositiveButton(android.R.string.ok, new DialogInterface.OnClickListener() {
            public void onClick(DialogInterface dialog, int id) {

                OTAMaxCount = Integer.parseInt(text.getText().toString());
                Log.d(TAG, "User clicked OK button + max count : "+OTAMaxCount);
                dialog.dismiss();
                mLabelcount.setVisibility(View.VISIBLE);

                if(OTAMaxCount > 0) {
                    // Test OTA upgrade
                    OTAUpgradeTestRun = true;
                    OTAVerified = true;
                    //Next iteration
                    //OTACount = 0;
                    try {
                        Thread.sleep(8000);
                    } catch (InterruptedException e) {
                        e.printStackTrace();
                    }
                    Log.d(TAG, "ProcessProgress verified OTAUpgradeTestRun true OTA count :" + OTACount);
                    OTACount = 1;
                    continueOTAUpgrade();
                    mLabelcount.setText("Loop Count :"+OTACount);
                }
            }
        });
        builder.setNegativeButton(android.R.string.cancel, new DialogInterface.OnClickListener() {
            public void onClick(DialogInterface dialog, int id) {
                Log.d(TAG, "User cancelled the dialog");
            }
        });
        AlertDialog alert = builder.create();
        alert.show();
        alert.getWindow().setLayout(ActionBar.LayoutParams.WRAP_CONTENT, ActionBar.LayoutParams.WRAP_CONTENT);

    }

    /**
     * Updates the UI widgets based on the latest connection state
     */
    private void updateWidgets() {
        Log.d(TAG,"updateWidgets -------");

        if (mPickedDevice == null) {
            // No devices selected: set initial state
            mButtonConnect.setEnabled(true);
            mButtonDisconnect.setEnabled(false);
            mButtonSelectDevice.setEnabled(true);
            mButtonSelectOTAImage.setEnabled(true);
            mTextDeviceName.setText(R.string.no_device);
            mTextDeviceAddress.setText("");
        } else {
            // Device picked, always set the connect/disconnect buttons enabled
            mButtonConnect.setEnabled(true);
            mButtonDisconnect.setEnabled(true);

            if (mPickedDeviceIsConnected) {
                // Set resources when connected

                // Disable selecting new device when connected
                mButtonSelectDevice.setEnabled(false);
                mButtonSelectOTAImage.setEnabled(true);
                // Set the connection state status
                mTextConnectionState.setText(getString(R.string.connected));

                // Update ota service components
                mButtonOTAUpdate.setEnabled(true);

            } else {
                // Update resources when disconnected

                // Enable selecting new device when connected
                mButtonSelectDevice.setEnabled(true);
                mButtonSelectOTAImage.setEnabled(true);

                // Set the connection state status
                mTextConnectionState.setText(getString(R.string.disconnected));

                // Update ota service components
                mButtonOTAUpdate.setEnabled(false);
            }
        }
    }

    @Override
    public void onDestroy() {
        closeDevice();
        cleanupDevicePicker();
        super.onDestroy();
    }

    byte[] getBytes (File file)
    {
        FileInputStream input = null;
        if (file.exists()) try
        {
            input = new FileInputStream (file);
            int len = (int) file.length();
            byte[] data = new byte[len];
            int count, total = 0;
            while ((count = input.read (data, total, len - total)) > 0) total += count;
            return data;
        }
        catch (Exception ex)
        {
            ex.printStackTrace();
        }
        finally
        {
            if (input != null) try
            {
                input.close();
            }
            catch (Exception ex)
            {
                ex.printStackTrace();
            }
        }
        return null;
    }

    /**
     * Callback invoked when buttons/switches clicked
     */
    @Override
    public void onClick(View v) {
        if (v == mButtonSelectDevice) {
            // Start the device selector
            if(!mDevicePicker.isAdded())
            {
                mDevicePicker.show(getFragmentManager(), FRAGMENT_DEVICE_PICKER);
            }

        }
        else if (v == mButtonSelectOTAImage)
        {
            // Choose OTA Image file from the local storage
            FileChooser filechooser = new FileChooser(MainActivity.this);
            filechooser.setFileListener(new FileChooser.FileSelectedListener() {
                @Override
                public void fileSelected(final File file) {
                    showMessage("file selected " + file.getAbsolutePath() + file.getName());
                    OTAFile = file;
                    mTextOTAImageName.setText(file.getAbsolutePath());
                    // Read the file into a byte array
                    if(file.exists())
                    {
                        m_Patch =  getBytes(file);
                        m_PatchSize = (int) file.length();
                        m_crc32 = 0xffffffff;
                        for (byte b : m_Patch) {
                            m_crc32 = (m_crc32 >>> 8) ^ crc32_table[(m_crc32 ^ b) & 0xff];
                        }
                        // flip bits
                        m_crc32 = m_crc32 ^ 0xffffffff;

                        Log.d(TAG, "CRC32: " + m_crc32);
                    }

                }
            });

            filechooser.showDialog();
        }
        else if (v == mButtonOTAUpdate)
        {

            if(mButtonOTAUpdate.getText().toString().equalsIgnoreCase("Abort"))
            {
                // Send abort request
                m_state = WS_UPGRADE_STATE_ABORTED;
                SendWsUpgradeCommand(WICED_OTA_UPGRADE_COMMAND_ABORT);
            }
            else
            {
                // Initiate the OTA Update procedure
                m_state = WS_UPGRADE_STATE_IDLE;
                ProcessEvent(WS_UPGRADE_CONNECTED);

                m_time = Calendar.getInstance().getTimeInMillis();
            }
        }
        else if (v == mButtonConnect) {
            // Start device connection
            connect();
        } else if (v == mButtonDisconnect) {
            // Start device disconnect
            disconnect();
        }
    }

    /**
     * Called when the ota input is selected by user
     *
     * @param view
     * @param view2
     * @param pos
     * @param id
     */
    @Override
    public void onItemSelected(AdapterView<?> view, View view2, int pos, long id) {
        //if (view == mSpinnerOTAInput)
        {
            // Update the input characteristic on the device
           // writeOTAInputCharacteristic();
        }
    }

    /**
     * Called when no ota input is selected
     */
    @Override
    public void onNothingSelected(AdapterView<?> view) {
    }

    /**
     * Callback invoked when a device was picked from the device picker
     *
     * @param device
     */
    @Override
    public void onDevicePicked(BluetoothDevice device) {
        Log.d(TAG, "onDevicePicked: " + device == null ? "" : device.getAddress());
        // Close any outstanding connections to remote devices
        closeDevice();

        // Get the remote device object
        String address = device.getAddress();
        mPickedDevice = mBtAdapter.getRemoteDevice(address);

        // Get the name
        String name = mPickedDevice.getName();
        OTADevName = name;
        if (name == null || name.isEmpty()) {
            name = address;
        }

        // Set UI resources
        mTextDeviceName.setText(name);
        mTextDeviceAddress.setText(address);
        // Update the connect widget
        mButtonConnect.setEnabled(true);
        mButtonDisconnect.setEnabled(true);


    }

    /**
     * Callback invoked when a devicepicker was dismissed without a device
     * picked
     */
    @Override
    public void onDevicePickError() {
        Log.d(TAG, "onDevicePickError");
    }

    /**
     * Callback invoked when a devicepicker encountered an unexpected error
     */
    @Override
    public void onDevicePickCancelled() {
        Log.d(TAG, "onDevicePickCancelled");
    }

    /**
     * Connect to the picked device
     */
    private void connect() {
        if (mPickedDevice == null) {
            showMessage(getString(R.string.error_connect, mPickedDevice.getName(),
                    mPickedDevice.getAddress()));
            return;
        }

        mPickedDeviceGatt = mPickedDevice.connectGatt(this, false, mGattCallback);

        if (mPickedDeviceGatt == null) {
            showMessage(getString(R.string.error_connect, mPickedDevice.getName(),
                    mPickedDevice.getAddress()));
        }
    }

    /**
     * Disconnects the picked device
     */
    private void disconnect() {
        if (mPickedDeviceGatt != null) {
            mPickedDeviceGatt.disconnect();
        }
    }

    /**
     * Called when a gatt connection state changes. This function updates the UI
     *
     * @param
     */
    private void processConnectionStateChanged(final boolean isConnected, final boolean hasError) {
        runOnUiThread(new Runnable() {

            @Override
            public void run() {
            if (hasError) {
                showMessage(getString(R.string.error_connect, mPickedDevice.getName(),
                            mPickedDevice.getAddress()));
            }
            mPickedDeviceIsConnected = isConnected;

            updateWidgets();

            // Refresh the device information
            if (mPickedDeviceIsConnected) {
                mSyncNotificationSetting = true;
                //readEverything();

                m_state = WS_UPGRADE_STATE_IDLE;
                if(OTAUpgradeTestRun && (OTACount <= OTAMaxCount)){
                    OTAVerified = false;
                    OTACount++;
                    startUpdate();
                }
            }
            }
        });
    }

    private void startUpdate() {
        showMessage("startUpdate :  " +OTAUpgradeTestRun);

            mRequestQueue.clear();

            File sdcard = Environment.getExternalStorageDirectory();
            //Get the text file
          //  File file = new File(sdcard,"OTA.bin");
            File file = OTAFile;

            showMessage("file selected " + file.getAbsolutePath() + file.getName());

            Log.d(TAG,"file selected "+ file.getAbsolutePath()+" length :"+ getBytes(file).length);
            mTextOTAImageName.setText(file.getAbsolutePath());
            // Read the file into a byte array
            if(file.exists())
            {
                m_Patch =  getBytes(file);
                m_PatchSize = (int) file.length();
                m_crc32 = 0xffffffff;
                for (byte b : m_Patch) {
                    m_crc32 = (m_crc32 >>> 8) ^ crc32_table[(m_crc32 ^ b) & 0xff];
                }
                // flip bits
                m_crc32 = m_crc32 ^ 0xffffffff;

                Log.d(TAG, "CRC32: " + m_crc32);
                Log.d(TAG, "ProcessEvent state --------- WS_UPGRADE_STATE_IDLE" + m_state);
                // Initiate the OTA Update procedure
                m_state = WS_UPGRADE_STATE_IDLE;
                ProcessEvent(WS_UPGRADE_CONNECTED);

                m_time = Calendar.getInstance().getTimeInMillis();
                //OTAUpgradeTestRun = false;
                //showMessage("OTAUpgradeTestRun make it false :  " +OTAUpgradeTestRun);
            }


    }

    /**
     * Reads the device info characteristics and updates the UI components
     */
    private void readDeviceInfoCharacteristics() {
        // Get all readable characteristics and descriptors of interest and add
        // request to a request queue

        BluetoothGattCharacteristic characteristic = null;

        // Get model number
        characteristic = GattUtils.getCharacteristic(mPickedDeviceGatt,
                Constants.DEVICE_INFO_SERVICE_UUID, Constants.MODEL_NUMBER_UUID);
        mRequestQueue.addReadCharacteristic(mPickedDeviceGatt, characteristic);

        // Get manufacturer name
        characteristic = GattUtils.getCharacteristic(mPickedDeviceGatt,
                Constants.DEVICE_INFO_SERVICE_UUID, Constants.MANUFACTURER_NAME_UUID);
        mRequestQueue.addReadCharacteristic(mPickedDeviceGatt, characteristic);

        // Get system Id
        characteristic = GattUtils.getCharacteristic(mPickedDeviceGatt,
                Constants.DEVICE_INFO_SERVICE_UUID, Constants.SYSTEM_ID_UUID);
        mRequestQueue.addReadCharacteristic(mPickedDeviceGatt, characteristic);
        mRequestQueue.execute();
    }

    /**
     * Reads the battery characteristics and updates the UI components
     */
    private void readBatteryCharacteristic() {
        // Get all readable characteristics and descriptors of interest and add
        // request to a request queue

        BluetoothGattCharacteristic characteristic = null;
        // Get battery level
        characteristic = GattUtils.getCharacteristic(mPickedDeviceGatt,
                Constants.BATTERY_SERVICE_UUID, Constants.BATTERY_LEVEL_UUID);
        mRequestQueue.addReadCharacteristic(mPickedDeviceGatt, characteristic);
        mRequestQueue.execute();
    }

    /**
     * Reads the ota input characteristic and updates the UI components
     */
    private void readOTAInputCharacteristic() {
        // Get all readable characteristics and descriptors of interest and add
        // request to a request queue
        BluetoothGattDescriptor descriptor = null;

        // Get client config descriptor: enable/disable notification
        descriptor = GattUtils.getDescriptor(mPickedDeviceGatt,
                mSecureService ? Constants.SECURE_UPGRADE_SERVICE_UUID : Constants.UPGRADE_SERVICE_UUID,
                Constants.UPGRADE_CHARACTERISTIC_CONTROL_POINT_UUID, Constants.CLIENT_CONFIG_DESCRIPTOR_UUID);
        mRequestQueue.addReadDescriptor(mPickedDeviceGatt, descriptor);
        mRequestQueue.execute();
    }

    /**
     * Reads the manufacturer name, model number, system id, battery level from
     * the device and updates the UI
     */
    private void readOTAConfigurationCharacteristic() {
        BluetoothGattCharacteristic characteristic = null;
        characteristic = GattUtils.getCharacteristic(mPickedDeviceGatt,
                mSecureService ? Constants.SECURE_UPGRADE_SERVICE_UUID : Constants.UPGRADE_SERVICE_UUID,
                Constants.UPGRADE_CHARACTERISTIC_CONTROL_POINT_UUID);
        mRequestQueue.addReadCharacteristic(mPickedDeviceGatt, characteristic);
        mRequestQueue.execute();
    }

    /**
     * Read every characteristic on the device
     */
    private void readEverything() {
        readDeviceInfoCharacteristics();
        readBatteryCharacteristic();
        readOTAConfigurationCharacteristic();
        readOTAInputCharacteristic();
    }

    /**
     * Write the ota configuration characteristic to the device
     */
    private void writeOTAControlPointCharacteristic(byte[] charValue) {
        BluetoothGattCharacteristic characteristic = null;
        Log.d(TAG, "writeOTAControlPointCharacteristic");
        String s = new String(serial_gatt_dump_hex_string(charValue));
        Log.d(TAG, "writeOTAControlPointCharacteristic value " + s);

        try {
            characteristic = GattUtils.getCharacteristic(mPickedDeviceGatt,
                    mSecureService ? Constants.SECURE_UPGRADE_SERVICE_UUID : Constants.UPGRADE_SERVICE_UUID,
                    Constants.UPGRADE_CHARACTERISTIC_CONTROL_POINT_UUID);
            mRequestQueue.addWriteCharacteristic(mPickedDeviceGatt, characteristic, charValue);
            mRequestQueue.execute();
        } catch (Throwable t) {
            Log.w(TAG, "Error Writing CP Characteristic");
            mLabelOTAStatus.setText("Error Writing CP Characteristic");
        }
    }

    /**
     * Write the ota configuration characteristic to the device
     */
    private void writeOTAControlDataCharacteristic(byte[] charValue) {
        BluetoothGattCharacteristic characteristic = null;
        //Log.d(TAG, "writeOTAControlDataCharacteristic");
        String s = new String(serial_gatt_dump_hex_string(charValue));
        Log.d(TAG, "writeOTAControlDataCharacteristic value " + s);

        try {
            characteristic = GattUtils.getCharacteristic(mPickedDeviceGatt,
                    mSecureService ? Constants.SECURE_UPGRADE_SERVICE_UUID : Constants.UPGRADE_SERVICE_UUID,
                    Constants.UPGRADE_CHARACTERISTIC_DATA_UUID);
            mRequestQueue.addWriteCharacteristic(mPickedDeviceGatt, characteristic, charValue);
            mRequestQueue.execute();
        } catch (Throwable t) {
            Log.w(TAG, "Error Writing CP Data characteristic");
            mLabelOTAStatus.setText("Error Writing CP Data characteristic");
        }
    }


    /**
     * Write the ota input descriptor to the device
     */
    private void RegisterOTANotification(boolean notify) {
        // Set the enable/disable notification settings
        BluetoothGattCharacteristic notifyCharacteristic = GattUtils.getCharacteristic(
                mPickedDeviceGatt,
                mSecureService ? Constants.SECURE_UPGRADE_SERVICE_UUID : Constants.UPGRADE_SERVICE_UUID,
                Constants.UPGRADE_CHARACTERISTIC_CONTROL_POINT_UUID);
        if(notifyCharacteristic == null) {
            Log.d(TAG, "notifyCharacteristic value is null");
            showMessage("OTA upgrade service not found");
            return;
        }

        BluetoothGattDescriptor descriptor = GattUtils.getDescriptor(mPickedDeviceGatt,
                mSecureService ? Constants.SECURE_UPGRADE_SERVICE_UUID : Constants.UPGRADE_SERVICE_UUID,
                Constants.UPGRADE_CHARACTERISTIC_CONTROL_POINT_UUID,
                Constants.CLIENT_CONFIG_DESCRIPTOR_UUID);
        Log.d(TAG, "descriptor is null");

        byte[] value =  new byte[2];
        if (notify == true) {
            mPickedDeviceGatt.setCharacteristicNotification(notifyCharacteristic, true);
            value[0] = 0x3;
            value[1] = 0x0;
        } else {
            mPickedDeviceGatt.setCharacteristicNotification(notifyCharacteristic, false);
            value[0] = 0x0;
            value[1] = 0x0;
        }
        Log.d(TAG, "addWriteDescriptor");
        mRequestQueue.addWriteDescriptor(mPickedDeviceGatt, descriptor, value);
        mRequestQueue.execute();

    }

    /**
     * Callback invoked by the Android framework when a read characteristic
     * successfully completes
     *
     * @param characteristic
     */
    private void processCharacteristicRead(final BluetoothGattCharacteristic characteristic) {
        runOnUiThread(new Runnable() {

            @Override
            public void run() {

            }
        });
    }

    /**
     * Callback invoked by the Android framework when a read descriptor
     * successfully completes
     *
     * @param descriptor
     */
    private void processDescriptorRead(final BluetoothGatt gatt, final BluetoothGattDescriptor descriptor) {
        runOnUiThread(new Runnable() {

            @Override
            public void run() {
            }
        });
    }

    /**
     * Callback invoked by the Android framework when a write descriptor
     * successfully completes
     *
     * @param descriptor
     */
    private void processDescriptorWrite(final BluetoothGatt gatt, final BluetoothGattDescriptor descriptor) {
        runOnUiThread(new Runnable() {

            @Override
            public void run() {
            }
        });
    }

    /**
     * Callback invoked by the Android framework when a write characteristic
     * successfully completes
     *
     * @param characteristic
     */
    private void processCharacteristicWrite(final BluetoothGattCharacteristic characteristic) {
        runOnUiThread(new Runnable() {

            @Override
            public void run() {

                UpdateProgress();
                // Continue if there is data to be sent
                if(m_bInTransfer)
                    SendOTAImageData();
            }
        });
    }


    void ProcessProgress(int state)
    {
        int total = m_PatchSize;
        int param = 0;

        if (state == WS_UPGRADE_STATE_WAIT_FOR_READY_FOR_DOWNLOAD)
        {
            Log.d(TAG, "ProcessProgress Ready For Download");
            total = m_PatchSize;
            mLabelOTAStatus.setText("Transfer");
            mButtonOTAUpdate.setText("Abort");
        }
        else if (state == WS_UPGRADE_STATE_DATA_TRANSFER)
        {
            param = m_offset;
            String status = "ProcessProgress offset: "  + m_offset + " of total: " + m_PatchSize;
            Log.d(TAG, status);
            mLabelOTAStatus.setText(status);

            if (param == total)
            {
                Log.d(TAG, "ProcessProgress - Sent Entire file param: "  + param + " total: " + total);
                runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                        ProcessEvent(WS_UPGRADE_START_VERIFICATION);
                    }
                });

                mLabelOTAStatus.setText("Download Verification");
            }
        }
        else if (state == WS_UPGRADE_STATE_VERIFIED)
        {
            Log.d(TAG, "ProcessProgress verified");
            OTAVerified = true;
            long elapsed_time = Calendar.getInstance().getTimeInMillis() - m_time;
            String status = "Success " + (elapsed_time / 1000) + "sec (" + (m_PatchSize * 8 * 1000 / elapsed_time) + "kbps)";
            mLabelOTAStatus.setText(status);
            mButtonOTAUpdate.setText("Update");

        }
        else if (state == WS_UPGRADE_STATE_ABORTED)
        {
            Log.d(TAG, "ProcessProgress Aborted");
            mLabelOTAStatus.setText("Aborted");
            mButtonOTAUpdate.setText("Update");
        }
    }


    /**TEST**/
    private BluetoothAdapter mBluetoothAdapter = null;

    private void continueOTAUpgrade() {
        BluetoothManager bluetoothManager = (BluetoothManager)getSystemService(Context.BLUETOOTH_SERVICE);
        mBluetoothAdapter = bluetoothManager.getAdapter();
        if (mBluetoothAdapter == null)
            return;
        mBluetoothAdapter.startLeScan(callback);
    }

    BluetoothAdapter.LeScanCallback callback = new BluetoothAdapter.LeScanCallback() {
        @Override
        public void onLeScan(BluetoothDevice device, int rssi, byte[] scanRecord) {

            BluetoothDevice newdev = mBluetoothAdapter.getRemoteDevice(device.getAddress());

              if(newdev != null && newdev.getName() != null) {

                  Log.d(TAG,"NAME ************* : "+newdev.getName()+ "scan rec : "+scanRecord.toString());
                  if(newdev.getName().equals(OTADevName)) {
                      mBluetoothAdapter.stopLeScan(callback);
                      mPickedDevice = newdev;
                      connect();
                  }

              }
        }
    };
    /**TEST**/

    void SendOTAImageData()
    {
        String status = "SendOTAImageData file param: "  + m_offset + " sent of total: " + m_PatchSize;
        Log.d(TAG, status);

        if ((m_PatchSize > m_offset) && (m_state != WS_UPGRADE_STATE_ABORTED) && m_bInTransfer)
        {
            int dwBytes = m_PatchSize - m_offset;

            int mtu = mtuUsed - 3;

            dwBytes = (dwBytes > mtu) ? mtu : dwBytes;

            byte[] value = new byte[dwBytes];
            for (int i = 0; i < dwBytes; i++) {
                value[i] = m_Patch[m_offset + i];
            }

            // If this is the last packet finalize CRC
            if ((m_offset + dwBytes) == m_PatchSize)
            {
                m_bInTransfer = false;
            }

            writeOTAControlDataCharacteristic(value);

            m_offset += dwBytes;

        }
        if (m_state == WS_UPGRADE_STATE_ABORTED)
        {
            SendWsUpgradeCommand(WICED_OTA_UPGRADE_COMMAND_ABORT);
        }
        return;
    }

    void SendWsUpgradeCommand(int command)
    {
        byte[] buffer =  new byte[1];
        buffer[0] = (byte) command;
        writeOTAControlPointCharacteristic(buffer);
    }

    void SendWsUpgradeCommand(int command, int value)
    {
        byte[] buffer =  new byte[5];
        buffer[0] = (byte) command;
        buffer[1] = (byte) (value & 0xff);
        buffer[2] = (byte) ((value >> 8) & 0xff);
        buffer[3] = (byte) ((value >> 16) & 0xff);
        buffer[4] = (byte) ((value >> 24) & 0xff);
        writeOTAControlPointCharacteristic(buffer);
    }

    void UpdateProgress()
    {
        ProcessProgress(m_state);
    }
    void ProcessEvent(int Event)
    {
        Log.d(TAG, "ProcessEvent state : " + m_state + " Event: " + Event);

        switch (m_state)
        {
            case WS_UPGRADE_STATE_IDLE:
                m_bConnected = true;
                if (Event == WS_UPGRADE_CONNECTED)
                {
                    if(m_PatchSize <= 0 || m_Patch == null)
                    {
                        mLabelOTAStatus.setText("Invalid Image File");
                        return;
                    }
                    // register for notifications and indications with the status
                    RegisterOTANotification(true);
                    SendWsUpgradeCommand(WICED_OTA_UPGRADE_COMMAND_PREPARE_DOWNLOAD);

                    m_state = WS_UPGRADE_STATE_WAIT_FOR_READY_FOR_DOWNLOAD;
                    Log.d(TAG, "ProcessEvent state --------- ready for download" + m_state);
                    //PostMessage(m_hWnd, WM_PROGRESS, (WPARAM)WS_UPGRADE_STATE_WAIT_FOR_READY_FOR_DOWNLOAD, (LPARAM)m_PatchSize);
                    UpdateProgress();
                }
                break;

            case WS_UPGRADE_STATE_WAIT_FOR_READY_FOR_DOWNLOAD:
                if (Event == WS_UPGRADE_RESPONSE_OK)
                {
                    m_offset = 0;

                    m_state = WS_UPGRADE_STATE_DATA_TRANSFER;
                    Log.d(TAG, "ProcessEvent state --------- WS_UPGRADE_STATE_DATA_TRANSFER" + m_state);
                   SendWsUpgradeCommand(WICED_OTA_UPGRADE_COMMAND_DOWNLOAD, (int)m_PatchSize);
                }
                break;

            case WS_UPGRADE_STATE_DATA_TRANSFER:
                if (Event == WS_UPGRADE_RESPONSE_OK)
                {
                    // Create thread reading unsolicited events
//                    CreateThread( NULL, 0, SendOTAImageData, this, 0, NULL);
//                    new Thread(new Runnable() {
//                        public void run() {
//                            m_offset = 0;
//                            m_bInTransfer = true;
//                            SendOTAImageData();
//                        }
//                    }).start();

                    if(m_bInTransfer == false) {
                        runOnUiThread(new Runnable() {

                            @Override
                            public void run() {
                                m_offset = 0;
                                m_bInTransfer = true;
                                SendOTAImageData();
                            }
                        });
                    }
                }
                else if (Event == WS_UPGRADE_CONTINUE)
                {
                }
                else if (Event == WS_UPGRADE_START_VERIFICATION)
                {
                    m_state = WS_UPGRADE_STATE_VERIFICATION;
                    SendWsUpgradeCommand(WICED_OTA_UPGRADE_COMMAND_VERIFY, m_crc32);
                }
                else if (Event == WS_UPGRADE_ABORT)
                {
                    m_state = WS_UPGRADE_STATE_ABORTED;
                    Log.d(TAG, "ProcessEvent state : " + WS_UPGRADE_STATE_DATA_TRANSFER + " Event: " + WS_UPGRADE_ABORT);

                }
                break;

            case WS_UPGRADE_STATE_VERIFICATION:
                if (Event == WS_UPGRADE_RESPONSE_OK)
                {
                    Log.d(TAG, "ProcessEvent state : " + WS_UPGRADE_STATE_VERIFICATION + " Event: " + WS_UPGRADE_RESPONSE_OK);
                    m_state = WS_UPGRADE_STATE_VERIFIED;
                    UpdateProgress();
                }
                else if (Event == WS_UPGRADE_RESPONSE_FAILED)
                {
                    Log.d(TAG, "ProcessEvent state : " + WS_UPGRADE_STATE_VERIFICATION + " Event: " + WS_UPGRADE_RESPONSE_FAILED);
                    m_state = WS_UPGRADE_STATE_ABORTED;
                    UpdateProgress();
                }
                break;

            case WS_UPGRADE_STATE_ABORTED:
                if (Event == WS_UPGRADE_RESPONSE_OK)
                {
                    Log.d(TAG, "ProcessEvent state : " + WS_UPGRADE_STATE_ABORTED + " Event: " + WS_UPGRADE_RESPONSE_OK);
                    UpdateProgress();
                }
                break;

            default:
                break;
        }
    }


    void ota_gatt_client_process_notification(short conn_id, byte[] p_data, short len)
    {
        // parse data received from the peer
        int upstate = p_data[0];

        if (len == 1)
        {
            switch (upstate)
            {
                case WICED_OTA_UPGRADE_STATUS_OK:
                    ProcessEvent(WS_UPGRADE_RESPONSE_OK);
                    break;
                case WICED_OTA_UPGRADE_STATUS_CONTINUE:
                    ProcessEvent(WS_UPGRADE_CONTINUE);
                    break;
                default:
                    ProcessEvent(WS_UPGRADE_RESPONSE_FAILED);
                    break;
            }
        }

    }

    /**
     * Callback invoked by the Android framework when a characteristic
     * notification is received
     *
     * @param characteristic
     */
    private void processCharacteristicNotification(final BluetoothGattCharacteristic characteristic) {
        runOnUiThread(new Runnable() {

            @Override
            public void run() {
                String s = characteristic.getStringValue(0);
                byte[] val = characteristic.getValue();
                byte[] data;
                short len = (short) val.length;
                short conn_id = 1;
                ota_gatt_client_process_notification(conn_id, val, len);
            }
        });
    }


    public void show(final String text,final int duration) {
        runOnUiThread(new Runnable() {

            public void run() {
                if (mToast == null || !mToast.getView().isShown()) {
                    if (mToast != null) {
                        mToast.cancel();
                    }
                }
                // if (mToast != null) mToast.cancel();
                mToast = Toast.makeText(getApplicationContext(), text, duration);
                mToast.show();
            }
        });

    }


}
