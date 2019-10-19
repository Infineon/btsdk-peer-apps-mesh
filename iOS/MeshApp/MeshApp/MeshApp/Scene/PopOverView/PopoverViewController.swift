/*
 * Copyright Cypress Semiconductor
 */

/** @file
 *
 * Customer Popover view controller implementation.
 */

import UIKit

enum PopoverType: String {
    case unknownType = "Unknown Type"
    case deleteNetwork = "Delete Network"
    case exportNetwork = "Export Network"
    case importNetwork = "Import Network"
    case componentAddToGroup = "Add to Group"
    case componentMoveToGroup = "Move to Group"
}

enum PopoverButtonType: String {
    case none = "None"  // indicates called from non popover VC.
    case confirm = "Confirm"
    case cancel = "Cancel"
}

typealias PopoverSelectionCallback = (_ btnType: PopoverButtonType, _ selectedItem: String?) -> ()

class PopoverViewController: UIViewController {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var confirmButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var tableView: UITableView!

    private let indicatorView = CustomIndicatorView()

    static var parentViewController: UIViewController?          // must be set before init.
    static var popoverCompletion: PopoverSelectionCallback?     // must be set before init.
    static var popoverType: PopoverType = .unknownType          // must be set before init.
    static var popoverItems: [String] = []                      // must be set before init.
    static var popoverTitle: String?                            // optional, set before init.

    var selectedItem: String? {
        return PopoverTableViewCell.selectedItem
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorStyle = .none

        titleLabel.text = PopoverViewController.popoverTitle ?? PopoverViewController.popoverType.rawValue
    }

    @IBAction func onConfirmButtonClick(_ sender: UIButton) {
        if let completion = PopoverViewController.popoverCompletion {
            DispatchQueue.main.async {
                completion(PopoverButtonType.confirm, self.selectedItem)
            }
        }
        self.dismiss(animated: false, completion: nil)
    }

    @IBAction func onCancelButtonClick(_ sender: UIButton) {
        if let completion = PopoverViewController.popoverCompletion {
            DispatchQueue.main.async {
                completion(PopoverButtonType.cancel, nil)
            }
        }
        self.dismiss(animated: false, completion: nil)
    }
}

extension PopoverViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return PopoverViewController.popoverItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: MeshAppStoryBoardIdentifires.POPOVER_CELL, for: indexPath) as? PopoverTableViewCell else {
            return UITableViewCell()
        }
        cell.item = PopoverViewController.popoverItems[indexPath.row]
        return cell
    }
}
