//
//  BillViewController.swift
//  Staffly
//
//  Created by Kirill Sysoev on 17.10.2025.
//

import UIKit
import FirebaseDatabase

class BillViewController: UIViewController {
    
    @IBOutlet weak var tableNumberLabel: UILabel!
    
    @IBOutlet weak var client2Label: UILabel!
    @IBOutlet weak var client3Label: UILabel!
    @IBOutlet weak var client4Label: UILabel!
    @IBOutlet weak var client5Label: UILabel!
    @IBOutlet weak var client6Label: UILabel!
    
    @IBOutlet weak var client1BillLabel: UILabel!
    @IBOutlet weak var client2BillLabel: UILabel!
    @IBOutlet weak var client3BillLabel: UILabel!
    @IBOutlet weak var client4BillLabel: UILabel!
    @IBOutlet weak var client5BillLabel: UILabel!
    @IBOutlet weak var client6BillLabel: UILabel!
    
    @IBOutlet weak var tipsSlider1: UISlider!
    @IBOutlet weak var tipsSlider2: UISlider!
    @IBOutlet weak var tipsSlider3: UISlider!
    @IBOutlet weak var tipsSlider4: UISlider!
    @IBOutlet weak var tipsSlider5: UISlider!
    @IBOutlet weak var tipsSlider6: UISlider!
    
    @IBOutlet weak var tipsClient1Label: UILabel!
    @IBOutlet weak var tipsClient2Label: UILabel!
    @IBOutlet weak var tipsClient3Label: UILabel!
    @IBOutlet weak var tipsClient4Label: UILabel!
    @IBOutlet weak var tipsClient5Label: UILabel!
    @IBOutlet weak var tipsClient6Label: UILabel!
    
    @IBOutlet weak var client1FinalBillLabel: UILabel!
    @IBOutlet weak var client2FinalBillLabel: UILabel!
    @IBOutlet weak var client3FinalBillLabel: UILabel!
    @IBOutlet weak var client4FinalBillLabel: UILabel!
    @IBOutlet weak var client5FinalBillLabel: UILabel!
    @IBOutlet weak var client6FinalBillLabel: UILabel!
    
    @IBOutlet weak var tableBillLabel: UILabel!
    @IBOutlet weak var tableFinalBillLabel: UILabel!
    
    @IBOutlet weak var detailButton: UIButton!
    @IBOutlet weak var doneButton: UIButton!
    
    let loadingIndicator = UIActivityIndicatorView(style: .large)
            
    var tableIndex: Int = 0
    
    var table: Table = Table(number: 0, personCount: 0, maximumPersonCount: 0, currentPersonCount: 0, client1Bill: 0, client2Bill: 0, client3Bill: 0, client4Bill: 0, client5Bill: 0, client6Bill: 0, bill: 0, waiterID: "")
    
    var finalTableBill = 0.0
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        loadingIndicator.center = view.center
        loadingIndicator.hidesWhenStopped = true
        view.addSubview(loadingIndicator)
        
        loadingIndicator.startAnimating()
        
        guard let cafeID = UserDefaults.standard.string(forKey: "cafeID"),
              let selfID = UserDefaults.standard.string(forKey: "selfID") else {
            loadingIndicator.stopAnimating()
            return
        }
        
        let tablesRef = Database.database().reference().child("Places").child(cafeID).child("employees").child(selfID).child("tables")
        
        tablesRef.observeSingleEvent(of: .value, with: { [weak self] snapshot in
            guard let self = self else { return }
            
            let newTableNumbers = snapshot.value as? [Int] ?? []
            tableNumbers = newTableNumbers
            
            loadTables(cafeID, selfID, newTableNumbers) { fetchedTables in
                let sortedTables = fetchedTables.sorted { $0.number < $1.number }
                tables = sortedTables
                tableNumbers = sortedTables.map { $0.number }
                
                DispatchQueue.main.async {
                    if self.tableIndex < tables.count {
                        self.table = tables[self.tableIndex]
                        self.setupUI()
                        
                        self.recalculateFinalTableBill()
                        
                        self.loadingIndicator.stopAnimating()
                        debugPrint("✅ Данные обновлены и чаевые пересчитаны")
                    } else {
                        self.loadingIndicator.stopAnimating()
                        print("Ошибка: tableIndex вне диапазона")
                    }
                }
            }
        })
    }

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        detailButton.addTarget(self, action: #selector(detailButtonTapped), for: .touchUpInside)
        doneButton.addTarget(self, action: #selector(doneButtonTapped), for: .touchUpInside)
    }
    
    func setupUI() {
        finalTableBill = table.bill
        
        let clientLabels: [UILabel] = [UILabel(), client2Label, client3Label, client4Label, client5Label, client6Label]
        let clientBillLabels: [UILabel] = [client1BillLabel, client2BillLabel, client3BillLabel, client4BillLabel, client5BillLabel, client6BillLabel]
        let clientTipsLabels: [UILabel] = [tipsClient1Label, tipsClient2Label, tipsClient3Label, tipsClient4Label, tipsClient5Label, tipsClient6Label]
        let clientFinalBillLabels: [UILabel] = [client1FinalBillLabel, client2FinalBillLabel, client3FinalBillLabel, client4FinalBillLabel, client5FinalBillLabel, client6FinalBillLabel]
        let sliders: [UISlider] = [UISlider(), tipsSlider2, tipsSlider3, tipsSlider4, tipsSlider5, tipsSlider6]
        
        for index in 0..<table.maximumPersonCount { // обновление UI после изменения количества клиентов
            clientLabels[index].isHidden = false
            clientBillLabels[index].isHidden = false
            clientTipsLabels[index].isHidden = false
            clientFinalBillLabels[index].isHidden = false
            sliders[index].isHidden = false
        }
        
        for index in table.maximumPersonCount..<6 {
            clientLabels[index].isHidden = true
            clientBillLabels[index].isHidden = true
            clientTipsLabels[index].isHidden = true
            clientFinalBillLabels[index].isHidden = true
            sliders[index].isHidden = true
        }
        
        tableNumberLabel.text = "Стол №\(table.number)"
        
        client1BillLabel.text = "\(table.client1Bill.roundValue())р."
        client2BillLabel.text = "\(table.client2Bill.roundValue())р."
        client3BillLabel.text = "\(table.client3Bill.roundValue())р."
        client4BillLabel.text = "\(table.client4Bill.roundValue())р."
        client5BillLabel.text = "\(table.client5Bill.roundValue())р."
        client6BillLabel.text = "\(table.client6Bill.roundValue())р."
        
        for index in 0..<6 {
            clientFinalBillLabels[index].text = clientBillLabels[index].text
        }
        
        tableBillLabel.text = "\(table.bill.roundValue())р."
        tableFinalBillLabel.text = "\(table.bill.roundValue())р."
    }
    
    @IBAction func tipsClient1Changed(_ sender: UISlider) {
        let tipPercentage = Int(sender.value)
        tipsClient1Label.text = "\(tipPercentage) %"
        
        let clientTip = table.client1Bill * Double(tipPercentage) / 100.0
        client1FinalBillLabel.text = "\((table.client1Bill + clientTip).roundValue())р."
        
        recalculateFinalTableBill()
    }
    
    @IBAction func tipsClient2Changed(_ sender: UISlider) {
        let tipPercentage = Int(sender.value)
        tipsClient2Label.text = "\(tipPercentage) %"
        
        let clientTip = table.client2Bill * Double(tipPercentage) / 100.0
        client2FinalBillLabel.text = "\((table.client2Bill + clientTip).roundValue())р."
        
        recalculateFinalTableBill()
    }
    
    @IBAction func tipsClient3Changed(_ sender: UISlider) {
        let tipPercentage = Int(sender.value)
        tipsClient3Label.text = "\(tipPercentage) %"
        
        let clientTip = table.client3Bill * Double(tipPercentage) / 100.0
        client3FinalBillLabel.text = "\((table.client3Bill + clientTip).roundValue())р."
        
        recalculateFinalTableBill()
    }
    
    @IBAction func tipsClient4Changed(_ sender: UISlider) {
        let tipPercentage = Int(sender.value)
        tipsClient4Label.text = "\(tipPercentage) %"
        
        let clientTip = table.client4Bill * Double(tipPercentage) / 100.0
        client4FinalBillLabel.text = "\((table.client4Bill + clientTip).roundValue())р."
        
        recalculateFinalTableBill()
    }
    
    @IBAction func tipsClient5Changed(_ sender: UISlider) {
        let tipPercentage = Int(sender.value)
        tipsClient5Label.text = "\(tipPercentage) %"
        
        let clientTip = table.client5Bill * Double(tipPercentage) / 100.0
        client5FinalBillLabel.text = "\((table.client5Bill + clientTip).roundValue())р."
        
        recalculateFinalTableBill()
    }
    
    @IBAction func tipsClient6Changed(_ sender: UISlider) {
        let tipPercentage = Int(sender.value)
        tipsClient6Label.text = "\(tipPercentage) %"
        
        let clientTip = table.client6Bill * Double(tipPercentage) / 100.0
        client6FinalBillLabel.text = "\((table.client6Bill + clientTip).roundValue())р."
        
        recalculateFinalTableBill()
    }
    
    func recalculateFinalTableBill() {
        let t1: Double = table.client1Bill + (table.client1Bill * (Double(Int(tipsClient1Label.text?.dropLast(2) ?? "0") ?? 0) / 100.0))
        let t2: Double = table.client2Bill + (table.client2Bill * (Double(Int(tipsClient2Label.text?.dropLast(2) ?? "0") ?? 0) / 100.0))
        let t3: Double = table.client3Bill + (table.client3Bill * (Double(Int(tipsClient3Label.text?.dropLast(2) ?? "0") ?? 0) / 100.0))
        let t4: Double = table.client4Bill + (table.client4Bill * (Double(Int(tipsClient4Label.text?.dropLast(2) ?? "0") ?? 0) / 100.0))
        let t5: Double = table.client5Bill + (table.client5Bill * (Double(Int(tipsClient5Label.text?.dropLast(2) ?? "0") ?? 0) / 100.0))
        let t6: Double = table.client6Bill + (table.client6Bill * (Double(Int(tipsClient6Label.text?.dropLast(2) ?? "0") ?? 0) / 100.0))
        
        let sum1 = t1 + t2 + t3
        let sum2 = t4 + t5 + t6
        
        self.finalTableBill = sum1 + sum2
        
        tableFinalBillLabel.text = "\(finalTableBill.roundValue())р."
    }

    
    @objc func detailButtonTapped() {
        performSegue(withIdentifier: "orderedProductsVC", sender: self)
    }
    
    @objc func doneButtonTapped() {
        guard let tableIndex = tables.firstIndex(of: table),
              let cafeID = UserDefaults.standard.string(forKey: "cafeID") else { return }
        
        let baseRef = db.child("Places").child(cafeID)
        let tableNumber = table.number
        let group = DispatchGroup()
        
        let alert = UIAlertController(title: nil, message: "Очистка данных о столе...", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(style: .medium)
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        alert.view.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor),
            loadingIndicator.bottomAnchor.constraint(equalTo: alert.view.bottomAnchor, constant: -20)
        ])
        loadingIndicator.startAnimating()
        present(alert, animated: true)
        
        group.enter()
        let clientsRef = baseRef.child("tables").child("\(tableNumber)").child("clients")
        clientsRef.observeSingleEvent(of: .value, with: { snapshot in
            for child in snapshot.children {
                if let snap = child as? DataSnapshot {
                    group.enter()
                    clearUserSession(uid: snap.key) {
                        print("Удалил клиента \(snap.key)")
                        group.leave()
                    }
                }
            }
            group.leave()
        }) { error in
            print(error.localizedDescription)
            group.leave()
        }
        
        let extraPaths = [
            baseRef.child("orders").child("\(tableNumber)"),
            baseRef.child("readyOrders").child("\(tableNumber)")
        ]
        
        for ref in extraPaths {
            group.enter()
            ref.removeValue { _, _ in group.leave() }
        }
        
        group.notify(queue: .main) {
            baseRef.child("tables").child("\(tableNumber)").removeValue { _, _ in
                
                let selfID = UserDefaults.standard.string(forKey: "selfID")!
                let tips = (self.finalTableBill - self.table.bill).roundValue()
                
                downloadUserData(cafeID, selfID) { currentEmployee in
                    var updatedEmployee = currentEmployee
                    updatedEmployee.tips += tips
                    updatedEmployee.tablesCount += 1
                    updatedEmployee.cafeProfit += self.table.bill

                    uploadUserData(cafeID, selfID, updatedEmployee) { _ in
                        removeTable(cafeID, selfID, tables[tableIndex], completion: {
                            if tableIndex < tables.count {
                                tables.remove(at: tableIndex)
                            }
                            alert.dismiss(animated: true) {
                                self.navigationController?.popViewController(animated: true)
                            }
                        })
                    }
                }
            }
        }
    }

    
    func countPercentage(_ total: Double, _ tip: Double) -> Double {
        guard total != 0 else { return 0 }
        return (tip / total * 100).roundValue()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "orderedProductsVC" {
            if let vc = segue.destination as? OrderedProductsViewController {
                vc.table = table
            }
        }
    }
}
