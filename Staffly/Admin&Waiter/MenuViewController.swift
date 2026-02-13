//
//  MenuViewController.swift
//  Staffly
//
//  Created by Kirill Sysoev on 15.10.2025.
//

import UIKit
import FirebaseDatabase

class MenuViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var filterMenuButton: UIButton!
    @IBOutlet weak var summaLabel: UILabel!

    var selectedCategory: String = ""

    var tableIndex: Int = 0
    var currentClient: Int = 0
    var selectedProducts: [SelectedProduct] = [] // служит только для отображения цвета ячейки с ранее выбранным блюдом
    var sharedDishes: [String: [Int]] = [:] // product.id -> [clientIndexes]
    var orderedProducts: [Product] = [] // отвечает за switch.isOn в ячейке таблицы и хранит в себе выбранные в этот раз блюда для заказа
    var summa: Double = 0
    var summaSelectedProducts: Double = 0
    var tappedProduct: Product = Product(id: "", menuNumber: 0, productCategory: "", productDescription: "", productImageURL: "", productName: "", productPrice: 0, additionWishes: "", weight: 0, ccal: 0)

    let searchController = UISearchController(searchResultsController: nil)
    let loading = UIActivityIndicatorView(style: .large)
    let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

    var allProducts: [Product] = menu
    var products: [Product] = []
    var cafeID = UserDefaults.standard.string(forKey: "cafeID") ?? ""
    let selfID = UserDefaults.standard.string(forKey: "selfID") ?? ""
    let role = UserDefaults.standard.string(forKey: "role") ?? ""

    let cloudinary = CloudinaryManager.shared
    let refreshControl = UIRefreshControl()

    override func viewDidLoad() {
        super.viewDidLoad()

        summaSelectedProducts = selectedProducts.reduce(0) { $0 + (Double($1.product.productPrice) * Double($1.quantity)) }.roundValue()
        summaLabel.text = "\(summaSelectedProducts.roundValue())р."

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

        switch currentClient {
        case 1:
            selectedProducts = tables[tableIndex].selectedProducts1
            summa = tables[tableIndex].client1Bill
        case 2:
            selectedProducts = tables[tableIndex].selectedProducts2
            summa = tables[tableIndex].client2Bill
        case 3:
            selectedProducts = tables[tableIndex].selectedProducts3
            summa = tables[tableIndex].client3Bill
        case 4:
            selectedProducts = tables[tableIndex].selectedProducts4
            summa = tables[tableIndex].client4Bill
        case 5:
            selectedProducts = tables[tableIndex].selectedProducts5
            summa = tables[tableIndex].client5Bill
        case 6:
            selectedProducts = tables[tableIndex].selectedProducts6
            summa = tables[tableIndex].client6Bill
        default:
            break
        }

        summaSelectedProducts = selectedProducts.reduce(0) { $0 + (Double($1.product.productPrice) * Double($1.quantity)) }.roundValue()
        summaLabel.text = "\(summaSelectedProducts.roundValue())р."

        debugPrint("📥 MenuVC открыт | Стол \(tableIndex) | Клиент \(currentClient)")
        debugPrint("📦 Старые блюда 1: \(tables[tableIndex].selectedProducts1.map { "\($0.product.productName) x\($0.quantity)" })")
        debugPrint("📦 Старые блюда 2: \(tables[tableIndex].selectedProducts2.map { "\($0.product.productName) x\($0.quantity)" })")
        debugPrint("📦 Старые блюда 3: \(tables[tableIndex].selectedProducts3.map { "\($0.product.productName) x\($0.quantity)" })")
        debugPrint("📦 Старые блюда 4: \(tables[tableIndex].selectedProducts4.map { "\($0.product.productName) x\($0.quantity)" })")
        debugPrint("📦 Старые блюда 5: \(tables[tableIndex].selectedProducts5.map { "\($0.product.productName) x\($0.quantity)" })")
        debugPrint("📦 Старые блюда 6: \(tables[tableIndex].selectedProducts6.map { "\($0.product.productName) x\($0.quantity)" })")
    }

    // MARK: - Helpers for matching by id + sharedWith

    /// Сравнивает массивы клиентов как множества — порядок не важен
    func sameClients(_ a: [Int], _ b: [Int]) -> Bool {
        return Set(a) == Set(b)
    }

    /// Находит индекс в selectedProducts по id блюда и набору клиентов (sharedWith).
    func indexInSelectedProducts(productId: String, sharedWith: [Int]) -> Int? {
        return selectedProducts.firstIndex { $0.product.id == productId && sameClients($0.sharedWith, sharedWith) }
    }

    /// Утилита для поиска в произвольном массиве SelectedProduct
    func indexIn(_ arr: [SelectedProduct], productId: String, sharedWith: [Int]) -> Int? {
        return arr.firstIndex { $0.product.id == productId && sameClients($0.sharedWith, sharedWith) }
    }

    // MARK: - Save on leave
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard self.isMovingFromParent else { return }

        debugPrint("⬅️ Выход из MenuVC | Стол \(tableIndex) | Клиент \(currentClient)")
        debugPrint("📦 Новые блюда для заказа (orderedProducts): \(orderedProducts.map { "\($0.productName)" })")

        // 🔥 Сохраняем копию ДО любых изменений
        let productsToSend = orderedProducts

        var table = tables[tableIndex]
        var remainingOrdered = orderedProducts

        for product in orderedProducts {
            if let clients = sharedDishes[product.id], !clients.isEmpty {
                let shareCount = Double(clients.count)
                let pricePerClient = (product.productPrice / shareCount).roundValue()

                for clientIndex in clients {
                    var productCopy = product
                    productCopy.productPrice = pricePerClient
                    let sw = clients

                    switch clientIndex {
                    case 1:
                        table.client1Bill += productCopy.productPrice
                        if let idx = indexIn(table.selectedProducts1, productId: productCopy.id, sharedWith: sw) {
                            table.selectedProducts1[idx].quantity += 1
                        } else {
                            table.selectedProducts1.append(SelectedProduct(product: productCopy, sharedWith: sw, quantity: 1))
                        }
                    case 2:
                        table.client2Bill += productCopy.productPrice
                        if let idx = indexIn(table.selectedProducts2, productId: productCopy.id, sharedWith: sw) {
                            table.selectedProducts2[idx].quantity += 1
                        } else {
                            table.selectedProducts2.append(SelectedProduct(product: productCopy, sharedWith: sw, quantity: 1))
                        }
                    case 3:
                        table.client3Bill += productCopy.productPrice
                        if let idx = indexIn(table.selectedProducts3, productId: productCopy.id, sharedWith: sw) {
                            table.selectedProducts3[idx].quantity += 1
                        } else {
                            table.selectedProducts3.append(SelectedProduct(product: productCopy, sharedWith: sw, quantity: 1))
                        }
                    case 4:
                        table.client4Bill += productCopy.productPrice
                        if let idx = indexIn(table.selectedProducts4, productId: productCopy.id, sharedWith: sw) {
                            table.selectedProducts4[idx].quantity += 1
                        } else {
                            table.selectedProducts4.append(SelectedProduct(product: productCopy, sharedWith: sw, quantity: 1))
                        }
                    case 5:
                        table.client5Bill += productCopy.productPrice
                        if let idx = indexIn(table.selectedProducts5, productId: productCopy.id, sharedWith: sw) {
                            table.selectedProducts5[idx].quantity += 1
                        } else {
                            table.selectedProducts5.append(SelectedProduct(product: productCopy, sharedWith: sw, quantity: 1))
                        }
                    case 6:
                        table.client6Bill += productCopy.productPrice
                        if let idx = indexIn(table.selectedProducts6, productId: productCopy.id, sharedWith: sw) {
                            table.selectedProducts6[idx].quantity += 1
                        } else {
                            table.selectedProducts6.append(SelectedProduct(product: productCopy, sharedWith: sw, quantity: 1))
                        }
                    default:
                        break
                    }
                }

                if let removeIdx = remainingOrdered.firstIndex(where: { $0.id == product.id }) {
                    remainingOrdered.remove(at: removeIdx)
                }

                sharedDishes.removeValue(forKey: product.id)

            } else {
                // не шарится
                switch currentClient {
                case 1:
                    table.client1Bill += product.productPrice
                    let sw = sharedDishes[product.id] ?? [1]
                    if let idx = indexIn(table.selectedProducts1, productId: product.id, sharedWith: sw) {
                        table.selectedProducts1[idx].quantity += 1
                    } else {
                        table.selectedProducts1.append(SelectedProduct(product: product, sharedWith: sw, quantity: 1))
                    }
                case 2:
                    table.client2Bill += product.productPrice
                    let sw = sharedDishes[product.id] ?? [2]
                    if let idx = indexIn(table.selectedProducts2, productId: product.id, sharedWith: sw) {
                        table.selectedProducts2[idx].quantity += 1
                    } else {
                        table.selectedProducts2.append(SelectedProduct(product: product, sharedWith: sw, quantity: 1))
                    }
                case 3:
                    table.client3Bill += product.productPrice
                    let sw = sharedDishes[product.id] ?? [3]
                    if let idx = indexIn(table.selectedProducts3, productId: product.id, sharedWith: sw) {
                        table.selectedProducts3[idx].quantity += 1
                    } else {
                        table.selectedProducts3.append(SelectedProduct(product: product, sharedWith: sw, quantity: 1))
                    }
                case 4:
                    table.client4Bill += product.productPrice
                    let sw = sharedDishes[product.id] ?? [4]
                    if let idx = indexIn(table.selectedProducts4, productId: product.id, sharedWith: sw) {
                        table.selectedProducts4[idx].quantity += 1
                    } else {
                        table.selectedProducts4.append(SelectedProduct(product: product, sharedWith: sw, quantity: 1))
                    }
                case 5:
                    table.client5Bill += product.productPrice
                    let sw = sharedDishes[product.id] ?? [5]
                    if let idx = indexIn(table.selectedProducts5, productId: product.id, sharedWith: sw) {
                        table.selectedProducts5[idx].quantity += 1
                    } else {
                        table.selectedProducts5.append(SelectedProduct(product: product, sharedWith: sw, quantity: 1))
                    }
                case 6:
                    table.client6Bill += product.productPrice
                    let sw = sharedDishes[product.id] ?? [6]
                    if let idx = indexIn(table.selectedProducts6, productId: product.id, sharedWith: sw) {
                        table.selectedProducts6[idx].quantity += 1
                    } else {
                        table.selectedProducts6.append(SelectedProduct(product: product, sharedWith: sw, quantity: 1))
                    }
                default:
                    break
                }

                if let removeIdx = remainingOrdered.firstIndex(where: { $0.id == product.id }) {
                    remainingOrdered.remove(at: removeIdx)
                }
            }
        }

        table.bill = (
            table.client1Bill +
            table.client2Bill +
            table.client3Bill +
            table.client4Bill +
            table.client5Bill +
            table.client6Bill
        ).roundValue()

        debugPrint("💵 Общий счёт: \(table.bill)")

        tables[tableIndex] = table
        saveTables(tables)

        for i in 0..<self.allProducts.count { self.allProducts[i].additionWishes = "" }
        for i in 0..<self.products.count { self.products[i].additionWishes = "" }
        for i in 0..<menu.count { menu[i].additionWishes = "" }

        if !productsToSend.isEmpty {
            orderProducts(productsToSend, cafeID, table.number, currentClient)
            debugPrint("📤 Отправлены в заказ: \(productsToSend.map { $0.productName })")
        } else {
            debugPrint("📤 Нет новых физических порций для отправки (productsToSend пуст).")
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
                categories = snapshot.value as? [String] ?? []

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
                            } else {
                                imageCache[product.id] = UIImage(named: "блюдо")
                            }
                            group.leave()
                        }
                    }
                }

                group.notify(queue: .main) {
                    menu.sort { $0.menuNumber < $1.menuNumber }
                    self.allProducts = menu
                    self.products = self.selectedCategory.isEmpty ? menu : menu.filter { $0.productCategory == self.selectedCategory }
                    globalImageCache = imageCache
                    self.setupMenuButton()

                    UIView.transition(with: self.tableView, duration: 0.25, options: .transitionCrossDissolve) {
                        self.tableView.reloadData()
                    }

                    if isRefreshing { self.refreshControl.endRefreshing() }
                    debugPrint("🔄 Обновление меню | Всего блюд: \(menu.count)")
                }
            }
        }
    }

    func setupMenuButton() {
        let categoryActions = categories.map { category in
            UIAction(title: category) { _ in
                self.selectedCategory = category
                self.products = self.allProducts.filter { $0.productCategory == category }
                self.tableView.setContentOffset(.zero, animated: true)
                self.filterMenuButton.setTitle(" \(category)", for: .normal)
                UIView.transition(with: self.tableView, duration: 0.25, options: .transitionCrossDissolve) {
                    self.tableView.reloadData()
                }
            }
        }
        let resetAction = UIAction(title: " Все категории", attributes: .destructive) { _ in
            self.selectedCategory = ""
            self.products = self.allProducts
            self.tableView.setContentOffset(.zero, animated: true)
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

// MARK: - TableView Delegate & DataSource
extension MenuViewController: UITableViewDelegate, UITableViewDataSource {

    // Обновлённые add/remove с sharedWith
    func addProductToCurrentClient(_ product: Product, qty: Int = 1, sharedWith: [Int]) {
        if let idx = indexInSelectedProducts(productId: product.id, sharedWith: sharedWith) {
            selectedProducts[idx].quantity += qty
        } else {
            selectedProducts.append(SelectedProduct(product: product, sharedWith: sharedWith, quantity: qty))
        }
        summaSelectedProducts += (Double(product.productPrice) * Double(qty)).roundValue()
        summaLabel.text = "\(summaSelectedProducts.roundValue())р."
    }

    func removeProductFromCurrentClient(_ product: Product, qty: Int = 1, sharedWith: [Int]) {
        if let idx = indexInSelectedProducts(productId: product.id, sharedWith: sharedWith) {
            if selectedProducts[idx].quantity > qty {
                selectedProducts[idx].quantity -= qty
            } else {
                selectedProducts.remove(at: idx)
            }
            summaSelectedProducts -= (Double(product.productPrice) * Double(qty)).roundValue()
            if summaSelectedProducts < 0 { summaSelectedProducts = 0 }
            summaLabel.text = "\(summaSelectedProducts.roundValue())р."
        } else {
            debugPrint("⚠️ Попытка удалить несуществующий SelectedProduct: id=\(product.id) sharedWith=\(sharedWith)")
        }
    }

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

        // Подсветка — ищем элемент с тем же sharedWith (если нет — считаем, что sharedWith = [currentClient])
        let currentShared = sharedDishes[product.id] ?? [currentClient]
        if self.selectedProducts.contains(where: { $0.product.id == product.id && sameClients($0.sharedWith, currentShared) }) {
            cell.backgroundColor = UIColor(red: 0.796, green: 0.874, blue: 0.811, alpha: 0.5)
        } else {
            cell.backgroundColor = .white
        }

        cell.switchAction = {
            if cell.productSwitch.isOn {
                // включили
                self.orderedProducts.append(product)

                let clients = self.sharedDishes[product.id] ?? [self.currentClient]
                if !clients.isEmpty && clients.contains(self.currentClient) {
                    let pricePerClient = (product.productPrice / Double(clients.count)).roundValue()
                    var productCopy = product
                    productCopy.productPrice = pricePerClient
                    self.addProductToCurrentClient(productCopy, qty: 1, sharedWith: clients)
                } else {
                    // не шарится или не для этого клиента
                    self.addProductToCurrentClient(product, qty: 1, sharedWith: [self.currentClient])
                }
                cell.backgroundColor = UIColor(red: 0.796, green: 0.874, blue: 0.811, alpha: 1)
            } else {
                // выключили
                if let idx = self.orderedProducts.firstIndex(where: { $0.id == product.id }) {
                    self.orderedProducts.remove(at: idx)
                }

                let clients = self.sharedDishes[product.id] ?? [self.currentClient]
                if !clients.isEmpty && clients.contains(self.currentClient) {
                    let pricePerClient = (product.productPrice / Double(clients.count)).roundValue()
                    var productCopy = product
                    productCopy.productPrice = pricePerClient
                    self.removeProductFromCurrentClient(productCopy, qty: 1, sharedWith: clients)
                } else {
                    self.removeProductFromCurrentClient(product, qty: 1, sharedWith: [self.currentClient])
                }

                // восстановим полупрозрачную подсветку, если было ранее выбрано в другом сеансе
                if self.selectedProducts.contains(where: { $0.product.id == product.id && self.sameClients($0.sharedWith, self.sharedDishes[product.id] ?? [self.currentClient]) }) {
                    cell.backgroundColor = UIColor(red: 0.796, green: 0.874, blue: 0.811, alpha: 0.5)
                } else {
                    cell.backgroundColor = .white
                }
            }
        }

        cell.layer.cornerRadius = 15
        cell.selectionStyle = .none
        return cell
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        // MARK: - Дополнительные пожелания
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
                if let selectedIndex = self.selectedProducts.firstIndex(where: { $0.product.id == product.id && self.sameClients($0.sharedWith, self.sharedDishes[product.id] ?? [self.currentClient]) }) {
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

        // MARK: - Разделить блюдо
        let shareDishAction = UIContextualAction(style: .normal, title: "Разделить") { _, _, completionHandler in
            let product = self.products[indexPath.row]
            let alert = UIAlertController(title: "Разделить блюдо", message: "\n\n\n\n\n\n\n\n\n\n\n\n\n", preferredStyle: .alert)
            var switches: [UISwitch] = []
            let count = tables[self.tableIndex].personCount

            for i in 1...count {
                let h = UIStackView()
                h.axis = .horizontal
                h.alignment = .center
                h.spacing = 10

                let label = UILabel()
                label.text = "Клиент \(i)"
                label.widthAnchor.constraint(equalToConstant: 80).isActive = true

                let sw = UISwitch()
                sw.isOn = (i == self.currentClient) || (self.sharedDishes[product.id]?.contains(i) ?? false)
                switches.append(sw)

                h.addArrangedSubview(label)
                h.addArrangedSubview(sw)
                alert.view.addSubview(h)

                h.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    h.leadingAnchor.constraint(equalTo: alert.view.leadingAnchor, constant: 20),
                    h.trailingAnchor.constraint(equalTo: alert.view.trailingAnchor, constant: -20),
                    h.topAnchor.constraint(equalTo: alert.view.topAnchor, constant: CGFloat(60 + (i-1) * 45)),
                    h.heightAnchor.constraint(equalToConstant: 40)
                ])
            }

            let okAction = UIAlertAction(title: "Готово", style: .default) { _ in
                let selectedClients = switches.enumerated().filter { $0.element.isOn }.map { $0.offset + 1 }

                if selectedClients.isEmpty {
                    self.sharedDishes.removeValue(forKey: product.id)
                } else {
                    self.sharedDishes[product.id] = selectedClients
                }

                // Добавляем в orderedProducts (если ещё нет)
                if !self.orderedProducts.contains(where: { $0.id == product.id }) {
                    self.orderedProducts.append(product)
                }

                if selectedClients.contains(self.currentClient) {
                    let sharePrice = (product.productPrice / Double(selectedClients.count)).roundValue()
                    var productCopy = product
                    productCopy.productPrice = sharePrice
                    self.addProductToCurrentClient(productCopy, qty: 1, sharedWith: selectedClients)
                } else {
                    // если текущий клиент не участвует — ничего не добавляем в выбранные этого клиента
                }

                self.tableView.reloadRows(at: [indexPath], with: .automatic)
                completionHandler(true)
            }
            alert.addAction(okAction)
            alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
            self.present(alert, animated: true)
        }
        shareDishAction.backgroundColor = .systemMint
        shareDishAction.image = UIImage(systemName: "person.3.sequence.fill")

        return UISwipeActionsConfiguration(actions: [additionWishes, shareDishAction])
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tappedProduct = products[indexPath.row]
        performSegue(withIdentifier: "productInfoVC", sender: self)
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { 130 }
}

// MARK: - Search
extension MenuViewController: UISearchResultsUpdating, UISearchControllerDelegate {
    func updateSearchResults(for searchController: UISearchController) {
        let text = searchController.searchBar.text?.lowercased() ?? ""
        var filtered = selectedCategory.isEmpty ? allProducts : allProducts.filter { $0.productCategory == selectedCategory }
        if !text.isEmpty { filtered = filtered.filter { $0.productName.lowercased().contains(text) } }
        products = filtered
        tableView.reloadData()
    }
}
