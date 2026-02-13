//
//  MessageTableViewCell.swift
//  Staffly
//
//  Created by Kirill Sysoev on 14.02.2026.
//

import UIKit

class MessageTableViewCell: UITableViewCell {

    @IBOutlet weak var messageLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
