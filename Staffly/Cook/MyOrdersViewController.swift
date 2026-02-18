//
//  MyOrdersViewController.swift
//  Staffly
//
//  Created by Kirill Sysoev on 18.02.2026.
//

import UIKit
import FirebaseDatabase

class MyOrdersViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    
    let cafeID = UserDefaults.standard.string(forKey: "cafeID")!
    let selfID = UserDefaults.standard.string(forKey: "selfID")!
    private var ordersRef: DatabaseReference!
    
    var alert: UIAlertController?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadMyOrders()
        loadMyOrderKeys()
        tableView.reloadData()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        ordersRef = db.child("Places").child(cafeID).child("orders")
        
        tableView.delegate = self
        tableView.dataSource = self
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

extension MyOrdersViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return myOrders.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! ProductTableViewCell
        let product = myOrders[indexPath.row]
        
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
        // Фиксируем данные сразу
        let currentKey = myOrderKeys[indexPath.row]
        let currentProduct = myOrders[indexPath.row]
        
        let doneAction = UIContextualAction(style: .destructive, title: "Готово") { [weak self] _, _, completionHandler in
            guard let self = self else { return }
            self.showLoadingAlert()
            
            let tableKey = "\(currentProduct.tableNumber)"
            
            // Ссылка на новое место хранения (готовые заказы)
            let readyRef = db.child("Places").child(self.cafeID).child("readyOrders").child(tableKey).child(currentKey)
            
            // Подготавливаем словарь из модели (так как в Firebase нужны данные)
            let orderData: [String: Any] = [
                "id": currentProduct.id,
                "menuNumber": currentProduct.menuNumber,
                "productCategory": currentProduct.productCategory,
                "productDescription": currentProduct.productDescription,
                "productImageURL": currentProduct.productImageURL,
                "productName": currentProduct.productName,
                "productPrice": currentProduct.productPrice,
                "additionWishes": currentProduct.additionWishes,
                "a tableNumber": currentProduct.tableNumber,
                "b clientNumber": currentProduct.clientNumber
            ]
            
            // 1. Обновляем статус у клиента (чтобы он видел "Готово")
            db.child("Places").child(self.cafeID).child("tables")
                .child(tableKey)
                .child("clients")
                .child("client\(currentProduct.clientNumber)")
                .child("orders")
                .child(currentProduct.id)
                .updateChildValues(["status": "Готово"])
            
            // 2. Сохраняем в ветку готовых заказов
            readyRef.setValue(orderData) { error, _ in
                if error != nil {
                    self.hideLoadingAlert()
                    completionHandler(false)
                    return
                }
                
                // 3. Обновляем статистику повара
                downloadUserData(self.cafeID, self.selfID) { employeeData in
                    var updatedEmployee = employeeData
                    updatedEmployee.productsCount += 1
                    updatedEmployee.cafeProfit += currentProduct.productPrice
                    
                    uploadUserData(self.cafeID, self.selfID, updatedEmployee) { _ in
                        DispatchQueue.main.async {
                            // 4. Удаляем из локального массива и интерфейса
                            if let indexToRemove = myOrderKeys.firstIndex(of: currentKey) {
                                myOrders.remove(at: indexToRemove)
                                myOrderKeys.remove(at: indexToRemove)
                                
                                saveMyOrders(myOrders)
                                saveMyOrderKeys(myOrderKeys)
                                
                                self.tableView.deleteRows(at: [IndexPath(row: indexToRemove, section: 0)], with: .fade)
                            }
                            self.hideLoadingAlert()
                            completionHandler(true)
                        }
                    }
                }
            }
        }
        
        doneAction.backgroundColor = .systemGreen
        doneAction.image = UIImage(systemName: "checkmark.seal.fill")
        return UISwipeActionsConfiguration(actions: [doneAction])
    }
}
