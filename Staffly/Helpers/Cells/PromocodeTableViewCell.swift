//
//  PromocodeTableViewCell.swift
//  Staffly
//
//  Created by Kirill Sysoev on 24.02.2026.
//

import UIKit

class PromocodeTableViewCell: UITableViewCell {

    @IBOutlet weak var promocodeLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var saleTypeLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
