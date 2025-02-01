import AVFoundation
import SwiftUI

class CameraManager: ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var permissionGranted = false
    private var currentCameraInput: AVCaptureDeviceInput?
    @Published var isMirrored = false
    let videoOutput = AVCaptureVideoDataOutput()
    private var isSettingUpCamera = false
    
    var videoOutputDelegate: AVCaptureVideoDataOutputSampleBufferDelegate? {
        didSet {
            if let delegate = videoOutputDelegate {
                let queue = DispatchQueue(label: "videoQueue", qos: .userInteractive)
                videoOutput.setSampleBufferDelegate(delegate, queue: queue)
            } else {
                videoOutput.setSampleBufferDelegate(nil, queue: nil)
            }
        }
    }
    
    init() {
        if session.canSetSessionPreset(.hd4K3840x2160) {
            session.sessionPreset = .hd4K3840x2160
            print("相机质量：4K (3840x2160)")
        } else if session.canSetSessionPreset(.hd1920x1080) {
            session.sessionPreset = .hd1920x1080
            print("相机质量：1080p (1920x1080)")
        } else if session.canSetSessionPreset(.hd1280x720) {
            session.sessionPreset = .hd1280x720
            print("相机质量：720p (1280x720)")
        } else {
            session.sessionPreset = .high
            print("相机质量：high")
        }
    }
    
    deinit {
        cleanupResources()
    }
    
    private func cleanupResources() {
        videoOutputDelegate = nil
        safelyStopSession()
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }
        currentCameraInput = nil
        isSettingUpCamera = false
    }
    
    func safelyStopSession() {
        if session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.stopRunning()
            }
        }
    }
    
    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            print("------------------------")
            print("相机权限状态：已授权")
            print("------------------------")
            DispatchQueue.main.async { [weak self] in
                self?.permissionGranted = true
            }
            setupCamera()
            
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    print("------------------------")
                    print("相机权限状态：已授权")
                    print("------------------------")
                    DispatchQueue.main.async {
                        self?.permissionGranted = true
                    }
                    DispatchQueue.global(qos: .userInitiated).async {
                        self?.setupCamera()
                    }
                } else {
                    DispatchQueue.main.async {
                        self?.permissionGranted = false
                    }
                }
            }
        case .denied:
            print("------------------------")
            print("相机权限状态：已拒绝")
            print("------------------------")
            DispatchQueue.main.async { [weak self] in
                self?.permissionGranted = false
            }
            return
        case .restricted:
            print("------------------------")
            print("相机权限状态：受限制")
            print("------------------------")
            DispatchQueue.main.async { [weak self] in
                self?.permissionGranted = false
            }
            return
        @unknown default:
            DispatchQueue.main.async { [weak self] in
                self?.permissionGranted = false
            }
            return
        }
    }
    
    func restartCamera() {
        if session.isRunning {
            print("------------------------")
            print("[相机] 会话正在运行，先停止当前会话")
            print("------------------------")
            stopSession()
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        if isSettingUpCamera {
            print("------------------------")
            print("[相机] 正在设置中，跳过重启")
            print("------------------------")
            return
        }
        
        print("------------------------")
        print("[相机] 准备重启")
        print("------------------------")
        
        // 确保在后台线程执行相机操作
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            print("------------------------")
            print("[相机] 重启中...")
            print("------------------------")
            
            self.setupCamera()
            
            DispatchQueue.main.async {
                print("------------------------")
                print("[相机] 重启完成")
                print("------------------------")
            }
        }
    }
    
    private func setupCamera() {
        print("------------------------")
        print("[相机设置] 开始")
        print("------------------------")
        
        guard !isSettingUpCamera else {
            print("------------------------")
            print("[相机设置] 已在进行中，跳过")
            print("------------------------")
            return
        }
        
        isSettingUpCamera = true
        
        do {
            if session.isRunning {
                session.stopRunning()
            }
            
            session.beginConfiguration()
            
            // 清理现有的输入和输出
            session.inputs.forEach { session.removeInput($0) }
            session.outputs.forEach { session.removeOutput($0) }
            
            // 设置视频输入
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
                throw NSError(domain: "CameraManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法获取前置相机"])
            }
            
            // 配置相机设备以获得最佳质量
            try videoDevice.lockForConfiguration()
            if videoDevice.isExposureModeSupported(.continuousAutoExposure) {
                videoDevice.exposureMode = .continuousAutoExposure
            }
            if videoDevice.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                videoDevice.whiteBalanceMode = .continuousAutoWhiteBalance
            }
            if videoDevice.isFocusModeSupported(.continuousAutoFocus) {
                videoDevice.focusMode = .continuousAutoFocus
            }
            videoDevice.unlockForConfiguration()
            
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            guard session.canAddInput(videoInput) else {
                throw NSError(domain: "CameraManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "无法添加相机输入"])
            }
            
            session.addInput(videoInput)
            currentCameraInput = videoInput
            
            // 设置视频输出
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            videoOutput.alwaysDiscardsLateVideoFrames = true
            
            guard session.canAddOutput(videoOutput) else {
                throw NSError(domain: "CameraManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "无法添加视频输出"])
            }
            
            session.addOutput(videoOutput)
            
            if let connection = videoOutput.connection(with: .video) {
                if connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = true
                }
                connection.videoOrientation = .portrait
            }
            
            // 尝试设置最高质量预设
            if session.canSetSessionPreset(.hd4K3840x2160) {
                session.sessionPreset = .hd4K3840x2160
                print("相机质量设置：4K (3840x2160)")
            } else if session.canSetSessionPreset(.hd1920x1080) {
                session.sessionPreset = .hd1920x1080
                print("相机质量设置：1080p (1920x1080)")
            } else if session.canSetSessionPreset(.hd1280x720) {
                session.sessionPreset = .hd1280x720
                print("相机质量设置：720p (1280x720)")
            }
            
            session.commitConfiguration()
            
            // 在后台线程启动会话
            if !session.isRunning {
                session.startRunning()
                print("------------------------")
                print("相机会话已启动")
                print("------------------------")
                
                // 确保在主线程更新状态
                DispatchQueue.main.async { [weak self] in
                    self?.permissionGranted = true
                }
            }
            
        } catch {
            print("------------------------")
            print("[相机设置] 错误：\(error.localizedDescription)")
            print("------------------------")
            session.commitConfiguration()
            
            // 发生错误时更新状态
            DispatchQueue.main.async { [weak self] in
                self?.permissionGranted = false
            }
        }
        
        isSettingUpCamera = false
    }
    
    func stopSession() {
        if session.isRunning {
            session.stopRunning()
            print("------------------------")
            print("相机会话已停止")
            print("------------------------")
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
} 