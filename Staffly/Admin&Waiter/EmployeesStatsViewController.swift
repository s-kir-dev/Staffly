//
//  EmployeesStatsViewController.swift
//  Staffly
//
//  Created by Kirill Sysoev on 07.11.2025.
//

import UIKit

class EmployeesStatsViewController: UIViewController {

    @IBOutlet weak var profileImage: UIImageView!
    @IBOutlet weak var nameSurnameLabel: UILabel!
    @IBOutlet weak var selfIDLabel: UILabel!
    @IBOutlet weak var roleLabel: UILabel!
    @IBOutlet weak var tablesCountLabel: UILabel!
    @IBOutlet weak var tablesCountValueLabel: UILabel!
    @IBOutlet weak var cafeProfitLabel: UILabel!
    @IBOutlet weak var cafeProfitValueLabel: UILabel!
    @IBOutlet weak var dishesCountLabel: UILabel!
    @IBOutlet weak var dishesCountValueLabel: UILabel!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let cafeID = UserDefaults.standard.string(forKey: "cafeID")!
        let selfID = UserDefaults.standard.string(forKey: "selfID")!
        downloadUserData(cafeID, selfID, completion: {
            employeeData in
            self.setupUI(role: employeeData.role)
        })
    }
    
    func setupUI(role: String) {
        
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
