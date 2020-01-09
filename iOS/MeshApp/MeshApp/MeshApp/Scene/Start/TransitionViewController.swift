/*
 * Copyright Cypress Semiconductor
 */

/** @file
 *
 * App state transition view controller implementation.
 */

import UIKit
import MeshFramework

class TransitionViewController: UIViewController {
    @IBOutlet weak var transitionLabel: UILabel!

    private var openingTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        transitionLabel.text = "Opening Network ..."
        //startTimer()
        notificationInit()
    }

    override func viewDidDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(self)
        super.viewDidDisappear(animated)
    }

    func notificationInit() {
        NotificationCenter.default.addObserver(self, selector: #selector(notificationHandler(_:)),
                                               name: Notification.Name(rawValue: MeshNotificationConstants.MESH_CLIENT_NODE_CONNECTION_STATUS_CHANGED), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notificationHandler(_:)),
                                               name: Notification.Name(rawValue: MeshNotificationConstants.MESH_CLIENT_NETWORK_LINK_STATUS_CHANGED), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notificationHandler(_:)),
                                               name: Notification.Name(rawValue: MeshNotificationConstants.MESH_NETWORK_DATABASE_CHANGED), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(notificationHandler(_:)),
                                               name: Notification.Name(rawValue: MeshNotificationConstants.MESH_CLIENT_NETWORK_OPENNED_CB), object: nil)
    }

    @objc func notificationHandler(_ notification: Notification) {
        guard let userInfo = notification.userInfo else {
            return
        }
        switch notification.name {
        case Notification.Name(rawValue: MeshNotificationConstants.MESH_CLIENT_NODE_CONNECTION_STATUS_CHANGED):
            if let nodeConnectionStatus = MeshNotificationConstants.getNodeConnectionStatus(userInfo: userInfo) {
                self.showToast(message: "Device \"\(nodeConnectionStatus.componentName)\" \((nodeConnectionStatus.status == MeshConstants.MESH_CLIENT_NODE_CONNECTED) ? "has connected." : "is unreachable").")
            }
        case Notification.Name(rawValue: MeshNotificationConstants.MESH_CLIENT_NETWORK_LINK_STATUS_CHANGED):
            if let linkStatus = MeshNotificationConstants.getLinkStatus(userInfo: userInfo) {
                self.showToast(message: "Mesh network has \((linkStatus.isConnected) ? "connected" : "disconnected").")
            }
        case Notification.Name(rawValue: MeshNotificationConstants.MESH_NETWORK_DATABASE_CHANGED):
            if let networkName = MeshNotificationConstants.getNetworkName(userInfo: userInfo) {
                self.showToast(message: "Database of mesh network \(networkName) has changed.")
            }
        case Notification.Name(rawValue: MeshNotificationConstants.MESH_CLIENT_NETWORK_OPENNED_CB):
            guard let status = MeshNotificationConstants.getNetworkOpenCbStatus(userInfo: userInfo), status == MeshErrorCode.MESH_SUCCESS else {
                meshLog("TransitionViewController, onMeshNetworkOpennedCb, failed to open mesh network, invalid status")
                UtilityManager.showAlertDialogue(parentVC: self,
                                                 message: "Failed to open mesh network, returned invalid status.", title: "Error",
                                                 action: UIAlertAction(title: "OK", style: .default, handler: { (action) in
                                                    // Go back to network list screen after User click the OK button when failed to open network.
                                                    UtilityManager.navigateToViewController(targetClass: NetworkListViewController.self)
                                                 }))
                return
            }
            //stopTimer()
            guard let meshNetworkName = UserSettings.shared.currentActiveMeshNetworkName else {
                meshLog("error: TransitionViewController, onMeshNetworkOpennedCb, UserSettings.shared.currentActiveMeshNetworkName is nil")
                return
            }
            UserSettings.shared.isCurrentActiveMeshNetworkOpenned = true
            meshLog("TransitionViewController, onMeshNetworkOpennedCb, mesh network: \(meshNetworkName) openned success")

            // navigate to mesh group list view controller.
            UtilityManager.navigateToViewController(targetClass: GroupListViewController.self)

            /*
             // [Dudley] test record.
             // Wait 10ms to wait the network open status be updated in the mesh library internal, than call try to connect to the mesh network.
             // But the issue is when there was no responsable compenent in the mesh network, then it will waiting long time until the timeout.
             // so, suggested do not connect to the mesh network here, suggest to connect to the mesh network through the menu network status UI.
             transitionLabel.text = "Connecting to Network ..."
             DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.01) {
             MeshFrameworkManager.shared.runHandlerWithMeshNetworkConnected { (error: Int) in
             meshLog("TransitionViewController, onMeshNetworkOpennedCb, connect to mesh network \(error == MeshErrorCode.MESH_SUCCESS ? "succes" : "failed, error=\(error)")")
             // navigate to mesh group list view controller.
             UtilityManager.navigateToViewController(targetClass: GroupListViewController.self)
             }
             }
             */
        default:
            break
        }
    }

    @objc func onNetworkOpeningTimeout() {
        meshLog("error: TransitionViewController, opening mesh network \(String(describing: UserSettings.shared.currentActiveMeshNetworkName)) timeout")
        UtilityManager.showAlertDialogue(parentVC: self, message: "Opening mesh network encounterred timeout error.", title: "Error",
                                         action: UIAlertAction(title: "OK", style: .default, handler: { (action) in
                                            // Go back to network list screen after User click the OK button when timeout happenned.
                                            UtilityManager.navigateToViewController(targetClass: NetworkListViewController.self)
                                         }))
    }

    func startTimer() {
        stopTimer()

        if #available(iOS 10.0, *) {
            openingTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(MeshConstants.MESH_DEFAULT_NETWORK_OPENING_TIMEOUT),
                                                repeats: false, block: { (Timer) in
                self.onNetworkOpeningTimeout()
            })
        } else {
            openingTimer = Timer.scheduledTimer(timeInterval: TimeInterval(MeshConstants.MESH_DEFAULT_NETWORK_OPENING_TIMEOUT),
                                                target: self,
                                                selector: #selector(self.onNetworkOpeningTimeout),
                                                userInfo: nil, repeats: false)
        }
    }

    func stopTimer() {
        if let runningTimer = openingTimer, runningTimer.isValid {
            runningTimer.invalidate()
        }
        openingTimer = nil
    }
}
