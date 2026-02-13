//
//  MessagesViewController.swift
//  Staffly
//
//  Created by Kirill Sysoev on 14.02.2026.
//

import UIKit
import FirebaseDatabase

class MessagesViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    
    let cafeID = UserDefaults.standard.string(forKey: "cafeID")!
    let selfID = UserDefaults.standard.string(forKey: "selfID")!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        observeMessages(cafeID: cafeID, selfID: selfID, completion: { messageTexts in
            self.tableView.reloadData()
        })
        
        tableView.delegate = self
        tableView.dataSource = self
    }

}


extension MessagesViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 81
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: "Удалить") { _,_,_ in
            let message = messages[indexPath.row]
            deleteMessage(messageID: message.id, cafeID: self.cafeID, selfID: self.selfID)
            messages.remove(at: indexPath.row)
            tableView.reloadData()
        }
        
        deleteAction.image = UIImage(systemName: "trash")
        
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
}

extension MessagesViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! MessageTableViewCell
        
        cell.messageLabel.text = messages[indexPath.row].text
        cell.selectionStyle = .none
        
        return cell
    }
}
