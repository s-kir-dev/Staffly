//
//  MainTabBarController.swift
//  Staffly
//
//  Created by Kirill Sysoev on 12.11.2025.
//

import UIKit
import FirebaseDatabase

class MainTabBarController: UITabBarController {
    
    let cafeID = UserDefaults.standard.string(forKey: "cafeID") ?? ""
    let selfID = UserDefaults.standard.string(forKey: "selfID") ?? ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupObservers()
    }
    
    func setupObservers() {
        guard !cafeID.isEmpty, !selfID.isEmpty else { return }
        
        let myTableNumbers = tables.map { "\($0.number)" }
        FirebaseObserver.shared.observeReadyOrdersCount(
            at: "Places/\(cafeID)/readyOrders",
            onlyForTables: myTableNumbers,
            badgeIndex: 1,
            tabBarController: self
        )
        
        let lastTabIndex = (self.tabBar.items?.count ?? 1) - 1
        
        FirebaseObserver.shared.observeMessagesCount(
            cafeID: cafeID,
            selfID: selfID,
            badgeIndex: lastTabIndex,
            tabBarController: self
        )
    }
    
    deinit {
        FirebaseObserver.shared.removeAllObservers()
    }
}
