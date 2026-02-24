//
//  PromocodesViewController.swift
//  Staffly
//
//  Created by Kirill Sysoev on 24.02.2026.
//

import UIKit
import FirebaseDatabase

class PromocodesViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    
    var promocodes: [Promocode] = []
    let cafeID = UserDefaults.standard.string(forKey: "cafeID")!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self

        downloadPromocodesData(cafeID: cafeID, completion: { promocodesData in
            self.promocodes = promocodesData
            self.tableView.reloadData()
        })
    }
    

    func downloadPromocodesData(cafeID: String, completion: @escaping ([Promocode]) -> Void) {
        let dbRef = db.child("Places").child(cafeID).child("sales").child("promocodes")
        dbRef.observeSingleEvent(of: .value, with: { snapshot in
            var promocodesData: [Promocode] = []
            
            for child in snapshot.children {
                if let snap = child as? DataSnapshot,
                   let value = snap.value as? [String: Any] {
                    let promocode = Promocode(
                        name: value["name"] as? String ?? "",
                        price: value["price"] as? Double ?? 0,
                        value: value["value"] as? String ?? ""
                    )
                    promocodesData.append(promocode)
                }
            }
            completion(promocodesData)
        })
    }
}

extension PromocodesViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: "Удалить") { _, _, _ in
            let promocode = self.promocodes[indexPath.row]
            
            let dbRef = db.child("Places").child(self.cafeID).child("sales").child("promocodes")
            
            dbRef.child(promocode.name).removeValue() { _, _ in
                self.promocodes.remove(at: indexPath.row)
                self.tableView.reloadData()
            }
        }
        
        deleteAction.backgroundColor = .systemRed
        deleteAction.image = UIImage(systemName: "trash.fill")
        
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 88
    }
}

extension PromocodesViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        promocodes.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! PromocodeTableViewCell
        
        let promocode = promocodes[indexPath.row]
        
        cell.promocodeLabel.text = "Промокод на скидку \(promocode.price)\(promocode.value) - \"\(promocode.name)\""
        
        return cell
    }
    
    
}
