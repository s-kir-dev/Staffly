//
//  Helper.swift
//  Staffly
//
//  Created by Kirill Sysoev on 15.10.2025.
//

import Foundation
import Cloudinary
import UIKit
import FirebaseDatabase

// MARK : - Storyboard

let storyboard = UIStoryboard(name: "Main", bundle: nil)
let onboardingVC = storyboard.instantiateViewController(withIdentifier: "onboardingVC")
let downloadVC = storyboard.instantiateViewController(withIdentifier: "downloadVC") as! DownloadViewController

// MARK : - Cloudinary

class CloudinaryManager {
    static let shared = CloudinaryManager()
    
    private var cloudinary: CLDCloudinary
    
    private init() {
        let config = CLDConfiguration(
            cloudName: "duhwr4zd0",
            apiKey: "764213155345326",
            apiSecret: "NAG10ufOQqg4OPS2TPjilhUU4qg"
        )
        cloudinary = CLDCloudinary(configuration: config)
    }
    
    func uploadImage(_ imageData: Data, publicId: String, completion: @escaping (Result<String, Error>) -> Void) {
        let params = CLDUploadRequestParams()
        params.setPublicId("reminderFolder/\(publicId)")
        
        cloudinary.createUploader().upload(data: imageData,
                                           uploadPreset: "Staffly",
                                           params: params, completionHandler:  { result, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let url = result?.url {
                completion(.success(url))
            } else {
                completion(.failure(NSError(
                    domain: "CloudinaryUpload",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Upload failed"]
                )))
            }
        })
    }
    
    func loadImage(from urlString: String, completion: @escaping (UIImage?) -> Void) {
        guard let url = URL(string: urlString.replacingOccurrences(of: "http://", with: "https://")) else {
            completion(UIImage(named: "блюдо"))
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil, let image = UIImage(data: data) else {
                completion(UIImage(named: "блюдо"))
                return
            }
            DispatchQueue.main.async {
                completion(image)
            }
        }.resume()
    }
}

func loadWithRetry(from urlString: String, retries: Int, completion: @escaping (UIImage?) -> Void) {
    let cloudinary = CloudinaryManager.shared
    cloudinary.loadImage(from: urlString) { image in
        if let image = image {
            completion(image)
        } else if retries > 0 {
            print("⚠️ Ошибка загрузки, повтор через 2 секунды… (\(retries))")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                loadWithRetry(from: urlString, retries: retries - 1, completion: completion)
            }
        } else {
            print("❌ Не удалось загрузить изображение: \(urlString)")
            completion(nil)
        }
    }
}

// MARK : - Structures

var categories: [String] = []

struct Product: Codable, Hashable {
    let id: String
    let menuNumber: Int
    let productCategory: String
    let productDescription: String
    var productImageURL: String
    let productName: String
    var productPrice: Double
    var additionWishes: String
}

struct ReadyOrder {
    let tableNumber: Int
    let clientNumber: Int
    let id: String
    let menuNumber: Int
    let productCategory: String
    let productDescription: String
    let productImageURL: String
    let productName: String
    let productPrice: Double
    var additionWishes: String
}

struct InviteCode {
    let code: String
    let role: String
}

struct SelectedProduct: Codable, Hashable {
    var product: Product
    var quantity: Int
}

struct Table: Codable, Equatable {
    let number: Int
    var personCount: Int
    var maximumPersonCount: Int
    
    var selectedProducts1: [SelectedProduct] = []
    var selectedProducts2: [SelectedProduct] = []
    var selectedProducts3: [SelectedProduct] = []
    var selectedProducts4: [SelectedProduct] = []
    var selectedProducts5: [SelectedProduct] = []
    var selectedProducts6: [SelectedProduct] = []
    
    var client1Bill: Double
    var client2Bill: Double
    var client3Bill: Double
    var client4Bill: Double
    var client5Bill: Double
    var client6Bill: Double
    
    var bill: Double
    
    static func == (lhs: Table, rhs: Table) -> Bool {
        lhs.number == rhs.number
    }
}

var tables: [Table] = []

struct Employee {
    var id: String
    var name: String
    var surname: String
    var email: String
    var password: String
    var role: String
    var tablesCount: Int
    var tips: Double
    var productsCount: Int
    var cafeProfit: Double
    var profileImageURL: String
}

var employee: Employee = Employee(id: "", name: "", surname: "", email: "", password: "", role: "", tablesCount: 0, tips: 0, productsCount: 0, cafeProfit: 0, profileImageURL: "") // Я

// MARK : - FirebaseDatabase

let db = Database.database().reference()

func uploadData(_ cafeID: String, tableNumber: Int, clientNumber: Int,  _ orders: [Product]) {
    for order in orders {
        db.child(cafeID).child("menu").child(UUID().uuidString).setValue([
            "a tableNumber": tableNumber,
            "b clientNumber": clientNumber,
            "id": order.id,
            "menuNumber": order.menuNumber,
            "productCategory": order.productCategory,
            "productDescription": order.productDescription,
            "productImageURL": order.productImageURL,
            "productName": order.productName,
            "productPrice": order.productPrice,
            "additionWishes": order.additionWishes
        ])
    }
}

func downloadData(_ cafeID: String, completion: @escaping([Product]) -> Void) {
    var products: [Product] = []
    
    db.child("Places").child(cafeID).child("menu").observeSingleEvent(of: .value, with: { snapshot in
        
        for child in snapshot.children {
            if let snap = child as? DataSnapshot, let data = snap.value as? [String: Any] {
                products.append(Product(
                    id: snap.key,
                    menuNumber: data["menuNumber"] as? Int ?? 0,
                    productCategory: data["productCategory"] as? String ?? "",
                    productDescription: data["productDescription"] as? String ?? "",
                    productImageURL: data["productImageURL"] as? String ?? "",
                    productName: data["productName"] as? String ?? "",
                    productPrice: data["productPrice"] as? Double ?? 0.0,
                    additionWishes: data["additionWishes"] as? String ?? ""
                ))
            }
        }
        completion(products)
    })
}

func downloadInviteCodes(_ cafeID: String, completion: @escaping([InviteCode]) -> Void) {
    db.child("Places").child(cafeID).child("inviteCodes").observeSingleEvent(of: .value, with: { snapshot in
        var codes = [InviteCode]()
        for child in snapshot.children {
            if let snap = child as? DataSnapshot, let data = snap.value as? [String: String] {
                
                let code = InviteCode(code: data["code"] ?? "", role: data["role"] ?? "")
                codes.append(code)
            }
        }
        completion(codes)
    })
}

func checkNumberExisting(_ number: Int, _ cafeID: String, completion: @escaping (Bool) -> Void) {
    db.child("Places").child(cafeID).child("menu").observeSingleEvent(of: .value) { snapshot in
        var exists = false
        for child in snapshot.children {
            if let snap = child as? DataSnapshot,
               let data = snap.value as? [String: Any],
               let menuNumber = data["menuNumber"] as? Int,
               menuNumber == number {
                exists = true
                break
            }
        }
        completion(!exists) // true — номер свободен, false — уже занят
    }
}

func checkTableNumberExisting(_ tableNumber: Int, _ cafeID: String, completion: @escaping (Bool) -> Void) {
    db.child("Places").child(cafeID).child("tables").observeSingleEvent(of: .value) { snapshot in
        var exists = false
        for child in snapshot.children {
            if let snap = child as? DataSnapshot,
               let data = snap.value as? [String: Any],
               let tableNumberData = data["tableNumber"] as? Int,
               tableNumberData == tableNumber {
                exists = true
                break
            }
        }
        completion(exists)
    }
}

func orderProducts(_ products: [Product], _ cafeID: String, _ tableNumber: Int, _ clientNumber: Int) {
    for product in products {
        db.child("Places").child(cafeID).child("orders").child("\(tableNumber)").child(UUID().uuidString).setValue([
            "a tableNumber": tableNumber,
            "b clientNumber": clientNumber,
            "id": product.id,
            "menuNumber": product.menuNumber,
            "productCategory": product.productCategory,
            "productDescription": product.productDescription,
            "productImageURL": product.productImageURL,
            "productName": product.productName,
            "productPrice": product.productPrice,
            "additionWishes": product.additionWishes
        ])
    }
}

func downloadUserData(_ cafeID: String, _ selfID: String, completion: @escaping (Employee) -> Void) {
    db.child("Places").child(cafeID).child("employees").child(selfID).observeSingleEvent(of: .value) { snapshot, _ in
        guard let data = snapshot.value as? [String: Any] else {
            completion(Employee(id: "", name: "", surname: "", email: "", password: "", role: "", tablesCount: 0, tips: 0.0, productsCount: 0, cafeProfit: 0.0, profileImageURL: ""))
            return
        }
        
        let id = data["id"] as? String ?? ""
        let name = data["name"] as? String ?? ""
        let surname = data["surname"] as? String ?? ""
        let role = data["role"] as? String ?? ""
        let email = data["email"] as? String ?? ""
        let password = data["password"] as? String ?? ""
        let productsCount = data["productsCount"] as? Int ?? 0
        let cafeProfit = data["cafeProfit"] as? Double ?? 0.0
        let tablesCount = data["tablesCount"] as? Int ?? 0
        let tips = data["tips"] as? Double ?? 0.0
        let profileImageURL = data["profileImageURL"] as? String ?? ""
        
        let employee = Employee(
            id: id,
            name: name,
            surname: surname,
            email: email,
            password: password,
            role: role,
            tablesCount: tablesCount,
            tips: tips.roundValue(),
            productsCount: productsCount,
            cafeProfit: cafeProfit,
            profileImageURL: profileImageURL
            
        )
        
        completion(employee)
    }
}

func uploadUserData(_ cafeID: String, _ selfID: String, _ employee: Employee, completion: @escaping (Error?) -> Void) {
    db.child("Places").child(cafeID).child("employees").child(selfID).updateChildValues([
        "productsCount": employee.productsCount,
        "cafeProfit": employee.cafeProfit,
        "tablesCount": employee.tablesCount,
        "tips": employee.tips.roundValue(),
        "profileImageURL": employee.profileImageURL
    ]) { error, _ in
        completion(error)
    }
}

// MARK : - Local data

func saveImageLocally(image: UIImage, name: String) {
    guard let data = image.pngData() else { return }
    
    let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(name)
    
    do {
        try data.write(to: path)
        debugPrint("Картинка \(name) успешно сохранена")
    } catch {
        debugPrint("Ошибка локального сохранения картинки \(name)")
    }
}

func downloadLocalImage(name: String) -> UIImage? {
    let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(name)
    guard let data = try? Data(contentsOf: path), let image = UIImage(data: data) else {
        return nil
    }
    return image
}

// MARK : - Arrays and dicts

var menu: [Product] = []
var inviteCodes: [InviteCode] = []
var globalImageCache: [String: UIImage] = [:]

// MARK : - Additional functions

func validateEmail(_ email: String) -> Bool {
    let emailRegex = "^[A-Za-z0-9.]+\\@[a-z]+\\.[a-z]{2,}$"
    
    return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: email)
}

func validatePassword(_ password: String) -> Bool {
    return password.count >= 6
}

func validateInviteCode(_ code: String) -> Bool {
    return code.count >= 6
}

func validateCafeID(_ id: String) -> Bool {
    return id.count >= 8
}

func makeRounded(_ textField: UITextField) {
    textField.clipsToBounds = true
    textField.layer.cornerRadius = textField.frame.height / 2
}

func generateInviteCode(role: String, cafeID: String) -> String {
    // role будет или админ или повар или официант
    let code = String(format: "%06d", Int.random(in: 0..<1_000_000))
    db.child("Places").child(cafeID).child("inviteCodes").child(code).setValue([
        "role": role,
        "code": code
    ])
    debugPrint("Создан пригласительный код для \(role)а: \(code)")
    return code
}

func generateCafeID(name: String, completion: @escaping (String) -> Void) {
    let cafeID = String(format: "%08d", Int.random(in: 0..<100_000_000))
    
    db.child("Places").child(cafeID).observeSingleEvent(of: .value) { snapshot in
        if snapshot.exists() {
            // Если ID уже занят, пробуем снова
            generateCafeID(name: name, completion: completion)
        } else {
            // Создаём новое кафе
            db.child("Places").child(cafeID).child("info").setValue(["name": name])
            debugPrint("Создан CafeID для \(name): \(cafeID)")
            UserDefaults.standard.set(cafeID, forKey: "cafeID")
            
            completion(cafeID)
        }
    }
}

func generatePersonalID(_ cafeID: String, _ name: String, _ surname: String, _ role: String, _ email: String, _ password: String) -> String {
    let selfID = UUID().uuidString
        db.child("Places").child(cafeID).child("employees").child(selfID).setValue([
            "name": name,
            "surname": surname,
            "role": role,
            "email": email,
            "password": password
        ])
    debugPrint("Создан код для \(role)а \(name) \(surname): id: \(selfID), email: \(email), password: \(password)")
    saveToUserDefaults(name, surname, cafeID, selfID, role)
    return selfID
}

func saveToUserDefaults(_ name: String, _ surname: String, _ cafeID: String, _ selfID: String, _ role: String) {
    UserDefaults.standard.set(0.00, forKey: "tips")
    UserDefaults.standard.set(name, forKey: "userName")
    UserDefaults.standard.set(surname, forKey: "userSurname")
    UserDefaults.standard.set(cafeID, forKey: "cafeID")
    UserDefaults.standard.set(selfID, forKey: "selfID")
    UserDefaults.standard.set(role, forKey: "role")
    debugPrint("Записал в UD name: \(name), surname: \(surname), cafeID: \(cafeID), selfID: \(selfID), role: \(role)")
}

func deleteUserFromUserDefaults() {
    UserDefaults.standard.set(0.0, forKey: "tips")
    UserDefaults.standard.removeObject(forKey: "userName")
    UserDefaults.standard.removeObject(forKey: "userSurname")
    UserDefaults.standard.removeObject(forKey: "cafeID")
    UserDefaults.standard.removeObject(forKey: "selfID")
    UserDefaults.standard.removeObject(forKey: "role")
    debugPrint("Данные о пользователе и кафе удалены")
}


// Сохранение массива столов
func saveTables(_ tables: [Table]) {
    if let data = try? JSONEncoder().encode(tables) {
        UserDefaults.standard.set(data, forKey: "tables")
    }
}

// Загрузка массива столов
func loadTables() -> [Table] {
    if let data = UserDefaults.standard.data(forKey: "tables"),
       let savedTables = try? JSONDecoder().decode([Table].self, from: data) {
        return savedTables
    }
    return []
}

func isBigger(_ a: Int, _ b: Int) -> Bool {
    return a > b
}

extension Double {
    func roundValue(toPlaces places: Int = 2) -> Double {
        let multiplier = pow(10.0, Double(places))
        return (self * multiplier).rounded() / multiplier
    }
}

extension Array where Element == SelectedProduct {
    var sum: Double {
        reduce(0) { $0 + (Double($1.product.productPrice) * Double($1.quantity)) }
    }
}
