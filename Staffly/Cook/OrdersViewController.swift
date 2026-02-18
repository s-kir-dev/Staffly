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
    var orders: [ReadyOrder] = []
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
            var newOrders: [ReadyOrder] = []
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
                        let tableNumber = dict["a tableNumber"] as? Int ?? 0
                        let clientNumber = dict["b clientNumber"] as? Int ?? 0
                        
                        let product = ReadyOrder(tableNumber: tableNumber, clientNumber: clientNumber, id: id, menuNumber: menuNumber, productCategory: productCategory, productDescription: productDescription, productImageURL: productImageURL, productName: productName, productPrice: productPrice, additionWishes: additionWishes)
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
        // Добавляем задержку 0.3 сек, чтобы алерт успел отобразиться перед закрытием
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.alert?.dismiss(animated: true, completion: nil)
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
        // Захватываем данные ДО начала асинхронной операции
        let key = orderKeys[indexPath.row]
        let product = orders[indexPath.row]
        
        let deleteAction = UIContextualAction(style: .destructive, title: "Взять заказ") { [weak self] _, _, completionHandler in
            guard let self = self else { return }
            
            self.showLoadingAlert()
            
            self.ordersRef.observeSingleEvent(of: .value, with: { snapshot in
                var found = false
                
                for case let tableSnapshot as DataSnapshot in snapshot.children {
                    if tableSnapshot.hasChild(key) {
                        found = true
                        let tableKey = tableSnapshot.key
                        let specificOrderRef = self.ordersRef.child(tableKey).child(key)
                        
                        // 1. Статус клиенту
                        db.child("Places").child(self.cafeID).child("tables")
                            .child("\(product.tableNumber)")
                            .child("clients")
                            .child("client\(product.clientNumber)")
                            .child("orders")
                            .child(product.id)
                            .updateChildValues(["status": "Готовится"])
                        
                        // 2. Просто удаляем из БД.
                        // Метод observe(.value) сам увидит удаление и обновит таблицу!
                        specificOrderRef.removeValue { error, _ in
                            DispatchQueue.main.async {
                                self.hideLoadingAlert()
                                
                                if error == nil {
                                    // Сохраняем себе
                                    myOrders.append(product)
                                    saveMyOrders(myOrders)
                                    
                                    var savedKeys = UserDefaults.standard.stringArray(forKey: "myOrderKeys") ?? []
                                    savedKeys.append(key)
                                    UserDefaults.standard.set(savedKeys, forKey: "myOrderKeys")
                                    
                                    // !!! УДАЛЯЕМ ручное изменение массивов и deleteRows !!!
                                    // Вместо этого просто завершаем экшен
                                    completionHandler(true)
                                } else {
                                    completionHandler(false)
                                }
                            }
                        }
                        break
                    }
                }
                
                if !found {
                    self.hideLoadingAlert()
                    completionHandler(false)
                }
            })
        }
        
        deleteAction.backgroundColor = .systemGreen
        deleteAction.image = UIImage(systemName: "hand.tap.fill")
        
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }

}
