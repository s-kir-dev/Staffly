//
//  AddNewSaleImageViewController.swift
//  Staffly
//
//  Created by Kirill Sysoev on 24.02.2026.
//

import UIKit
import FirebaseDatabase

class AddNewSaleImageViewController: UIViewController {

    @IBOutlet weak var saleImageView: UIImageView!
    @IBOutlet weak var changeImageButton: UIButton!
    @IBOutlet weak var addSaleImageButton: UIButton!
    
    let imagePicker = UIImagePickerController()
    let cloudinary = CloudinaryManager.shared
    let cafeID = UserDefaults.standard.string(forKey: "cafeID") ?? ""
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        imagePicker.delegate = self
        imagePicker.allowsEditing = true
        
        saleImageView.layer.borderWidth = 3
        saleImageView.layer.borderColor = UIColor.orange.cgColor
        
        changeImageButton.addTarget(self, action: #selector(pickImage), for: .touchUpInside)
        addSaleImageButton.addTarget(self, action: #selector(addSaleImageButtonTapped), for: .touchUpInside)
    }
    
    @objc func addSaleImageButtonTapped() {
        guard let image = saleImageView.image, image != UIImage(systemName: "plus.circle.dashed") else {
            showAlert("Ошибка", "Выберите изображение акции из галереи, нажав на +", UIAlertAction(title: "Ок", style: .default, handler: nil))
            return
        }
        let alert = UIAlertController(title: "Добавление акции...", message: "\n", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(style: .medium)
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.startAnimating()
        alert.view.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor),
            loadingIndicator.bottomAnchor.constraint(equalTo: alert.view.bottomAnchor, constant: -20)
        ])
        present(alert, animated: true)
        
        let saleImageID = UUID().uuidString
        
        if let imageData = image.pngData() {
            cloudinary.uploadImage(imageData, publicId: saleImageID) { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success(let imageUrl):
                    db.child("Places").child(self.cafeID).child("sales").child("\(saleImageID)").setValue([
                        "\(saleImageID)": imageUrl
                    ]) { error, _ in
                        DispatchQueue.main.async {
                            alert.dismiss(animated: true) {
                                if let error = error {
                                    self.showAlert("Ошибка БД", error.localizedDescription, UIAlertAction(title: "Ок", style: .default))
                                } else {
                                    self.showAlert("Успех", "Акция добавлена!", UIAlertAction(title: "Ок", style: .default, handler: { _ in
                                        self.saleImageView.image = nil
                                        self.navigationController?.popViewController(animated: true)
                                    }))
                                }
                            }
                        }
                    }
                    
                case .failure(let error):
                    DispatchQueue.main.async {
                        alert.dismiss(animated: true)
                        self.showAlert("Ошибка загрузки", error.localizedDescription, UIAlertAction(title: "Ок", style: .default))
                    }
                }
            }
        } else {
            self.showAlert("Ошибка", "Проблемы с картинкой", UIAlertAction(title: "Ок", style: .default))
        }
    }
    
    @objc func pickImage() {
        present(imagePicker, animated: true)
    }
    
    func showAlert(_ title: String, _ message: String, _ action: UIAlertAction) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(action)
        present(alert, animated: true)
    }

}

extension AddNewSaleImageViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[.editedImage] as? UIImage {
            saleImageView.image = image
        } else if let image = info[.originalImage] as? UIImage {
            saleImageView.image = image
        }
        saleImageView.contentMode = .scaleAspectFill
        dismiss(animated: true)
    }
}
