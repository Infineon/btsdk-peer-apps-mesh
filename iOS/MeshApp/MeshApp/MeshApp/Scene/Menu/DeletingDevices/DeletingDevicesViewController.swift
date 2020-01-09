/*
 * Copyright Cypress Semiconductor
 */

/** @file
 *
 * Deleting devices view controller implementation.
 */

import UIKit
import MeshFramework

class DeletingDevicesViewController: UIViewController {
    @IBOutlet weak var topNavigationItem: UINavigationItem!
    @IBOutlet weak var menuButtonItem: UIBarButtonItem!
    @IBOutlet weak var rightBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var deletingMessageLabel: UILabel!
    @IBOutlet weak var deletingDevicesTable: UITableView!


    var deletingDevices: [String] = []

    override func viewDidDisappear(_ animated: Bool) {
        MeshGattClient.shared.stopScan()
        super.viewDidDisappear(animated)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        meshDeletingDevicesInit()
        notificationInit()
        viewInit()
        MeshGattClient.shared.startScan()
    }

    func notificationInit() {
        NotificationCenter.default.addObserver(self, selector: #selector(notificationHandler(_:)),
                                               name: Notification.Name(rawValue: MeshNotificationConstants.MESH_CLIENT_NODE_CONNECTION_STATUS_CHANGED), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notificationHandler(_:)),
                                               name: Notification.Name(rawValue: MeshNotificationConstants.MESH_CLIENT_NETWORK_LINK_STATUS_CHANGED), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notificationHandler(_:)),
                                               name: Notification.Name(rawValue: MeshNotificationConstants.MESH_NETWORK_DATABASE_CHANGED), object: nil)
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
        default:
            break
        }
    }

    func viewInit() {
        self.topNavigationItem.rightBarButtonItem = nil

        deletingDevicesTable.dataSource = self
        deletingDevicesTable.delegate = self
        deletingDevicesTable.separatorStyle = .none

        deletingMessageLabel.text = "Please make sure the deleting devices are powered on, reachable and accessable before it was deleted successfully."
    }

    func meshDeletingDevicesInit() {
        deletingDevices.removeAll()
        if let networkName = UserSettings.shared.currentActiveMeshNetworkName,
            let components = MeshFrameworkManager.shared.getMeshGroupComponents(groupName: networkName) {
            for component in components {
                let groupList = MeshFrameworkManager.shared.getMeshComponentGroupList(componentName: component)
                if groupList == nil || groupList?.isEmpty ?? false {
                    deletingDevices.append(component)
                }
            }
        }
    }


    @IBAction func onMenuButtonItemClick(_ sender: UIBarButtonItem) {
        meshLog("DeletingDevicesViewController, onMenuButtonItemClick")
        UtilityManager.navigateToViewController(sender: self, targetVCClass: MenuViewController.self, modalPresentationStyle: UIModalPresentationStyle.overCurrentContext)
    }

    @IBAction func onRightBarButtonItemClick(_ sender: UIBarButtonItem) {
        meshLog("DeletingDevicesViewController, onRightBarButtonItemClick")
    }
}

extension DeletingDevicesViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if deletingDevices.isEmpty {
            return 1
        }
        return deletingDevices.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if deletingDevices.isEmpty {
            // Show empty cell.
            guard let cell = deletingDevicesTable.dequeueReusableCell(withIdentifier: MeshAppStoryBoardIdentifires.DELETING_DEVIES_EMPTY_CELL, for: indexPath) as? DeletingDevicesEmptyTableViewCell else {
                return UITableViewCell()
            }
            cell.emptyMessageLabel.text = "Congruatulations! No device is pending for deleting."
            return cell
        }

        guard let cell = deletingDevicesTable.dequeueReusableCell(withIdentifier: MeshAppStoryBoardIdentifires.DELETING_DEVIES_CELL, for: indexPath) as? DeletingDevicesTableViewCell else {
            return UITableViewCell()
        }
        cell.parentVC = self
        cell.deviceName = deletingDevices[indexPath.row]
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        meshLog("DeletingDevicesViewController, tableView didSelectRowAt \(indexPath.row), deletingDevices.count=\(deletingDevices.count)")
        guard !deletingDevices.isEmpty, indexPath.row < deletingDevices.count else {
            return
        }

        if let cell = deletingDevicesTable.cellForRow(at: indexPath) as? DeletingDevicesTableViewCell, let _ = cell.deviceName {
            cell.deviceConnectSync()
        }
    }
}
