/*
 * Copyright Cypress Semiconductor
 */

/** @file
 *
 * WatchOS App ExtensionDelegate implementation.
 */

import WatchKit
import MeshFramework

class ExtensionDelegate: NSObject, WKExtensionDelegate {

    func applicationDidFinishLaunching() {
        // Perform any final initialization of your application.

        // [Cypress] Some of the sample Code demoes the call of Mesh Library initialization API from MeshFramework library.
        let provisioinerName = "test_provisioner_name"
        let meshNetworkName = "test_mesh_network_name"
        var error = MeshFrameworkManager.shared.initMeshLibrary(forUser: "test_username")
        print("MeshFrameworkManager.shared.initMeshLibrary, invoked result: \(error)")
        error = MeshFrameworkManager.shared.createMeshNetwork(provisioinerName: provisioinerName, networkName: meshNetworkName)
        print("MeshFrameworkManager.shared.createMeshNetwork, invoked result: \(error)")
        MeshFrameworkManager.shared.openMeshNetwork(provisioinerName: provisioinerName, networkName: meshNetworkName, completion: { (networkName: String?, status: Int, error: Int) in

            guard error == MeshErrorCode.MESH_SUCCESS else {
                print("error: MeshFrameworkManager.shared.openMeshNetwork, failed to execute openMeshNetwork API, networkName:\(String(describing: networkName)), error=\(error)")
                return
            }
            guard status == MeshErrorCode.MESH_SUCCESS else {
                print("error: MeshFrameworkManager.shared.openMeshNetwork, failed to do openMeshNetwork, networkName:\(String(describing: networkName)), completion with status=\(status)")
                return
            }

            print("MeshFrameworkManager.shared.openMeshNetwork, opened success, networkName:\(String(describing: networkName)), status=\(status), error=\(error)")
        })
    }

    func applicationDidBecomeActive() {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillResignActive() {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, etc.
    }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        // Sent when the system needs to launch the application in the background to process tasks. Tasks arrive in a set, so loop through and process each one.
        for task in backgroundTasks {
            // Use a switch statement to check the task type
            switch task {
            case let backgroundTask as WKApplicationRefreshBackgroundTask:
                // Be sure to complete the background task once you’re done.
                backgroundTask.setTaskCompletedWithSnapshot(false)
            case let snapshotTask as WKSnapshotRefreshBackgroundTask:
                // Snapshot tasks have a unique completion call, make sure to set your expiration date
                snapshotTask.setTaskCompleted(restoredDefaultState: true, estimatedSnapshotExpiration: Date.distantFuture, userInfo: nil)
            case let connectivityTask as WKWatchConnectivityRefreshBackgroundTask:
                // Be sure to complete the connectivity task once you’re done.
                connectivityTask.setTaskCompletedWithSnapshot(false)
            case let urlSessionTask as WKURLSessionRefreshBackgroundTask:
                // Be sure to complete the URL session task once you’re done.
                urlSessionTask.setTaskCompletedWithSnapshot(false)
            case let relevantShortcutTask as WKRelevantShortcutRefreshBackgroundTask:
                // Be sure to complete the relevant-shortcut task once you're done.
                relevantShortcutTask.setTaskCompletedWithSnapshot(false)
            case let intentDidRunTask as WKIntentDidRunRefreshBackgroundTask:
                // Be sure to complete the intent-did-run task once you're done.
                intentDidRunTask.setTaskCompletedWithSnapshot(false)
            default:
                // make sure to complete unhandled task types
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }

}
