/*
 * Copyright Cypress Semiconductor
 */

/** @file
 *
 * My Network table cell for Menu Scene implementation.
 */

import UIKit

class MenuMyNetworkTableViewCell: UITableViewCell {
    @IBOutlet weak var myNetworkIconImageView: UIImageView!
    @IBOutlet weak var myNetworkMessageLable: UILabel!

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
