/*
 * Copyright Cypress Semiconductor
 */

/** @file
 *
 * My Groups table cell for Menu Scene implementation.
 */

import UIKit

class MenuMyGroupsTableViewCell: UITableViewCell {
    @IBOutlet weak var myGroupsIconImageView: UIImageView!
    @IBOutlet weak var myGroupsMessageLabel: UILabel!

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
