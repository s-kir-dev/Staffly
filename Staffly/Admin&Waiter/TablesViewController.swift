//
//  TablesViewController.swift
//  SepBill
//
//  Created by Kirill Sysoev on 17.10.2025.
//

import UIKit
import FirebaseDatabase

class TablesViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var emptyImageView: UIImageView!
    @IBOutlet weak var plusButton: UIButton!
    
    var currentClient: Int = 0
    var tableIndex: Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self

        plusButton.addTarget(self, action: #selector(plusButtonTapped), for: .touchUpInside)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if tables.isEmpty {
            emptyImageView.isHidden = false
        } else {
            emptyImageView.isHidden = true
        }
        
        
        tableView.reloadData()
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
        let tableNumber = tables[indexPath.row].number
        guard let cafeID = UserDefaults.standard.string(forKey: "cafeID") else {
            return UISwipeActionsConfiguration(actions: [])
        }

        let deleteAction = UIContextualAction(style: .destructive, title: "Удалить") { _, _, completionHandler in
            let baseRef = db.child("Places").child(cafeID)

            let group = DispatchGroup()

            let pathsToRemove = [
                baseRef.child("orders").child("\(tableNumber)"),
                baseRef.child("readyOrders").child("\(tableNumber)"),
                baseRef.child("tables").child("\(tableNumber)")
            ]

            for ref in pathsToRemove {
                group.enter()
                ref.removeValue { error, _ in
                    if let error = error {
                        print("Ошибка при удалении \(ref): \(error.localizedDescription)")
                    }
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                tables.remove(at: indexPath.row)
                saveTables(tables)
                
                if tables.isEmpty {
                    self.emptyImageView.isHidden = false
                } else {
                    self.emptyImageView.isHidden = true
                }

                tableView.deleteRows(at: [indexPath], with: .automatic)
                completionHandler(true)
            }
        }

        let updatePeopleCountAction = UIContextualAction(style: .normal, title: "Изменить") { _, _, completionHandler in
            let alert = UIAlertController(title: "Изменить количество людей", message: "Введите новое количество людей за столом", preferredStyle: .alert)
            alert.addTextField { textField in
                textField.placeholder = "Количество людей"
                textField.keyboardType = .numberPad
            }

            let saveAction = UIAlertAction(title: "Сохранить", style: .default) { _ in
                if let countText = alert.textFields?.first?.text, let count = Int(countText), (1...6).contains(count) {
                    if isBigger(count, tables[indexPath.row].personCount) {
                        tables[indexPath.row].maximumPersonCount = count
                    }
                    tables[indexPath.row].personCount = count
                    saveTables(tables)
                    self.tableView.reloadData()
                } else {
                    let errorAlert = UIAlertController(title: "Ошибка", message: "Количество людей должно быть от 1 до 6.", preferredStyle: .alert)
                    errorAlert.addAction(UIAlertAction(title: "Ок", style: .default))
                    self.present(errorAlert, animated: true)
                }
            }

            alert.addAction(saveAction)
            alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
            self.present(alert, animated: true)
            completionHandler(true)
        }

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
