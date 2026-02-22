//
//  TablesViewController.swift
//  Staffly
//
//  Created by Kirill Sysoev on 17.10.2025.
//

import UIKit
import FirebaseDatabase

class TablesViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var emptyImageView: UIImageView!
    @IBOutlet weak var plusButton: UIButton!
    
    private let refreshControl = UIRefreshControl()
    
    var currentClient: Int = 0
    var tableIndex: Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        tableView.refreshControl = refreshControl

        plusButton.addTarget(self, action: #selector(plusButtonTapped), for: .touchUpInside)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshData()
    }
    
    @objc private func refreshData() {
        guard let cafeID = UserDefaults.standard.string(forKey: "cafeID"),
              let selfID = UserDefaults.standard.string(forKey: "selfID") else {
            self.refreshControl.endRefreshing()
            return
        }
        
        let tablesRef = db.child("Places").child(cafeID).child("employees").child(selfID).child("tables")
        
        tablesRef.observeSingleEvent(of: .value) { snapshot in
            let newTableNumbers = snapshot.value as? [Int] ?? []
            tableNumbers = newTableNumbers
            
            loadTables(cafeID, selfID, newTableNumbers) { fetchedTables in
                let sortedTables = fetchedTables.sorted { $0.number < $1.number }
                tables = sortedTables
                
                tableNumbers = sortedTables.map { $0.number }
                
                DispatchQueue.main.async {
                    self.emptyImageView.isHidden = !tables.isEmpty
                    self.tableView.reloadData()
                    self.refreshControl.endRefreshing()
                    debugPrint("✅ Данные обновлены: столы \(tableNumbers)")
                }
            }
        }
    }

    @objc func plusButtonTapped() {
        performSegue(withIdentifier: "newTableVC", sender: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "orderedProductsVC" {
            if let destination = segue.destination as? OrderedProductsViewController {
                destination.table = tables[tableIndex]
            }
        } else if segue.identifier == "menuVC" {
            if let menuVC = segue.destination as? MenuViewController {
                menuVC.tableIndex = self.tableIndex
                menuVC.currentClient = self.currentClient
            }
        } else if segue.identifier == "billVC" {
            if let billVC = segue.destination as? BillViewController {
                billVC.table = tables[tableIndex]
            }
        }
    }
}



extension TablesViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        tables.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
//        switch tables[indexPath.row].personCount {
//        case 1: return 34
//        case 2: return 80
//        case 3: return 126
//        case 4: return 172
//        case 5: return 218
//        case 6: return 264
//        default: return 264
//        }
        
        return 264
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let table = tables[indexPath.row]
        
        let cafeID = UserDefaults.standard.string(forKey: "cafeID") ?? ""
        let selfID = UserDefaults.standard.string(forKey: "selfID") ?? ""
        
        let qrImage = generateTableQR(cafeID, table.number, table.personCount, selfID)
        
        let alert = UIAlertController(
            title: "Для добавления отсканируйте",
            message: "QR-код для стола №\(table.number):",
            preferredStyle: .alert
        )
        
        if let qr = qrImage {
            let imageView = UIImageView(image: qr)
            imageView.contentMode = .scaleAspectFit
            
            imageView.translatesAutoresizingMaskIntoConstraints = false
            alert.view.addSubview(imageView)
            
            NSLayoutConstraint.activate([
                imageView.topAnchor.constraint(equalTo: alert.view.topAnchor, constant: 70),
                imageView.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 150),
                imageView.heightAnchor.constraint(equalToConstant: 150),
                alert.view.bottomAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 70)
            ])
        }
        
        let okAction = UIAlertAction(title: "Ок", style: .default) { _ in
            self.navigationController?.popViewController(animated: true)
        }
        
        alert.addAction(okAction)
        self.present(alert, animated: true)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let table = tables[indexPath.row]
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "tableCell", for: indexPath) as! TablesTableViewCell
        
        let buttons: [UIButton] = [cell.client1Button, cell.client2Button, cell.client3Button, cell.client4Button, cell.client5Button, cell.client6Button]
        let bills: [UILabel] = [cell.client1BillLabel, cell.client2BillLabel, cell.client3BillLabel, cell.client4BillLabel, cell.client5BillLabel, cell.client6BillLabel]
        
        for index in 0..<table.personCount { // обновление UI после изменения количества клиентов
            buttons[index].isHidden = false
            bills[index].isHidden = false
        }
        
        for index in table.personCount..<buttons.count {
            buttons[index].isHidden = true
            bills[index].isHidden = true
        }
        
        cell.tableImage.image = UIImage(named: "table")
        cell.tableNumberLabel.text = "Стол №\(table.number)"
        cell.client1BillLabel.text = "\(table.client1Bill.roundValue())р."
        cell.client2BillLabel.text = "\(table.client2Bill.roundValue())р."
        cell.client3BillLabel.text = "\(table.client3Bill.roundValue())р."
        cell.client4BillLabel.text = "\(table.client4Bill.roundValue())р."
        cell.client5BillLabel.text = "\(table.client5Bill.roundValue())р."
        cell.client6BillLabel.text = "\(table.client6Bill.roundValue())р."
        cell.tableBillLabel.text = "\(table.bill.roundValue())р."
        
        cell.layer.cornerRadius = 15
        cell.selectionStyle = .none
        
        cell.client1ButtonAction = {
            self.currentClient = 1
            self.tableIndex = indexPath.row
            self.performSegue(withIdentifier: "menuVC", sender: self)
        }
        
        cell.client2ButtonAction = {
            self.currentClient = 2
            self.tableIndex = indexPath.row
            self.performSegue(withIdentifier: "menuVC", sender: self)
        }
        
        cell.client3ButtonAction = {
            self.currentClient = 3
            self.tableIndex = indexPath.row
            self.performSegue(withIdentifier: "menuVC", sender: self)
        }
        
        cell.client4ButtonAction = {
            self.currentClient = 4
            self.tableIndex = indexPath.row
            self.performSegue(withIdentifier: "menuVC", sender: self)
        }
        
        cell.client5ButtonAction = {
            self.currentClient = 5
            self.tableIndex = indexPath.row
            self.performSegue(withIdentifier: "menuVC", sender: self)
        }
        
        cell.client6ButtonAction = {
            self.currentClient = 6
            self.tableIndex = indexPath.row
            self.performSegue(withIdentifier: "menuVC", sender: self)
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let cafeID = UserDefaults.standard.string(forKey: "cafeID") else {
            return UISwipeActionsConfiguration(actions: [])
        }

        let deleteAction = UIContextualAction(style: .destructive, title: "Удалить") { _, _, completionHandler in
            let tableToDelete = tables[indexPath.row]
            let tableNumber = tableToDelete.number
            
            let alert = UIAlertController(title: "Вы уверены?", message: "Вы уверены, что хотите удалить стол №\(tableNumber)?", preferredStyle: .alert)
            
            let cancelAction = UIAlertAction(title: "Отмена", style: .cancel) { _ in
                completionHandler(false)
            }
            
            let deleteConfirm = UIAlertAction(title: "Удалить", style: .destructive) { _ in
                let selfID = UserDefaults.standard.string(forKey: "selfID") ?? ""
                let baseRef = db.child("Places").child(cafeID)
                let group = DispatchGroup()
                
                group.enter()
                removeTable(cafeID, selfID, tableToDelete) {
                    group.leave()
                }
                
                let pathsToRemove = [
                    baseRef.child("orders").child("\(tableNumber)"),
                    baseRef.child("readyOrders").child("\(tableNumber)"),
                    baseRef.child("tables").child("\(tableNumber)")
                ]
                
                for ref in pathsToRemove {
                    group.enter()
                    ref.removeValue { error, _ in
                        if let error = error {
                            print("Ошибка удаления пути \(ref.key ?? ""): \(error.localizedDescription)")
                        }
                        group.leave()
                    }
                }
                
                group.notify(queue: .main) {
                    if indexPath.row < tables.count {
                        tables.remove(at: indexPath.row)
                        
                        tableView.performBatchUpdates({
                            tableView.deleteRows(at: [indexPath], with: .fade)
                        }, completion: { _ in
                            self.emptyImageView.isHidden = !tables.isEmpty
                            completionHandler(true)
                        })
                    }
                }
            }
            
            alert.addAction(cancelAction)
            alert.addAction(deleteConfirm)
            self.present(alert, animated: true)
        }


        let updatePeopleCountAction = UIContextualAction(style: .normal, title: "Изменить") { [weak self] _, _, completionHandler in
            guard let self = self else { return }
            let table = tables[indexPath.row]
            let alert = UIAlertController(title: "Изменить количество людей", message: "Введите новое количество людей за столом №\(table.number)", preferredStyle: .alert)
            
            alert.addTextField { textField in
                textField.placeholder = "Количество людей"
                textField.keyboardType = .numberPad
            }

            let saveAction = UIAlertAction(title: "Сохранить", style: .default) { _ in
                guard let countText = alert.textFields?.first?.text,
                      let count = Int(countText), (1...6).contains(count) else {
                    let errorAlert = UIAlertController(title: "Ошибка", message: "Количество людей должно быть от 1 до 6.", preferredStyle: .alert)
                    errorAlert.addAction (UIAlertAction(title: "OK", style: .default, handler: {_ in
                        completionHandler(false)
                    }))
                    self.present(errorAlert, animated: true)
                    return
                }
                
                if count != table.personCount {
                    tables[indexPath.row].personCount = count
                    if count > tables[indexPath.row].maximumPersonCount {
                        tables[indexPath.row].maximumPersonCount = count
                    }
                    
                    updateTableData(cafeID, tables[indexPath.row]) {
                        DispatchQueue.main.async {
                            self.refreshData()
                            completionHandler(true)
                        }
                    }
                } else {
                    completionHandler(true)
                }
            }

            let cancelAction = UIAlertAction(title: "Отмена", style: .cancel) { _ in
                completionHandler(false)
            }

            alert.addAction(saveAction)
            alert.addAction(cancelAction)
            self.present(alert, animated: true)
        }

        updatePeopleCountAction.backgroundColor = .systemMint
        updatePeopleCountAction.image = UIImage(systemName: "square.and.pencil")

        let showOrderedProductsAction = UIContextualAction(style: .normal, title: "Заказы") { _, _, _ in
            self.tableIndex = indexPath.row
            self.performSegue(withIdentifier: "orderedProductsVC", sender: nil)
        }

        let billAction = UIContextualAction(style: .normal, title: "Чек") { _, _, _ in
            self.tableIndex = indexPath.row
            self.performSegue(withIdentifier: "billVC", sender: indexPath)
        }

        deleteAction.image = UIImage(systemName: "trash.fill")
        deleteAction.backgroundColor = .red
        updatePeopleCountAction.backgroundColor = .systemBlue.withAlphaComponent(0.5)
        updatePeopleCountAction.image = UIImage(systemName: "square.and.pencil")
        showOrderedProductsAction.image = UIImage(systemName: "list.number")
        showOrderedProductsAction.backgroundColor = .systemPurple
        billAction.backgroundColor = .systemMint.withAlphaComponent(0.95)
        billAction.image = UIImage(systemName: "wallet.pass")

        return UISwipeActionsConfiguration(actions: [billAction, showOrderedProductsAction, updatePeopleCountAction, deleteAction])
    }
}
