//
//  CreateTableViewController.swift
//  Staffly
//
//  Created by Kirill Sysoev on 17.10.2025.
//

import UIKit
import FirebaseDatabase

class CreateTableViewController: UIViewController {

    @IBOutlet weak var tableNumberTextField: UITextField!
    @IBOutlet weak var personCountTextField: UITextField!
    @IBOutlet weak var confirmButton: UIButton!
    
    let cafeID = UserDefaults.standard.string(forKey: "cafeID")!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        tableNumberTextField.delegate = self
        personCountTextField.delegate = self
        
        confirmButton.addTarget(self, action: #selector(confirmButtonTapped), for: .touchUpInside)
        
        makeRounded(tableNumberTextField)
        makeRounded(personCountTextField)
        addDoneButtonKeyboard(tableNumberTextField)
        addDoneButtonKeyboard(personCountTextField)
        
    }
    
    @objc func confirmButtonTapped() {
        guard let tableNumberText = tableNumberTextField.text, !tableNumberText.isEmpty, let tableNumber = Int(tableNumberText) else {
            showAlert("Ошибка", "Введите номер стола", UIAlertAction(title: "Ок", style: .default))
            return
        }
        
        guard let personCountText = personCountTextField.text, !personCountText.isEmpty, let personCount = Int(personCountText) else {
            showAlert("Ошибка", "Введите количество человек за столом", UIAlertAction(title: "Ок", style: .default))
            return
        }
        
        guard personCount <= 6 else {
            showAlert("Ошибка", "За столом не может быть больше 6 человек!", UIAlertAction(title: "Ок", style: .default))
            return
        }
        
        checkTableNumberExisting(tableNumber, cafeID, completion: {
            existingTableNumber in
            if !existingTableNumber, let cafeID = UserDefaults.standard.string(forKey: "cafeID"),
                let selfID = UserDefaults.standard.string(forKey: "selfID") {
                
                let qrImage = generateTableQR(cafeID, tableNumber, personCount, selfID)
                
                let tablesRef = db.child("Places").child(cafeID).child("employees").child(selfID).child("tables")

                tablesRef.runTransactionBlock({ (currentData: MutableData) -> TransactionResult in
                    var numbers = currentData.value as? [Int] ?? []
                    
                    if !numbers.contains(tableNumber) {
                        numbers.append(tableNumber)
                    }
                    
                    currentData.value = numbers
                    
                    return TransactionResult.success(withValue: currentData)
                })

                
                let newTable = Table(
                    number: tableNumber,
                    personCount: personCount,
                    maximumPersonCount: personCount,
                    currentPersonCount: 0,
                    client1Bill: 0,
                    client2Bill: 0,
                    client3Bill: 0,
                    client4Bill: 0,
                    client5Bill: 0,
                    client6Bill: 0,
                    bill: 0,
                    waiterID: selfID
                )
                                
                updateTableData(cafeID, newTable) {
                    tableNumbers.append(tableNumber)
                    tables.append(newTable)
                }
                
                let alert = UIAlertController(
                    title: "Успешно!",
                    message: "Стол №\(tableNumber) добавлен. Клиент может отсканировать этот код:",
                    preferredStyle: .alert
                )
                
                if let qr = qrImage {
                    let imageView = UIImageView(image: qr)
                    imageView.contentMode = .scaleAspectFit
                    
                    imageView.translatesAutoresizingMaskIntoConstraints = false
                    alert.view.addSubview(imageView)
                    
                    NSLayoutConstraint.activate([
                        imageView.topAnchor.constraint(equalTo: alert.view.topAnchor, constant: 100),
                        imageView.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor),
                        imageView.widthAnchor.constraint(equalToConstant: 150),
                        imageView.heightAnchor.constraint(equalToConstant: 150),
                        alert.view.bottomAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 70)
                    ])
                }
                
                let okAction = UIAlertAction(title: "Ок", style: .default) { _ in
                    self.navigationController?.popViewController(animated: true)
                }
                
                alert.addAction(okAction)
                self.present(alert, animated: true)
                
            } else {
                self.showAlert("Ошибка", "Номер стола \(tableNumber) занят. Введите другой номер стола", UIAlertAction(title: "Ок", style: .default))
            }
        })
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
    
    func showAlert(_ title: String, _ message: String, _ action: UIAlertAction) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = action
        alert.addAction(okAction)
        present(alert, animated: true)
    }

}

extension CreateTableViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

