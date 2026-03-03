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
    
    let activityIndicatorView = UIActivityIndicatorView(style: .large)

    var selectedCategory: String = ""

    var tableIndex: Int = 0
    var currentClient: Int = 0
    var selectedProducts: [SelectedProduct] = []
    var initialClientBalance: Double = 0.0
    
    // Словарь: ID блюда -> Список ID клиентов, между которыми оно делится
    var sharedDishes: [String: [Int]] = [:]
    
    // Массив блюд, выбранных в текущий заход (ДО отправки в БД)
    var orderedProducts: [Product] = []
    
    var summaSelectedProducts: Double = 0
    var tappedProduct: Product = Product(id: "", menuNumber: 0, productCategory: "", productDescription: "", productImageURL: "", productName: "", productPrice: 0, additionWishes: "", weight: 0, ccal: 0)

    let searchController = UISearchController(searchResultsController: nil)
    var allProducts: [Product] = menu
    var products: [Product] = []
    
    var cafeID = UserDefaults.standard.string(forKey: "cafeID") ?? ""

    let refreshControl = UIRefreshControl()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        loadInitialData()
    }

    private func setupUI() {
        activityIndicatorView.hidesWhenStopped = true
        activityIndicatorView.center = view.center
        view.addSubview(activityIndicatorView)

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
        //searchController.delegate = self
    }

    private func loadInitialData() {
        activityIndicatorView.startAnimating()
        loadSelectedProducts(cafeID, currentClient, tableNumbers[tableIndex]) { [weak self] data in
            guard let self = self else { return }
            self.selectedProducts = data
            self.initialClientBalance = data.reduce(0) { $0 + ($1.product.productPrice * Double($1.quantity)) }
            self.updateSummaLabel()
            self.tableView.reloadData()
            self.activityIndicatorView.stopAnimating()
        }
    }

    func updateSummaLabel() {
        var currentSelectionTotal: Double = 0
        
        for product in orderedProducts {
            let participants = sharedDishes[product.id] ?? [currentClient]
            if participants.contains(currentClient) {
                let sharePrice = (product.productPrice / Double(participants.count))
                currentSelectionTotal += sharePrice
            }
        }
        
        let total = initialClientBalance + currentSelectionTotal
        summaSelectedProducts = total.roundUp()
        summaLabel.text = String(format: "%.2fр.", summaSelectedProducts)
    }


    func sameClients(_ a: [Int], _ b: [Int]) -> Bool {
        return Set(a) == Set(b)
    }

    func indexInSelectedProducts(productId: String, sharedWith: [Int]) -> Int? {
        return selectedProducts.firstIndex { $0.product.id == productId && sameClients($0.sharedWith, sharedWith) }
    }

    // MARK: - Save on leave
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard self.isMovingFromParent, !orderedProducts.isEmpty else { return }

        activityIndicatorView.startAnimating()
        let group = DispatchGroup()
        
        group.enter()
        orderProducts(orderedProducts, cafeID, tableNumbers[tableIndex], currentClient) {
            group.leave()
        }

        var distribution: [Int: [SelectedProduct]] = [:]
        for product in orderedProducts {
            let participants = sharedDishes[product.id] ?? [currentClient]
            let shareCount = Double(participants.count)
            let pricePerPerson = (product.productPrice / shareCount).roundUp()
            
            for clientIdx in participants {
                var productCopy = product
                productCopy.productPrice = pricePerPerson
                
                if distribution[clientIdx] == nil { distribution[clientIdx] = [] }
                
                if let existingIdx = distribution[clientIdx]!.firstIndex(where: {
                    $0.product.id == product.id && sameClients($0.sharedWith, participants)
                }) {
                    distribution[clientIdx]![existingIdx].quantity += 1
                } else {
                    let newSelected = SelectedProduct(product: productCopy, sharedWith: participants, quantity: 1)
                    distribution[clientIdx]!.append(newSelected)
                }
            }
        }

        for (clientIndex, productsToSave) in distribution {
            group.enter()
            let clientSum = productsToSave.reduce(0) { $0 + ($1.product.productPrice * Double($1.quantity)) }
            orderProductsClient(cafeID, tableNumbers[tableIndex], clientIndex, clientSum.roundUp(), productsToSave) {
                group.leave()
            }
        }

        group.notify(queue: .main) {
            self.orderedProducts.removeAll()
            self.sharedDishes.removeAll()
            self.activityIndicatorView.stopAnimating()
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
                self.allProducts = menu
                self.products = self.selectedCategory.isEmpty ? menu : menu.filter { $0.productCategory == self.selectedCategory }
                self.setupMenuButton()
                self.tableView.reloadData()
                if isRefreshing { self.refreshControl.endRefreshing() }
            }
        }
    }

    func setupMenuButton() {
        let categoryActions = categories.map { category in
            UIAction(title: category) { _ in
                self.selectedCategory = category
                self.products = self.allProducts.filter { $0.productCategory == category }
                self.filterMenuButton.setTitle(" \(category)", for: .normal)
                self.tableView.reloadData()
            }
        }
        let resetAction = UIAction(title: " Все категории", attributes: .destructive) { _ in
            self.selectedCategory = ""
            self.products = self.allProducts
            self.filterMenuButton.setTitle(" Все категории", for: .normal)
            self.tableView.reloadData()
        }
        filterMenuButton.menu = UIMenu(title: "Категории", children: [resetAction] + categoryActions)
        filterMenuButton.showsMenuAsPrimaryAction = true
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let destination = segue.destination as? ProductInfoViewController {
            destination.product = tappedProduct
        }
    }
}

// MARK: - TableView Logic
// MARK: - TableView Logic
extension MenuViewController: UITableViewDelegate, UITableViewDataSource {

    func addProductToCurrentClient(_ product: Product, qty: Int = 1, sharedWith: [Int]) {
        if let idx = indexInSelectedProducts(productId: product.id, sharedWith: sharedWith) {
            selectedProducts[idx].quantity += qty
        } else {
            selectedProducts.append(SelectedProduct(product: product, sharedWith: sharedWith, quantity: qty))
        }
        updateSummaLabel()
    }

    func removeProductFromCurrentClient(_ product: Product, qty: Int = 1, sharedWith: [Int]) {
        if let idx = indexInSelectedProducts(productId: product.id, sharedWith: sharedWith) {
            if selectedProducts[idx].quantity > qty {
                selectedProducts[idx].quantity -= qty
            } else {
                selectedProducts.remove(at: idx)
            }
        }
        updateSummaLabel()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return products.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! ProductTableViewCell
        let product = products[indexPath.row]
        
        // Цвет для выделенных ячеек
        let highlightColor = UIColor(red: 0.796, green: 0.874, blue: 0.811, alpha: 0.5)
        
        // 1. Проверяем, выбрано ли блюдо сейчас (в текущую сессию)
        let isSelectedNow = orderedProducts.contains(where: { $0.id == product.id })
        
        // 2. Проверяем, было ли оно заказано ранее (в базе данных)
        let currentShared = sharedDishes[product.id] ?? [currentClient]
        let isAlreadyInDB = selectedProducts.contains(where: { $0.product.id == product.id && sameClients($0.sharedWith, currentShared) })
        
        // Итоговое состояние: подсвечиваем, если блюдо есть хоть где-то
        let isActuallySelected = isSelectedNow || isAlreadyInDB
        
        // Настройка внешнего вида
        cell.productSwitch.setOn(isSelectedNow, animated: false)
        cell.backgroundColor = isActuallySelected ? highlightColor : .white
        cell.menuNumberLabel.text = "\(product.menuNumber)"
        cell.productNameLabel.text = product.productName
        cell.productPriceLabel.text = "\(product.productPrice.roundValue())р."
        
        // Картинка
        cell.productImageView.image = globalImageCache[product.id] ?? UIImage(named: "блюдо")
        cell.productImageView.layer.cornerRadius = 17
        cell.productImageView.clipsToBounds = true
        
        // Логика переключателя
        cell.switchAction = { [weak self, weak cell] in
            guard let self = self, let cell = cell else { return }
            
            if cell.productSwitch.isOn {
                // Добавляем в список новых заказов
                if !self.orderedProducts.contains(where: { $0.id == product.id }) {
                    self.orderedProducts.append(product)
                }
            } else {
                // Убираем из новых заказов и очищаем разделение, если оно было
                self.orderedProducts.removeAll(where: { $0.id == product.id })
                self.sharedDishes.removeValue(forKey: product.id)
            }
            
            // Плавная анимация цвета БЕЗ перезагрузки всей таблицы
            UIView.animate(withDuration: 0.3) {
                cell.backgroundColor = cell.productSwitch.isOn ? highlightColor : .white
            }
            
            // Обновляем только лейбл с общей суммой
            self.updateSummaLabel()
        }
        
        cell.layer.cornerRadius = 15
        cell.selectionStyle = .none
        
        return cell
    }


    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        // Доп пожелания
        let additionWishes = UIContextualAction(style: .normal, title: "Доп пожелания") { (_, _, completionHandler) in
            let product = self.products[indexPath.row]
            let alert = UIAlertController(title: "Доп пожелания", message: "Введите пожелания", preferredStyle: .alert)
            alert.addTextField { $0.text = product.additionWishes }
            alert.addAction(UIAlertAction(title: "Сохранить", style: .default) { _ in
                guard let wishes = alert.textFields?.first?.text else { return }
                self.products[indexPath.row].additionWishes = wishes
                if let idx = self.selectedProducts.firstIndex(where: { $0.product.id == product.id }) {
                    self.selectedProducts[idx].product.additionWishes = wishes
                }
            })
            alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
            self.present(alert, animated: true)
            completionHandler(true)
        }
        additionWishes.backgroundColor = .purple
        additionWishes.image = UIImage(systemName: "pencil.tip.crop.circle.badge.plus")

        // Разделить блюдо
        let shareDishAction = UIContextualAction(style: .normal, title: "Разделить") { _, _, completionHandler in
            let product = self.products[indexPath.row]
            let alert = UIAlertController(title: "Разделить блюдо", message: "\n\n\n\n\n\n\n\n\n\n\n\n\n", preferredStyle: .alert)
            var switches: [UISwitch] = []
            let count = tables[self.tableIndex].personCount

            for i in 1...count {
                let h = UIStackView()
                h.axis = .horizontal
                h.spacing = 10
                let label = UILabel()
                label.text = "Клиент \(i)"
                let sw = UISwitch()
                sw.isOn = (i == self.currentClient) || (self.sharedDishes[product.id]?.contains(i) ?? false)
                switches.append(sw)
                h.addArrangedSubview(label)
                h.addArrangedSubview(sw)
                alert.view.addSubview(h)
                h.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    h.leadingAnchor.constraint(equalTo: alert.view.leadingAnchor, constant: 20),
                    h.topAnchor.constraint(equalTo: alert.view.topAnchor, constant: CGFloat(60 + (i-1) * 45))
                ])
            }

            alert.addAction(UIAlertAction(title: "Готово", style: .default) { _ in
                let selectedClients = switches.enumerated().filter { $0.element.isOn }.map { $0.offset + 1 }
                
                if selectedClients.isEmpty {
                    self.sharedDishes.removeValue(forKey: product.id)
                    self.orderedProducts.removeAll(where: { $0.id == product.id })
                } else {
                    self.sharedDishes[product.id] = selectedClients
                    // Если блюдо разделено, оно автоматически считается "выбранным" (ordered)
                    if !self.orderedProducts.contains(where: { $0.id == product.id }) {
                        self.orderedProducts.append(product)
                    }
                }
                
                self.updateSummaLabel() // Лейбл теперь подхватит новую долю цены
                self.tableView.reloadRows(at: [indexPath], with: .automatic)
                completionHandler(true)
            })

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


extension MenuViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let text = searchController.searchBar.text?.lowercased() ?? ""
        var filtered = selectedCategory.isEmpty ? allProducts : allProducts.filter { $0.productCategory == selectedCategory }
        if !text.isEmpty { filtered = filtered.filter { $0.productName.lowercased().contains(text) } }
        products = filtered
        tableView.reloadData()
    }
}
