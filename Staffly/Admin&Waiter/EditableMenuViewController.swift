//
//  EditableMenuViewController.swift
//  SepBill
//
//  Created by Kirill Sysoev on 17.10.2025.
//

import UIKit
import FirebaseDatabase

class EditableMenuViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var filterMenuButton: UIButton!

    let searchController = UISearchController(searchResultsController: nil)
    let loading = UIActivityIndicatorView(style: .large)
    let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

    var selectedCategory = ""
    
    var allProducts: [Product] = menu
    var products: [Product] = []
    var cafeID = ""
    let selfID = UserDefaults.standard.string(forKey: "selfID")!
    let role = UserDefaults.standard.string(forKey: "role")!

    let cloudinary = CloudinaryManager.shared
    let refreshControl = UIRefreshControl()
    
    var selectedProduct: Product = Product(id: "", menuNumber: 0, productCategory: "", productDescription: "", productImageURL: "", productName: "", productPrice: 0.0, additionWishes: "")

    override func viewDidLoad() {
        super.viewDidLoad()

        cafeID = UserDefaults.standard.string(forKey: "cafeID") ?? ""
        products = allProducts

        tableView.delegate = self
        tableView.dataSource = self

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

                let currentImageNames = menu.map { "\($0.id).png" }
                let allFiles = try? FileManager.default.contentsOfDirectory(atPath: self.documentsURL.path)
                allFiles?.forEach { file in
                    if !currentImageNames.contains(file) && !file.contains(self.selfID) {
                        try? FileManager.default.removeItem(at: self.documentsURL.appendingPathComponent(file))
                    }
                }

                var imageCache: [String: UIImage] = [:]
                let group = DispatchGroup()

                for product in menu {
                    group.enter()
                    let imageName = "\(product.id).png"

                    if let localImage = downloadLocalImage(name: imageName),
                       let savedUrl = UserDefaults.standard.string(forKey: "\(product.id)_imageUrl"),
                       savedUrl == product.productImageURL {
                        imageCache[product.id] = localImage
                        group.leave()
                    } else {
                        loadWithRetry(from: product.productImageURL.replacingOccurrences(of: "http://", with: "https://"), retries: 2) { image in
                            if let image = image {
                                imageCache[product.id] = image
                                saveImageLocally(image: image, name: imageName)
                                UserDefaults.standard.set(product.productImageURL, forKey: "\(product.id)_imageUrl")
                                debugPrint("♻️ Обновлено изображение для \(product.productName)")
                            } else {
                                imageCache[product.id] = UIImage(named: "блюдо")
                                debugPrint("❌ Не удалось загрузить изображение для \(product.productName)")
                            }
                            group.leave()
                        }
                    }
                }

                group.notify(queue: .main) {
                    menu.sort { $0.menuNumber < $1.menuNumber }
                    self.allProducts = menu
                    self.products = self.selectedCategory.isEmpty
                        ? menu
                        : menu.filter { $0.productCategory == self.selectedCategory }

                    globalImageCache = imageCache
                    self.setupMenuButton()

                    UIView.transition(with: self.tableView, duration: 0.25, options: .transitionCrossDissolve) {
                        self.tableView.reloadData()
                    }

                    if isRefreshing {
                        self.refreshControl.endRefreshing()
                    }

                    debugPrint("✅ Меню обновлено через свайп — \(menu.count) продуктов, \(globalImageCache.count) изображений")
                }
            }
        }
    }

    func setupMenuButton() {
        let categoryActions = categories.map { category in
            UIAction(title: category) { _ in
                self.selectedCategory = category
                self.products = self.allProducts.filter { $0.productCategory == category }
                self.tableView.setContentOffset(CGPoint(x: 0, y: 0), animated: true)
                self.filterMenuButton.setTitle(" \(category)", for: .normal)
                UIView.transition(with: self.tableView, duration: 0.25, options: .transitionCrossDissolve) {
                    self.tableView.reloadData()
                }
            }
        }

        let resetAction = UIAction(title: " Все категории", attributes: .destructive) { _ in
            self.selectedCategory = ""
            self.products = self.allProducts
            self.tableView.setContentOffset(CGPoint(x: 0, y: 0), animated: true)
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
        if let vc = segue.destination as? EditProductViewController {
            vc.product = selectedProduct
        }
    }
}

extension EditableMenuViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return products.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell") as! MenuTableViewCell
        let product = products[indexPath.row]

        cell.menuNumberLabel.text = "\(product.menuNumber)"
        cell.productImageView.image = globalImageCache[product.id] ?? UIImage(named: "блюдо")
        cell.productImageView.layer.cornerRadius = 17
        cell.productImageView.clipsToBounds = true
        cell.productNameLabel.text = product.productName
        cell.productCategoryLabel.text = product.productCategory
        cell.productPriceLabel.text = "\(product.productPrice)р."
        cell.selectionStyle = .none

        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 130
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard role.lowercased() == "admin" else { return UISwipeActionsConfiguration(actions: []) }
        let product = products[indexPath.row]

        let deleteAction = UIContextualAction(style: .destructive, title: "Удалить") { _, _, completionHandler in
            self.loading.startAnimating()

            db.child("Places").child(self.cafeID).child("menu").child(product.id).removeValue { _, _ in
                if let index = menu.firstIndex(where: { $0.id == product.id }) {
                    menu.remove(at: index)
                }

                self.allProducts = menu
                self.products = self.allProducts

                let imageURL = self.documentsURL.appendingPathComponent("\(product.id).png")
                if FileManager.default.fileExists(atPath: imageURL.path) {
                    try? FileManager.default.removeItem(at: imageURL)
                }
                globalImageCache.removeValue(forKey: product.id)

                // Обновляем категории
                let categoriesRef = db.child("Places").child(self.cafeID).child("categories").child("categories")
                categoriesRef.observeSingleEvent(of: .value) { snapshot in
                    if var categoriesArray = snapshot.value as? [String] {
                        let remainingProductsInCategory = menu.filter { $0.productCategory == product.productCategory }
                        if remainingProductsInCategory.isEmpty {
                            categoriesArray.removeAll { $0 == product.productCategory }
                            categoriesRef.setValue(categoriesArray)
                        }
                        categories = categoriesArray
                    } else {
                        categories = []
                    }
                    self.setupMenuButton()
                    tableView.reloadData()
                    self.loading.stopAnimating()
                    completionHandler(true)
                }
            }
        }
        
        let editProductAction = UIContextualAction(style: .normal, title: "Изменить") { _, _, completionHandler in
            self.selectedProduct = product
            self.performSegue(withIdentifier: "editProductVC", sender: self)
            completionHandler(true)
        }
        
        deleteAction.backgroundColor = .red
        deleteAction.image = UIImage(systemName: "trash.fill")
        
        editProductAction.backgroundColor = .blue.withAlphaComponent(0.3)
        editProductAction.image = UIImage(systemName: "pencil.circle")
        
        return UISwipeActionsConfiguration(actions: [deleteAction, editProductAction])
    }
}

extension EditableMenuViewController: UISearchResultsUpdating, UISearchControllerDelegate {
    func updateSearchResults(for searchController: UISearchController) {
        let text = searchController.searchBar.text?.lowercased() ?? ""
        
        // Базовый массив: либо все продукты, либо по выбранной категории
        var filtered = selectedCategory.isEmpty
            ? allProducts
            : allProducts.filter { $0.productCategory == selectedCategory }
        
        // Если введён текст — отфильтровываем по нему
        if !text.isEmpty {
            filtered = filtered.filter { $0.productName.lowercased().contains(text) }
        }
        
        // Присваиваем и обновляем таблицу
        products = filtered
        tableView.reloadData()
    }
}
