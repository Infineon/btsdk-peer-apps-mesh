/*
 * Copyright Cypress Semiconductor
 */

/** @file
 *
 * Sign up view controller implementation.
 */

import UIKit
import MeshFramework

class SignUpViewController: UIViewController {
    @IBOutlet weak var errorInfoView: UIView!
    @IBOutlet weak var errorInfoTextFiled: UILabel!
    @IBOutlet weak var accountEmailTextField: UITextField!
    @IBOutlet weak var accountPasswordTextField: UITextField!
    @IBOutlet weak var accoutnReenterPasswordTextField: UITextField!
    @IBOutlet weak var signUpButton: UIButton!
    @IBOutlet weak var createNewAccoutDetailView: UIView!

    let activeIndcator = CustomIndicatorView()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        notificationInit()
        errorInfoView.isHidden = true
        accountEmailTextField.delegate = self
        accountPasswordTextField.delegate = self
        accoutnReenterPasswordTextField.delegate = self
        let tapBackGround = UITapGestureRecognizer(target: self, action: #selector(onTapBackGround))
        self.view.addGestureRecognizer(tapBackGround)
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

    @objc func onTapBackGround() {
        self.view.endEditing(true)
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

    func validateInputAccount() -> Bool {
        if accountEmailTextField.text == nil || accountEmailTextField.text!.isEmpty ||
            !UtilityManager.validateEmail(email: accountEmailTextField.text) {
            errorInfoTextFiled.text = "Invalid Email Address"
            errorInfoView.isHidden = false
            return false
        }

        if accountPasswordTextField.text == nil || accountPasswordTextField.text!.isEmpty ||
            accoutnReenterPasswordTextField.text == nil || accountPasswordTextField.text != accoutnReenterPasswordTextField.text {
            errorInfoTextFiled.text = "Password Not Match"
            errorInfoView.isHidden = false
            return false
        }

        return true
    }

    @IBAction func onSignUpButtonUp(_ sender: Any) {
        guard validateInputAccount(), let email = accountEmailTextField.text, let password = accountPasswordTextField.text  else {
            return
        }

        activeIndcator.showAnimating(parentView: self.view, isTransparent: true)
        DispatchQueue.main.async { [weak self] in
            NetworkManager.shared.accountRegister(name: email, password: password) { (status: Int) -> Void in
                self?.activeIndcator.stopAnimating()

                if status != 0 {
                    meshLog("onSignUpButtonUp, NetworkManager.shared.accountRegister status=\(status)")
                    self?.errorInfoTextFiled.text = "Invalid Account"
                    self?.errorInfoView.isHidden = false
                    return
                }

                UserSettings.shared.lastActiveAccountEmail = email
                UtilityManager.navigateToViewController(targetClass: LoginViewController.self)
            }
        }
    }
}

extension SignUpViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == accountEmailTextField {
            _ = accountPasswordTextField.becomeFirstResponder()
        } else if textField == accountPasswordTextField {
            _ = accoutnReenterPasswordTextField.becomeFirstResponder()
        } else if textField == accoutnReenterPasswordTextField {
            textField.resignFirstResponder()
            onSignUpButtonUp(signUpButton as Any)
        }
        return false
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if !errorInfoView.isHidden {
            errorInfoView.isHidden = true
        }
        return true
    }

    /// MARK: avoid the TextField to be hidden by the keyboard when inputing.
    func textFieldDidBeginEditing(_ textField: UITextField) {
        createNewAccoutDetailView.frame = CGRect(x: createNewAccoutDetailView.frame.origin.x,
                                                 y: createNewAccoutDetailView.frame.origin.y - 100,
                                                 width: createNewAccoutDetailView.frame.size.width,
                                                 height: createNewAccoutDetailView.frame.size.height)
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        createNewAccoutDetailView.frame = CGRect(x: createNewAccoutDetailView.frame.origin.x,
                                                 y: createNewAccoutDetailView.frame.origin.y + 100,
                                                 width: createNewAccoutDetailView.frame.size.width,
                                                 height: createNewAccoutDetailView.frame.size.height)
    }
}
