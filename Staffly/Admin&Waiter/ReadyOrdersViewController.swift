//
//  ReadyOrdersViewController.swift
//  Staffly
//
//  Created by Kirill Sysoev on 31.10.2025.
//

import UIKit
import FirebaseDatabase

class ReadyOrdersViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    
    let cafeID = UserDefaults.standard.string(forKey: "cafeID")!
    var readyOrders: [ReadyOrder] = []
    
    var readyOrderKeys: [String] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        
        
        observeReadyOrders()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        downloadReadyOrders()
    }
    
    func observeReadyOrders() {
        let ordersRef = db.child("Places").child(cafeID).child("readyOrders")
        
        ordersRef.observe(.value) { snapshot in
            var readyOrders: [ReadyOrder] = []
            var keys: [String] = []
            
            // Перебираем все столы
            for case let tableSnapshot as DataSnapshot in snapshot.children {
                let tableNumberString = tableSnapshot.key
                let tableNumber = Int(tableNumberString) ?? 0
                
                // Перебираем все заказы (UUID) внутри стола
                for case let orderSnapshot as DataSnapshot in tableSnapshot.children {
                    if let dict = orderSnapshot.value as? [String: Any],
                       let clientNumber = dict["b clientNumber"] as? Int,
                       let id = dict["id"] as? String,
                       let menuNumber = dict["menuNumber"] as? Int,
                       let productCategory = dict["productCategory"] as? String,
                       let productDescription = dict["productDescription"] as? String,
                       let productImageURL = dict["productImageURL"] as? String,
                       let productName = dict["productName"] as? String,
                       let productPrice = dict["productPrice"] as? Double {
                        
                        let additionWishes = dict["additionWishes"] as? String ?? ""
                        
                        // Показываем только те, что с моих столов
                        if tables.firstIndex(where: { $0.number == tableNumber }) != nil {
                            let product = ReadyOrder(
                                tableNumber: tableNumber,
                                clientNumber: clientNumber,
                                id: id,
                                menuNumber: menuNumber,
                                productCategory: productCategory,
                                productDescription: productDescription,
                                productImageURL: productImageURL,
                                productName: productName,
                                productPrice: productPrice,
                                additionWishes: additionWishes
                            )
                            
                            readyOrders.append(product)
                            keys.append(orderSnapshot.key)
                        }
                    }
                }
            }
            
            self.readyOrders = readyOrders
            self.readyOrderKeys = keys
            self.tableView.reloadData()
        }
    }
    
    func downloadReadyOrders() {
        let ordersRef = db.child("Places").child(cafeID).child("readyOrders")
        
        ordersRef.observeSingleEvent(of: .value, with: { snapshot in
            var readyOrders: [ReadyOrder] = []
            var keys: [String] = []
            
            for case let tableSnapshot as DataSnapshot in snapshot.children {
                let tableNumberString = tableSnapshot.key
                let tableNumber = Int(tableNumberString) ?? 0
                
                for case let orderSnapshot as DataSnapshot in tableSnapshot.children {
                    if let dict = orderSnapshot.value as? [String: Any],
                       let clientNumber = dict["b clientNumber"] as? Int,
                       let id = dict["id"] as? String,
                       let menuNumber = dict["menuNumber"] as? Int,
                       let productCategory = dict["productCategory"] as? String,
                       let productDescription = dict["productDescription"] as? String,
                       let productImageURL = dict["productImageURL"] as? String,
                       let productName = dict["productName"] as? String,
                       let productPrice = dict["productPrice"] as? Double {
                        
                        let additionWishes = dict["additionWishes"] as? String ?? ""
                        
                        if tables.firstIndex(where: { $0.number == tableNumber }) != nil {
                            let product = ReadyOrder(
                                tableNumber: tableNumber,
                                clientNumber: clientNumber,
                                id: id,
                                menuNumber: menuNumber,
                                productCategory: productCategory,
                                productDescription: productDescription,
                                productImageURL: productImageURL,
                                productName: productName,
                                productPrice: productPrice,
                                additionWishes: additionWishes
                            )
                            
                            readyOrders.append(product)
                            keys.append(orderSnapshot.key)
                        }
                    }
                }
            }
            
            self.readyOrders = readyOrders
            self.readyOrderKeys = keys
            self.tableView.reloadData()
        })
    }
}

extension ReadyOrdersViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return readyOrders.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! ProductTableViewCell
        let product = readyOrders[indexPath.row]
        
        cell.productImageView.layer.cornerRadius = 17
        cell.productImageView.clipsToBounds = true
        cell.productImageView.image = globalImageCache[product.id] ?? UIImage(named: "блюдо")
        cell.productNameLabel.text = product.productName
        cell.clientNumberLabel.text = "Клиент \(product.clientNumber)"
        cell.tableNumberLabel.text = "Стол №\(product.tableNumber)"
        
        cell.selectionStyle = .none
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 155
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let key = readyOrderKeys[indexPath.row]
        let tableNumber = readyOrders[indexPath.row].tableNumber
        
        let deleteAction = UIContextualAction(style: .destructive, title: "Удалить") { _, _, completionHandler in
            let orderRef = db.child("Places").child(self.cafeID)
                                 .child("readyOrders")
                                 .child("\(tableNumber)")
                                 .child(key)

            orderRef.removeValue()
            
            completionHandler(true)
        }
        
        deleteAction.backgroundColor = .red
        deleteAction.image = UIImage(systemName: "trash.fill")
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
}

