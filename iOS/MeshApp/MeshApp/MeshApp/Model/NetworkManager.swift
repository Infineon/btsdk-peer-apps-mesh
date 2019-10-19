/*
 * Copyright Cypress Semiconductor
 */

/** @file
 *
 * Network storage and access simulation implementation.
 */

import Foundation
import MeshFramework

class NetworkManager {
    static let shared = NetworkManager()

    /// MARK: placeholder functions of network operations.

    /**
     Upload and store the specific file into network for current loggin user.

     @param fileName    The file name should be uploaded and stored in network space for current user.
     @param content     The content of the file should be uploaded and stored.

     @return            None
     */
    func uploadMeshFile(fileName: String, content: Data, completion: @escaping (Int) -> Void) {
        DispatchQueue.main.async {
            let status: Int = 0
            UserSettings.shared.setMeshFile(fileName: fileName, content: content)
            completion(status)
        }
    }

    func downloadMeshFile(fileName: String, completion: @escaping (Int, Data?) -> Void) {
        DispatchQueue.main.async {
            let status: Int = 0
            let content = UserSettings.shared.getMeshFile(fileName: fileName) as? Data
            completion(status, content)
        }
    }

    func deleteMeshFile(fileName: String, completion: @escaping (Int) -> Void) {
        DispatchQueue.main.async {
            let status: Int = 0
            UserSettings.shared.deleteMeshFile(fileName: fileName)
            completion(status)
        }
    }

    func uploadMeshFiles(completion: @escaping (Int) -> Void) {
        DispatchQueue.main.async {
            let status: Int = 0
            if let meshFiles = MeshFrameworkManager.shared.getUserMeshFileNameList(), meshFiles.count > 0 {
                for fileName in meshFiles {
                    if let content = MeshFrameworkManager.shared.readMeshFile(fileName: fileName) {
                        self.uploadMeshFile(fileName: fileName, content: content) { (status) in
                            // TODO: do something after netwokr mesh files updated if required.
                        }
                    }
                }
            }
            completion(status)
        }
    }

    func restoreMeshFiles(completion: @escaping (Int) -> Void) {
        DispatchQueue.main.async {
            let status: Int = 0
            if let meshFiles = UserSettings.shared.getMeshFilesList(), meshFiles.count > 0 {
                for fileName in meshFiles {
                    self.downloadMeshFile(fileName: fileName) { (status, content) in
                        _ = MeshFrameworkManager.shared.restoreMeshFile(fileName: fileName, content: content)
                    }
                }
            }
            completion(status)
        }
    }

    func deleteMeshFiles(completion: @escaping (Int) -> Void) {
        DispatchQueue.main.async {
            let status: Int = 0
            if let meshFiles = MeshFrameworkManager.shared.getUserMeshFileNameList(), meshFiles.count > 0 {
                for fileName in meshFiles {
                    self.deleteMeshFile(fileName: fileName, completion: { (status) in
                        // TODO: do something after netwokr mesh file delete if required.
                    })
                }
            }
            completion(status)
        }
    }

    /// MARK: regiser and store the new account information into network.
    ///       return 0 on success; 1 duplicated name failed; 2 unknown register failed.
    func accountRegister(name: String, password: String, completion: @escaping (Int) -> Void) {
        DispatchQueue.main.async {
            var status: Int = 0

            guard name.count > 0, password.count > 0 else {
                completion(1)   // invalid name or password.
                return
            }

            if UserSettings.shared.accounts[name] != nil {
                status = 1      // the same name has been registerred.
            } else {
                UserSettings.shared.accounts[name] = password
            }
            completion(status)
        }
    }

    /// MARK: authentication the account name and password through network.
    ///       return 0 on success; 1 account specified by the name not exists; 2 account name and password authentication failed.
    func accountLogin(name: String, password: String, completion: @escaping (Int) -> Void) {
        DispatchQueue.main.async {
            var status: Int = 0

            if name.count > 0, password.count > 0, let storedPwd = UserSettings.shared.accounts[name] {
                if storedPwd != password {
                    status = 2
                }
            } else {
                status = 1
            }
            completion(status)
        }
    }
}
