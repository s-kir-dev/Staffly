//
//  ProfileViewController.swift
//  Staffly
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
    let loading = UIActivityIndicatorView(style: .large)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imagePicker.delegate = self
        imagePicker.allowsEditing = true
        
        cafeID = UserDefaults.standard.string(forKey: "cafeID") ?? ""
        selfID = UserDefaults.standard.string(forKey: "selfID") ?? ""
        
        signOutButton.addTarget(self, action: #selector(signOutButtonTapped), for: .touchUpInside)
        deleteAccountButton.addTarget(self, action: #selector(deleteAccountButtonTapped), for: .touchUpInside)
        selectImageButton.addTarget(self, action: #selector(selectImageButtonTapped), for: .touchUpInside)
        
        loading.center = view.center
        loading.hidesWhenStopped = true
        view.addSubview(loading)
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
                db.child("Places").child(self.cafeID).child("orders").observeSingleEvent(of: .value) { snapshot, _ in
                    if !snapshot.exists() || snapshot.childrenCount == 0 {
                        self.signOutAndResetApp()
                    } else {
                        self.showAlert("Ошибка", "Сначала приготовьте все заказы")
                    }
                }
            }
        }
        alert.addAction(okAction)
        alert.addAction(UIAlertAction(title: "Нет", style: .cancel))
        present(alert, animated: true)
    }

    func signOutAndResetApp() {
        if let appDomain = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: appDomain)
        }
        UserDefaults.standard.synchronize()
        performSegue(withIdentifier: "onboardingVC", sender: self)
    }
        
    @objc func deleteAccountButtonTapped() {
        let alert = UIAlertController(title: "Подтверждение", message: "Вы уверены, что хотите удалить аккаунт?", preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Да", style: .default, handler: { _ in
            db.child("Places").child(self.cafeID).child("employees").child(self.selfID).removeValue()
            if let appDomain = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: appDomain)
            }
            UserDefaults.standard.synchronize()
            self.performSegue(withIdentifier: "onboardingVC", sender: self)
        })
        alert.addAction(okAction)
        alert.addAction(UIAlertAction(title: "Нет", style: .cancel))
        present(alert, animated: true)
    }
    
    @objc func selectImageButtonTapped() {
        present(imagePicker, animated: true)
    }
    
    func showAlert(_ title: String, _ message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ок", style: .default))
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
            summaTipsLabel.text = "Сумма чаевых: \(employee.tips.roundValue())р."
        case "Waiter":
            roleString = "Официант"
            workersButton.isHidden = true
            inviteCodesButton.isHidden = true
            cafeIDLabel.isHidden = true
            summaTipsLabel.text = "Сумма чаевых: \(employee.tips.roundValue())р."
        case "Cook":
            roleString = "Повар"
            workersButton.isHidden = true
            inviteCodesButton.isHidden = true
            cafeIDLabel.isHidden = true
            summaTipsLabel.text = "Блюд приготовлено: \(employee.productsCount)"
        default: break
        }
        
        let name = UserDefaults.standard.string(forKey: "userName") ?? ""
        let surname = UserDefaults.standard.string(forKey: "userSurname") ?? ""
        
        profileImageView.layer.cornerRadius = profileImageView.frame.width / 2
        profileImageView.clipsToBounds = true
        
        if let localImage = downloadLocalImage(name: selfID) {
            profileImageView.image = localImage
        } else if let cloudURL = UserDefaults.standard.string(forKey: "profileImageURL") {
            loadWithRetry(from: cloudURL, retries: 3) { image in
                DispatchQueue.main.async {
                    if let img = image {
                        self.profileImageView.image = img
                        saveImageLocally(image: img, name: self.selfID)
                    } else {
                        self.profileImageView.image = UIImage(systemName: "person.crop.circle")
                    }
                }
            }
        } else {
            profileImageView.image = UIImage(systemName: "person.crop.circle")
        }
        
        userNameSurnameLabel.text = "\(name) \(surname) (\(roleString))"
        selfIDLabel.text = "ID: \(selfID)"
        cafeIDLabel.text = "ID заведения: \(cafeID)"
    }
}

extension ProfileViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard let image = info[.editedImage] as? UIImage else { return }
        dismiss(animated: true)
        profileImageView.image = image
        saveImageLocally(image: image, name: selfID)
        
        loading.startAnimating()
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            self.showAlert("Ошибка", "Не удалось подготовить изображение")
            return
        }

        let newPublicId = UUID().uuidString
        
        CloudinaryManager.shared.uploadImage(imageData, publicId: newPublicId) { result in
            DispatchQueue.main.async {
                self.loading.stopAnimating()
                switch result {
                case .success(let url):
                    UserDefaults.standard.set(url, forKey: "profileImageURL")
                    employee.profileImageURL = url
                    uploadUserData(self.cafeID, self.selfID, employee) { error in
                        if let error = error {
                            self.showAlert("Ошибка", "Не удалось обновить данные: \(error.localizedDescription)")
                        } else {
                            debugPrint("✅ Фото успешно загружено и обновлено с новым UUID")
                        }
                    }
                case .failure(let error):
                    self.showAlert("Ошибка", error.localizedDescription)
                }
            }
        }
    }
}
