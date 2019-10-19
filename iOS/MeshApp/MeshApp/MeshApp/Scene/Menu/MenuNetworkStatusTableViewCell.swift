/*
 * Copyright Cypress Semiconductor
 */

/** @file
 *
 * Network Status table cell for Menu Scene implementation.
 */

import UIKit
import MeshFramework

class MenuNetworkStatusTableViewCell: UITableViewCell {
    @IBOutlet weak var networkStatusTitleLabel: UILabel!
    @IBOutlet weak var networkStatusLightView: UIView!
    @IBOutlet weak var networkStatusMessageLabel: UILabel!
    @IBOutlet weak var networkStatusReflashButton: UIButton!
    @IBOutlet weak var segmentationLineView: UIView!

    var parentVC: UIViewController?

    let networkConnectedMsg = "Network is connected"
    let networkDisconnectedMsg = "Network is disconnected"
    let networkConnectingMsg = "Searching for network"

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        self.networkStatusLightView.layer.cornerRadius = self.networkStatusLightView.frame.size.width/2
        self.networkStatusLightView.clipsToBounds = true

        if MeshFrameworkManager.shared.isMeshNetworkConnected() {
            self.networkStatusLightView.backgroundColor = UIColor.green
            self.networkStatusMessageLabel.text = networkConnectedMsg
        } else {
            self.networkStatusLightView.backgroundColor = UIColor.red
            self.networkStatusMessageLabel.text = networkDisconnectedMsg
        }
    }

    func onNetworkLinkStatusChanged() {
        if MeshFrameworkManager.shared.isMeshNetworkConnected() {
            self.networkStatusLightView.backgroundColor = UIColor.green
            self.networkStatusMessageLabel.text = self.networkConnectedMsg
        } else {
            self.networkStatusLightView.backgroundColor = UIColor.red
            self.networkStatusMessageLabel.text = self.networkDisconnectedMsg
        }
        self.networkStatusReflashButton.imageView?.stopRotate()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        //super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
        if self.networkStatusReflashButton.imageView?.isRotating ?? true {
            return  // busying already.
        }

        if selected {
            if let vc = self.parentVC, !UserSettings.shared.isCurrentActiveMeshNetworkOpenned {
                UtilityManager.showAlertDialogue(parentVC: vc, message: "Please select and open a mesh network before searching for the network.")
                return
            }

            connectingToMeshNetwork()
        }
    }

    @IBAction func onNetworkStatusReflashButtonClick(_ sender: UIButton) {
        print("MenuNetworkStatusTableViewCell, onNetworkStatusReflashButtonClick")
        connectingToMeshNetwork()
    }

    func connectingToMeshNetwork() {
        guard let _ = MeshFrameworkManager.shared.getOpenedMeshNetworkName() else {
            if let vc = self.parentVC {
                UtilityManager.showAlertDialogue(parentVC: vc, message: "No mesh network opened, please select and open a mesh network firstly.")
            }
            return
        }

        if MeshFrameworkManager.shared.isMeshNetworkConnected() {
            self.networkStatusLightView.backgroundColor = UIColor.green
            self.networkStatusMessageLabel.text = networkConnectedMsg
            networkStatusReflashButton.imageView?.stopRotate()
        } else {
            self.networkStatusLightView.backgroundColor = UIColor.yellow
            self.networkStatusMessageLabel.text = networkConnectingMsg
            networkStatusReflashButton.imageView?.startRotate()
            MeshFrameworkManager.shared.connectMeshNetwork { (isConnected: Bool, connId: Int, addr: Int, isOverGatt: Bool, error: Int) in
                print("MenuNetworkStatusTableViewCell, connectingToMeshNetwork completion, isConnected:\(isConnected), connId:\(connId), addr:\(addr), isOverGatt:\(isOverGatt), error:\(error)")
                guard error == MeshErrorCode.MESH_SUCCESS else {
                    if let vc = self.parentVC {
                        var message = "Failed to connect to mesh network. Error Code: \(error)."
                        if error == MeshErrorCode.MESH_ERROR_INVALID_STATE {
                            message = "Mesh network is busying, please try again a litte later."
                        }
                        self.onNetworkLinkStatusChanged()
                        UtilityManager.showAlertDialogue(parentVC: vc, message: message)
                    }
                    return
                }
                self.onNetworkLinkStatusChanged()
            }
        }
    }
}

extension UIImageView {
    func startRotate() {
        let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotationAnimation.toValue = NSNumber(value: Double.pi * 2)
        rotationAnimation.duration = 1
        rotationAnimation.isCumulative = true
        rotationAnimation.repeatCount = MAXFLOAT
        layer.add(rotationAnimation, forKey: "rotationAnimation")
    }

    func stopRotate() {
        layer.removeAllAnimations()
    }

    var isRotating: Bool {
        if let _ = layer.animation(forKey: "rotationAnimation") {
            return true
        }
        return false
    }
}
