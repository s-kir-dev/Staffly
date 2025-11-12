//
//  InviteCodesViewController.swift
//  SepBill
//
//  Created by Kirill Sysoev on 20.10.2025.
//

import UIKit
import FirebaseDatabase

class InviteCodesViewController: UIViewController {
    
    var cafeID = ""

    @IBOutlet weak var generateInviteCodeButton: UIButton!
    @IBOutlet weak var tableView: UITableView!
    
    let loading = UIActivityIndicatorView(style: .large)
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        // получать все коды из БД и выводить в таблицу
        
        loading.hidesWhenStopped = true
        loading.isUserInteractionEnabled = false
        
        loading.center = view.center
        view.addSubview(loading)
        
        cafeID = UserDefaults.standard.string(forKey: "cafeID") ?? ""
        
        tableView.delegate = self
        tableView.dataSource = self
        
        generateInviteCodeButton.addTarget(self, action: #selector(generateInviteCodeButtonTapped), for: .touchUpInside)
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loading.startAnimating()
        downloadInviteCodes(cafeID, completion: { codes in
            inviteCodes = codes
            self.tableView.reloadData()
            self.loading.stopAnimating()
            debugPrint("Пригласительные коды загружены: \(codes.count)")
        })
        
    }
    
    @objc func generateInviteCodeButtonTapped() {
        showAlertTextField("Пригласительный код", "Для генерации кода введите должность")
    }

    func showAlertTextField(_ title: String, _ message: String) {
        let alert = UIAlertController(title: title, message: message + "\n\n", preferredStyle: .alert)
        
        // Создаём SegmentedControl
        let segmentedControl = UISegmentedControl(items: ["Админ", "Повар", "Официант"])
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        alert.view.addSubview(segmentedControl)
        
        // Auto Layout — чтобы красиво встал по центру
        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: alert.view.topAnchor, constant: 100),
            segmentedControl.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor),
            segmentedControl.widthAnchor.constraint(equalToConstant: 220)
        ])
        
        let saveAction = UIAlertAction(title: "Сгенерировать", style: .default) { _ in
            
            
            var selectedRole = ""
            
            switch segmentedControl.selectedSegmentIndex {
            case 0:
                selectedRole = "Admin"
            case 1:
                selectedRole = "Cook"
            case 2:
                selectedRole = "Waiter"
            default: break
            }
            
            alert.dismiss(animated: true) {
                let code = generateInviteCode(role: selectedRole, cafeID: self.cafeID)
                
                downloadInviteCodes(self.cafeID) { codes in
                    inviteCodes = codes
                    self.tableView.reloadData()
                    self.loading.stopAnimating()
                    debugPrint("Пригласительные коды загружены: \(codes.count)")
                }
                
                self.showAlert("Сгенерированный код", code)
            }
        }
        
        let cancelAction = UIAlertAction(title: "Отмена", style: .cancel, handler: nil)
        
        alert.addAction(saveAction)
        alert.addAction(cancelAction)
        
        self.present(alert, animated: true, completion: nil)
    }
    
    func showAlert(_ title: String, _ message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Ок", style: .cancel, handler: nil)
        
        alert.addAction(okAction)
        
        self.present(alert, animated: true, completion: nil)
    }

}

extension InviteCodesViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 130
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return inviteCodes.count
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! InviteCodeTableViewCell
        
        let inviteCode = inviteCodes[indexPath.row]
        
        cell.codeImage.image = UIImage(named: "\(inviteCode.role.lowercased())Icon")
        
        cell.codeLabel.text = "Код: \(inviteCode.code)"
        cell.cafeIDLabel.text = "ID заведения: \(cafeID)"
        
        switch inviteCode.role {
        case "Admin": cell.roleLabel.text = "Должность: Админ"
        case "Cook": cell.roleLabel.text = "Должность: Повар"
        case "Waiter": cell.roleLabel.text = "Должность: Официант"
        default: break
        }
        
        cell.selectionStyle = .none
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: "Удалить", handler: { _, _, _ in
            let inviteCode = inviteCodes[indexPath.row]
            db.child("Places").child(self.cafeID).child("inviteCodes").child(inviteCode.code).removeValue()
            inviteCodes.remove(at: indexPath.row)
            tableView.reloadData()
        })
        
        deleteAction.backgroundColor = .red
        deleteAction.image = UIImage(systemName: "trash.fill")!
        
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
}
