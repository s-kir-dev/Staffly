//
//  SalesViewController.swift
//  Staffly
//
//  Created by Kirill Sysoev on 24.02.2026.
//

import UIKit
import FirebaseDatabase

class SalesViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    
    let cafeID = UserDefaults.standard.string(forKey: "cafeID")!
    
    var keys: [String] = []
    var saleImages: [UIImage] = []
    
    let loading = UIActivityIndicatorView(style: .large)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        
        loading.hidesWhenStopped = true
        loading.center = view.center
        view.addSubview(loading)
        
        loading.startAnimating()
        
        db.child("Places").child(cafeID).child("sales").child("images").observeSingleEvent(of: .value, with: { snapshot in
            self.keys.removeAll()
            self.saleImages.removeAll()
            
            let group = DispatchGroup()
            
            for child in snapshot.children {
                if let snap = child as? DataSnapshot {
                    let key = snap.key
                    
                    if let dict = snap.value as? [String: Any],
                       let urlString = dict.values.first as? String {
                        
                        self.keys.append(key)
                        
                        group.enter()
                        
                        loadWithRetry(from: urlString, retries: 2) { image in
                            if let downloadedImage = image {
                                self.saleImages.append(downloadedImage)
                            } else {
                                self.saleImages.append(UIImage(named: "блюдо") ?? UIImage())
                            }
                            group.leave()
                        }
                    }
                }
            }
            
            group.notify(queue: .main) {
                self.tableView.reloadData()
                self.loading.stopAnimating()
            }
            
        }) { error in
            print("Ошибка БД: \(error.localizedDescription)")
        }
    }
}

extension SalesViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: "Удалить") { _, _, _ in
            let key = self.keys[indexPath.row]
            
            db.child("Places").child(self.cafeID).child("sales").child("images").child(key).removeValue() { _, _ in
                self.keys.remove(at: indexPath.row)
                self.saleImages.remove(at: indexPath.row)
                self.tableView.reloadData()
            }
        }
        
        deleteAction.backgroundColor = .systemRed
        deleteAction.image = UIImage(systemName: "trash.fill")
        
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 160
    }
}

extension SalesViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        saleImages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! SaleImageTableViewCell
        
        let image = saleImages[indexPath.row]
        
        cell.saleImageView.image = image
        cell.saleImageView.layer.cornerRadius = 20
        cell.selectionStyle = .none
        
        return cell
    }
}
