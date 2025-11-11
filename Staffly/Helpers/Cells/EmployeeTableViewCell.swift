//
//  EmployeeTableViewCell.swift
//  Staffly
//
//  Created by Kirill Sysoev on 11.11.2025.
//

import UIKit

class EmployeeTableViewCell: UITableViewCell {

    @IBOutlet weak var roleImageView: UIImageView!
    @IBOutlet weak var nameSurnameLabel: UILabel!
    @IBOutlet weak var selfIDLabel: UILabel!
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
