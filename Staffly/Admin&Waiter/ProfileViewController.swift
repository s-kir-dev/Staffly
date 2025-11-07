//
//  ProfileViewController.swift
//  SepBill
//
//  Created by Kirill Sysoev on 17.10.2025.
//

import UIKit
import FirebaseDatabase

class ProfileViewController: UIViewController {
    @IBOutlet weak var selectImageButton: UIButton!
    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var userNameSurnameLabel: UILabel!
    @IBOutlet weak var selfIDLabel: UILabel!
    @IBOutlet weak var cafeIDLabel: UILabel!
    @IBOutlet weak var summaTipsLabel: UILabel!
    @IBOutlet weak var inviteCodesButton: UIButton!
    @IBOutlet weak var workersButton: UIButton!
    @IBOutlet weak var signOutButton: UIButton!
    @IBOutlet weak var deleteAccountButton: UIButton!
    
    let role = UserDefaults.standard.string(forKey: "role") ?? ""
    var roleString = ""
    var cafeID = ""
    var selfID = ""
    
    let imagePicker = UIImagePickerController()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imagePicker.delegate = self
        imagePicker.allowsEditing = true
        
        cafeID = UserDefaults.standard.string(forKey: "cafeID") ?? ""
        selfID = UserDefaults.standard.string(forKey: "selfID") ?? ""
        
        signOutButton.addTarget(self, action: #selector(signOutButtonTapped), for: .touchUpInside)
        deleteAccountButton.addTarget(self, action: #selector(deleteAccountButtonTapped), for: .touchUpInside)
        
        selectImageButton.addTarget(self, action: #selector(selectImageButtonTapped), for: .touchUpInside)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupUI()
    }
    
    @objc func signOutButtonTapped() {
        let alert = UIAlertController(title: "Подтверждение", message: "Вы уверены, что хотите выйти из аккаунта?", preferredStyle: .alert)
        
        let okAction = UIAlertAction(title: "Да", style: .default) { _ in
            if self.role == "Admin" || self.role == "Waiter" {
                guard tables.isEmpty else {
                    self.showAlert("Ошибка", "Сначала обслужите взятые Вами столы")
                    return
                }
                self.signOutAndResetApp()
            } else {
                db.child("Places").child(self.cafeID).child("orders").observeSingleEvent(of: .value) { snapshot in
                    if !snapshot.exists() || snapshot.childrenCount == 0 {
                        self.signOutAndResetApp()
                    } else {
                        self.showAlert("Ошибка", "Сначала приготовьте все заказы")
                    }
                }
            }
        }
        
        let cancelAction = UIAlertAction(title: "Нет", style: .cancel)
        alert.addAction(okAction)
        alert.addAction(cancelAction)
        present(alert, animated: true)
    }

    func signOutAndResetApp() {
        if let appDomain = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: appDomain)
        }
        UserDefaults.standard.synchronize()
        self.performSegue(withIdentifier: "onboardingVC", sender: self)
    }
    
    @objc func workersButtonTapped() {
        
    }
    
    @objc func deleteAccountButtonTapped() {
        let alert = UIAlertController(title: "Подтверждение", message: "Вы уверены, что хотите удалить аккаунт?", preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Да", style: .default, handler: {
            _ in
            db.child("Places").child(self.cafeID).child("employees").child(self.selfID).removeValue()
            
            if let appDomain = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: appDomain)
            }
            UserDefaults.standard.synchronize()
            
            self.performSegue(withIdentifier: "onboardingVC", sender: self)
        })
        let cancelAction = UIAlertAction(title: "Нет", style: .cancel)
        
        alert.addAction(okAction)
        alert.addAction(cancelAction)
        present(alert, animated: true)
    }
    
    @objc func selectImageButtonTapped() {
        present(imagePicker, animated: true)
    }
    
    func showAlert(_ title: String, _ message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Ок", style: .default)
        alert.addAction(okAction)
        present(alert, animated: true)
    }
    

    func setupUI() {
        switch role {
        case "Admin":
            roleString = "Админ"
            inviteCodesButton.isHidden = false
            workersButton.isHidden = false
            cafeIDLabel.isHidden = false
            summaTipsLabel.isHidden = false
        case "Waiter":
            roleString = "Официант"
            workersButton.isHidden = true
            inviteCodesButton.isHidden = true
            cafeIDLabel.isHidden = true
        case "Cook":
            roleString = "Повар"
            workersButton.isHidden = true
            cafeIDLabel.isHidden = true
            inviteCodesButton.isHidden = true
            summaTipsLabel.isHidden = true
        default:
            break
        }
        
        let name = UserDefaults.standard.string(forKey: "userName") ?? ""
        let surname = UserDefaults.standard.string(forKey: "userSurname") ?? ""
        let tips = UserDefaults.standard.double(forKey: "userTips")
        
        profileImageView.layer.cornerRadius = profileImageView.frame.width / 2
        
        profileImageView.image = downloadLocalImage(name: selfID) ?? UIImage(systemName: "person.crop.circle")!
        
        userNameSurnameLabel.text = "\(name) \(surname) (\(roleString))"
        selfIDLabel.text = "ID: \(selfID)"
        cafeIDLabel.text = "ID заведения: \(cafeID)"
        summaTipsLabel.text = "Сумма чаевых: \(tips)"
    }
}

extension ProfileViewController {
    enum Role: String {
        case admin = "Admin"
        case waiter = "Waiter"
        case cook = "Cook"
    }
}

extension ProfileViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard let image = info[.editedImage] as? UIImage else { return }
        profileImageView.image = image
        saveImageLocally(image: image, name: selfID)
        dismiss(animated: true)
    }
}
