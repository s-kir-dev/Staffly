//
//  OrdersViewController.swift
//  SepBill
//
//  Created by Kirill Sysoev on 17.10.2025.
//

import UIKit
import FirebaseDatabase

class OrdersViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    
    let cafeID = UserDefaults.standard.string(forKey: "cafeID")!
    var orders: [Product] = []
    
    var orderKeys: [String] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        
        observeOrders()
    }
    
    func observeOrders() {
        let ordersRef = db.child("Places").child(cafeID).child("orders")
        
        ordersRef.observe(.value) { snapshot in
            var newOrders: [Product] = []
            var keys: [String] = []
            
            for case let tableSnapshot as DataSnapshot in snapshot.children {
                _ = tableSnapshot.key
                
                for case let orderSnapshot as DataSnapshot in tableSnapshot.children {
                    if let dict = orderSnapshot.value as? [String: Any],
                       let id = dict["id"] as? String,
                       let menuNumber = dict["menuNumber"] as? Int,
                       let productCategory = dict["productCategory"] as? String,
                       let productDescription = dict["productDescription"] as? String,
                       let productImageURL = dict["productImageURL"] as? String,
                       let productName = dict["productName"] as? String,
                       let productPrice = dict["productPrice"] as? Double {
                        
                        let additionWishes = dict["additionWishes"] as? String ?? ""
                        let product = Product(
                            id: id,
                            menuNumber: menuNumber,
                            productCategory: productCategory,
                            productDescription: productDescription,
                            productImageURL: productImageURL,
                            productName: productName,
                            productPrice: productPrice,
                            additionWishes: additionWishes
                        )
                        
                        newOrders.append(product)
                        keys.append(orderSnapshot.key)
                    }
                }
            }
            
            self.orders = newOrders
            self.orderKeys = keys
            self.tableView.reloadData()
        }
    }
}

extension OrdersViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return orders.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! ProductTableViewCell
        let product = orders[indexPath.row]
        
        cell.productImageView.layer.cornerRadius = 17
        cell.productImageView.clipsToBounds = true
        cell.productImageView.image = globalImageCache[product.id] ?? UIImage(systemName: "house")
        cell.productNameLabel.text = product.productName
        cell.additionalWishesLabel.text = product.additionWishes
        cell.selectionStyle = .none
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 155
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let key = orderKeys[indexPath.row]
        _ = orders[indexPath.row]
        
        let deleteAction = UIContextualAction(style: .destructive, title: "Готово") { _, _, completionHandler in
            let ordersRef = db.child("Places").child(self.cafeID).child("orders")
            
            ordersRef.observeSingleEvent(of: .value) { snapshot in
                for case let tableSnapshot as DataSnapshot in snapshot.children {
                    let tableNumber = tableSnapshot.key
                    if tableSnapshot.hasChild(key) {
                        let orderRef = ordersRef.child(tableNumber).child(key)
                        let readyRef = db.child("Places").child(self.cafeID).child("readyOrders").child(tableNumber).child(key)
                        
                        orderRef.observeSingleEvent(of: .value) { orderSnap in
                            if let value = orderSnap.value as? [String: Any] {
                                readyRef.setValue(value) { error, _ in
                                    if error == nil {
                                        orderRef.removeValue()
                                    }
                                }
                            }
                        }
                        break
                    }
                }
            }
            
            completionHandler(true)
        }
        
        deleteAction.backgroundColor = .systemGreen
        deleteAction.image = UIImage(systemName: "checkmark.seal.fill")
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
}
