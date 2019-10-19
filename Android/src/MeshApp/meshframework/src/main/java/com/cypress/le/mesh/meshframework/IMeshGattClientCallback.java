package com.cypress.le.mesh.meshframework;
   interface IMeshGattClientCallback {
    /**
     * Callback invoked upon connection state change
     */
    void onNetworkConnectionStateChange();
       public void onOTAUpgradeStatusChanged(byte status, int percent);

   }