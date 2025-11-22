//
//  AddNewProductViewController.swift
//  Staffly
//
//  Created by Kirill Sysoev on 17.10.2025.
//

import UIKit
import FirebaseDatabase

class AddNewProductViewController: UIViewController {

    @IBOutlet weak var productNumberTextField: UITextField!
    @IBOutlet weak var productNameTextField: UITextField!
    @IBOutlet weak var productDescriptionTextView: UITextView!
    @IBOutlet weak var productCategoryTextField: UITextField!
    @IBOutlet weak var productPriceTextField: UITextField!
    @IBOutlet weak var productImageView: UIImageView!
    @IBOutlet weak var changeImageButton: UIButton!
    @IBOutlet weak var addNewProductButton: UIButton!
    
    let imagePicker = UIImagePickerController()
    
    let cloudinary = CloudinaryManager.shared
    
    let cafeID = UserDefaults.standard.string(forKey: "cafeID") ?? ""
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // если номер блюда в меню уже занять выводить alert и писать ближайший свободный номер к тому который вводил админ
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
        productDescriptionTextView.clipsToBounds = true
        productImageView.layer.cornerRadius = 17
        productImageView.clipsToBounds = true
        
        
        changeImageButton.addTarget(self, action: #selector(pickImage), for: .touchUpInside)
        
        addDoneButtonKeyboard(productNumberTextField)
        addDoneButtonKeyboard(productPriceTextField)
        
        imagePicker.delegate = self
        imagePicker.allowsEditing = true
        
        addNewProductButton.addTarget(self, action: #selector(addProductButtonTapped), for: .touchUpInside)
    }
    
    
    @objc func addProductButtonTapped() {
        guard let numberText = productNumberTextField.text, !numberText.isEmpty, let number = Int(numberText) else {
            showAlert("Ошибка", "Введите номер блюда")
            return
        }
        
        guard let name = productNameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            showAlert("Ошибка", "Введите название блюда")
            return
        }
        
        guard let description = productDescriptionTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines), !description.isEmpty else {
            showAlert("Ошибка", "Введите описание блюда")
            return
        }
        
        guard let rawCategory = productCategoryTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !rawCategory.isEmpty else {
            showAlert("Ошибка", "Введите категорию блюда")
            return
        }
        
        let normalizedCategory = rawCategory.replacingOccurrences(of: " ", with: "").lowercased()
        let categoryDisplay = rawCategory.capitalized
        
        guard let priceText = productPriceTextField.text, let price = Double(priceText)?.roundValue() else {
            showAlert("Ошибка", "Введите стоимость блюда")
            return
        }
        
        let image = productImageView.image ?? UIImage(named: "блюдо")!
        
        guard let imageData = image.pngData() else {
            showAlert("Ошибка", "Картинка не подходит")
            return
        }
        
        checkNumberExisting(number, cafeID) { isExistingNumber in
            if !isExistingNumber {
                self.showAlert("Ошибка", "Номер \(number) уже занят другим блюдом")
                return
            }
            
            let alert = UIAlertController(title: nil, message: "Идёт запись информации в базу данных…", preferredStyle: .alert)
            let loadingIndicator = UIActivityIndicatorView(style: .medium)
            loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
            loadingIndicator.startAnimating()
            alert.view.addSubview(loadingIndicator)
            NSLayoutConstraint.activate([
                loadingIndicator.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor),
                loadingIndicator.bottomAnchor.constraint(equalTo: alert.view.bottomAnchor, constant: -20)
            ])
            self.present(alert, animated: true)
            
            let productId = UUID().uuidString
            
            self.cloudinary.uploadImage(imageData, publicId: productId) { result in
                switch result {
                case .success(let imageUrl):
                    let product = Product(
                        id: productId,
                        menuNumber: number,
                        productCategory: categoryDisplay,
                        productDescription: description,
                        productImageURL: imageUrl,
                        productName: name,
                        productPrice: price,
                        additionWishes: ""
                    )
                    
                    let categoriesRef = db.child("Places").child(self.cafeID).child("categories")
                    categoriesRef.observeSingleEvent(of: .value) { snapshot in
                        var categories: [String] = []
                        var immutableCategories: [String] = []
                        if let value = snapshot.value as? [String: Any],
                           let existingCategories = value["categories"] as? [String] {
                            immutableCategories = existingCategories
                            categories = existingCategories.map { $0.replacingOccurrences(of: " ", with: "").lowercased() }
                        }
                        
                        if !categories.contains(normalizedCategory) {
                            immutableCategories.append(categoryDisplay)
                        }
                        
                        categoriesRef.setValue(["categories": immutableCategories])
                    }
                    
                    db.child("Places").child(self.cafeID).child("menu").child(productId).setValue([
                        "id": product.id,
                        "menuNumber": product.menuNumber,
                        "productCategory": product.productCategory,
                        "productDescription": product.productDescription,
                        "productImageURL": product.productImageURL,
                        "productName": product.productName,
                        "productPrice": product.productPrice,
                        "additionWishes": product.additionWishes
                    ]) { error, _ in
                        DispatchQueue.main.async {
                            alert.dismiss(animated: true)
                        }
                        if let error = error {
                            print("❌ Ошибка добавления в БД: \(error.localizedDescription)")
                            return
                        }
                        
                        self.cloudinary.loadImage(from: imageUrl) { loadedImage in
                            if loadedImage != nil {
                                print("✅ Картинка успешно доступна в Cloudinary")
                            } else {
                                print("❌ Не удалось проверить картинку в Cloudinary")
                            }
                        }
                        
                        DispatchQueue.main.async {
                            self.productNumberTextField.text = ""
                            self.productNameTextField.text = ""
                            self.productDescriptionTextView.text = ""
                            self.productCategoryTextField.text = ""
                            self.productPriceTextField.text = ""
                            self.productImageView.image = nil
                        }
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        alert.dismiss(animated: true)
                    }
                    print("❌ Ошибка загрузки изображения: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func showAlert(_ title: String, _ message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Ок", style: .default)
        alert.addAction(okAction)
        present(alert, animated: true)
    }
    
    @objc func pickImage() {
        present(imagePicker, animated: true)
    }
}

extension AddNewProductViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard let image = info[.editedImage] as? UIImage else { return }
        productImageView.image = image
        dismiss(animated: true)
    }
}

extension AddNewProductViewController {
    func addDoneButtonKeyboard(_ view: UITextField) {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        
        let doneButton = UIBarButtonItem(title: "Готово", style: UIBarButtonItem.Style.prominent, target: self, action: #selector(closeKeyboard))
        toolbar.setItems([doneButton], animated: true)
        
        view.inputAccessoryView = toolbar
    }

    @objc func closeKeyboard() {
        self.view.endEditing(true)
    }
}


extension AddNewProductViewController: UITextFieldDelegate, UITextViewDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textViewShouldEndEditing(_ textView: UITextView) -> Bool {
        textView.resignFirstResponder()
        return true
    }
}
