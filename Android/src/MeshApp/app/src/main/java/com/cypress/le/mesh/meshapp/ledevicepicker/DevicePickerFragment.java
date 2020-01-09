/*
* Copyright 2017, Cypress Semiconductor Corporation or a subsidiary of Cypress Semiconductor
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
package com.cypress.le.mesh.meshapp.ledevicepicker;

import java.util.Collection;

import com.cypress.le.mesh.meshapp.R;
import com.cypress.le.mesh.meshapp.leotaapp.Constants;
import com.cypress.le.mesh.meshapp.ledevicepicker.DeviceListFragment.Callback;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.Dialog;
import android.app.DialogFragment;
import android.app.FragmentManager;
import android.bluetooth.BluetoothDevice;
import android.content.DialogInterface;
import android.os.Bundle;
import android.view.View;
import android.widget.Button;

/**
 * Wrapper fragment to wrap the Device Picker device list in a Fragment
 * @author fredc
 *
 */
public class DevicePickerFragment extends DialogFragment implements DeviceListFragment.Callback,
        android.view.View.OnClickListener {
    private static final String TAG = Constants.TAG_PREFIX + "DevicePickerFragment";

    public static DevicePickerFragment createDialog(Callback callback, String dialogTitle,
            boolean startScanning) {
        DevicePickerFragment f = new DevicePickerFragment();
        f.mTitle = dialogTitle;
        f.mCallback = callback;
        f.mStartScanning = startScanning;
        f.setStyle(DialogFragment.STYLE_NORMAL, R.style.DialogTheme);

        return f;
    }

    private String mTitle;
    private Callback mCallback;
    private Button mScanButton;
    private boolean mIsScanning;
    private boolean mStartScanning;
    private DeviceListFragment mDevicePickerFragment;

    private void setScanState(boolean isScanning) {
        if (isScanning) {
            mScanButton.setText(R.string.devicepicker_menu_stop);
        } else {
            mScanButton.setText(R.string.devicepicker_menu_scan);
        }
        mIsScanning = isScanning;

    }

    private void initDevicePickerFragment() {
        FragmentManager mgr = getFragmentManager();
        mDevicePickerFragment = (DeviceListFragment) mgr.findFragmentById(R.id.device_picker_id);
        mDevicePickerFragment.setCallback(this);

    }

    private void scan() {
        if (!mIsScanning) {
            setScanState(true);
            mDevicePickerFragment.scan(true);
        }
    }

    private void stopScan() {
        if (mIsScanning) {
            setScanState(false);
            mDevicePickerFragment.scan(false);
        }
    }

    @Override
    public Dialog onCreateDialog(Bundle savedInstanceState) {
        Activity appContext = getActivity();
        View view = appContext.getLayoutInflater().inflate(R.layout.devicepicker_layout, null);
        mScanButton = (Button) view.findViewById(R.id.scan_button);
        mScanButton.setOnClickListener(this);
        initDevicePickerFragment();
        AlertDialog.Builder builder = new AlertDialog.Builder(appContext);
        builder.setTitle(mTitle != null ? mTitle : getActivity().getString(
                R.string.devicepicker_default_title));
        builder.setView(view);
        return builder.create();
    }

    @Override
    public void onClick(View v) {
        boolean isScanning = !mIsScanning;
        setScanState(isScanning);
        mDevicePickerFragment.scan(isScanning);
    }

    @Override
    public void onDevicePicked(BluetoothDevice device) {
        if (mCallback != null) {
            mCallback.onDevicePicked(device);
        }
        dismiss();
    }

    @Override
    public void onDevicePickCancelled() {
        if (mCallback != null) {
            mCallback.onDevicePickCancelled();
        }

    }

    @Override
    public void onDevicePickError() {
        if (mCallback != null) {
            mCallback.onDevicePickError();
        }
    }

    @Override
    public void onResume() {
        super.onResume();
        if (mStartScanning) {
            scan();
        } else {
            stopScan();
        }
    }

    @Override
    public void onPause() {
        super.onPause();
        stopScan();
        dismiss();
    }

    @Override
    public void onDismiss(DialogInterface dialog) {
        super.onDismiss(dialog);
        if (mDevicePickerFragment != null) {
            mDevicePickerFragment.getFragmentManager().beginTransaction()
                    .remove(mDevicePickerFragment).commit();
        }
    }

    /**
     * Add a collection of devices to the list of devices excluded from the
     * device picker
     *
     * @param deviceAddress
     */
    public void addExcludedDevices(Collection<String> deviceAddresses) {
        mDevicePickerFragment.addExcludedDevices(deviceAddresses);
    }

    /**
     * Add a device to the list of devices excluded from the device picker
     *
     * @param deviceAddress
     */
    public void addExcludedDevice(String deviceAddress) {
        mDevicePickerFragment.addExcludedDevice(deviceAddress);
    }

    /**
     * Remove the device from the list of devices excluded from the device
     * picker
     *
     * @param deviceAddress
     */
    public void removeExcludedDevice(String address) {
        mDevicePickerFragment.removeExcludedDevice(address);
    }

    /**
     * Clear the list of devices excluded from the device picker
     *
     * @param deviceAddress
     */
    public void clearExcludedDevices() {
        mDevicePickerFragment.clearExcludedDevices();
    }
}
