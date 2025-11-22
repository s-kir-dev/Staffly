//
//  InviteCodesViewController.swift
//  Staffly
//
//  Created by Kirill Sysoev on 20.10.2025.
//

import UIKit
import FirebaseDatabase

class InviteCodesViewController: UIViewController {
    
    var cafeID = ""
    var inviteCodes: [InviteCode] = []

    @IBOutlet weak var generateInviteCodeButton: UIButton!
    @IBOutlet weak var tableView: UITableView!
    
    let loading = UIActivityIndicatorView(style: .large)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        cafeID = UserDefaults.standard.string(forKey: "cafeID") ?? ""
        
        tableView.delegate = self
        tableView.dataSource = self
        
        generateInviteCodeButton.addTarget(self, action: #selector(generateInviteCodeButtonTapped), for: .touchUpInside)
        
        loading.hidesWhenStopped = true
        loading.center = view.center
        view.addSubview(loading)
        
        loadInviteCodes()
    }
    
    func loadInviteCodes() {
        loading.startAnimating()
        
        // Сначала делаем однократную загрузку всех кодов
        db.child("Places").child(cafeID).child("inviteCodes").getData { error, snapshot in
            guard error == nil else {
                self.loading.stopAnimating()
                return
            }
            
            var codes: [InviteCode] = []
            if let snapshot = snapshot {
                for child in snapshot.children {
                    if let snap = child as? DataSnapshot,
                       let data = snap.value as? [String: String] {
                        let code = InviteCode(code: data["code"] ?? "", role: data["role"] ?? "")
                        codes.append(code)
                    }
                }
            }
            
            self.inviteCodes = codes
            self.tableView.reloadData()
            self.loading.stopAnimating()
            debugPrint("Пригласительные коды загружены: \(codes.count)")
            
            // После начальной загрузки ставим observer на изменения
            self.observeInviteCodes()
        }
    }
    
    func observeInviteCodes() {
        db.child("Places").child(cafeID).child("inviteCodes").observe(.childRemoved) { snapshot in
            if let index = self.inviteCodes.firstIndex(where: { $0.code == snapshot.key }) {
                self.inviteCodes.remove(at: index)
                self.tableView.reloadData()
            }
        }
    }
    
    @objc func generateInviteCodeButtonTapped() {
        showAlertTextField("Пригласительный код", "Для генерации кода введите должность")
    }
    
    func showAlertTextField(_ title: String, _ message: String) {
        let alert = UIAlertController(title: title, message: message + "\n\n", preferredStyle: .alert)
        
        let segmentedControl = UISegmentedControl(items: ["Админ", "Повар", "Официант"])
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        alert.view.addSubview(segmentedControl)
        
        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: alert.view.topAnchor, constant: 100),
            segmentedControl.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor),
            segmentedControl.widthAnchor.constraint(equalToConstant: 220)
        ])
        
        let saveAction = UIAlertAction(title: "Сгенерировать", style: .default) { _ in
            var selectedRole = ""
            switch segmentedControl.selectedSegmentIndex {
            case 0: selectedRole = "Admin"
            case 1: selectedRole = "Cook"
            case 2: selectedRole = "Waiter"
            default: break
            }
            
            alert.dismiss(animated: true) {
                let code = generateInviteCode(role: selectedRole, cafeID: self.cafeID)
                self.loadInviteCodes()
                self.showAlert("Сгенерированный код", code)
            }
        }
        
        let cancelAction = UIAlertAction(title: "Отмена", style: .cancel)
        
        alert.addAction(saveAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }
    
    func showAlert(_ title: String, _ message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ок", style: .cancel))
        present(alert, animated: true)
    }
}

extension InviteCodesViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { 130 }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        inviteCodes.count
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
        let deleteAction = UIContextualAction(style: .destructive, title: "Удалить") { _, _, _ in
            let inviteCode = self.inviteCodes[indexPath.row]
            db.child("Places").child(self.cafeID).child("inviteCodes").child(inviteCode.code).removeValue()
        }
        deleteAction.backgroundColor = .red
        deleteAction.image = UIImage(systemName: "trash.fill")
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
}
