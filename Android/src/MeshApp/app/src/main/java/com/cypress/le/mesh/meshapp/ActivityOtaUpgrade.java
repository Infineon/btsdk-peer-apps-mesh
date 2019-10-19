/*
 *
 *  * Copyright 2019, Cypress Semiconductor Corporation or a subsidiary of
 *  * Cypress Semiconductor Corporation. All Rights Reserved.
 *  *
 *  * This software, including source code, documentation and related
 *  * materials ("Software"), is owned by Cypress Semiconductor Corporation
 *  * or one of its subsidiaries ("Cypress") and is protected by and subject to
 *  * worldwide patent protection (United States and foreign),
 *  * United States copyright laws and international treaty provisions.
 *  * Therefore, you may use this Software only as provided in the license
 *  * agreement accompanying the software package from which you
 *  * obtained this Software ("EULA").
 *  * If no EULA applies, Cypress hereby grants you a personal, non-exclusive,
 *  * non-transferable license to copy, modify, and compile the Software
 *  * source code solely for use in connection with Cypress's
 *  * integrated circuit products. Any reproduction, modification, translation,
 *  * compilation, or representation of this Software except as specified
 *  * above is prohibited without the express written permission of Cypress.
 *  *
 *  * Disclaimer: THIS SOFTWARE IS PROVIDED AS-IS, WITH NO WARRANTY OF ANY KIND,
 *  * EXPRESS OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, NONINFRINGEMENT, IMPLIED
 *  * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. Cypress
 *  * reserves the right to make changes to the Software without notice. Cypress
 *  * does not assume any liability arising out of the application or use of the
 *  * Software or any product or circuit described in the Software. Cypress does
 *  * not authorize its products for use in any products where a malfunction or
 *  * failure of the Cypress product may reasonably be expected to result in
 *  * significant property damage, injury or death ("High Risk Product"). By
 *  * including Cypress's product in a High Risk Product, the manufacturer
 *  * of such system or application assumes all risk of such use and in doing
 *  * so agrees to indemnify Cypress against all liability.
 *
 */
package com.cypress.le.mesh.meshapp;

import android.app.AlertDialog;
import android.content.ComponentName;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.ServiceConnection;
import android.os.Bundle;
import android.os.Handler;
import android.os.IBinder;
import android.os.Message;
import android.support.v7.app.AppCompatActivity;
import android.util.Log;
import android.view.Menu;
import android.view.MenuItem;
import android.view.MotionEvent;
import android.view.View;
import android.widget.AdapterView;
import android.widget.ImageButton;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.Toast;

import com.cypress.le.mesh.meshapp.leotaapp.FileChooser;
import com.cypress.le.mesh.meshframework.IMeshControllerCallback;
import com.cypress.le.mesh.meshframework.MeshController;

import java.io.File;
import java.util.UUID;

public class ActivityOtaUpgrade extends AppCompatActivity implements LightingService.IServiceCallback{

    private static final int DISTRIBUTION_STATUS_TIMEOUT    = 10000;
    private static final int DISTRIBUTION_ACTION_START      = 1;
    private static final int DISTRIBUTION_ACTION_STOP       = 2;
    private static final int DISTRIBUTION_ACTION_APPLY      = 3;
    private static final int DISTRIBUTION_ACTION_GET_STATUS = 4;

    private static final int DFU_STATE_IDLE                 = 0;
    private static final int DFU_STATE_UPLOADING            = 1;       // Initiator -> Distributor
    private static final int DFU_STATE_UPDATING             = 2;       // Distributor -> Updating Node
    private static final int DFU_STATE_COMPLETED            = 3;
    private static final String TAG = "ActivityModel";

    private static final int WICED_BT_MESH_FW_DISTR_PHASE_IDLE                   =0x00; // Distribution is not active.
    private static final int WICED_BT_MESH_FW_DISTR_PHASE_TRANSFER_ACTIVE        =0x01; // Firmware transfer in progress.
    private static final int WICED_BT_MESH_FW_DISTR_PHASE_TRANSFER_SUCCESS       =0x02; //Firmware transfer is complete and Updating Nodes verified the firmware successfully.
    private static final int WICED_BT_MESH_FW_DISTR_PHASE_APPLY_ACTIVE           =0x03; // Firmware applying in progress.
    private static final int WICED_BT_MESH_FW_DISTR_PHASE_COMPLETED              =0x04; // At least one Updating Node was updated successfully.
    private static final int WICED_BT_MESH_FW_DISTR_PHASE_FAILED                 =0x05; // No Updating Nodes were updated successfully.

    LightingService serviceReference = null;
    int mDfuState;
    int mDfuAction;

    String mGroupName, name, type = null;
    ImageButton startOta, fwFileAttach, metadataFileAttach, apply, status, stopUpgrade;
    TextView path, metapath, progress, dfuStatusTxt;
    Spinner dfuType;
    String mFileName = null;
    String mMetaFileName = null;
    byte mDfuMethod = (byte)0;

    private static Toast mToast = null;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.ota_upgrade);
        mDfuState = DFU_STATE_IDLE;
        Intent intent = new Intent(ActivityOtaUpgrade.this, LightingService.class);
        bindService(intent, mConnection, Context.BIND_AUTO_CREATE);

        Bundle extras = getIntent().getExtras();
        if (extras != null) {
            Log.d(TAG, "Extras is not null");
            type = extras.getString("groupType");
            name = extras.getString("name");
            mGroupName = extras.getString("GroupName");
            Log.d(TAG, "type =" + type + " name=" + name);
        } else {
            Log.d(TAG, "Extras is null");
        }

        startOta = (ImageButton) findViewById(R.id.startOta);
        dfuStatusTxt = (TextView)findViewById(R.id.dfustatus);
        stopUpgrade = (ImageButton)findViewById(R.id.stop_upgrade);
        status = (ImageButton) findViewById(R.id.getinfo);
        apply = (ImageButton) findViewById(R.id.apply);

        fwFileAttach = (ImageButton) findViewById(R.id.attach_fw);
        metadataFileAttach = (ImageButton) findViewById(R.id.attach_metadata);

        metapath = (TextView) findViewById(R.id.meta_path);
        path = (TextView) findViewById(R.id.path);
        progress = (TextView) findViewById(R.id.progress);
        dfuType = (Spinner) findViewById(R.id.dfu_type);

/*
        if(!WICED_MESH_DFU_ENABLED) {
            metadataFileAttach.setEnabled(false);
            metapath.setText("DFU NOT SUPPORTED");
            dfuType.setSelection(3);
            apply.setEnabled(false);
            status.setEnabled(false);
            status.setAlpha((float) 0.3);
            apply.setAlpha((float)0.3);
            metadataFileAttach.setAlpha((float)0.3);
            dfuType.setEnabled(false);
            dfuType.setAlpha((float)0.5);
            mDfuMethod = MeshController.DFU_METHOD_APP_TO_DEVICE;
        } else {
            dfuType.setSelection(0);
            mDfuMethod = MeshController.DFU_METHOD_PROXY_TO_ALL;
        }
*/
        dfuType.setSelection(0);
        mDfuMethod = MeshController.DFU_METHOD_PROXY_TO_ALL;

        dfuType.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {
            @Override
            public void onItemSelected(AdapterView<?> adapterView, View view, int i, long l) {
                mDfuMethod = (byte) i;
                Log.d(TAG, "DFU Method"+i);

            }

            @Override
            public void onNothingSelected(AdapterView<?> adapterView) {

            }
        });

        startOta.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                Log.d(TAG, "OTaUpgrade");
                AlertDialog alertDialog = new AlertDialog.Builder(ActivityOtaUpgrade.this).create();
                alertDialog.setTitle("OTA upgrade");
                alertDialog.setMessage("\nStart OTA Upgrade ? \n\nFile selected :\n \n" + mFileName);
                alertDialog.setButton(AlertDialog.BUTTON_POSITIVE, "OK",
                        new DialogInterface.OnClickListener() {
                            public void onClick(DialogInterface dialog, int which) {
                                if (mDfuState != DFU_STATE_IDLE)
                                {
                                    Log.d(TAG,"DFU is already started!");
                                    return;
                                }

                                if (mFileName != null) {
                                    mDfuAction = DISTRIBUTION_ACTION_START;
                                    serviceReference.setOtaUpgradeNode(name);
                                    ConnectDfuDistributor();
                                } else {
                                    show("Please fwFileAttach OTA file to upgrade", Toast.LENGTH_SHORT);
                                }

                                dialog.dismiss();
                            }
                        });
                alertDialog.setButton(AlertDialog.BUTTON_NEGATIVE, "CANCEL",
                        new DialogInterface.OnClickListener() {
                            public void onClick(DialogInterface dialog, int which) {
                                dialog.dismiss();
                            }
                        });
                alertDialog.show();

            }
        });

        apply.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                Log.d(TAG, "Apply !");
                AlertDialog alertDialog = new AlertDialog.Builder(ActivityOtaUpgrade.this).create();
                alertDialog.setTitle("Apply!");
                alertDialog.setMessage("\nDo you want to upgrade the device?");
                alertDialog.setButton(AlertDialog.BUTTON_POSITIVE, "OK",
                        new DialogInterface.OnClickListener() {
                            public void onClick(DialogInterface dialog, int which) {
                                dialog.dismiss();
//                                Log.d(TAG, "DISTRIBUTION_ACTION_APPLY"+ mDfuState);
////                                if (mDfuState != DFU_STATE_COMPLETED)
////                                    return;
//                                mDfuAction = DISTRIBUTION_ACTION_APPLY;
//                                ConnectDfuDistributor();
                            }
                        });
                alertDialog.setButton(AlertDialog.BUTTON_NEGATIVE, "CANCEL",
                        new DialogInterface.OnClickListener() {
                            public void onClick(DialogInterface dialog, int which) {
                                dialog.dismiss();
                            }
                        });
                alertDialog.show();
            }
        });
        stopUpgrade.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                Log.d(TAG, "stopUpgrade !");
                AlertDialog alertDialog = new AlertDialog.Builder(ActivityOtaUpgrade.this).create();
                alertDialog.setTitle("Stop Upgrade!");
                alertDialog.setMessage("\nDo you want to stop upgrading all devices?");
                alertDialog.setButton(AlertDialog.BUTTON_POSITIVE, "OK",
                        new DialogInterface.OnClickListener() {
                            public void onClick(DialogInterface dialog, int which) {
                                dialog.dismiss();
                                serviceReference.getMesh().stopOtaUpgrade();
                                mStatusHandler.removeMessages(DISTRIBUTION_ACTION_GET_STATUS);
                            }
                        });
                alertDialog.setButton(AlertDialog.BUTTON_NEGATIVE, "CANCEL",
                        new DialogInterface.OnClickListener() {
                            public void onClick(DialogInterface dialog, int which) {
                                dialog.dismiss();
                            }
                        });
                alertDialog.show();
            }
        });

        fwFileAttach.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                // Choose OTA Image file from the local storage
                FileChooser filechooser = new FileChooser(ActivityOtaUpgrade.this);
                filechooser.setFileListener(new FileChooser.FileSelectedListener() {
                    @Override
                    public void fileSelected(final File file) {
                        show("file selected " + file.getAbsolutePath(),Toast.LENGTH_SHORT );

                        path.setText(file.getAbsolutePath());
                        mFileName = file.getAbsolutePath();
                        // Read the file into a byte array
                        if(!file.exists())
                        {
                            show("file selected doesn't exist!!!", Toast.LENGTH_SHORT);
                        }
                    }
                });

                filechooser.showDialog();
            }
        });

        metadataFileAttach.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                // Choose OTA Image file from the local storage
                FileChooser filechooser = new FileChooser(ActivityOtaUpgrade.this);
                filechooser.setFileListener(new FileChooser.FileSelectedListener() {
                    @Override
                    public void fileSelected(final File file) {
                        show("file selected " + file.getAbsolutePath(),Toast.LENGTH_SHORT );

                        metapath.setText(file.getAbsolutePath());
                        mMetaFileName = file.getAbsolutePath();
                        // Read the file into a byte array
                        if(!file.exists())
                        {
                            show("file selected doesn't exist!!!", Toast.LENGTH_SHORT);
                        }
                    }
                });

                filechooser.showDialog();
            }
        });

        status.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                Log.d(TAG,"dfu status");
                AlertDialog alertDialog = new AlertDialog.Builder(ActivityOtaUpgrade.this).create();
                alertDialog.setTitle("UpgradeStatus");
                alertDialog.setMessage("\nGet DFU Upgrade Status ? \nStatus will be updated every 10 seconds");
                alertDialog.setButton(AlertDialog.BUTTON_POSITIVE, "OK",
                        new DialogInterface.OnClickListener() {
                            public void onClick(DialogInterface dialog, int which) {
                                mDfuAction = DISTRIBUTION_ACTION_GET_STATUS;
                                ConnectDfuDistributor();
                                dialog.dismiss();
                            }
                        });
                alertDialog.setButton(AlertDialog.BUTTON_NEGATIVE, "CANCEL",
                        new DialogInterface.OnClickListener() {
                            public void onClick(DialogInterface dialog, int which) {
                                dialog.dismiss();
                            }
                        });
                alertDialog.show();

            }
        });
    }

    private Handler mStatusHandler = new Handler() {
        @Override
        public void handleMessage(Message msg) {
            switch (msg.what) {
                case DISTRIBUTION_ACTION_GET_STATUS :
                    Log.d(TAG,"Get DFU status");
                    serviceReference.getMesh().setOTAFiles(mFileName, mMetaFileName);
                    serviceReference.getMesh().dfuGetStatus(name);
            };
        }
    };

    private void ConnectDfuDistributor() {
        serviceReference.getMesh().connectComponent(name, (byte) 100);
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

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        // Inflate the menu; this adds items to the action bar if it is present.
        getMenuInflater().inflate(R.menu.menu_light, menu);
        return true;
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        return super.onOptionsItemSelected(item);
    }

    @Override
    public boolean dispatchTouchEvent(MotionEvent ev) {
        try {
            return super.dispatchTouchEvent(ev);
        } catch (Exception e) {
            return false;
        }
    }

    @Override
    protected void onDestroy() {
        unbindService(mConnection);
        super.onDestroy();
    }

    private ServiceConnection mConnection= new ServiceConnection() {
        @Override
        public void onServiceConnected(ComponentName compname, IBinder service) {
            Log.d(TAG, "bound service connected");
            LightingService.MyBinder binder = (LightingService.MyBinder) service;
            serviceReference = binder.getService();
            serviceReference.registerCb(ActivityOtaUpgrade.this);

        }

        @Override
        public void onServiceDisconnected(ComponentName name) {
            serviceReference = null;
        }
    };

    @Override
    public void onMeshServiceStatusChangeCb(int status) {

    }

    @Override
    public void onDeviceFound(UUID uuid, String name) {

    }

    @Override
    public void onProvisionComplete(UUID device, byte status) {

    }

    @Override
    public void onHslStateChanged(String deviceName, final int lightness, int hue, int saturation) {
    }

    @Override
    public void onOnOffStateChanged(String deviceName, final byte onOff) {
        show("onOnOffStateChanged : "+onOff,Toast.LENGTH_SHORT);
    }

    @Override
    public void onLevelStateChanged(String deviceName, final short level) {
        show("onLevelStateChanged : "+level,
                Toast.LENGTH_SHORT);
    }

    @Override
    public void onNetworkConnectionStatusChanged(final byte transport, final byte status) {
        Log.d(TAG,"recieved onNetworkConnectionStatusChanged status = " +status);
        String text = null;
        if(status == IMeshControllerCallback.NETWORK_CONNECTION_STATE_CONNECTED)
            text = "Connected to network";
        if(status == IMeshControllerCallback.NETWORK_CONNECTION_STATE_DISCONNECTED)
            text = "Disconnected from network";
        if(text != null)
            show(text, Toast.LENGTH_SHORT);
        runOnUiThread(new Runnable() {

            public void run() {
                progress.setText("Device disconnected");
            }
        });
    }

    @Override
    public void onCtlStateChanged(String deviceName, int presentLightness, short presentTemperature, int targetLightness, short targetTemperature, int remainingTime) {

    }

    @Override
    public void onNodeConnStateChanged(final byte status, final String componentName) {
        Log.d(TAG,"onNodeConnStateChanged in Model UI");

        if(status == IMeshControllerCallback.MESH_CLIENT_NODE_CONNECTED) {
            onNodeConnected();
        }
    }

    private void onNodeConnected() {
        if (mDfuAction == DISTRIBUTION_ACTION_START)
        {
            serviceReference.getMesh().setOTAFiles(mFileName, mMetaFileName);
            Log.d(TAG,"onNode connected start OTA upgrade");
            serviceReference.getMesh().startOtaUpgrade(name, mDfuMethod);
        }
        else if (mDfuAction == DISTRIBUTION_ACTION_STOP)
        {
            serviceReference.getMesh().stopOtaUpgrade();
        }
        else if (mDfuAction == DISTRIBUTION_ACTION_APPLY)
        {
            OnOtaUpgradeApply();
        }
        else if (mDfuAction == DISTRIBUTION_ACTION_GET_STATUS)
        {
            if (mMetaFileName == null)
                return;

            serviceReference.getMesh().dfuGetStatus(name);
        }
    }

    private void OnOtaUpgradeApply() {
        Log.d(TAG, "OnOtaUpgradeApply ");
        mDfuMethod = MeshController.DFU_METHOD_APPLY;
       serviceReference.getMesh().startOtaUpgrade(name, mDfuMethod);
    }

    @Override
    public void onOTAUpgradeStatus(byte status, final int percentComplete) {
        if((name != null) && (!name.equals(serviceReference.getOtaUpgradeNode()))) {
            Log.d(TAG, "onOTAUpgradeStatus not displaying status");
            return;
        }
        if(status == IMeshControllerCallback.OTA_UPGRADE_STATUS_IN_PROGRESS) {
          runOnUiThread(new Runnable() {

              public void run() {
                  progress.setText("OTA upgrade Percentage Complete : "+percentComplete);
              }
          });
      } else if(status == IMeshControllerCallback.OTA_UPGRADE_STATUS_COMPLETED) {
            mDfuState = DFU_STATE_COMPLETED;
            runOnUiThread(new Runnable() {

              public void run() {
                  progress.setText("OTA upgrade Success");
              }
          });

      }  else if(status == IMeshControllerCallback.OTA_UPGRADE_STATUS_CONNECTED) {
          runOnUiThread(new Runnable() {

              public void run() {
                  progress.setText("Device connected");
              }
          });

      } else if(status == IMeshControllerCallback.OTA_UPGRADE_STATUS_DISCONNECTED) {
          runOnUiThread(new Runnable() {

              public void run() {
                  progress.setText("Device disconnected");
              }
          });

      } else if(status == IMeshControllerCallback.OTA_UPGRADE_STATUS_SERVICE_NOT_FOUND) {
          runOnUiThread(new Runnable() {

              public void run() {
                  progress.setText("OTA Service is not found");
              }
          });
      } else if(status == IMeshControllerCallback.OTA_UPGRADE_STATUS_UPGRADE_TO_ALL_STARTED) {
            runOnUiThread(new Runnable() {

                public void run() {
                    progress.setText("Upgrade to all started!");
                }
            });
        }

    }

    @Override
    public void onNetworkOpenedCallback(byte status) {

    }

    @Override
    public void onComponentInfoStatus(byte status, String componentName, final String componentInfoStr) {

    }

    @Override
    public void onDfuStatus(byte status, byte progress) {
        Log.d(TAG,"onDfuStatus");
        int percent;
        String txt = dfuStatusTxt.getText().toString();

        switch(status){
            case WICED_BT_MESH_FW_DISTR_PHASE_IDLE:
                if (progress == 0)
                    txt = "\nDFU_IDLE.";
                else
                    txt = "\nDFU_UPLOADING: "+progress+"%";
                break;
            case WICED_BT_MESH_FW_DISTR_PHASE_TRANSFER_ACTIVE:
                txt = "\nDFU_UPDATING: "+progress+"%";
                break;
            case WICED_BT_MESH_FW_DISTR_PHASE_FAILED:
                txt = "\nDFU_FAILED.";
                break;
            case WICED_BT_MESH_FW_DISTR_PHASE_COMPLETED:
                txt = "\nDFU_COMPLETED.";
                break;
            default:
                break;
        }

        final String finalTxt = txt;
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                dfuStatusTxt.setText(finalTxt);
            }
        });
//        if(progress == 100)
//            mStatusHandler.removeMessages(DISTRIBUTION_ACTION_GET_STATUS);
        Message msg = new Message();
        msg.what = DISTRIBUTION_ACTION_GET_STATUS;
        mStatusHandler.sendMessageDelayed(msg, 10000);

        if(status == WICED_BT_MESH_FW_DISTR_PHASE_COMPLETED)
            mStatusHandler.removeMessages(DISTRIBUTION_ACTION_GET_STATUS);
    }

    @Override
    public void onSensorStatusCb(String componentName, int propertyId, byte[] data) {

    }

    @Override
    public void onVendorStatusCb(short src, short companyId, short modelId, byte opcode, byte[] data, short dataLen) {

    }

    @Override
    public void onLightnessStateChanged(String deviceName, int target, int present, int remainingTime) {

    }

    @Override
    public void onLightLcModeStatus(String componentName, int mode) {

    }

    @Override
    public void onLightLcOccupancyModeStatus(String componentName, int mode) {

    }

    @Override
    public void onLightLcPropertyStatus(String componentName, int propertyId, int value) {

    }
}
