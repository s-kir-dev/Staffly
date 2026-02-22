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
import CoreImage.CIFilterBuiltins

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
    var weight: Int
    var ccal: Int
}

struct ReadyOrder: Codable {
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
    var sharedWith: [Int]
    var quantity: Int
}

struct Table: Codable, Equatable {
    let number: Int
    
    var personCount: Int
    var maximumPersonCount: Int
    var currentPersonCount: Int
    
//    var selectedProducts1: [SelectedProduct] = []
//    var selectedProducts2: [SelectedProduct] = []
//    var selectedProducts3: [SelectedProduct] = []
//    var selectedProducts4: [SelectedProduct] = []
//    var selectedProducts5: [SelectedProduct] = []
//    var selectedProducts6: [SelectedProduct] = []
    
    var client1Bill: Double
    var client2Bill: Double
    var client3Bill: Double
    var client4Bill: Double
    var client5Bill: Double
    var client6Bill: Double
    
    var bill: Double
    
    var waiterID: String
    
    static func == (lhs: Table, rhs: Table) -> Bool {
        lhs.number == rhs.number
    }
}

// MARK : - Structures

struct Message: Hashable {
    let id: String
    let text: String 
}

var tables: [Table] = []
var tableNumbers: [Int] = []
var messages: [Message] = []
var myOrders: [ReadyOrder] = []

var myOrderKeys: [String] = []

func saveMyOrderKeys(_ keys: [String]) {
    UserDefaults.standard.set(keys, forKey: "myOrderKeys")
}

func loadMyOrderKeys() {
    myOrderKeys = UserDefaults.standard.stringArray(forKey: "myOrderKeys") ?? []
}



func generateTableQR(_ cafeID: String, _ tableNumber: Int, _ clientCount: Int, _ waiterID: String) -> UIImage? {
    let rawString = "staffly://table?cafeID=\(cafeID)&num=\(tableNumber)&clients=\(clientCount)&waiter=\(waiterID)"
    
    guard let encodedString = rawString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
          let data = encodedString.data(using: .utf8) else { return nil }
    
    let filter = CIFilter.qrCodeGenerator()
    filter.setValue(data, forKey: "inputMessage")
    
    filter.setValue("Q", forKey: "inputCorrectionLevel")
    
    guard let outputImage = filter.outputImage else { return nil }
    
    let transform = CGAffineTransform(scaleX: 100, y: 100)
    let scaledImage = outputImage.transformed(by: transform)
    
    return UIImage(ciImage: scaledImage)
}


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
                    additionWishes: data["additionWishes"] as? String ?? "",
                    weight: data["productWeight"] as? Int ?? 0,
                    ccal: data["productCcal"] as? Int ?? 0
                ))
            }
        }
        completion(products)
    })
}

func observeMessages(cafeID: String, selfID: String, completion: @escaping ([Message]) -> Void) {
    db.child("Places").child(cafeID).child("employees").child(selfID).child("messages").observe(.value) { snapshot in
        var newMessages: [Message] = []
        
        for child in snapshot.children {
            if let snap = child as? DataSnapshot,
               let messageText = snap.value as? String {
                let msg = Message(id: snap.key, text: messageText)
                newMessages.append(msg)
            }
        }
        
        messages = newMessages
        completion(newMessages)
    }
}

func deleteMessage(messageID: String, cafeID: String, selfID: String) {
    db.child("Places").child(cafeID).child("employees").child(selfID).child("messages").child(messageID).removeValue()
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

func generateCafeID(name: String, address: String, completion: @escaping (String) -> Void) {
    let cafeID = String(format: "%08d", Int.random(in: 0..<100_000_000))
    
    db.child("Places").child(cafeID).observeSingleEvent(of: .value) { snapshot in
        if snapshot.exists() {
            // Если ID уже занят, пробуем снова
            generateCafeID(name: name, address: address, completion: completion)
        } else {
            // Создаём новое кафе
            db.child("Places").child(cafeID).child("info").setValue(["name": name, "address": address])
            debugPrint("Создан CafeID для \(name): \(cafeID)")
            UserDefaults.standard.set(cafeID, forKey: "cafeID")
            
            completion(cafeID)
        }
    }
}

func generatePersonalID(_ cafeID: String, _ name: String, _ surname: String, _ role: String, _ email: String, _ password: String, cafeName: String) -> String {
    let selfID = UUID().uuidString
        db.child("Places").child(cafeID).child("employees").child(selfID).setValue([
            "name": name,
            "surname": surname,
            "role": role,
            "email": email,
            "password": password
        ])
    debugPrint("Создан код для \(role)а \(name) \(surname): id: \(selfID), email: \(email), password: \(password)")
    saveToUserDefaults(name, surname, cafeID, selfID, role, cafeName)
    return selfID
}

func saveToUserDefaults(_ name: String, _ surname: String, _ cafeID: String, _ selfID: String, _ role: String, _ cafeName: String) {
    UserDefaults.standard.set(0.00, forKey: "tips")
    UserDefaults.standard.set(name, forKey: "userName")
    UserDefaults.standard.set(surname, forKey: "userSurname")
    UserDefaults.standard.set(cafeID, forKey: "cafeID")
    UserDefaults.standard.set(selfID, forKey: "selfID")
    UserDefaults.standard.set(role, forKey: "role")
    UserDefaults.standard.set(name, forKey: "cafeName")
    debugPrint("Записал в UD name: \(cafeName), surname: \(surname), cafeID: \(cafeID), selfID: \(selfID), role: \(role)")
}

func deleteUserFromUserDefaults() {
    UserDefaults.standard.set(0.0, forKey: "tips")
    UserDefaults.standard.removeObject(forKey: "userName")
    UserDefaults.standard.removeObject(forKey: "userSurname")
    UserDefaults.standard.removeObject(forKey: "cafeID")
    UserDefaults.standard.removeObject(forKey: "selfID")
    UserDefaults.standard.removeObject(forKey: "role")
    UserDefaults.standard.removeObject(forKey: "cafeName")
    debugPrint("Данные о пользователе и кафе удалены")
}


func removeTable(_ cafeID: String, _ selfID: String, _ table: Table, completion: @escaping () -> ()) {
    let tablesRef = db.child("Places").child(cafeID).child("employees").child(selfID).child("tables")
    
    tablesRef.runTransactionBlock({ (currentData: MutableData) -> TransactionResult in
        var items = currentData.value as? [Int] ?? []
        
        if let index = items.firstIndex(of: table.number) {
            items.remove(at: index)
            currentData.value = items
            return TransactionResult.success(withValue: currentData)
        } else {
            return TransactionResult.success(withValue: currentData)
        }
    }) { error, committed, snapshot in
        if let error = error {
            print("Ошибка транзакции: \(error.localizedDescription)")
        }
        DispatchQueue.main.async {
            completion()
        }
    }
}


func updateTableData(_ cafeID: String, _ table: Table, completion: @escaping ()->()) {
    db.child("Places").child(cafeID).child("tables").child("\(table.number)").updateChildValues([
        "tableNumber": table.number,
        "personCount": table.personCount,
        "maximumPersonCount": table.maximumPersonCount,
        "client1Bill": table.client1Bill,
        "client2Bill": table.client2Bill,
        "client3Bill": table.client3Bill,
        "client4Bill": table.client4Bill,
        "client5Bill": table.client5Bill,
        "client6Bill": table.client6Bill,
        "bill": table.bill
    ]) { _,_ in 
        completion()
    }
}

func loadTables(_ cafeID: String, _ selfID: String, _ tableNumbers: [Int], completion: @escaping ([Table]) -> ()) {
    var tablesData: [Table] = []
    let group = DispatchGroup()

    for number in tableNumbers {
        group.enter()
        db.child("Places").child(cafeID).child("tables").child("\(number)").observeSingleEvent(of: .value, with: { snapshot in
            
            if let dict = snapshot.value as? [String: Any] {
                let table = Table(
                    number: dict["tableNumber"] as? Int ?? 0,
                    personCount: dict["personCount"] as? Int ?? 0,
                    maximumPersonCount: dict["maximumPersonCount"] as? Int ?? 0,
                    currentPersonCount: dict["currentPersonCount"] as? Int ?? 0,
                    client1Bill: dict["client1Bill"] as? Double ?? 0,
                    client2Bill: dict["client2Bill"] as? Double ?? 0,
                    client3Bill: dict["client3Bill"] as? Double ?? 0,
                    client4Bill: dict["client4Bill"] as? Double ?? 0,
                    client5Bill: dict["client5Bill"] as? Double ?? 0,
                    client6Bill: dict["client6Bill"] as? Double ?? 0,
                    bill: dict["bill"] as? Double ?? 0,
                    waiterID: dict["waiterID"] as? String ?? ""
                )
                tablesData.append(table)
            }
            
            group.leave()
        })
    }
    
    group.notify(queue: .main) {
        let sortedTables = tablesData.sorted { $0.number < $1.number }
        completion(sortedTables)
    }
}


func loadSelectedProducts(_ cafeID: String, _ clientNumber: Int, _ tableNumber: Int, completion: @escaping ([SelectedProduct]) -> Void) {
    let selectedProductsRef = db.child("Places").child(cafeID).child("tables").child("\(tableNumber)").child("clients").child("client\(clientNumber)").child("orders")
    
    selectedProductsRef.observeSingleEvent(of: .value, with: { snapshot in
        var selectedProducts: [SelectedProduct] = []
        let group = DispatchGroup()
        
        for child in snapshot.children {
            if let snap = child as? DataSnapshot, let dict = snap.value as? [String: Any] {
                let productDict = dict
                
                let selectedProduct = SelectedProduct(
                    product: Product(
                        id: productDict["id"] as? String ?? "",
                        menuNumber: productDict["menuNumber"] as? Int ?? 0,
                        productCategory: productDict["productCategory"] as? String ?? "",
                        productDescription: productDict["productDescription"] as? String ?? "",
                        productImageURL: productDict["productImageURL"] as? String ?? "",
                        productName: productDict["productName"] as? String ?? "",
                        productPrice: productDict["productPrice"] as? Double ?? 0,
                        additionWishes: productDict["additionWishes"] as? String ?? "",
                        weight: productDict["weight"] as? Int ?? 0,
                        ccal: productDict["ccal"] as? Int ?? 0
                    ),
                    sharedWith: productDict["sharedWith"] as? [Int] ?? [],
                    quantity: productDict["quantity"] as? Int ?? 0
                )
                selectedProducts.append(selectedProduct)
            }
        }
        // Возвращаем данные только после того, как цикл завершен
        completion(selectedProducts)
    })
}


func orderProductsClient(_ cafeID: String, _ tableNumber: Int, _ clientNumber: Int, _ summa: Double, _ products: [SelectedProduct], completion: @escaping () -> Void) {
    let group = DispatchGroup()
    
    let cookRef = db.child("Places").child(cafeID).child("orders").child("\(tableNumber)")
    let clientRef = db.child("Places").child(cafeID).child("tables").child("\(tableNumber)").child("clients").child("client\(clientNumber)")
    let clientOrdersRef = clientRef.child("orders")
    
    for selectedProduct in products {
        for _ in 1...selectedProduct.quantity {
            group.enter()
            //let orderItemID = (auth.currentUser?.uid ?? "") + UUID().uuidString
            cookRef.child(UUID().uuidString).setValue([
                "a tableNumber": tableNumber,
                "b clientNumber": clientNumber,
                "id": selectedProduct.product.id,
                "menuNumber": selectedProduct.product.menuNumber,
                "productCategory": selectedProduct.product.productCategory,
                "productName": selectedProduct.product.productName,
                "productDescription": selectedProduct.product.productDescription,
                "productPrice": selectedProduct.product.productPrice,
                "productImageURL": selectedProduct.product.productImageURL,
                "rating": 0,
                "myRating": 0,
                "additionWishes": selectedProduct.product.additionWishes,
                "placeName": "Ля салют",
                "weight": selectedProduct.product.weight,
                "ccal": selectedProduct.product.ccal,
                
                "sharedWith": selectedProduct.sharedWith,
                "quantity": selectedProduct.quantity,
                
                "status": "Отправлен"
            ]) { _, _ in
                group.leave()
            }
        }
    }
    
    for selectedProduct in products {
        group.enter()
        let productRef = clientOrdersRef.child(selectedProduct.product.id)
        
        productRef.observeSingleEvent(of: .value, with: { snapshot in
            if snapshot.exists(), let productData = snapshot.value as? [String: Any], let oldQty = productData["quantity"] as? Int {
                let newQty = oldQty + selectedProduct.quantity
                productRef.updateChildValues(["quantity": newQty]) { _, _ in
                    group.leave()
                }
            } else {
                let newProductData: [String: Any] = [
                    "id": selectedProduct.product.id,
                    "menuNumber": selectedProduct.product.menuNumber,
                    "productCategory": selectedProduct.product.productCategory,
                    "productName": selectedProduct.product.productName,
                    "productDescription": selectedProduct.product.productDescription,
                    "productPrice": selectedProduct.product.productPrice,
                    "productImageURL": selectedProduct.product.productImageURL,
                    "rating": 0,
                    "myRating": 0,
                    "additionWishes": selectedProduct.product.additionWishes,
                    "placeName": "Ля салют",
                    "weight": selectedProduct.product.weight,
                    "ccal": selectedProduct.product.ccal,
                    
                    "sharedWith": selectedProduct.sharedWith,
                    "quantity": selectedProduct.quantity,
                    
                    "status": "Отправлен"
                ]
                productRef.updateChildValues(newProductData) { _, _ in
                    group.leave()
                }
            }
        })
    }
    
    group.enter()
    clientRef.updateChildValues([
        "bill": ServerValue.increment(NSNumber(value: summa))
    ]) { _, _ in
        group.leave()
    }
    
    
    let tableRef = db.child("Places").child(cafeID).child("tables").child("\(tableNumber)")
    
    group.enter()
    tableRef.updateChildValues([
        "bill": ServerValue.increment(NSNumber(value: summa)),
        "client\(clientNumber)Bill": ServerValue.increment(NSNumber(value: summa))
    ]) { _, _ in
        group.leave()
    }
    
    group.notify(queue: .main) {
        completion()
    }
}

func saveMyOrders(_ orders: [ReadyOrder]) { // сохранение взятых поваром блюд
    if let encoded = try? JSONEncoder().encode(orders) {
        UserDefaults.standard.set(encoded, forKey: "myOrders")
    }
}

func loadMyOrders() {
    if let data = UserDefaults.standard.data(forKey: "myOrders"),
       let decoded = try? JSONDecoder().decode([ReadyOrder].self, from: data) {
        myOrders = decoded
    } else {
        myOrders = []
    }
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

extension Double {
    func roundUp(toPlaces places: Int = 2) -> Double {
        let multiplier = pow(10.0, Double(places))
        return ceil(self * multiplier) / multiplier
    }
}


extension Array where Element == SelectedProduct {
    var sum: Double {
        reduce(0) { $0 + (Double($1.product.productPrice) * Double($1.quantity)) }
    }
}
