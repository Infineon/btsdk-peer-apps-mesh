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
package com.cypress.le.mesh.meshframework;

import java.util.UUID;

/**
 * Contains the UUID of services, characteristics, and descriptors
 */
class OTAUpgradeConstants {

    /**
     * UUID of Upgrade Service
     */
    public static UUID UPGRADE_SERVICE_UUID;
    /**
     * UUID of Secure Upgrade Service
     */
	public static UUID SECURE_UPGRADE_SERVICE_UUID;

    /**
     * UUID of Upgrade Control Point
     */
    public static UUID UPGRADE_CHARACTERISTIC_CONTROL_POINT_UUID;
    /**
     * UUID of Upgrade Control Data
     */
    public static UUID UPGRADE_CHARACTERISTIC_DATA_UUID;
    /**
     * UUID of Upgrade Service
     */
    public static UUID UPGRADE_SERVICE_UUID_2;
    /**
     * UUID of Secure Upgrade Service
     */
    public static UUID SECURE_UPGRADE_SERVICE_UUID_2;

    /**
     * UUID of Upgrade Control Point
     */
    public static UUID UPGRADE_CHARACTERISTIC_CONTROL_POINT_UUID_2;
    /**
     * UUID of Upgrade Control Data
     */
    public static UUID UPGRADE_CHARACTERISTIC_DATA_UUID_2;
    /**
     * UUID of the client configuration descriptor
     */
    public static final UUID CLIENT_CONFIG_DESCRIPTOR_UUID = UUID
            .fromString("00002902-0000-1000-8000-00805f9b34fb");

    public OTAUpgradeConstants() {
            //OTA_VERSION_2
            UPGRADE_SERVICE_UUID_2 = UUID.fromString("10022922-ccf5-11e8-b680-025041000001");
            SECURE_UPGRADE_SERVICE_UUID_2 = UUID.fromString("10270b52-ccf5-11e8-8c28-025041000001");
            UPGRADE_CHARACTERISTIC_CONTROL_POINT_UUID_2 = UUID.fromString("1058fcfc-ccf5-11e8-b112-025041000001");
            UPGRADE_CHARACTERISTIC_DATA_UUID_2 = UUID.fromString("107163c8-ccf5-11e8-9b81-025041000001");
            //OTA_VERSION_1
            UPGRADE_SERVICE_UUID = UUID.fromString("ae5d1e47-5c13-43a0-8635-82ad38a1381f");
            SECURE_UPGRADE_SERVICE_UUID = UUID.fromString("c7261110-f425-447a-a1bd-9d7246768bd8");
            UPGRADE_CHARACTERISTIC_CONTROL_POINT_UUID = UUID.fromString("a3dd50bf-f7a7-4e99-838e-570a086c661b");
            UPGRADE_CHARACTERISTIC_DATA_UUID = UUID.fromString("a2e86c7a-d961-4091-b74f-2409e72efe26");
    }
}
