//
//  MainTabBarController.swift
//  Staffly
//
//  Created by Kirill Sysoev on 12.11.2025.
//

import UIKit
import FirebaseDatabase

class MainTabBarController: UITabBarController {
    
    let cafeID = UserDefaults.standard.string(forKey: "cafeID")!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupObservers()
    }
    
    func setupObservers() {
        let myTableNumbers = tables.map { "\($0.number)" }

        FirebaseObserver.shared.observeReadyOrdersCount(
            at: "Places/\(cafeID)/readyOrders",
            onlyForTables: myTableNumbers,
            badgeIndex: 1,
            tabBarController: self
        )
    }
    
    deinit {
        FirebaseObserver.shared.removeAllObservers()
    }
}
