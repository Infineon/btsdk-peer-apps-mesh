/*
 * Copyright Cypress Semiconductor
 */

/** @file
 *
 * Group List empty table view cell implementation.
 */

import UIKit

class GroupListEmptyTableViewCell: UITableViewCell {
    @IBOutlet weak var emptyImage: UIImageView!
    @IBOutlet weak var emptyMessage: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        //super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
