//
//  EmployeeStatsViewController.swift
//  Staffly
//
//  Created by Kirill Sysoev on 07.11.2025.
//

import UIKit

class EmployeeStatsViewController: UIViewController {

    @IBOutlet weak var profileImage: UIImageView!
    @IBOutlet weak var nameSurnameLabel: UILabel!
    @IBOutlet weak var selfIDLabel: UILabel!
    @IBOutlet weak var roleLabel: UILabel!
    @IBOutlet weak var tablesCountLabel: UILabel!
    @IBOutlet weak var tablesCountValueLabel: UILabel!
    @IBOutlet weak var cafeProfitValueLabel: UILabel!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    
    var selectedEmployee = Employee(id: "", name: "", surname: "", email: "", password: "", role: "", tablesCount: 0, tips: 0.0, productsCount: 0, cafeProfit: 0.0, profileImageURL: "")
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI(role: selectedEmployee.role)
    }
    
    func setupUI(role: String) {
        switch role {
        case "Admin":
            profileImage.image = UIImage(named: "adminIcon")
            roleLabel.text = "Администратор"
            tablesCountLabel.text = "Столов обслужено:"
            tablesCountValueLabel.text = "\(selectedEmployee.tablesCount)"
            cafeProfitValueLabel.text = "+\(selectedEmployee.cafeProfit)р."
        case "Waiter":
            profileImage.image = UIImage(named: "waiterIcon")
            roleLabel.text = "Официант"
            tablesCountLabel.text = "Столов обслужено:"
            tablesCountValueLabel.text = "\(selectedEmployee.tablesCount)"
            cafeProfitValueLabel.text = "+\(selectedEmployee.cafeProfit)р."
        case "Cook":
            profileImage.image = UIImage(named: "cookIcon")
            roleLabel.text = "Повар"
            tablesCountLabel.text = "Блюд приготовлено:"
            tablesCountValueLabel.text = "\(selectedEmployee.productsCount)"
            cafeProfitValueLabel.text = "+\(selectedEmployee.cafeProfit)р."
        default: break
        }
        
        nameSurnameLabel.text = "\(selectedEmployee.name) \(selectedEmployee.surname)"
        selfIDLabel.text = "ID: \(selectedEmployee.id)"
        
        emailTextField.text = selectedEmployee.email
        passwordTextField.text = selectedEmployee.password
    }

}
