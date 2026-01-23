//
//  DownloadViewController.swift
//  Staffly
//
//  Created by Kirill Sysoev on 15.10.2025.
//

import UIKit
import FirebaseDatabase

class DownloadViewController: UIViewController {
    
    var role: String = ""
    var alert: UIAlertController?
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationItem.leftBarButtonItems = []
        
        showLoadingAlert()
        
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let cafeID = UserDefaults.standard.string(forKey: "cafeID") ?? "cafeID1"
        let selfID = UserDefaults.standard.string(forKey: "selfID") ?? ""
        role = UserDefaults.standard.string(forKey: "role") ?? "Worker"
        UserDefaults.standard.set(true, forKey: "flag")
        
        db.child("Places").child(cafeID).child("employees").child(selfID).observeSingleEvent(of: .value, with: { snapshot in
            guard snapshot.exists() else {
                DispatchQueue.main.async {
                    self.alert?.dismiss(animated: true) {
                        self.showAlert(title: "Извините!", message: "Вы были уволены") {
                            if let appDomain = Bundle.main.bundleIdentifier {
                                UserDefaults.standard.removePersistentDomain(forName: appDomain)
                            }
                            UserDefaults.standard.synchronize()
                            self.performSegue(withIdentifier: "wasFiredVC", sender: self)
                        }
                    }
                }
                return
            }
            
            let group = DispatchGroup()
            
            group.enter()
            downloadData(cafeID) { products in
                menu = products
                group.leave()
            }
            
            group.enter()
            let categoriesRef = db.child("Places").child(cafeID).child("categories")
            categoriesRef.observeSingleEvent(of: .value) { snapshot in
                if let value = snapshot.value as? [String: Any],
                   let existingCategories = value["categories"] as? [String] {
                    categories = existingCategories
                }
                group.leave()
            }
            
            group.enter()
            downloadUserData(cafeID, selfID) { employeeData in
                employee = employeeData
                group.leave()
            }
            
            group.notify(queue: .global(qos: .userInitiated)) {
                let profileImageName = selfID

                UserDefaults.standard.removeObject(forKey: "profileImageURL")

                if let imageUrlString = !employee.profileImageURL.isEmpty ? employee.profileImageURL : nil,
                   let url = URL(string: imageUrlString) {
                    
                    loadWithRetry(from: url.absoluteString, retries: 2) { image in
                        if let image = image {
                            saveImageLocally(image: image, name: profileImageName)
                            debugPrint("✅ Профильная картинка обновлена")
                        } else if let placeholder = UIImage(systemName: "person.crop.circle") {
                            saveImageLocally(image: placeholder, name: profileImageName)
                            debugPrint("❌ Не удалось загрузить аватарку профиля, поставлен placeholder")
                        }
                    }
                } else {
                    if let placeholder = UIImage(systemName: "person.crop.circle") {
                        saveImageLocally(image: placeholder, name: profileImageName)
                        debugPrint("ℹ️ Профиль без картинки, установлен placeholder")
                    }
                }
                
                let currentImageNames = menu.map { "\($0.id).png" }
                let allFiles = try? FileManager.default.contentsOfDirectory(atPath: documentsURL.path)
                allFiles?.forEach { file in
                    if !currentImageNames.contains(file) && !file.contains(profileImageName) {
                        try? FileManager.default.removeItem(at: documentsURL.appendingPathComponent(file))
                        debugPrint("🗑 Удалено старое изображение: \(file)")
                    }
                }
                
                // Загрузка изображений продуктов
                let imageGroup = DispatchGroup()
                var imageCache: [String: UIImage] = [:]
                
                for product in menu {
                    imageGroup.enter()
                    let imageName = "\(product.id).png"
                    
                    if let localImage = downloadLocalImage(name: imageName),
                       let savedUrl = UserDefaults.standard.string(forKey: "\(product.id)_imageUrl"),
                       savedUrl == product.productImageURL {
                        imageCache[product.id] = localImage
                        imageGroup.leave()
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
                            imageGroup.leave()
                        }
                    }
                }
                
                imageGroup.notify(queue: .main) {
                    tables = loadTables()
                    menu.sort(by: { $0.menuNumber < $1.menuNumber })
                    globalImageCache = imageCache
                    debugPrint("✅ Загружено \(menu.count) продуктов, \(globalImageCache.count) изображений. Должность: \(self.role)")
                    
                    self.alert?.dismiss(animated: true) {
                        switch self.role {
                        case "Cook":
                            self.performSegue(withIdentifier: "CookVC", sender: self)
                        case "Waiter":
                            self.performSegue(withIdentifier: "WaiterVC", sender: self)
                        case "Admin":
                            self.performSegue(withIdentifier: "AdminVC", sender: self)
                        default:
                            self.performSegue(withIdentifier: "wasFiredVC", sender: self)
                        }
                    }
                }
            }
        })
    }
    
    func showLoadingAlert() {
        let alert = UIAlertController(title: "Загрузка данных…", message: "Подождите пока все данные загрузятся и обновятся \n\n", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.startAnimating()
        alert.view.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor),
            loadingIndicator.topAnchor.constraint(equalTo: alert.view.topAnchor, constant: 90)
        ])
        present(alert, animated: true)
        self.alert = alert
    }
    
    func showAlert(title: String, message: String, completion: @escaping () -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ок", style: .default) { _ in completion() })
        present(alert, animated: true)
    }
}
