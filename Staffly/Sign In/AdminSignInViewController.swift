//
//  AdminSignInViewController.swift
//  Staffly
//
//  Created by Kirill Sysoev on 17.10.2025.
//

import UIKit
import FirebaseDatabase

class AdminSignInViewController: UIViewController {

    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var surnameTextField: UITextField!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var cafeNameAndAdressTextField: UITextField!
    @IBOutlet weak var addressTextField: UITextField!
    @IBOutlet weak var cafeIDTextField: UITextField!
    @IBOutlet weak var inviteCodeTextField: UITextField!
    @IBOutlet weak var signInButton: UIButton!
    
    var success: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // админ вводит почту и пароль
        // вводит название кафе и его адрес
        // после этого если у кафе уже есть админ
        // необходимо ввести заранее сгеренированный пригласительный код
        // код должен быть выбран для администратора иначе не подойдет
        // и ID кафе
        // также ввести имя и фамилию админа
        // если все данные корректны вход успешно выполнен
        // генерируется персональный ID сотрудника
        // добро пожаловать в приложение
        
        nameTextField.delegate = self
        surnameTextField.delegate = self
        emailTextField.delegate = self
        passwordTextField.delegate = self
        cafeNameAndAdressTextField.delegate = self
        addressTextField.delegate = self
        cafeIDTextField.delegate = self
        inviteCodeTextField.delegate = self
        signInButton.addTarget(self, action: #selector(signInButtonTapped), for: .touchUpInside)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let textFields: [UITextField] = [nameTextField, surnameTextField, emailTextField, passwordTextField, cafeNameAndAdressTextField, addressTextField, cafeIDTextField, inviteCodeTextField]
        
        for textField in textFields {
            makeRounded(textField)
        }
        
        addDoneButtonKeyboard(cafeIDTextField)
        addDoneButtonKeyboard(inviteCodeTextField)
    }
    
    @objc func signInButtonTapped() {
        guard let nameText = nameTextField.text, !nameText.isEmpty else {
            showAlert("Ошибка!", "Заполните данные в поле \"Имя\"")
            return
        }
        guard let surnameText = surnameTextField.text, !surnameText.isEmpty else {
            showAlert("Ошибка!", "Заполните данные в поле \"Фамилия\"")
            return
        }
        guard let email = emailTextField.text, validateEmail(email) else {
            showAlert("Ошибка", "Некорректный адрес электронной почты")
            return
        }
        guard let password = passwordTextField.text, validatePassword(password) else {
            showAlert("Ошибка", "Пароль должен содержать не менее 6 символов")
            return
        }
        guard let cafeNameText = cafeNameAndAdressTextField.text, !cafeNameText.isEmpty else {
            showAlert("Ошибка", "Данные о полном названии заведения должны быть заполнены!")
            return
        }
        guard let cafeAdressText = addressTextField.text, !cafeAdressText.isEmpty else {
            showAlert("Ошибка", "Данные о адресе заведения должны быть заполнены!")
            return
        }
        
        // Проверяем, существует ли уже аккаунт с таким email
        db.child("Places").observeSingleEvent(of: .value) { snapshot in
            var emailExists = false
            
            for placeChild in snapshot.children {
                if let placeSnap = placeChild as? DataSnapshot {
                    if placeSnap.hasChild("employees") {
                        for employeeChild in placeSnap.childSnapshot(forPath: "employees").children {
                            if let empSnap = employeeChild as? DataSnapshot,
                               let data = empSnap.value as? [String: Any],
                               let existingEmail = data["email"] as? String,
                               existingEmail.lowercased() == email.lowercased() {
                                emailExists = true
                                break
                            }
                        }
                    }
                }
                if emailExists { break }
            }
            
            // Если email уже есть — показываем ошибку
            if emailExists {
                self.showAlert("Внимание!", "Аккаунт с такой электронной почтой уже существует. Перейдите на экран входа.")
                return
            }
            
            // Ищем кафе с таким именем
            var existingCafeID: String?
            
            for child in snapshot.children {
                if let snap = child as? DataSnapshot,
                   let info = snap.childSnapshot(forPath: "info").value as? [String: Any],
                   let cafeName = info["name"] as? String,
                   cafeName.lowercased().replacingOccurrences(of: " ", with: "") == cafeNameText.lowercased().replacingOccurrences(of: " ", with: "") {
                    existingCafeID = snap.key
                    break
                }
            }
            
            // кафе существует
            if let cafeID = existingCafeID {
                db.child("Places").child(cafeID).child("employees").observeSingleEvent(of: .value) { snapshot in
                    var hasAdmin = false
                    
                    for child in snapshot.children {
                        if let snap = child as? DataSnapshot,
                           let data = snap.value as? [String: Any],
                           let role = data["role"] as? String,
                           role == "Admin" {
                            hasAdmin = true
                            break
                        }
                    }
                    
                    if hasAdmin {
                        // У кафе уже есть админ → требуем ID и пригласительный код
                        self.cafeIDTextField.isHidden = false
                        self.inviteCodeTextField.isHidden = false
                        
                        guard let cafeIDText = self.cafeIDTextField.text,
                              validateCafeID(cafeIDText),
                              cafeIDText == cafeID else {
                            self.showAlert("Ошибка", "Введите ID заведения")
                            return
                        }
                        guard let codeText = self.inviteCodeTextField.text,
                              validateInviteCode(codeText) else {
                            self.showAlert("Ошибка", "Введите правильный пригласительный код")
                            return
                        }
                        
                        let inviteCodesRef = db.child("Places").child(cafeID).child("inviteCodes")
                        inviteCodesRef.observeSingleEvent(of: .value) { snap in
                            var codeValid = false
                            var roleForUser: String?
                            
                            for child in snap.children {
                                if let codeSnap = child as? DataSnapshot,
                                   let data = codeSnap.value as? [String: Any],
                                   let codeData = data["code"] as? String,
                                   let roleData = data["role"] as? String,
                                   codeData == codeText {
                                    
                                    codeValid = true
                                    roleForUser = roleData
                                    
                                    inviteCodesRef.child(codeSnap.key).removeValue()
                                    break
                                }
                            }
                            
                            if codeValid {
                                debugPrint(generatePersonalID(cafeID, nameText, surnameText, roleForUser ?? "Worker", email, password))
                                self.performSegue(withIdentifier: "AdminStartVC", sender: self)
                            } else {
                                self.showAlert("Ошибка", "Пригласительный код неверен")
                            }
                        }
                    } else {
                        // Кафе есть, но админа нет → создаем админа
                        debugPrint(generatePersonalID(cafeID, nameText, surnameText, "Admin", email, password))
                        self.performSegue(withIdentifier: "AdminStartVC", sender: self)
                    }
                }
            } else {
                // Кафе не существует → создаем новое кафе и регистрируем админа
                self.cafeIDTextField.isHidden = true
                self.inviteCodeTextField.isHidden = true
                generateCafeID(name: cafeNameText, address: cafeAdressText) { newCafeID in
                    print(generatePersonalID(newCafeID, nameText, surnameText, "Admin", email, password))
                    self.performSegue(withIdentifier: "AdminStartVC", sender: self)
                }
                self.performSegue(withIdentifier: "AdminStartVC", sender: self)
            }
        }
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
    
    func showAlert(_ title: String, _ message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Ок", style: .default)
        alert.addAction(okAction)
        present(alert, animated: true)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "AdminStartVC" {
            if let vc = segue.destination as? DownloadViewController {
                vc.role = "Admin"
            } else {
                debugPrint("Не удалось привести destination к DownloadViewController")
            }
        }
    }

}

extension AdminSignInViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
