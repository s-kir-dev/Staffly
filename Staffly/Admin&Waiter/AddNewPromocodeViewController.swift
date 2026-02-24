//
//  AddNewPromocodeViewController.swift
//  Staffly
//
//  Created by Kirill Sysoev on 24.02.2026.
//

import UIKit
import FirebaseDatabase

class AddNewPromocodeViewController: UIViewController {

    @IBOutlet weak var promocodeTextField: UITextField!
    @IBOutlet weak var priceTextField: UITextField!
    @IBOutlet weak var saleTypeMenuButton: UIButton!
    @IBOutlet weak var addPromocodeButton: UIButton!
    
    let cafeID = UserDefaults.standard.string(forKey: "cafeID")!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        promocodeTextField.delegate = self
        priceTextField.delegate = self
        addDoneButtonKeyboard(priceTextField)
        
        setupMenuButton()
        addPromocodeButton.addTarget(self, action: #selector(addPromocodeButtonTapped), for: .touchUpInside)
    }
    

    func setupMenuButton() {
        let categoryActions: [UIAction] = ["Руб.", "%"].map { title in
            UIAction(title: title) { _ in
                self.saleTypeMenuButton.setTitle(" \(title)", for: .normal)
            }
        }
        
        let menu = UIMenu(title: "Выберите ед. измерения скидки", children:  categoryActions)
        saleTypeMenuButton.menu = menu
        saleTypeMenuButton.showsMenuAsPrimaryAction = true
        saleTypeMenuButton.setTitle("Руб.", for: .normal)
    }
    
    @objc func addPromocodeButtonTapped() {
        guard let promocode = promocodeTextField.text, !promocode.isEmpty, let priceText = priceTextField.text, let price = Double(priceText), let value = saleTypeMenuButton.titleLabel?.text else {
            showAlert("Ошибка", "Заполните все поля", UIAlertAction(title: "Ок", style: .default))
            return
        }
        
        db.child("Places").child(cafeID).child("sales").child("promocodes").child(promocode).setValue([
            promocode: "\(price) \(value)"
        ]) { error, _ in
            let alert = UIAlertController(title: "Добавление помокода...", message: "\n", preferredStyle: .alert)
            let loadingIndicator = UIActivityIndicatorView(style: .medium)
            loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
            loadingIndicator.startAnimating()
            alert.view.addSubview(loadingIndicator)
            NSLayoutConstraint.activate([
                loadingIndicator.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor),
                loadingIndicator.bottomAnchor.constraint(equalTo: alert.view.bottomAnchor, constant: -20)
            ])
            self.present(alert, animated: true)
            
            DispatchQueue.main.async {
                alert.dismiss(animated: true) {
                    if let error = error {
                        self.showAlert("Ошибка БД", error.localizedDescription, UIAlertAction(title: "Ок", style: .default))
                    } else {
                        self.showAlert("Успех", "Промокод добавлен!", UIAlertAction(title: "Ок", style: .default, handler: { _ in
                            self.navigationController?.popViewController(animated: true)
                        }))
                    }
                }
            }
        }
    }
    
    func showAlert(_ title: String, _ message: String, _ action: UIAlertAction) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(action)
        present(alert, animated: true)
    }
    
    func addDoneButtonKeyboard(_ view: UITextField) {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        
        var doneButton = UIBarButtonItem(title: "Готово", style: UIBarButtonItem.Style.plain, target: self, action: #selector(closeKeyboard))
        if #available(iOS 26.0, *) {
            doneButton = UIBarButtonItem(title: "Готово", style: UIBarButtonItem.Style.prominent, target: self, action: #selector(closeKeyboard))
        }
        toolbar.setItems([doneButton], animated: true)
        
        view.inputAccessoryView = toolbar
    }
    
    @objc func closeKeyboard() {
        self.view.endEditing(true)
    }

}


extension AddNewPromocodeViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
