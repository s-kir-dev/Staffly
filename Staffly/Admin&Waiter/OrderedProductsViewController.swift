//
//  OrderedProductsViewController.swift
//  Staffly
//
//  Created by Kirill Sysoev on 17.10.2025.
//

import UIKit

class OrderedProductsViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    
    var table: Table = Table(number: 0, personCount: 0, maximumPersonCount: 0, currentPersonCount: 0, client1Bill: 0, client2Bill: 0, client3Bill: 0, client4Bill: 0, client5Bill: 0, client6Bill: 0, bill: 0, waiterID: "")
    
    var selectedProducts1: [SelectedProduct] = []
    var selectedProducts2: [SelectedProduct] = []
    var selectedProducts3: [SelectedProduct] = []
    var selectedProducts4: [SelectedProduct] = []
    var selectedProducts5: [SelectedProduct] = []
    var selectedProducts6: [SelectedProduct] = []
    
    private var allSelectedProducts: [SelectedProduct] = []
    private var productToClient: [Int] = [] // хранит номер клиента для каждого продукта
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let cafeID = UserDefaults.standard.string(forKey: "cafeID")!
        
        loadSelectedProducts(cafeID, 1, table.number, completion: { selectedProductsData in
            self.selectedProducts1 = selectedProductsData
            loadSelectedProducts(cafeID, 2, self.table.number, completion: { selectedProductsData in
                self.selectedProducts2 = selectedProductsData
                loadSelectedProducts(cafeID, 3, self.table.number, completion: { selectedProductsData in
                    self.selectedProducts3 = selectedProductsData
                    loadSelectedProducts(cafeID, 4, self.table.number, completion: { selectedProductsData in
                        self.selectedProducts4 = selectedProductsData
                        loadSelectedProducts(cafeID, 5, self.table.number, completion: { selectedProductsData in
                            self.selectedProducts5 = selectedProductsData
                            loadSelectedProducts(cafeID, 6, self.table.number, completion: { selectedProductsData in
                                self.selectedProducts6 = selectedProductsData
                                self.tableView.reloadData()
                            })
                        })
                    })
                })
            })
        })
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        
        navigationItem.title = "Заказанные блюда стола №\(table.number)"
        
        combineSelectedProducts()
    }
    
    private func combineSelectedProducts() {
        allSelectedProducts.removeAll()
        productToClient.removeAll()
        
        let clientsProducts = [
            selectedProducts1,
            selectedProducts2,
            selectedProducts3,
            selectedProducts4,
            selectedProducts5,
            selectedProducts6
        ]
        
        for (index, products) in clientsProducts.enumerated() {
            for _ in products {
                productToClient.append(index + 1)
            }
            allSelectedProducts.append(contentsOf: products)
        }
    }
    
    func productsCount() -> Int {
        return allSelectedProducts.count
    }
}

// MARK: - UITableViewDataSource, UITableViewDelegate
extension OrderedProductsViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return productsCount()
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! ProductTableViewCell
        let product = allSelectedProducts[indexPath.row]
        let clientNumber = productToClient[indexPath.row]
        
        // Цвет фона в зависимости от клиента
        switch clientNumber {
        case 1:
            cell.clientNumberLabel.text = product.sharedWith.count > 1 ? "Разделено между клиентами \(product.sharedWith.map(\.description).joined(separator: ", "))" : "Заказывал клиент 1"
            cell.backgroundColor = UIColor(red: 173/255, green: 216/255, blue: 230/255, alpha: 1)
        case 2:
            cell.clientNumberLabel.text = product.sharedWith.count > 1 ? "Разделено между клиентами \(product.sharedWith.map(\.description).joined(separator: ", "))" : "Заказывал клиент 2"
            cell.backgroundColor = UIColor(red: 255/255, green: 182/255, blue: 193/255, alpha: 0.5)
        case 3:
            cell.clientNumberLabel.text = product.sharedWith.count > 1 ? "Разделено между клиентами \(product.sharedWith.map(\.description).joined(separator: ", "))" : "Заказывал клиент 3"
            cell.backgroundColor = UIColor(red: 144/255, green: 238/255, blue: 144/255, alpha: 0.7)
        case 4:
            cell.clientNumberLabel.text = product.sharedWith.count > 1 ? "Разделено между клиентами \(product.sharedWith.map(\.description).joined(separator: ", "))" : "Заказывал клиент 4"
            cell.backgroundColor = UIColor(red: 1, green: 1, blue: 224/255, alpha: 1)
        case 5:
            cell.clientNumberLabel.text = product.sharedWith.count > 1 ? "Разделено между клиентами \(product.sharedWith.map(\.description).joined(separator: ", "))" : "Заказывал клиент 5"
            cell.backgroundColor = UIColor(red: 224/255, green: 1, blue: 224/255, alpha: 1)
        case 6:
            cell.clientNumberLabel.text = product.sharedWith.count > 1 ? "Разделено между клиентами \(product.sharedWith.map(\.description).joined(separator: ", "))" : "Заказывал клиент 6"
            cell.backgroundColor = UIColor(red: 1, green: 224/255, blue: 1, alpha: 1)
        default:
            cell.backgroundColor = .white
        }
        
        if let image = globalImageCache[product.product.id] {
            cell.productImageView.image = image
        }
        cell.productImageView.layer.cornerRadius = 17
        
        cell.productNameLabel.text = product.product.productName
        cell.productPriceLabel.text = "\(product.product.productPrice) р."
        cell.menuNumberLabel.text = "\(product.product.menuNumber)"
        cell.countLabel.text = "x\(product.quantity)"
        
        cell.selectionStyle = .none
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 155
    }
}
