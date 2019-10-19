/*
 * Copyright Cypress Semiconductor
 */

/** @file
 *
 * Network List empty table view cell implementation.
 */

import UIKit

class NetworkListEmptyTableViewCell: UITableViewCell {
    @IBOutlet weak var emptyImage: UIImageView!
    @IBOutlet weak var emptyMessageLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        // Empty Cell is just for show messages, so should not support select opertions.
        //super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }


}
