//
//  ProductTableViewCell.swift
//  SepBill
//
//  Created by Kirill Sysoev on 17.10.2025.
//

import UIKit

class ProductTableViewCell: UITableViewCell {

    @IBOutlet weak var menuNumberLabel: UILabel!
    @IBOutlet weak var productImageView: UIImageView!
    @IBOutlet weak var productNameLabel: UILabel!
    @IBOutlet weak var productPriceLabel: UILabel!
    @IBOutlet weak var productSwitch: UISwitch!
    @IBOutlet weak var clientNumberLabel: UILabel!
    
    var switchAction: (() -> Void)?
    
    @IBAction func productSwitchChanged(_ sender: Any) {
        switchAction?()
    }
    @IBOutlet weak var countLabel: UILabel!
    
    @IBOutlet weak var tableNumberLabel: UILabel!
    
    @IBOutlet weak var additionalWishesLabel: UILabel!
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
