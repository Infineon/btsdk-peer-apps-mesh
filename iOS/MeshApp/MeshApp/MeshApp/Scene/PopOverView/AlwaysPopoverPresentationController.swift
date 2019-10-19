/*
 * Copyright Cypress Semiconductor
 */

/** @file
 *
 * Always popover presentation controller implementation.
 */

import UIKit

class AlwaysPopoverPresentationController: NSObject, UIPopoverPresentationControllerDelegate {
    private static let shared = AlwaysPopoverPresentationController()
    private override init() {
        super.init()
    }

    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }

    static func configurePresentation(for controller: UIViewController) -> UIPopoverPresentationController {
        controller.modalPresentationStyle = .popover
        let presentationController = controller.presentationController as! UIPopoverPresentationController
        presentationController.delegate = AlwaysPopoverPresentationController.shared
        return presentationController
    }
}
