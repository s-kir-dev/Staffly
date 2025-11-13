//
//  EmployeesViewController.swift
//  Staffly
//
//  Created by Kirill Sysoev on 11.11.2025.
//

import UIKit
import FirebaseDatabase

class EmployeesViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    
    var employees: [Employee] = []
    var selectedEmployee = Employee(id: "", name: "", surname: "", email: "", password: "", role: "", tablesCount: 0, tips: 0.0, productsCount: 0, cafeProfit: 0.0)
    
    let loading = UIActivityIndicatorView(style: .large)
    let cafeID = UserDefaults.standard.string(forKey: "cafeID")!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        loading.hidesWhenStopped = true
        loading.center = view.center
        view.addSubview(loading)
        loading.startAnimating()
        
        downloadEmployeesData(cafeID: cafeID) { employeesData in
            DispatchQueue.main.async {
                self.employees = employeesData
                self.tableView.reloadData()
                self.loading.stopAnimating()
            }
        }
    }
    
    func downloadEmployeesData(cafeID: String, completion: @escaping ([Employee]) -> Void) {
        let dbRef = db.child("Places").child(cafeID).child("employees")
        dbRef.observeSingleEvent(of: .value) { snapshot in
            var employees: [Employee] = []
            
            for child in snapshot.children {
                if let snap = child as? DataSnapshot,
                   let value = snap.value as? [String: Any] {
                    let selfID = snap.key
                    let employee = Employee(
                        id: selfID,
                        name: value["name"] as? String ?? "",
                        surname: value["surname"] as? String ?? "",
                        email: value["email"] as? String ?? "",
                        password: value["password"] as? String ?? "",
                        role: value["role"] as? String ?? "",
                        tablesCount: value["tablesCount"] as? Int ?? 0,
                        tips: (value["tips"] as? Double ?? 0.0).roundValue(),
                        productsCount: value["productsCount"] as? Int ?? 0,
                        cafeProfit: value["cafeProfit"] as? Double ?? 0.0
                    )
                    employees.append(employee)
                }
            }
            completion(employees)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "statsVC" {
            let destinationVC = segue.destination as! EmployeeStatsViewController
            destinationVC.selectedEmployee = selectedEmployee
        }
    }
}

extension EmployeesViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedEmployee = employees[indexPath.row]
        performSegue(withIdentifier: "statsVC", sender: self)
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return employees.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell") as! EmployeeTableViewCell
        let employee = employees[indexPath.row]
        
        switch employee.role {
        case "Admin":
            cell.roleImageView.image = UIImage(named: "adminIcon")
            cell.roleLabel.text = "Администратор"
        case "Waiter":
            cell.roleImageView.image = UIImage(named: "waiterIcon")
            cell.roleLabel.text = "Официант"
        case "Cook":
            cell.roleImageView.image = UIImage(named: "cookIcon")
            cell.roleLabel.text = "Повар"
        default: break
        }
        
        cell.nameSurnameLabel.text = "\(employee.name) \(employee.surname)"
        cell.selfIDLabel.text = "\(employee.id)"
        cell.selectionStyle = .none
        
        return cell
    }
        
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 130
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let employeeToFire = employees[indexPath.row]

        let deleteAction = UIContextualAction(style: .destructive, title: "Уволить сотрудника") { _, _, completionHandler in
            self.loading.startAnimating()
            let cafeID = UserDefaults.standard.string(forKey: "cafeID")!
            
            db.child("Places").child(cafeID).child("employees").child(employeeToFire.id).removeValue { error, _ in
                guard error == nil else {
                    DispatchQueue.main.async {
                        self.loading.stopAnimating()
                    }
                    completionHandler(false)
                    return
                }
                
                self.downloadEmployeesData(cafeID: cafeID) { employeesData in
                    DispatchQueue.main.async {
                        self.employees = employeesData
                        self.tableView.reloadData()
                        self.loading.stopAnimating()
                        completionHandler(true)
                    }
                }
            }
        }
        
        deleteAction.backgroundColor = .red
        deleteAction.image = UIImage(systemName: "trash.fill")
        
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
}
