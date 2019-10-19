/*
 * Copyright Cypress Semiconductor
 */

/** @file
 *
 * Title table cell for Menu Scene implementation.
 */

import UIKit

class MenuTitleTableViewCell: UITableViewCell {
    @IBOutlet weak var menuTitleImageView: UIImageView!
    @IBOutlet weak var accountNameLabel: UILabel!
    @IBOutlet weak var accountEmailLabel: UILabel!
    @IBOutlet weak var clickFlagLabel: UILabel!

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
