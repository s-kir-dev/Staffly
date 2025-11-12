//
//  EditProductViewController.swift
//  Staffly
//
//  Created by Kirill Sysoev on 11.11.2025.
//

import UIKit
import FirebaseDatabase

class EditProductViewController: UIViewController {
    
    @IBOutlet weak var productNumberTextField: UITextField!
    @IBOutlet weak var productNameTextField: UITextField!
    @IBOutlet weak var productDescriptionTextView: UITextView!
    @IBOutlet weak var productCategoryTextField: UITextField!
    @IBOutlet weak var productPriceTextField: UITextField!
    @IBOutlet weak var productImageView: UIImageView!
    @IBOutlet weak var changeImageButton: UIButton!
    @IBOutlet weak var saveProductButton: UIButton!
    
    let imagePicker = UIImagePickerController()
    let cloudinary = CloudinaryManager.shared
    let cafeID = UserDefaults.standard.string(forKey: "cafeID")!
    
    var product: Product = Product(
        id: "",
        menuNumber: 0,
        productCategory: "",
        productDescription: "",
        productImageURL: "",
        productName: "",
        productPrice: 0.0,
        additionWishes: ""
    )
    
    private var imageChanged = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        productNumberTextField.delegate = self
        productNameTextField.delegate = self
        productDescriptionTextView.delegate = self
        productCategoryTextField.delegate = self
        productPriceTextField.delegate = self
        
        makeRounded(productNumberTextField)
        makeRounded(productNameTextField)
        makeRounded(productCategoryTextField)
        makeRounded(productPriceTextField)
        
        productDescriptionTextView.layer.cornerRadius = 17
        productImageView.layer.cornerRadius = 17
        productImageView.clipsToBounds = true
        
        changeImageButton.addTarget(self, action: #selector(pickImage), for: .touchUpInside)
        saveProductButton.addTarget(self, action: #selector(saveProductTapped), for: .touchUpInside)
        
        addDoneButtonKeyboard(productNumberTextField)
        addDoneButtonKeyboard(productPriceTextField)
        
        imagePicker.delegate = self
        imagePicker.allowsEditing = true
        
        setupUI()
    }
    
    func setupUI() {
        productNumberTextField.text = "\(product.menuNumber)"
        productNameTextField.text = product.productName
        productDescriptionTextView.text = product.productDescription
        productCategoryTextField.text = product.productCategory
        productPriceTextField.text = "\(product.productPrice)"
        productImageView.image = globalImageCache[product.id] ?? UIImage(named: "блюдо")
    }
    
    @objc func saveProductTapped() {
        guard let numberText = productNumberTextField.text, !numberText.isEmpty,
              let number = Int(numberText) else {
            showAlert("Ошибка", "Введите номер блюда", action: UIAlertAction(title: "Ок", style: .default))
            return
        }
        
        guard let name = productNameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            showAlert("Ошибка", "Введите название блюда", action: UIAlertAction(title: "Ок", style: .default))
            return
        }
        
        guard let description = productDescriptionTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines), !description.isEmpty else {
            showAlert("Ошибка", "Введите описание блюда", action: UIAlertAction(title: "Ок", style: .default))
            return
        }
        
        guard let rawCategory = productCategoryTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !rawCategory.isEmpty else {
            showAlert("Ошибка", "Введите категорию блюда", action: UIAlertAction(title: "Ок", style: .default))
            return
        }
        
        let categoryDisplay = rawCategory.capitalized
        
        guard let priceText = productPriceTextField.text,
              let price = Double(priceText)?.roundValue() else {
            showAlert("Ошибка", "Введите корректную цену блюда", action: UIAlertAction(title: "Ок", style: .default))
            return
        }
        
        let alert = UIAlertController(title: nil, message: "Сохранение изменений...\n", preferredStyle: .alert)
        let loading = UIActivityIndicatorView(style: .medium)
        loading.translatesAutoresizingMaskIntoConstraints = false
        alert.view.addSubview(loading)
        NSLayoutConstraint.activate([
            loading.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor),
            loading.bottomAnchor.constraint(equalTo: alert.view.bottomAnchor, constant: -20)
        ])
        loading.startAnimating()
        present(alert, animated: true)
        
        func updateProductInDatabase(imageUrl: String) {
            let updatedProduct = Product(
                id: self.product.id,
                menuNumber: number,
                productCategory: categoryDisplay,
                productDescription: description,
                productImageURL: imageUrl,
                productName: name,
                productPrice: price,
                additionWishes: ""
            )
            
            let productRef = db.child("Places").child(self.cafeID).child("menu").child(self.product.id)
            productRef.setValue([
                "id": updatedProduct.id,
                "menuNumber": updatedProduct.menuNumber,
                "productCategory": updatedProduct.productCategory,
                "productDescription": updatedProduct.productDescription,
                "productImageURL": updatedProduct.productImageURL,
                "productName": updatedProduct.productName,
                "productPrice": updatedProduct.productPrice,
                "additionWishes": updatedProduct.additionWishes
            ]) { error, _ in
                DispatchQueue.main.async {
                    alert.dismiss(animated: true) {
                        if let error = error {
                            self.showAlert("Ошибка", "Не удалось сохранить: \(error.localizedDescription)", action: UIAlertAction(title: "Ок", style: .default))
                        } else {
                            globalImageCache[self.product.id] = self.productImageView.image
                            self.product.productImageURL = imageUrl
                            self.showAlert("Успех", "Изменения успешно сохранены!", action: UIAlertAction(title: "Ок", style: .default, handler: { _ in
                                self.navigationController?.popViewController(animated: true)
                            }))
                        }
                    }
                }
            }
        }
        
        if !imageChanged {
            updateProductInDatabase(imageUrl: product.productImageURL)
            return
        }
        
        guard let imageData = productImageView.image?.pngData() else {
            showAlert("Ошибка", "Изображение не выбрано", action: UIAlertAction(title: "Ок", style: .default))
            alert.dismiss(animated: true)
            return
        }
        
        let newUrl = "\(UUID().uuidString)"
        
        cloudinary.uploadImage(imageData, publicId: newUrl) { result in
            switch result {
            case .success(let imageUrl):
                DispatchQueue.main.async {
                    if let index = menu.firstIndex(where: { $0.id == self.product.id }) {
                        menu[index].productImageURL = imageUrl
                    }
                    globalImageCache[self.product.id] = self.productImageView.image
                    self.imageChanged = false
                    
                    let imageName = "\(self.product.id).png"
                    if let image = self.productImageView.image {
                        saveImageLocally(image: image, name: imageName)
                        debugPrint("♻️ Обновлено локальное изображение: \(imageName)")
                    }

                    updateProductInDatabase(imageUrl: imageUrl)
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    alert.dismiss(animated: true)
                    self.showAlert("Ошибка", "Ошибка загрузки изображения: \(error.localizedDescription)", action: UIAlertAction(title: "Ок", style: .default))
                }
            }
        }
    }
    
    @objc func pickImage() {
        present(imagePicker, animated: true)
    }
    
    func showAlert(_ title: String, _ message: String, action: UIAlertAction) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(action)
        present(alert, animated: true)
    }
}

extension EditProductViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let edited = info[.editedImage] as? UIImage {
            productImageView.image = edited
            imageChanged = true
        } else if let original = info[.originalImage] as? UIImage {
            productImageView.image = original
            imageChanged = true
        }
        dismiss(animated: true)
    }
}

extension EditProductViewController {
    func addDoneButtonKeyboard(_ view: UITextField) {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let doneButton = UIBarButtonItem(title: "Готово", style: .plain, target: self, action: #selector(closeKeyboard))
        toolbar.setItems([doneButton], animated: true)
        view.inputAccessoryView = toolbar
    }
    
    @objc func closeKeyboard() {
        view.endEditing(true)
    }
}

extension EditProductViewController: UITextFieldDelegate, UITextViewDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textViewShouldEndEditing(_ textView: UITextView) -> Bool {
        textView.resignFirstResponder()
        return true
    }
}
