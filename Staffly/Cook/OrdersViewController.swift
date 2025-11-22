//
//  OrdersViewController.swift
//  Staffly
//
//  Created by Kirill Sysoev on 17.10.2025.
//

import UIKit
import FirebaseDatabase

class OrdersViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    
    let cafeID = UserDefaults.standard.string(forKey: "cafeID")!
    let selfID = UserDefaults.standard.string(forKey: "selfID")!
    var orders: [Product] = []
    var orderKeys: [String] = []
    
    private var ordersRef: DatabaseReference!
    private var alert: UIAlertController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        ordersRef = db.child("Places").child(cafeID).child("orders")
        observeOrders()
    }
    
    func observeOrders() {
        ordersRef.observe(.value) { snapshot in
            var newOrders: [Product] = []
            var keys: [String] = []
            
            for case let tableSnapshot as DataSnapshot in snapshot.children {
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
            
            DispatchQueue.main.async {
                self.orders = newOrders
                self.orderKeys = keys
                self.tableView.reloadData()
            }
        }
    }
    
    func showLoadingAlert() {
        alert = UIAlertController(title: nil, message: "Обработка...", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(style: .medium)
        
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.startAnimating()
        
        alert?.view.addSubview(loadingIndicator)
        
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: alert!.view.centerXAnchor),
            loadingIndicator.topAnchor.constraint(equalTo: alert!.view.topAnchor, constant: 55)
        ])
        present(alert!, animated: true, completion: nil)
    }
    
    func hideLoadingAlert() {
        alert?.dismiss(animated: true, completion: nil)
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
        cell.productImageView.image = globalImageCache[product.id] ?? UIImage(named: "блюдо")
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
        let product = orders[indexPath.row]
        
        let deleteAction = UIContextualAction(style: .destructive, title: "Готово") { _, _, completionHandler in
            self.showLoadingAlert()
            self.ordersRef.removeAllObservers()
            
            self.ordersRef.observeSingleEvent(of: .value) { snapshot in
                for case let tableSnapshot as DataSnapshot in snapshot.children {
                    let tableNumber = tableSnapshot.key
                    if tableSnapshot.hasChild(key) {
                        let orderRef = self.ordersRef.child(tableNumber).child(key)
                        let readyRef = db.child("Places").child(self.cafeID).child("readyOrders").child(tableNumber).child(key)
                        
                        orderRef.observeSingleEvent(of: .value) { orderSnap in
                            guard let value = orderSnap.value as? [String: Any] else {
                                self.hideLoadingAlert()
                                completionHandler(false)
                                self.observeOrders()
                                return
                            }
                            
                            readyRef.setValue(value) { error, _ in
                                guard error == nil else {
                                    self.hideLoadingAlert()
                                    completionHandler(false)
                                    self.observeOrders()
                                    return
                                }
                                
                                orderRef.removeValue { error, _ in
                                    guard error == nil else {
                                        self.hideLoadingAlert()
                                        completionHandler(false)
                                        self.observeOrders()
                                        return
                                    }
                                    
                                    downloadUserData(self.cafeID, self.selfID) { employeeData in
                                        employee = employeeData
                                        employee.productsCount += 1
                                        employee.cafeProfit += product.productPrice
                                        
                                        uploadUserData(self.cafeID, self.selfID, employee) { _ in
                                            DispatchQueue.main.async {
                                                self.orders.remove(at: indexPath.row)
                                                self.orderKeys.remove(at: indexPath.row)
                                                self.tableView.deleteRows(at: [indexPath], with: .fade)
                                                self.hideLoadingAlert()
                                                completionHandler(true)
                                                self.observeOrders()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        break
                    }
                }
            }
        }
        
        deleteAction.backgroundColor = .systemGreen
        deleteAction.image = UIImage(systemName: "checkmark.seal.fill")
        
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
}
