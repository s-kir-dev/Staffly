//
//  QrScannerViewController.swift
//  Staffly
//
//  Created by Kirill Sysoev on 28.02.2026.
//

import UIKit
import AVFoundation
import FirebaseDatabase
import FirebaseAuth

class QrScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    var tableNumber: Int = 0
    
    private let overlayLayer = CAShapeLayer()
    private let maskLayer = CAShapeLayer()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupScanner()
        
        setupOverlay()
        
        if (captureSession?.isRunning == false) {
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.startRunning()
            }
        }
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if (captureSession?.isRunning == true) {
            captureSession.stopRunning()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
        drawScannerUI()
    }
    
    func setupScanner() {
        view.backgroundColor = .black
        captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch { return }
        
        if (captureSession.canAddInput(videoInput)) {
            captureSession.addInput(videoInput)
        } else { return }
        
        let metadataOutput = AVCaptureMetadataOutput()
        if (captureSession.canAddOutput(metadataOutput)) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else { return }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
    }
    
    private func setupOverlay() {
        maskLayer.fillRule = .evenOdd
        maskLayer.fillColor = UIColor.black.withAlphaComponent(0.6).cgColor
        view.layer.addSublayer(maskLayer)
        
        overlayLayer.strokeColor = UIColor(red: 233/255, green: 98/255, blue: 43/255, alpha: 1).cgColor
        overlayLayer.lineWidth = 4
        overlayLayer.fillColor = UIColor.clear.cgColor
        view.layer.addSublayer(overlayLayer)
    }
    
    private func drawScannerUI() {
        let size: CGFloat = 240
        let rect = CGRect(x: view.bounds.midX - size/2,
                          y: view.bounds.midY - size/2,
                          width: size,
                          height: size)
        
        let path = UIBezierPath(rect: view.bounds)
        let cp = UIBezierPath(roundedRect: rect, cornerRadius: 12)
        path.append(cp)
        maskLayer.path = path.cgPath
        
        let lineLength: CGFloat = 30
        let cornerPath = UIBezierPath()
        
        cornerPath.move(to: CGPoint(x: rect.minX, y: rect.minY + lineLength))
        cornerPath.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        cornerPath.addLine(to: CGPoint(x: rect.minX + lineLength, y: rect.minY))
        
        cornerPath.move(to: CGPoint(x: rect.maxX - lineLength, y: rect.minY))
        cornerPath.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        cornerPath.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + lineLength))
        
        cornerPath.move(to: CGPoint(x: rect.maxX, y: rect.maxY - lineLength))
        cornerPath.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        cornerPath.addLine(to: CGPoint(x: rect.maxX - lineLength, y: rect.maxY))
        
        cornerPath.move(to: CGPoint(x: rect.minX + lineLength, y: rect.maxY))
        cornerPath.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        cornerPath.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - lineLength))
        
        overlayLayer.path = cornerPath.cgPath
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
                  let stringValue = readableObject.stringValue else { return }
            
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            captureSession.stopRunning()
            
            parseQRCode(stringValue)
        }
    }
    
    func parseQRCode(_ code: String) {
        guard let url = URL(string: code),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            showResult("Ошибка", "Неверный QR-код", [UIAlertAction(title: "OK", style: .default, handler: nil)])
            return
        }
        
        guard let cafeID = UserDefaults.standard.string(forKey: "cafeID"),
              let employeeID = queryItems.first(where: { $0.name == "employeeID" })?.value else {
            showResult("Ошибка", "QR-код не подходит", [UIAlertAction(title: "Oк", style: .default, handler: { _ in
                self.captureSession.startRunning()
            })])
            return
        }
        
        db.child("Places").child(cafeID).child("employees").child(employeeID).child("tables").runTransactionBlock({ (currentData: MutableData) -> TransactionResult in
            var numbers = currentData.value as? [Int] ?? []
            
            if !numbers.contains(self.tableNumber) {
                numbers.append(self.tableNumber)
            }
            
            currentData.value = numbers
            
            return TransactionResult.success(withValue: currentData)
        })
        
        if let selfID = UserDefaults.standard.string(forKey: "selfID") {
            let group = DispatchGroup()
            
            group.enter()
            
            db.child("Places").child(cafeID).child("employees").child(selfID).child("tables").runTransactionBlock({ (currentData: MutableData) -> TransactionResult in
                var numbers = currentData.value as? [Int] ?? []
                
                print(numbers)
                
                if let index = numbers.firstIndex(of: self.tableNumber) {
                    numbers.remove(at: index)
                } else {
                    print("Нет стола для передачи")
                }
                
                currentData.value = numbers
                
                return TransactionResult.success(withValue: currentData)
            }) { _, _, _ in
                group.leave()
            }
            
            group.enter()
            db.child("Places").child(cafeID).child("tables").child("\(self.tableNumber)").updateChildValues([
                "waiterID": employeeID
            ]) { _, _ in
                group.leave()
            }
        }
        
        DispatchQueue.main.async {
            self.showResult("Успешно!", "Стол №\(self.tableNumber) был успешно передан другому сотруднику", [UIAlertAction(title: "Oк", style: .default, handler: { _ in
                self.navigationController?.popViewController(animated: true)
            })])
        }
    }
    
    
    
    func showResult(_ title: String, _ message: String, _ actions: [UIAlertAction]) {
        DispatchQueue.main.async {
            let alert = self.customAlertController(title, message, actions)
            self.present(alert, animated: true)
        }
    }
    
    func customAlertController(_ title: String, _ message: String, _ actions: [UIAlertAction]) -> UIAlertController {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        for action in actions {
            alertController.addAction(action)
        }
        return alertController
    }
}
