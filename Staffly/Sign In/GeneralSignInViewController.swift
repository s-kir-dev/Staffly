//
//  GeneralSignInViewController.swift
//  Staffly
//
//  Created by Kirill Sysoev on 19.10.2025.
//

import UIKit
import FirebaseDatabase

class GeneralSignInViewController: UIViewController {

    @IBOutlet weak var cafeNameTextField: UITextField!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    
    @IBOutlet weak var signInButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        cafeNameTextField.delegate = self
        emailTextField.delegate = self
        passwordTextField.delegate = self

        signInButton.addTarget(self, action: #selector(signInButtonTapped), for: .touchUpInside)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        makeRounded(cafeNameTextField)
        makeRounded(emailTextField)
        makeRounded(passwordTextField)
    }

    @objc func signInButtonTapped() {
        guard let name = cafeNameTextField.text, !name.isEmpty else {
            showAlert("Ошибка", "Введите название заведения")
            return
        }
        guard let email = emailTextField.text?.replacingOccurrences(of: " ", with: ""), validateEmail(email) else {
            showAlert("Ошибка", "Некорректный email")
            return
        }
        guard let password = passwordTextField.text, validatePassword(password) else {
            showAlert("Ошибка", "Пароль должен содержать не менее 6 символов")
            return
        }

        db.child("Places").observeSingleEvent(of: .value, with: { snapshot in
            var existingCafeID: String?

            // ищем кафе по имени
            for child in snapshot.children {
                if let snap = child as? DataSnapshot,
                   let info = snap.childSnapshot(forPath: "info").value as? [String: Any],
                   let cafeName = info["name"] as? String,
                   cafeName.lowercased().replacingOccurrences(of: " ", with: "") ==
                   name.lowercased().replacingOccurrences(of: " ", with: "") {
                    existingCafeID = snap.key
                    break
                }
            }

            guard let cafeID = existingCafeID else {
                self.showAlert("Ошибка", "Кафе с таким названием не найдено")
                return
            }

            // ищем пользователя по email
            db.child("Places").child(cafeID).child("employees").observeSingleEvent(of: .value) { employeesSnap in
                var foundUser: [String: Any]?
                var foundID: String?
                
                for case let personalSnap as DataSnapshot in employeesSnap.children {
                    if let userData = personalSnap.value as? [String: Any],
                       let userEmail = userData["email"] as? String,
                       userEmail == email {
                        foundUser = userData
                        foundID = personalSnap.key
                        break
                    }
                }
                
                guard let user = foundUser,
                      let userPassword = user["password"] as? String else {
                    self.showAlert("Ошибка", "Пользователь с таким email не найден в заведении \(self.cafeNameTextField.text ?? "")")
                    return
                }
                
                if password != userPassword {
                    self.showAlert("Ошибка", "Неверный пароль")
                    return
                }
                
                // вход успешен
                let userName = user["name"] as? String ?? ""
                let userSurname = user["surname"] as? String ?? ""
                let userRole = user["role"] as? String ?? "Worker"
                let userID = foundID ?? ""
                
                saveToUserDefaults(userName, userSurname, cafeID, userID, userRole)
                
                debugPrint("✅ Вход выполнен для \(userName) \(userSurname) (\(userRole)) в кафе \(name)")
                
                self.performSegue(withIdentifier: "SignedInVC", sender: self)
            }
        })
    }
    
    func showAlert(_ title: String, _ message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Ок", style: .default)
        alert.addAction(okAction)
        present(alert, animated: true)
    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let vc = segue.destination as? DownloadViewController {
            vc.role = UserDefaults.standard.string(forKey: "role") ?? "Worker"
        }
    }
}

extension GeneralSignInViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
