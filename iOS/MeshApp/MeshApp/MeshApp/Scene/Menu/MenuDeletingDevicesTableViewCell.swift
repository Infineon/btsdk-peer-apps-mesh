/*
 * Copyright Cypress Semiconductor
 */

/** @file
 *
 * Deleting devices menu item table cell implementation.
 */

import UIKit

class MenuDeletingDevicesTableViewCell: UITableViewCell {
    @IBOutlet weak var deletingDevicesIconImage: UIImageView!
    @IBOutlet weak var deletingDevicesMessageLabel: UILabel!

    var parentVC: UIViewController?

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        //super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
