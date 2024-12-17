import AVFoundation
import SwiftUI

class CameraManager: ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var permissionGranted = false
    private var currentCameraInput: AVCaptureDeviceInput?
    @Published var isMirrored = false
    
    init() {
        if session.canSetSessionPreset(.high) {
            session.sessionPreset = .high
        }
    }
    
    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
            DispatchQueue.main.async { [weak self] in
                self?.setupCamera()
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.permissionGranted = granted
                    if granted {
                        self?.setupCamera()
                    }
                }
            }
        default:
            permissionGranted = false
        }
    }
    
    func setupCamera() {
        do {
            session.beginConfiguration()
            
            session.inputs.forEach { session.removeInput($0) }
            
            guard let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
                return
            }
            
            let input = try AVCaptureDeviceInput(device: frontCamera)
            currentCameraInput = input
            
            if session.canAddInput(input) {
                session.addInput(input)
            }
            
            session.commitConfiguration()
            
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
            }
        } catch {
            print("相机设置错误: \(error.localizedDescription)")
        }
    }
    
    func toggleMirror() {
        isMirrored.toggle()
        print("镜像状态：\(isMirrored ? "开启" : "关闭")")
    }
    
    deinit {
        session.stopRunning()
    }
} 