/*
 * Copyright Cypress Semiconductor
 */

/** @file
 *
 * Firmware Upgrade View implementation.
 */

import UIKit
import MeshFramework

class FirmwareUpgradeViewController: UIViewController, OtaManagerDelegate {
    @IBOutlet weak var navigationBarItem: UINavigationItem!
    @IBOutlet weak var menuBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var rightBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var firmwareUpgradeTitleLabel: UILabel!
    @IBOutlet weak var firmwareUpgradeMessageLabel: UILabel!
    @IBOutlet weak var discoverredDevicesTableView: UITableView!
    @IBOutlet weak var deviceScanIndicator: UIActivityIndicatorView!

    private var indicatorUpdateTimer: Timer?
    private let tableRefreshControl = UIRefreshControl()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        notificationInit()
        viewInit()
    }

    override func viewDidDisappear(_ animated: Bool) {
        if let _ = indicatorUpdateTimer {
            stopScan()
        }
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
        navigationBarItem.rightBarButtonItem = nil  // not used currently.

        if let _ = UserSettings.shared.activeEmail {
            navigationBarItem.title = UserSettings.shared.activeName ?? "@me"
        } else {
            navigationBarItem.title = ""
            navigationBarItem.leftBarButtonItem?.image = UIImage(named: MeshAppImageNames.backIconImage)
        }

        self.tableRefreshControl.tintColor = UIColor.blue
        self.tableRefreshControl.addTarget(self, action: #selector(pullToRefresh), for: .valueChanged)

        DispatchQueue.main.async {
            // Execuated in UI thread to avoid "Main Thread Checker: UI API called on a background thread: -[UIApplication applicationState]" issue.
            self.discoverredDevicesTableView.delegate = self
            self.discoverredDevicesTableView.dataSource = self
            self.discoverredDevicesTableView.separatorStyle = .none

            if #available(iOS 10.0, *) {
                self.discoverredDevicesTableView.refreshControl = self.tableRefreshControl
            } else {
                self.discoverredDevicesTableView.addSubview(self.tableRefreshControl)
            }

            OtaManager.shared.delegate = self
            OtaManager.shared.clearOtaDevices()
            self.pullToRefresh()
        }
    }


    ///
    /// Implementation of OtaManagerDelegate
    ///
    func onOtaDevicesUpdate() {
        discoverredDevicesTableView.reloadData()
    }

    @objc func pullToRefresh() {
        tableRefreshControl.beginRefreshing()
        stopScan()
        OtaManager.shared.clearOtaDevices()
        startScan()
        tableRefreshControl.endRefreshing()
    }

    @objc func indicatorUpdateHandler() {
        if MeshGattClient.shared.centralManager.state == .poweredOn && MeshGattClient.shared.centralManager.isScanning {
            indicatorStartAnimating()
        } else {
            indicatorStopAnimating()
        }
    }

    func indicatorStartAnimating() {
        deviceScanIndicator.startAnimating()
        deviceScanIndicator.isHidden = false
        if indicatorUpdateTimer == nil {
            indicatorUpdateTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(indicatorUpdateHandler), userInfo: nil, repeats: true)
        }
    }

    func indicatorStopAnimating() {
        indicatorUpdateTimer?.invalidate()
        indicatorUpdateTimer = nil
        deviceScanIndicator.stopAnimating()
        deviceScanIndicator.isHidden = true
    }

    func startScan() {
        OtaManager.shared.startScan()
        indicatorStartAnimating()
    }

    func stopScan() {
        indicatorStopAnimating()
        OtaManager.shared.stopScan()
    }

    @IBAction func onMenuBarButtonItemClick(_ sender: UIBarButtonItem) {
        meshLog("FirmwareUpgradeViewController, onMenuBarButtonItemClick")
        if let _ = UserSettings.shared.activeEmail {
            UtilityManager.navigateToViewController(sender: self, targetVCClass: MenuViewController.self, modalPresentationStyle: UIModalPresentationStyle.overCurrentContext)
        } else {
            UtilityManager.navigateToViewController(targetClass: LoginViewController.self)
        }
    }

    @IBAction func onRightBarButtonItemClick(_ sender: UIBarButtonItem) {
        meshLog("FirmwareUpgradeViewController, onRightBarButtonItemClick")
    }
}

extension FirmwareUpgradeViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if OtaManager.shared.otaDevices.count == 0 {
            return 1    // show empty table cell
        }
        return OtaManager.shared.otaDevices.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if OtaManager.shared.otaDevices.count == 0 {
            guard let cell = self.discoverredDevicesTableView.dequeueReusableCell(withIdentifier: MeshAppStoryBoardIdentifires.FIRMWARE_UPGRADE_EMPTY_CELL, for: indexPath) as? FirmwareUpgradeEmptyTableViewCell else {
                return UITableViewCell()
            }
            return cell
        }

        guard let cell = self.discoverredDevicesTableView.dequeueReusableCell(withIdentifier: MeshAppStoryBoardIdentifires.FIRMWARE_UPGRADE_CELL, for: indexPath) as? FirmwareUpgradeTableViewCell else {
            return UITableViewCell()
        }

        let otaDevice = OtaManager.shared.otaDevices[indexPath.row]
        cell.otaDevice = otaDevice
        cell.deviceTypeLabel.text = OtaManager.getOtaDeviceTypeString(by: otaDevice.getDeviceType())
        cell.deviceNameLabel.text = otaDevice.getDeviceName()
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if OtaManager.shared.otaDevices.count == 0 {
            return
        }

        meshLog("FirmwareUpgradeViewController, tableView didSelectRowAt, row=\(indexPath.row)")
        stopScan()
        OtaManager.shared.activeOtaDevice = OtaManager.shared.otaDevices[indexPath.row]
        if let _ = MeshFrameworkManager.shared.getOpenedMeshNetworkName() {
            UtilityManager.navigateToViewController(sender: self, targetVCClass: MeshOtaDfuViewController.self)
        } else {
            UtilityManager.navigateToViewController(sender: self, targetVCClass: DeviceOtaUpgradeViewController.self)
        }
        // TODO: need developing.
        //UtilityManager.navigateToViewController(sender: self, targetVCClass: MeshOtaDfuViewController.self)
    }
}
