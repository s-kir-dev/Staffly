//
//  SignInViewController.swift
//  SepBill
//
//  Created by Kirill Sysoev on 17.10.2025.
//

import UIKit
import FirebaseDatabase

class SignInViewController: UIViewController {

    @IBOutlet weak var cafeIDTextField: UITextField!
    @IBOutlet weak var inviteCodeTextField: UITextField!
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var surnameTextField: UITextField!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    
    @IBOutlet weak var signInButton: UIButton!
    @IBOutlet weak var adminButton: UIButton!
    
    var user = "Cook"
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // повар или официант вводит id кафе
        // потом вводит пригласительный код админа
        // по этому коду админа будет понятно на кого устроился сотрудник
        // потом вводит имя и фамилию
        // если все данные корректны вход выполнен успешно
        // генерируется персональный ID сотрудника
        // добро пожаловать в приложение
        
        cafeIDTextField.delegate = self
        inviteCodeTextField.delegate = self
        nameTextField.delegate = self
        surnameTextField.delegate = self
        emailTextField.delegate = self
        passwordTextField.delegate = self
        
        addDoneButtonKeyboard(cafeIDTextField)
        addDoneButtonKeyboard(inviteCodeTextField)
        
        signInButton.addTarget(self, action: #selector(signInButtonTapped), for: .touchUpInside)
        adminButton.addTarget(self, action: #selector(adminButtonTapped), for: .touchUpInside)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let textFields: [UITextField] = [cafeIDTextField, inviteCodeTextField, nameTextField, surnameTextField, emailTextField, passwordTextField]
        
        for textField in textFields {
            makeRounded(textField)
        }
    }
    
    @objc func signInButtonTapped() {
        // 1️⃣ Проверка полей
        guard let cafeIDText = cafeIDTextField.text, validateCafeID(cafeIDText) else {
            showAlert("Ошибка", "Введите ID заведения, который выдал Вам администратор")
            return
        }
        guard let codeText = inviteCodeTextField.text, validateInviteCode(codeText) else {
            showAlert("Ошибка", "Введите пригласительный код, который выдал Вам администратор заведения")
            return
        }
        guard let nameText = nameTextField.text, !nameText.isEmpty else {
            showAlert("Ошибка", "Заполните поле \"Имя\"")
            return
        }
        guard let surnameText = surnameTextField.text, !surnameText.isEmpty else {
            showAlert("Ошибка", "Заполните поле \"Фамилия\"")
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
        
        // 2️⃣ Проверяем, существует ли уже аккаунт с таким email
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
            
            if emailExists {
                self.showAlert("Внимание!", "Аккаунт с такой электронной почтой уже существует. Перейдите на экран входа.")
                return
            }
            
            // 3️⃣ Проверяем, есть ли такое кафе и код подходит ли
            let inviteRef = db.child("Places").child(cafeIDText).child("inviteCodes")
            
            inviteRef.observeSingleEvent(of: .value) { snapshot in
                var codeFound = false
                var roleForUser: String = "Worker"

                for child in snapshot.children {
                    if let snap = child as? DataSnapshot,
                       let data = snap.value as? [String: Any],
                       let code = data["code"] as? String,
                       let role = data["role"] as? String,
                       code == codeText {

                        codeFound = true
                        roleForUser = role

                        inviteRef.child(snap.key).removeValue()
                        break
                    }
                }

                if codeFound {
                    UserDefaults.standard.set(cafeIDText, forKey: "cafeID")
                    let userID = generatePersonalID(cafeIDText, nameText, surnameText, roleForUser, email, password)
                    debugPrint("Пользователь создан с ID: \(userID)")
                    self.performSegue(withIdentifier: "StartVC", sender: self)
                } else {
                    self.showAlert("Ошибка", "ID заведения или пригласительный код введены неверно")
                }
            }
        }
    }
    
    @objc func adminButtonTapped() {
        performSegue(withIdentifier: "AdminSignIn", sender: self)
    }
    
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
    
    func showAlert(_ title: String, _ message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Ок", style: .default)
        alert.addAction(okAction)
        present(alert, animated: true)
    }
    
}

extension SignInViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
