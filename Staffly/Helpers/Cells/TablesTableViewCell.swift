//
//  TablesTableViewCell.swift
//  Staffly
//
//  Created by Kirill Sysoev on 31.10.2025.
//

import UIKit

class TablesTableViewCell: UITableViewCell {
    
    
    @IBOutlet weak var tableNumberLabel: UILabel!
    @IBOutlet weak var tableImage: UIImageView!
    
    @IBOutlet weak var client1Button: UIButton!
    @IBOutlet weak var client2Button: UIButton!
    @IBOutlet weak var client3Button: UIButton!
    @IBOutlet weak var client4Button: UIButton!
    @IBOutlet weak var client5Button: UIButton!
    @IBOutlet weak var client6Button: UIButton!
    @IBOutlet weak var client1BillLabel: UILabel!
    @IBOutlet weak var client2BillLabel: UILabel!
    @IBOutlet weak var client3BillLabel: UILabel!
    @IBOutlet weak var client4BillLabel: UILabel!
    @IBOutlet weak var client5BillLabel: UILabel!
    @IBOutlet weak var client6BillLabel: UILabel!
    @IBOutlet weak var tableBillLabel: UILabel!
    
    var client1ButtonAction: (() -> Void)?
    var client2ButtonAction: (() -> Void)?
    var client3ButtonAction: (() -> Void)?
    var client4ButtonAction: (() -> Void)?
    var client5ButtonAction: (() -> Void)?
    var client6ButtonAction: (() -> Void)?
    
    @IBAction func client1ButtonTapped(_ sender: Any) {
        client1ButtonAction?()
    }
    
    @IBAction func client2ButtonTapped(_ sender: Any) {
        client2ButtonAction?()
    }
    
    @IBAction func client3ButtonTapped(_ sender: Any) {
        client3ButtonAction?()
    }
    
    @IBAction func client4ButtonTapped(_ sender: Any) {
        client4ButtonAction?()
    }
    
    @IBAction func client5ButtonTapped(_ sender: Any) {
        client5ButtonAction?()
    }
    
    @IBAction func client6ButtonTapped(_ sender: Any) {
        client6ButtonAction?()
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
