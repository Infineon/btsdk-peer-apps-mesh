/*
 * Copyright Cypress Semiconductor
 */

/** @file
 *
 * Deleting devices empty table view cell implementation.
 */

import UIKit

class DeletingDevicesEmptyTableViewCell: UITableViewCell {
    @IBOutlet weak var emptyImage: UIImageView!
    @IBOutlet weak var emptyMessageLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        //super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
