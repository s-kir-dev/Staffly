//
//  DownloadViewController.swift
//  SepBill
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
        
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let cafeID = UserDefaults.standard.string(forKey: "cafeID") ?? "cafeID1"
        role = UserDefaults.standard.string(forKey: "role") ?? "Worker"
        
        UserDefaults.standard.set(true, forKey: "flag")
        
        showLoadingAlert()
        
        let selfID = UserDefaults.standard.string(forKey: "selfID") ?? ""
        
        downloadData(cafeID, completion: { products in
            menu = products
            
            let categoriesRef = db.child("Places").child(cafeID).child("categories")
            categoriesRef.observeSingleEvent(of: .value) { snapshot in
                if let value = snapshot.value as? [String: Any],
                   let existingCategories = value["categories"] as? [String] {
                    categories = existingCategories
                }
            }
            
            let currentImageNames = menu.map { "\($0.id).png" }
            let allFiles = try? FileManager.default.contentsOfDirectory(atPath: documentsURL.path)
            
            allFiles?.forEach { file in
                if !currentImageNames.contains(file) && !file.contains(selfID) {
                    try? FileManager.default.removeItem(at: documentsURL.appendingPathComponent(file))
                    debugPrint("🗑 Удалено старое изображение: \(file)")
                }
            }
            
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
                        if let image = image {
                            imageCache[product.id] = image
                            saveImageLocally(image: image, name: imageName)
                            debugPrint("✅ Картинка \(product.productName) загружена")
                        } else {
                            imageCache[product.id] = UIImage(named: "блюдо")
                            debugPrint("❌ Не удалось загрузить картинку для \(product.productName)")
                        }
                        group.leave()
                    }
                }
            }
            
            group.notify(queue: .main) {
                
                tables = loadTables()
                debugPrint("Загружено столов: \(tables.count)")
                
                menu.sort(by: {$0.menuNumber < $1.menuNumber})
                
                globalImageCache = imageCache
                debugPrint("✅ Загружено \(menu.count) продуктов, \(globalImageCache.count) изображений. Должность: \(self.role)")
                
                self.alert?.dismiss(animated: true) {
                    switch self.role {
                    case "Cook":
                        self.performSegue(withIdentifier: "CookVC", sender: self)
                    case "Waiter":
                        self.performSegue(withIdentifier: "WaiterVC", sender: self)
                    default:
                        self.performSegue(withIdentifier: "AdminVC", sender: self)
                    }
                }
            }
        })
    }
    
    func showLoadingAlert() {
        let alert = UIAlertController(title: "Загрузка данных…", message: "Подождите пока все данные загрузятся и обновятся \n \n", preferredStyle: .alert)
        
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
}
