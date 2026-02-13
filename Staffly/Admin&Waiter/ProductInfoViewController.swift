//
//  ProductInfoViewController.swift
//  Staffly
//
//  Created by Kirill Sysoev on 17.10.2025.
//

import UIKit

class ProductInfoViewController: UIViewController {
    
    @IBOutlet weak var productImageView: UIImageView!
    @IBOutlet weak var productNameLabel: UILabel!
    @IBOutlet weak var productDescriptionLabel: UILabel!
    @IBOutlet weak var productPriceLabel: UILabel!
    
    var product: Product = Product(id: "", menuNumber: 0, productCategory: "", productDescription: "", productImageURL: "", productName: "", productPrice: 0, additionWishes: "", weight: 0, ccal: 0)
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI(product)
    }
    
    
    func setupUI(_ product: Product) {
        self.navigationItem.title = "Блюдо №\(product.menuNumber)"
        productImageView.layer.cornerRadius = 15
        productImageView.clipsToBounds = true
        productImageView.image = globalImageCache[product.id]
        productNameLabel.text = product.productName
        productDescriptionLabel.text = product.productDescription
        productPriceLabel.text = "\(product.productPrice)р."
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
