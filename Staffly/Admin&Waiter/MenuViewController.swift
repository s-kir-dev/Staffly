//
//  MenuViewController.swift
//  SepBill
//
//  Created by Kirill Sysoev on 15.10.2025.
//

import UIKit
import FirebaseDatabase

class MenuViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var filterMenuButton: UIButton!
    @IBOutlet weak var summaLabel: UILabel!
    
    var selectedCategory: String = "" // для удобного поиска
    
    var tableIndex: Int = 0 // индекс стола в массиве
    var currentClient: Int = 0 // номер клиента
    var selectedProducts: [SelectedProduct] = [] // выбранные продукты
    var orderedProducts: [Product] = [] // заказанные продукты (из-за другого типа)
    var summa: Double = 0 // сумма персонального счета
    var summaSelectedProducts: Double = 0 // сумма для Label
    var tappedProduct: Product = Product(id: "", menuNumber: 0, productCategory: "", productDescription: "", productImageURL: "", productName: "", productPrice: 0, additionWishes: "") // для переноса на экран подробной информации
    
    let searchController = UISearchController(searchResultsController: nil)
    let loading = UIActivityIndicatorView(style: .large)
    let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

    var allProducts: [Product] = menu // все продукты в меню
    var products: [Product] = [] // фильтрованные продукты
    var cafeID = UserDefaults.standard.string(forKey: "cafeID")!
    let selfID = UserDefaults.standard.string(forKey: "selfID")!
    let role = UserDefaults.standard.string(forKey: "role")!

    let cloudinary = CloudinaryManager.shared
    let refreshControl = UIRefreshControl() // для обновления таблицы при скролле

    override func viewDidLoad() {
        super.viewDidLoad()
        
        summaLabel.text = "\(summaSelectedProducts.roundValue())р."

        products = allProducts

        tableView.delegate = self
        tableView.dataSource = self

        // Настройка pull-to-refresh
        refreshControl.tintColor = .blue
        refreshControl.addTarget(self, action: #selector(refreshMenu), for: .valueChanged)
        tableView.refreshControl = refreshControl

        setupMenuButton()

        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        searchController.searchBar.placeholder = "Введите название блюда"
        searchController.searchResultsUpdater = self
        searchController.delegate = self
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        switch currentClient {
        case 1:
            selectedProducts = tables[tableIndex].selectedProducts1
            summa = tables[tableIndex].selectedProducts1.reduce(0) { $0 + (Double($1.product.productPrice) * Double($1.quantity)).roundValue() }.roundValue()
            tables[tableIndex].client1Bill = tables[tableIndex].client1Bill.roundValue()
        case 2:
            selectedProducts = tables[tableIndex].selectedProducts2
            summa = tables[tableIndex].selectedProducts2.reduce(0) { $0 + (Double($1.product.productPrice) * Double($1.quantity)).roundValue() }.roundValue()
            tables[tableIndex].client2Bill = tables[tableIndex].client2Bill.roundValue()
        case 3:
            selectedProducts = tables[tableIndex].selectedProducts3
            summa = tables[tableIndex].selectedProducts3.reduce(0) { $0 + (Double($1.product.productPrice) * Double($1.quantity)).roundValue() }.roundValue()
            tables[tableIndex].client3Bill = tables[tableIndex].client3Bill.roundValue()
        case 4:
            selectedProducts = tables[tableIndex].selectedProducts4
            summa = tables[tableIndex].selectedProducts4.reduce(0) { $0 + (Double($1.product.productPrice) * Double($1.quantity)).roundValue() }.roundValue()
            tables[tableIndex].client4Bill = tables[tableIndex].client4Bill.roundValue()
        case 5:
            selectedProducts = tables[tableIndex].selectedProducts5
            summa = tables[tableIndex].selectedProducts5.reduce(0) { $0 + (Double($1.product.productPrice) * Double($1.quantity)).roundValue() }.roundValue()
            tables[tableIndex].client5Bill = tables[tableIndex].client5Bill.roundValue()
        case 6:
            selectedProducts = tables[tableIndex].selectedProducts6
            summa = tables[tableIndex].selectedProducts6.reduce(0) { $0 + (Double($1.product.productPrice) * Double($1.quantity)).roundValue() }.roundValue()
            tables[tableIndex].client6Bill = tables[tableIndex].client6Bill.roundValue()
        default:
            break
        }
        
        setupMenuButton()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if self.isMovingFromParent {
            switch currentClient {
            case 1:
                tables[tableIndex].selectedProducts1 = selectedProducts
                tables[tableIndex].client1Bill = selectedProducts.reduce(0) { $0 + (Double($1.product.productPrice) * Double($1.quantity)).roundValue() }.roundValue()
            case 2:
                tables[tableIndex].selectedProducts2 = selectedProducts
                tables[tableIndex].client2Bill = selectedProducts.reduce(0) { $0 + (Double($1.product.productPrice) * Double($1.quantity)).roundValue() }.roundValue()
            case 3:
                tables[tableIndex].selectedProducts3 = selectedProducts
                tables[tableIndex].client3Bill = selectedProducts.reduce(0) { $0 + (Double($1.product.productPrice) * Double($1.quantity)).roundValue() }.roundValue()
            case 4:
                tables[tableIndex].selectedProducts4 = selectedProducts
                tables[tableIndex].client4Bill = selectedProducts.reduce(0) { $0 + (Double($1.product.productPrice) * Double($1.quantity)).roundValue() }.roundValue()
            case 5:
                tables[tableIndex].selectedProducts5 = selectedProducts
                tables[tableIndex].client5Bill = selectedProducts.reduce(0) { $0 + (Double($1.product.productPrice) * Double($1.quantity)).roundValue() }.roundValue()
            case 6:
                tables[tableIndex].selectedProducts6 = selectedProducts
                tables[tableIndex].client6Bill = selectedProducts.reduce(0) { $0 + (Double($1.product.productPrice) * Double($1.quantity)).roundValue() }.roundValue()
            default:
                break
            }
            
            tables[tableIndex].bill = (
                tables[tableIndex].client1Bill +
                tables[tableIndex].client2Bill +
                tables[tableIndex].client3Bill +
                tables[tableIndex].client4Bill +
                tables[tableIndex].client5Bill +
                tables[tableIndex].client6Bill
            ).roundValue()
            
            let tableNumber = tables[tableIndex].number
            
            orderProducts(orderedProducts, cafeID, tableNumber, currentClient)
            saveTables(tables)
            
            // очищаем доп. пожелания
            for i in 0..<self.allProducts.count {
                self.allProducts[i].additionWishes = ""
            }
            for i in 0..<self.products.count {
                self.products[i].additionWishes = ""
            }
            for i in 0..<menu.count {
                menu[i].additionWishes = ""
            }
            
            selectedProducts = []
        }
    }

    @objc func refreshMenu() {
        updateMenu(isRefreshing: true)
    }

    func updateMenu(isRefreshing: Bool = false) {
        downloadData(cafeID) { products in
            menu = products

            let categoriesRef = db.child("Places").child(self.cafeID).child("categories").child("categories")
            categoriesRef.observeSingleEvent(of: .value) { snapshot in
                if let value = snapshot.value as? [String] {
                    categories = value
                } else {
                    categories = []
                }

                // Удаляем старые картинки
                let currentImageNames = menu.map { "\($0.id).png" }
                let allFiles = try? FileManager.default.contentsOfDirectory(atPath: self.documentsURL.path)
                allFiles?.forEach { file in
                    if !currentImageNames.contains(file) && !file.contains(self.selfID) {
                        try? FileManager.default.removeItem(at: self.documentsURL.appendingPathComponent(file))
                    }
                }

                // Загружаем картинки
                var imageCache: [String: UIImage] = [:]
                let group = DispatchGroup()

                for product in menu {
                    group.enter()
                    let imageName = "\(product.id).png"
                    if let localImage = downloadLocalImage(name: imageName) {
                        imageCache[product.id] = localImage
                        group.leave()
                    } else {
                        loadWithRetry(from: product.productImageURL.replacingOccurrences(of: "http://", with: "https://"), retries: 2) { image in
                            imageCache[product.id] = image ?? UIImage(named: "блюдо")
                            if let image = image {
                                saveImageLocally(image: image, name: imageName)
                            }
                            group.leave()
                        }
                    }
                }

                group.notify(queue: .main) {
                    menu.sort { $0.menuNumber < $1.menuNumber }
                    self.allProducts = menu
                    self.products = menu
                    globalImageCache = imageCache

                    self.setupMenuButton()

                    UIView.transition(with: self.tableView, duration: 0.25, options: .transitionCrossDissolve) {
                        self.tableView.reloadData()
                    }

                    if isRefreshing {
                        self.refreshControl.endRefreshing()
                    }
                }
            }
        }
    }

    func setupMenuButton() {
        let categoryActions = categories.map { category in
            UIAction(title: category) { _ in
                self.selectedCategory = category
                self.products = self.allProducts.filter { $0.productCategory == category }
                self.filterMenuButton.setTitle(" \(category)", for: .normal)
                UIView.transition(with: self.tableView, duration: 0.25, options: .transitionCrossDissolve) {
                    self.tableView.reloadData()
                }
            }
        }

        let resetAction = UIAction(title: " Все категории", attributes: .destructive) { _ in
            self.selectedCategory = ""
            self.products = self.allProducts
            self.filterMenuButton.setTitle(" Все категории", for: .normal)
            UIView.transition(with: self.tableView, duration: 0.25, options: .transitionCrossDissolve) {
                self.tableView.reloadData()
            }
        }

        let menu = UIMenu(title: "Выберите категорию", children: [resetAction] + categoryActions)
        filterMenuButton.menu = menu
        filterMenuButton.showsMenuAsPrimaryAction = true
        filterMenuButton.setTitle(" Все категории", for: .normal)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let destination = segue.destination as? ProductInfoViewController {
            destination.product = tappedProduct
        }
    }
}

extension MenuViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return products.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell") as! ProductTableViewCell
        let product = products[indexPath.row]

        cell.productSwitch.isOn = orderedProducts.contains(where: { $0.id == product.id })
        cell.menuNumberLabel.text = "\(product.menuNumber)"
        cell.productImageView.image = globalImageCache[product.id] ?? UIImage(named: "блюдо")
        cell.productImageView.layer.cornerRadius = 17
        cell.productImageView.clipsToBounds = true
        cell.productNameLabel.text = product.productName
        cell.productPriceLabel.text = "\(product.productPrice.roundValue())р."
        
        if self.selectedProducts.contains(where: { $0.product.id == product.id }) {
            cell.backgroundColor = UIColor(red: 0.796, green: 0.874, blue: 0.811, alpha: 0.5)
        } else {
            cell.backgroundColor = .white
        }
                
        cell.switchAction = {
            if cell.productSwitch.isOn {
                
                self.summaSelectedProducts += product.productPrice.roundValue()
                
                let orderedProduct = self.products[indexPath.row]
                self.orderedProducts.append(orderedProduct)

                if let index = self.selectedProducts.firstIndex(where: { $0.product.id == orderedProduct.id }) {
                    self.selectedProducts[index].quantity += 1
                } else {
                    let selectedProduct = SelectedProduct(product: orderedProduct, quantity: 1)
                    self.selectedProducts.append(selectedProduct)
                }

                cell.backgroundColor = UIColor(red: 0.796, green: 0.874, blue: 0.811, alpha: 1)
            } else {
                
                self.summaSelectedProducts -= product.productPrice.roundValue()
                
                if let removeIndex = self.orderedProducts.firstIndex(where: { $0.id == product.id }) {
                    self.orderedProducts.remove(at: removeIndex)
                }

                if let index = self.selectedProducts.firstIndex(where: { $0.product.id == product.id }) {
                    if self.selectedProducts[index].quantity - 1 > 0 {
                        self.selectedProducts[index].quantity -= 1
                    } else {
                        self.selectedProducts.remove(at: index)
                    }
                }

                if self.selectedProducts.contains(where: { $0.product.id == product.id }) {
                    cell.backgroundColor = UIColor(red: 0.796, green: 0.874, blue: 0.811, alpha: 0.5)
                } else {
                    cell.backgroundColor = .white
                }
            }
            
            self.summaLabel.text = "\(self.summaSelectedProducts.roundValue())р."
        }
        
        cell.layer.cornerRadius = 15
        cell.selectionStyle = .none

        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tappedProduct = products[indexPath.row]
        performSegue(withIdentifier: "productInfoVC", sender: self)
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 130
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let additionWishes = UIContextualAction(style: .normal, title: "Доп пожелания") { (_, _, completionHandler) in
            
            let product = self.products[indexPath.row]
            
            let alert = UIAlertController(title: "Доп пожелания",
                                          message: "Введите доп пожелания клиента к блюду",
                                          preferredStyle: .alert)
            alert.addTextField { textField in
                textField.placeholder = "Доп пожелания"
                textField.text = product.additionWishes
            }

            let saveAction = UIAlertAction(title: "Сохранить", style: .default) { _ in
                guard let wishes = alert.textFields?.first?.text else { return }

                self.products[indexPath.row].additionWishes = wishes
                if let allIndex = self.allProducts.firstIndex(where: { $0.id == product.id }) {
                    self.allProducts[allIndex].additionWishes = wishes
                }
                if let menuIndex = menu.firstIndex(where: { $0.id == product.id }) {
                    menu[menuIndex].additionWishes = wishes
                }
                if let selectedIndex = self.selectedProducts.firstIndex(where: { $0.product.id == product.id }) {
                    self.selectedProducts[selectedIndex].product.additionWishes = wishes
                    if let orderedIndex = self.orderedProducts.firstIndex(where: { $0.id == product.id }) {
                        self.orderedProducts[orderedIndex].additionWishes = wishes
                    }
                }
            }

            let cancelAction = UIAlertAction(title: "Отмена", style: .cancel)
            alert.addAction(saveAction)
            alert.addAction(cancelAction)

            self.present(alert, animated: true)
            completionHandler(true)
        }

        additionWishes.backgroundColor = .purple
        additionWishes.image = UIImage(systemName: "pencil.tip.crop.circle.badge.plus")

        return UISwipeActionsConfiguration(actions: [additionWishes])
    }
}

extension MenuViewController: UISearchResultsUpdating, UISearchControllerDelegate {
    func updateSearchResults(for searchController: UISearchController) {
        let text = searchController.searchBar.text?.lowercased() ?? ""
        
        var filtered = selectedCategory.isEmpty
            ? allProducts
            : allProducts.filter { $0.productCategory == selectedCategory }
        
        if !text.isEmpty {
            filtered = filtered.filter { $0.productName.lowercased().contains(text) }
        }
        
        products = filtered
        tableView.reloadData()
    }
}
