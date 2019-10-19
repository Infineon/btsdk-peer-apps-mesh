/*
 * Copyright Cypress Semiconductor
 */

/** @file
 *
 * Customer Popover choise table view controller implementation.
 */

import UIKit

/* Define the popover view position compared to its parent view. */
enum PopoverTableViewPosition {
    case left
    case right
    case center
}

class PopoverChoiceTableViewController<Element>: UITableViewController {
    typealias SelectionHandler = (Int, Element) -> Void
    typealias LabelProvider = (Element) -> String

    private let choices: [Element]
    private let labels: LabelProvider
    private let onSelected: SelectionHandler?
    private var dismissCompletion: (() -> Void)?

    init(choices: [Element], labels: @escaping LabelProvider = String.init(describing:), onSelected: SelectionHandler? = nil) {
        self.choices = choices
        self.labels = labels
        self.onSelected = onSelected
        super.init(style: .plain)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("PopoverChoiceTableViewController, init(coder:) not implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }

    override func viewDidDisappear(_ animated: Bool) {
        dismissCompletion?()
        super.viewDidDisappear(animated)
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return choices.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = labels(choices[indexPath.row])
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.dismiss(animated: true, completion: nil)
        onSelected?(indexPath.row, choices[indexPath.row])
    }

    func showPopoverPresentation(parent: UIViewController, sourceView: UIView?, position: PopoverTableViewPosition = .center, dismissCompletion: (() -> Void)? = nil) {
        //guard choices.count > 0 else {
        //    dismissCompletion?()
        //    return
        //}
        let presentationController = AlwaysPopoverPresentationController.configurePresentation(for: self)
        presentationController.sourceView = sourceView ?? parent.view
        // default position is pointing to the center of the parent view.
        var positionX = parent.view.bounds.origin.x + parent.view.bounds.size.width / 2
        var positionY = parent.view.bounds.origin.y + 30
        if let srcView = sourceView {
            positionX = srcView.bounds.origin.x + srcView.bounds.size.width / 2
            positionY = srcView.bounds.origin.y + 30
        }
        switch position {
        case .left:
            positionX = parent.view.bounds.origin.x + 20
        case .right:
            positionX = parent.view.bounds.origin.x + parent.view.bounds.size.width - 20
        default:
            break
        }
        presentationController.sourceRect = /*sourceView?.bounds ?? */CGRect(x: positionX, y: positionY, width: 0, height: 0)
        presentationController.permittedArrowDirections = [.down, .up]
        self.dismissCompletion = dismissCompletion
        parent.present(self, animated: true, completion: nil)
    }

    // Calculate the possible popover view size based on how many items will be shown in the popover view.
    func getPreferredPopoverViewSize() -> Int {
        guard choices.count > 0 else {
            return 45
        }
        return choices.count * 45 - 1
    }
}
