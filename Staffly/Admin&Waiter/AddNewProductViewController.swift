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
    @IBOutlet weak var weightTextField: UITextField!
    @IBOutlet weak var ccalTextField: UITextField!
    @IBOutlet weak var addNewProductButton: UIButton!
    
    let imagePicker = UIImagePickerController()
    let cloudinary = CloudinaryManager.shared
    let cafeID = UserDefaults.standard.string(forKey: "cafeID") ?? ""
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupDelegates()
        setupUI()
        
        imagePicker.delegate = self
        imagePicker.allowsEditing = true
        
        changeImageButton.addTarget(self, action: #selector(pickImage), for: .touchUpInside)
        addNewProductButton.addTarget(self, action: #selector(addProductButtonTapped), for: .touchUpInside)
    }
    
    private func setupDelegates() {
        productNumberTextField.delegate = self
        productNameTextField.delegate = self
        productDescriptionTextView.delegate = self
        productCategoryTextField.delegate = self
        productPriceTextField.delegate = self
        weightTextField.delegate = self
        ccalTextField.delegate = self
    }
    
    private func setupUI() {
        [productNumberTextField, productNameTextField, productCategoryTextField, productPriceTextField, weightTextField, ccalTextField].forEach {
            makeRounded($0)
            addDoneButtonKeyboard($0)
        }
        
        productDescriptionTextView.layer.cornerRadius = 17
        productDescriptionTextView.clipsToBounds = true
        productImageView.layer.cornerRadius = 17
        productImageView.clipsToBounds = true
        
        addDoneButtonKeyboard(weightTextField)
        addDoneButtonKeyboard(ccalTextField)
    }
    
    @objc func addProductButtonTapped() {
        guard !cafeID.isEmpty else {
            showAlert("Ошибка", "ID кафе не найден. Перезайдите в систему.")
            return
        }
        
        // Валидация полей
        guard let numberText = productNumberTextField.text, let number = Int(numberText) else {
            showAlert("Ошибка", "Введите номер блюда")
            return
        }
        
        guard let name = productNameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            showAlert("Ошибка", "Введите название блюда")
            return
        }
        
        let description = productDescriptionTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        guard let rawCategory = productCategoryTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !rawCategory.isEmpty else {
            showAlert("Ошибка", "Введите категорию блюда")
            return
        }
        
        let normalizedCategory = rawCategory.replacingOccurrences(of: " ", with: "").lowercased()
        let categoryDisplay = rawCategory.capitalized
        
        guard let priceText = productPriceTextField.text?.replacingOccurrences(of: ",", with: "."),
              let price = Double(priceText)?.roundValue() else {
            showAlert("Ошибка", "Введите корректную стоимость")
            return
        }
        
        guard let weightText = weightTextField.text, let weight = Int(weightText) else {
            showAlert("Ошибка", "Введите вес блюда")
            return
        }
        
        guard let ccalText = ccalTextField.text, let ccal = Int(ccalText) else {
            showAlert("Ошибка", "Введите калории")
            return
        }
        
        let image = productImageView.image ?? UIImage(named: "блюдо")
        guard let imageData = image?.jpegData(compressionQuality: 0.7) else {
            showAlert("Ошибка", "Проблема с форматом изображения")
            return
        }
        
        // Проверка существования номера
        checkNumberExisting(number, cafeID) { isAvailable in
            if !isAvailable {
                self.showAlert("Ошибка", "Номер \(number) уже занят другим блюдом")
                return
            }
            
            self.uploadAndSaveProduct(imageData: imageData, number: number, name: name, description: description, categoryDisplay: categoryDisplay, normalizedCategory: normalizedCategory, price: price, weight: weight, ccal: ccal)
        }
    }
    
    private func uploadAndSaveProduct(imageData: Data, number: Int, name: String, description: String, categoryDisplay: String, normalizedCategory: String, price: Double, weight: Int, ccal: Int) {
        
        let alert = UIAlertController(title: nil, message: "Запись в базу данных...", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(style: .medium)
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.startAnimating()
        alert.view.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor),
            loadingIndicator.bottomAnchor.constraint(equalTo: alert.view.bottomAnchor, constant: -20)
        ])
        present(alert, animated: true)
        
        let productId = UUID().uuidString
        
        cloudinary.uploadImage(imageData, publicId: productId) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let imageUrl):
                // 1. Обновление категорий
                let categoriesRef = db.child("Places").child(self.cafeID).child("categories")
                categoriesRef.observeSingleEvent(of: .value) { snapshot in
                    var immutableCategories: [String] = []
                    if let value = snapshot.value as? [String: Any],
                       let existingCategories = value["categories"] as? [String] {
                        immutableCategories = existingCategories
                    }
                    
                    let categoriesLowercased = immutableCategories.map { $0.replacingOccurrences(of: " ", with: "").lowercased() }
                    if !categoriesLowercased.contains(normalizedCategory) {
                        immutableCategories.append(categoryDisplay)
                        categoriesRef.setValue(["categories": immutableCategories])
                    }
                }
                
                // 2. Сохранение блюда
                let productData: [String: Any] = [
                    "id": productId,
                    "menuNumber": number,
                    "productCategory": categoryDisplay,
                    "productDescription": description,
                    "productImageURL": imageUrl,
                    "productName": name,
                    "productPrice": price,
                    "additionWishes": "",
                    "productWeight": weight,
                    "productCcal": ccal,
                    "placeName": UserDefaults.standard.string(forKey: "cafeName") ?? "Cafe"
                ]
                
                db.child("Places").child(self.cafeID).child("menu").child(productId).setValue(productData) { error, _ in
                    DispatchQueue.main.async {
                        alert.dismiss(animated: true) {
                            if let error = error {
                                self.showAlert("Ошибка БД", error.localizedDescription)
                            } else {
                                self.clearFields()
                                self.showAlert("Успех", "Блюдо добавлено!")
                            }
                        }
                    }
                }
                
            case .failure(let error):
                DispatchQueue.main.async {
                    alert.dismiss(animated: true)
                    self.showAlert("Ошибка загрузки", error.localizedDescription)
                }
            }
        }
    }
    
    private func clearFields() {
        productNumberTextField.text = ""
        productNameTextField.text = ""
        productDescriptionTextView.text = ""
        productCategoryTextField.text = ""
        productPriceTextField.text = ""
        weightTextField.text = ""
        ccalTextField.text = ""
        productImageView.image = UIImage(named: "блюдо")
    }
    
    func showAlert(_ title: String, _ message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ок", style: .default))
        present(alert, animated: true)
    }
    
    @objc func pickImage() {
        present(imagePicker, animated: true)
    }
}

extension AddNewProductViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[.editedImage] as? UIImage {
            productImageView.image = image
        } else if let image = info[.originalImage] as? UIImage {
            productImageView.image = image
        }
        dismiss(animated: true)
    }
}

extension AddNewProductViewController {
    func addDoneButtonKeyboard(_ view: UITextField) {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let doneButton = UIBarButtonItem(title: "Готово", style: .done, target: self, action: #selector(closeKeyboard))
        toolbar.setItems([doneButton], animated: true)
        view.inputAccessoryView = toolbar
    }

    @objc func closeKeyboard() {
        view.endEditing(true)
    }
}

extension AddNewProductViewController: UITextFieldDelegate, UITextViewDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
