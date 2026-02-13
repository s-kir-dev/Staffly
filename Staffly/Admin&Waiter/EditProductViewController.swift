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
    @IBOutlet weak var weightTextField: UITextField!
    @IBOutlet weak var ccalTextField: UITextField!
    @IBOutlet weak var saveProductButton: UIButton!
    
    let imagePicker = UIImagePickerController()
    let cloudinary = CloudinaryManager.shared
    let cafeID = UserDefaults.standard.string(forKey: "cafeID") ?? ""
    
    var product: Product = Product(id: "", menuNumber: 0, productCategory: "", productDescription: "", productImageURL: "", productName: "", productPrice: 0.0, additionWishes: "", weight: 0, ccal: 0)
    
    private var imageChanged = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupDelegates()
        setupStyles()
        setupUI()
        
        imagePicker.delegate = self
        imagePicker.allowsEditing = true
        
        changeImageButton.addTarget(self, action: #selector(pickImage), for: .touchUpInside)
        saveProductButton.addTarget(self, action: #selector(saveProductTapped), for: .touchUpInside)
    }
    
    private func setupDelegates() {
        [productNumberTextField, productNameTextField, productCategoryTextField, productPriceTextField, weightTextField, ccalTextField].forEach {
            $0?.delegate = self
            addDoneButtonKeyboard($0!)
        }
        productDescriptionTextView.delegate = self
    }
    
    private func setupStyles() {
        [productNumberTextField, productNameTextField, productCategoryTextField, productPriceTextField, weightTextField, ccalTextField].forEach {
            makeRounded($0!)
        }
        productDescriptionTextView.layer.cornerRadius = 17
        productImageView.layer.cornerRadius = 17
        productImageView.clipsToBounds = true
    }
    
    func setupUI() {
        productNumberTextField.text = "\(product.menuNumber)"
        productNameTextField.text = product.productName
        productDescriptionTextView.text = product.productDescription
        productCategoryTextField.text = product.productCategory
        productPriceTextField.text = "\(product.productPrice)"
        weightTextField.text = "\(product.weight)" // Добавил
        ccalTextField.text = "\(product.ccal)"     // Добавил
        productImageView.image = globalImageCache[product.id] ?? UIImage(named: "блюдо")
        addDoneButtonKeyboard(weightTextField)
        addDoneButtonKeyboard(ccalTextField)
    }
    
    @objc func saveProductTapped() {
        // 1. Валидация
        guard let numberText = productNumberTextField.text, let number = Int(numberText),
              let name = productNameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty,
              let priceText = productPriceTextField.text?.replacingOccurrences(of: ",", with: "."),
              let price = Double(priceText),
              let weight = Int(weightTextField.text ?? ""),
              let ccal = Int(ccalTextField.text ?? "") else {
            showAlert("Ошибка", "Заполните все поля корректно", action: UIAlertAction(title: "Ок", style: .default))
            return
        }
        
        let description = productDescriptionTextView.text ?? ""
        let category = productCategoryTextField.text?.capitalized ?? ""
        
        // 2. Лоадер
        let alert = UIAlertController(title: nil, message: "Сохранение...\n", preferredStyle: .alert)
        let loading = UIActivityIndicatorView(style: .medium)
        loading.translatesAutoresizingMaskIntoConstraints = false
        alert.view.addSubview(loading)
        NSLayoutConstraint.activate([
            loading.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor),
            loading.bottomAnchor.constraint(equalTo: alert.view.bottomAnchor, constant: -20)
        ])
        loading.startAnimating()
        present(alert, animated: true)
        
        // 3. Функция сохранения в БД
        func updateProductInDatabase(imageUrl: String) {
            let productRef = db.child("Places").child(self.cafeID).child("menu").child(self.product.id)
            
            let data: [String: Any] = [
                "id": self.product.id,
                "menuNumber": number,
                "productCategory": category,
                "productDescription": description,
                "productImageURL": imageUrl,
                "productName": name,
                "productPrice": price,
                "additionWishes": self.product.additionWishes,
                "productWeight": weight,
                "productCcal": ccal,
                "placeName": UserDefaults.standard.string(forKey: "cafeName") ?? ""
            ]
            
            productRef.setValue(data) { error, _ in
                DispatchQueue.main.async {
                    alert.dismiss(animated: true) {
                        if let error = error {
                            self.showAlert("Ошибка", error.localizedDescription, action: UIAlertAction(title: "Ок", style: .default))
                        } else {
                            // Обновляем локальный кэш
                            globalImageCache[self.product.id] = self.productImageView.image
                            
                            // Важно: обновляем объект в глобальном массиве, если он есть
                            if let index = menu.firstIndex(where: { $0.id == self.product.id }) {
                                menu[index] = Product(id: self.product.id, menuNumber: number, productCategory: category, productDescription: description, productImageURL: imageUrl, productName: name, productPrice: price, additionWishes: self.product.additionWishes, weight: weight, ccal: ccal)
                            }
                            
                            self.navigationController?.popViewController(animated: true)
                        }
                    }
                }
            }
        }
        
        // 4. Логика с картинкой
        if imageChanged, let imageData = productImageView.image?.jpegData(compressionQuality: 0.7) {
            let newPublicId = UUID().uuidString
            cloudinary.uploadImage(imageData, publicId: newPublicId) { result in
                switch result {
                case .success(let url):
                    DispatchQueue.main.async {
                        saveImageLocally(image: self.productImageView.image!, name: "\(self.product.id).png")
                        updateProductInDatabase(imageUrl: url)
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        alert.dismiss(animated: true)
                        self.showAlert("Ошибка загрузки фото", error.localizedDescription, action: UIAlertAction(title: "Ок", style: .default))
                    }
                }
            }
        } else {
            updateProductInDatabase(imageUrl: product.productImageURL)
        }
    }
    
    @objc func pickImage() { present(imagePicker, animated: true) }
    
    func showAlert(_ title: String, _ message: String, action: UIAlertAction) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(action)
        present(alert, animated: true)
    }
}

// MARK: - Extensions
extension EditProductViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        let image = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage)
        productImageView.image = image
        imageChanged = true
        dismiss(animated: true)
    }
}

extension EditProductViewController {
    func addDoneButtonKeyboard(_ view: UITextField) {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let doneButton = UIBarButtonItem(title: "Готово", style: .done, target: self, action: #selector(closeKeyboard))
        toolbar.setItems([doneButton], animated: true)
        view.inputAccessoryView = toolbar
    }
    @objc func closeKeyboard() { view.endEditing(true) }
}

extension EditProductViewController: UITextFieldDelegate, UITextViewDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
