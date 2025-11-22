//
//  InviteCodeTableViewCell.swift
//  Staffly
//
//  Created by Kirill Sysoev on 25.10.2025.
//

import UIKit

class InviteCodeTableViewCell: UITableViewCell {
    
    @IBOutlet weak var codeImage: UIImageView!
    @IBOutlet weak var codeLabel: UILabel!
    @IBOutlet weak var cafeIDLabel: UILabel!
    @IBOutlet weak var roleLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
