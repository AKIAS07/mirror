import AVFoundation
import SwiftUI

class CameraManager: ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var permissionGranted = false
    private var currentCameraInput: AVCaptureDeviceInput?
    @Published var isMirrored = false
    let videoOutput = AVCaptureVideoDataOutput()
    var videoOutputDelegate: AVCaptureVideoDataOutputSampleBufferDelegate? {
        didSet {
            if let delegate = videoOutputDelegate {
                let queue = DispatchQueue(label: "videoQueue", qos: .userInteractive)
                videoOutput.setSampleBufferDelegate(delegate, queue: queue)
            }
        }
    }
    
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
            session.outputs.forEach { session.removeOutput($0) }
            
            guard let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
                return
            }
            
            let input = try AVCaptureDeviceInput(device: frontCamera)
            currentCameraInput = input
            
            if session.canAddInput(input) {
                session.addInput(input)
            }
            
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
            videoOutput.alwaysDiscardsLateVideoFrames = true
            
            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
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
    
    func setZoom(level: CGFloat) {
        guard let device = (currentCameraInput?.device as? AVCaptureDevice) else { return }
        
        do {
            try device.lockForConfiguration()
            
            let zoom = max(1.0, min(level, device.activeFormat.videoMaxZoomFactor))
            device.videoZoomFactor = zoom
            
            device.unlockForConfiguration()
            
            print("相机焦距已调整：\(zoom)x")
            print("设备支持的最大焦距：\(device.activeFormat.videoMaxZoomFactor)x")
        } catch {
            print("设置焦距失败：\(error.localizedDescription)")
        }
    }
    
    deinit {
        session.stopRunning()
    }
} 