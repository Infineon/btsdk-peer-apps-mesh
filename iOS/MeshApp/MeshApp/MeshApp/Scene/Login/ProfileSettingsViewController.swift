/*
 * Copyright Cypress Semiconductor
 */

/** @file
 *
 * Profile Settings View implementation.
 */

import UIKit
import MeshFramework

class ProfileSettingsViewController: UIViewController {
    @IBOutlet weak var topNavigationBarItem: UINavigationItem!
    @IBOutlet weak var leftBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var rightBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var prifileSettingsView: UIView!
    @IBOutlet weak var profileSettingsLabel: UILabel!
    @IBOutlet weak var nameTitleLabel: UILabel!
    @IBOutlet weak var nameContentLabel: UILabel!
    @IBOutlet weak var editNameButton: UIButton!
    @IBOutlet weak var emailTitleLabel: UILabel!
    @IBOutlet weak var emailContentLabel: UILabel!
    @IBOutlet weak var changePasswordButton: UIButton!
    @IBOutlet weak var logoutButton: UIButton!
    @IBOutlet weak var deleteAccountButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        viewInit()
    }

    func viewInit() {
        notificationInit()
        self.topNavigationBarItem.rightBarButtonItem = nil
        self.nameContentLabel.text = UserSettings.shared.activeName
        self.emailContentLabel.text = UserSettings.shared.activeEmail ?? ""
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

    @IBAction func onLeftBarButtonItemClick(_ sender: UIBarButtonItem) {
        UtilityManager.navigateToViewController(sender: self, targetVCClass: MenuViewController.self, modalPresentationStyle: UIModalPresentationStyle.overCurrentContext)
    }

    @IBAction func onRightBarButtonItemClick(_ sender: UIBarButtonItem) {
    }


    @IBAction func onEditNameButtonClick(_ sender: UIButton) {
        let alertController = UIAlertController(title: "Edit Name", message: nil, preferredStyle: .alert)
        alertController.addTextField { (textField: UITextField) in
            textField.placeholder = "Enter New Name"
        }
        alertController.addAction(UIAlertAction(title: "Cancel", style: .default, handler: nil))
        alertController.addAction(UIAlertAction(title: "Update", style: .default, handler: { (action: UIAlertAction) -> Void in
            if let textField = alertController.textFields?.first, let newName = textField.text, newName.count > 0 {
                UserSettings.shared.activeName = newName
                self.nameContentLabel.text = newName
            } else {
                UtilityManager.showAlertDialogue(parentVC: self, message: "Invalid or Empty new name!", title: "Error")
            }
        }))
        self.present(alertController, animated: true, completion: nil)
    }

    @IBAction func onChangePasswordButtonClick(_ sender: UIButton) {
        let alertController = UIAlertController(title: "Change Password", message: nil, preferredStyle: .alert)
        alertController.addTextField { (textField: UITextField) in
            textField.borderStyle = UITextField.BorderStyle.roundedRect
            textField.placeholder = "New Password"
            textField.isSecureTextEntry = true
            textField.returnKeyType = UIReturnKeyType.next
        }
        alertController.addTextField { (textField: UITextField) in
            textField.borderStyle = UITextField.BorderStyle.roundedRect
            textField.placeholder = "Retype New Password"
            textField.isSecureTextEntry = true
            textField.returnKeyType = UIReturnKeyType.done
        }
        alertController.addAction(UIAlertAction(title: "Cancel", style: .default, handler: nil))
        alertController.addAction(UIAlertAction(title: "Update", style: .default, handler: { (action: UIAlertAction) -> Void in
            if let textFields = alertController.textFields, textFields.count >= 2,
                let newPwd = textFields[0].text, newPwd.count > 0,
                let reenterPwd = textFields[1].text, newPwd == reenterPwd {
                UserSettings.shared.activePssword = newPwd
                UserSettings.shared.accounts[UserSettings.shared.activeEmail ?? ""] = newPwd
                UtilityManager.showAlertDialogue(parentVC: self, message: "New password has been updated success!", title: "Success")
            } else {
                UtilityManager.showAlertDialogue(parentVC: self, message: "Empty or mismatched new password!", title: "Error")
            }
        }))
        self.present(alertController, animated: true, completion: nil)
    }

    @IBAction func onLogoutButtonClick(_ sender: UIButton) {
        MeshFrameworkManager.shared.closeMeshNetwork()
        MeshFrameworkManager.shared.deinitMeshLibrary()

        UserSettings.shared.resetCurrentAccount()

        // go back to login view.
        UtilityManager.navigateToViewController(targetClass: LoginViewController.self)
    }

    @IBAction func onDeleteAccountButtonClick(_ sender: UIButton) {
        let deleteAccount = UserSettings.shared.activeEmail ?? ""

        MeshFrameworkManager.shared.closeMeshNetwork()

        // Remove mesh files and account info data stored in the network for the user.
        NetworkManager.shared.deleteMeshFiles { (status) in
            print("ProfileSettingsViewController, onDeleteAccountButtonClick, delete network data status=\(status)")

            // Remove device loacl mesh files and account info.
            let error = MeshFrameworkManager.shared.deleteMeshStorage()
            print("ProfileSettingsViewController, onDeleteAccountButtonClick, error=\(error)")
            MeshFrameworkManager.shared.deinitMeshLibrary()

            UserSettings.shared.resetCurrentAccount()
            UserSettings.shared.accounts.removeValue(forKey: deleteAccount)

            // go back to login view.
            UtilityManager.navigateToViewController(targetClass: LoginViewController.self)
        }

    }
}
