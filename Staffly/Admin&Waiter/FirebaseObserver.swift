//
//  FirebaseObserver.swift
//  Staffly
//
//  Created by Kirill Sysoev on 12.11.2025.
//

import FirebaseDatabase
import UIKit

final class FirebaseObserver {
    static let shared = FirebaseObserver()
    private init() {}
    
    private var databaseHandles: [DatabaseHandle] = []
    private var observers: [DatabaseReference] = []
    
    func observeReadyOrdersCount(
        at path: String,
        onlyForTables tableNumbers: [String],
        badgeIndex: Int,
        tabBarController: UITabBarController
    ) {
        let ref = Database.database().reference(withPath: path)
        
        removeObserver(for: ref)
        
        let handle = ref.observe(.value) { snapshot in
            var count = 0
            
            for case let tableSnapshot as DataSnapshot in snapshot.children {
                guard tableNumbers.contains(tableSnapshot.key) else { continue }
                
                count += Int(tableSnapshot.childrenCount)
            }
            
            DispatchQueue.main.async {
                if count > 0 {
                    tabBarController.tabBar.items?[badgeIndex].badgeValue = "\(count)"
                } else {
                    tabBarController.tabBar.items?[badgeIndex].badgeValue = nil
                }
            }
        }
        
        observers.append(ref)
        databaseHandles.append(handle)
    }
    
    func observeMessagesCount(cafeID: String, selfID: String, badgeIndex: Int, tabBarController: UITabBarController?) {
        let ref = Database.database().reference()
            .child("Places")
            .child(cafeID)
            .child("employees")
            .child(selfID)
            .child("messages")
        
        removeObserver(for: ref)
        
        let handle = ref.observe(.value) { snapshot in
            let count = snapshot.childrenCount
            
            DispatchQueue.main.async {
                if count > 0 {
                    tabBarController?.tabBar.items?[badgeIndex].badgeValue = "\(count)"
                } else {
                    tabBarController?.tabBar.items?[badgeIndex].badgeValue = nil
                }
            }
        }
        
        observers.append(ref)
        databaseHandles.append(handle)
    }



    
    func removeAllObservers() {
        for (index, ref) in observers.enumerated() {
            ref.removeObserver(withHandle: databaseHandles[index])
        }
        observers.removeAll()
        databaseHandles.removeAll()
    }
    
    private func removeObserver(for ref: DatabaseReference) {
        if let index = observers.firstIndex(of: ref) {
            ref.removeObserver(withHandle: databaseHandles[index])
            observers.remove(at: index)
            databaseHandles.remove(at: index)
        }
    }
}
