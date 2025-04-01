import AVFoundation
import SwiftUI
import Photos
import UIKit

class CameraManager: ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var permissionGranted = false
    @Published var isUsingSystemCamera = false
    @Published var isCapturingLivePhoto = false
    private var currentCameraInput: AVCaptureDeviceInput?
    @Published var isMirrored = false
    @Published var isFront = true
    @Published var isBack = false
    let videoOutput = AVCaptureVideoDataOutput()
    private var isSettingUpCamera = false
    private var photoOutput: AVCapturePhotoOutput?
    private var livePhotoCaptureProcessor: AVCapturePhotoCaptureDelegate?
    private var photoCaptureProcessor: PhotoCaptureProcessor?
    var latestProcessedImage: UIImage?
    
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
        print("当前模式：\(isUsingSystemCamera ? "系统相机" : "自定义相机")")
        print("------------------------")
        
        guard !isSettingUpCamera else {
            print("------------------------")
            print("[相机设置] 已在进行中，跳过")
            print("------------------------")
            return
        }
        
        isSettingUpCamera = true
        
        do {
            // 停止当前会话
            if session.isRunning {
                print("[相机设置] 停止当前会话")
                session.stopRunning()
            }
            
            // 开始配置
            session.beginConfiguration()
            
            // 清理现有的输入和输出
            session.inputs.forEach { session.removeInput($0) }
            session.outputs.forEach { session.removeOutput($0) }
            
            if isUsingSystemCamera {
                print("------------------------")
                print("[系统相机设置] 开始")
                print("------------------------")
                
                // 配置系统相机
                try configureSystemCamera()
            } else {
                // 配置自定义相机
                try configureCustomCamera()
            }
            
            // 提交配置
            session.commitConfiguration()
            print("[相机设置] 配置提交完成")
            
            // 在配置完成后启动会话
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
                DispatchQueue.main.async {
                    print("------------------------")
                    print("相机会话已启动")
                    print("------------------------")
                }
            }
            
        } catch {
            print("------------------------")
            print("[相机设置] 错误：\(error.localizedDescription)")
            print("------------------------")
            session.commitConfiguration()
        }
        
        isSettingUpCamera = false
    }
    
    // 添加系统相机配置方法
    private func configureSystemCamera() throws {
        // 使用系统相机配置
        session.sessionPreset = .photo
        
        // 设置视频输入
        let cameraPosition: AVCaptureDevice.Position = isFront ? .front : .back
        print("[系统相机设置] 获取\(isFront ? "前置" : "后置")相机")
        
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: cameraPosition
        )
        
        guard let videoDevice = discoverySession.devices.first else {
            throw NSError(domain: "CameraManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法获取相机设备"])
        }
        
        // 配置相机设备
        try videoDevice.lockForConfiguration()
        
        // 配置基本相机参数
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
        
        // 设置视频输入
        let videoInput = try AVCaptureDeviceInput(device: videoDevice)
        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
            currentCameraInput = videoInput
            print("[系统相机设置] 添加视频输入成功")
        }
        
        // 配置照片输出
        photoOutput = AVCapturePhotoOutput()
        if let photoOutput = photoOutput {
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
                
                print("[系统相机设置] 照片输出配置：")
                print("是否支持 Live Photo：\(photoOutput.isLivePhotoCaptureSupported)")
                
                // 启用高分辨率拍摄
                photoOutput.isHighResolutionCaptureEnabled = true
                print("高分辨率拍摄已启用：\(photoOutput.isHighResolutionCaptureEnabled)")
                
                // 尝试启用 Live Photo
                if photoOutput.isLivePhotoCaptureSupported {
                    photoOutput.isLivePhotoCaptureEnabled = true
                    print("尝试启用 Live Photo 后的状态：\(photoOutput.isLivePhotoCaptureEnabled)")
                }
            }
        }
        
        // 设置视频输出
        if session.canAddOutput(videoOutput) {
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            videoOutput.alwaysDiscardsLateVideoFrames = true
            session.addOutput(videoOutput)
            
            if let connection = videoOutput.connection(with: .video) {
                if connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = isMirrored
                }
                connection.videoOrientation = .portrait
            }
        }
    }
    
    // 添加自定义相机配置方法
    private func configureCustomCamera() throws {
        // 根据 isFront 和 isBack 设置摄像头位置
        let cameraPosition: AVCaptureDevice.Position = isFront ? .front : .back
        
        // 设置视频输入
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraPosition) else {
            throw NSError(domain: "CameraManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法获取\(isFront ? "前置" : "后置")相机"])
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
    
    func switchCamera() {
        isFront.toggle()
        isBack.toggle()
        restartCamera()
        print("切换到\(isFront ? "前置" : "后置")摄像头")
    }
    
    func toggleSystemCamera() {
        isUsingSystemCamera.toggle()
        print("切换系统相机状态：\(isUsingSystemCamera ? "开启" : "关闭")")
        restartCamera()
    }
    
    func captureLivePhoto(completion: @escaping (Bool, Error?) -> Void) {
        guard let photoOutput = photoOutput else {
            completion(false, NSError(domain: "CameraManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "PhotoOutput not initialized"]))
            return
        }
        
        // 检查是否支持 Live Photo
        guard photoOutput.isLivePhotoCaptureSupported else {
            completion(false, NSError(domain: "CameraManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Live Photo not supported"]))
            return
        }
        
        // 创建临时文件路径
        let livePhotoURL = FileManager.default.temporaryDirectory.appendingPathComponent("LivePhoto_\(UUID().uuidString).mov")
        
        // 配置拍摄设置
        let settings = AVCapturePhotoSettings()
        settings.livePhotoMovieFileURL = livePhotoURL
        
        // 启用高质量设置
        settings.isHighResolutionPhotoEnabled = true
        photoOutput.isLivePhotoCaptureEnabled = true
        
        if #available(iOS 11.0, *) {
            settings.livePhotoVideoCodecType = .h264
        }
        
        // 创建处理器
        let processor = SimpleLivePhotoCaptureProcessor(completion: completion)
        livePhotoCaptureProcessor = processor
        
        // 开始捕获
        photoOutput.capturePhoto(with: settings, delegate: processor)
    }
    
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        print("------------------------")
        print("[系统相机] 开始拍照")
        print("------------------------")
        
        guard let photoOutput = photoOutput else {
            print("[系统相机] 错误：photoOutput 未初始化")
            completion(nil)
            return
        }
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
        
        // 创建照片捕获处理器
        let processor = PhotoCaptureProcessor(completion: completion)
        
        // 保持对处理器的引用
        photoCaptureProcessor = processor
        
        // 开始捕获照片
        photoOutput.capturePhoto(with: settings, delegate: processor)
    }
    
    // 添加新方法，用于Live Photo预览
    func captureLivePhotoForPreview(completion: @escaping (Bool, Data?, URL?, UIImage?, Error?) -> Void) {
        guard let photoOutput = photoOutput else {
            completion(false, nil, nil, nil, NSError(domain: "CameraManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "PhotoOutput not initialized"]))
            return
        }
        
        // 检查是否支持 Live Photo
        guard photoOutput.isLivePhotoCaptureSupported else {
            completion(false, nil, nil, nil, NSError(domain: "CameraManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Live Photo not supported"]))
            return
        }
        
        // 创建临时文件路径
        let livePhotoURL = FileManager.default.temporaryDirectory.appendingPathComponent("LivePhoto_\(UUID().uuidString).mov")
        
        // 配置拍摄设置
        let settings = AVCapturePhotoSettings()
        settings.livePhotoMovieFileURL = livePhotoURL
        
        // 启用高质量设置
        settings.isHighResolutionPhotoEnabled = true
        photoOutput.isLivePhotoCaptureEnabled = true
        
        if #available(iOS 11.0, *) {
            settings.livePhotoVideoCodecType = .h264
        }
        
        // 创建处理器
        let processor = LivePhotoPreviewProcessor(completion: completion)
        livePhotoCaptureProcessor = processor
        
        // 开始捕获
        photoOutput.capturePhoto(with: settings, delegate: processor)
    }
    
    func updateLatestProcessedImage(_ image: UIImage) {
        self.latestProcessedImage = image
    }
}

// Live Photo 捕获处理器
class SimpleLivePhotoCaptureProcessor: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (Bool, Error?) -> Void
    private var photoData: Data?
    
    init(completion: @escaping (Bool, Error?) -> Void) {
        self.completion = completion
        super.init()
    }
    
    // 添加照片处理方法
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            completion(false, error)
            return
        }
        
        // 保存照片数据
        photoData = photo.fileDataRepresentation()
    }
    
    // 处理 Live Photo 视频
    func photoOutput(_ output: AVCapturePhotoOutput,
                    didFinishProcessingLivePhotoToMovieFileAt outputFileURL: URL,
                    duration: CMTime,
                    photoDisplayTime: CMTime,
                    resolvedSettings: AVCaptureResolvedPhotoSettings,
                    error: Error?) {
        
        if let error = error {
            completion(false, error)
            return
        }
        
        // 确保我们有照片数据
        guard let photoData = self.photoData else {
            completion(false, NSError(domain: "LivePhotoCapture", code: 3, userInfo: [NSLocalizedDescriptionKey: "No photo data"]))
            return
        }
        
        // 创建临时图片文件
        let tempImageURL = FileManager.default.temporaryDirectory.appendingPathComponent("LivePhoto_\(UUID().uuidString).jpg")
        
        do {
            // 写入照片数据
            try photoData.write(to: tempImageURL)
            
            // 保存到相册
            PHPhotoLibrary.shared().performChanges({
                let creationRequest = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                options.shouldMoveFile = true
                
                // 添加照片和视频资源
                creationRequest.addResource(with: .photo, fileURL: tempImageURL, options: options)
                creationRequest.addResource(with: .pairedVideo, fileURL: outputFileURL, options: options)
                
            }) { success, error in
                // 清理临时文件
                try? FileManager.default.removeItem(at: tempImageURL)
                
                self.completion(success, error)
            }
        } catch {
            completion(false, error)
        }
    }
}

// 在 LivePhotoCaptureProcessor 类后添加新的 delegate 类
class PhotoCaptureProcessor: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (UIImage?) -> Void
    
    init(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
        super.init()
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("[系统相机] 拍照失败：\(error.localizedDescription)")
            completion(nil)
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            print("[系统相机] 错误：无法从照片数据创建图像")
            completion(nil)
            return
        }
        
        print("[系统相机] 拍照成功")
        completion(image)
    }
}

// 添加Live Photo预览处理器
class LivePhotoPreviewProcessor: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (Bool, Data?, URL?, UIImage?, Error?) -> Void
    private var photoData: Data?
    
    init(completion: @escaping (Bool, Data?, URL?, UIImage?, Error?) -> Void) {
        self.completion = completion
        super.init()
    }
    
    // 添加照片处理方法
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            completion(false, nil, nil, nil, error)
            return
        }
        
        // 保存照片数据
        photoData = photo.fileDataRepresentation()
    }
    
    // 处理 Live Photo 视频
    func photoOutput(_ output: AVCapturePhotoOutput,
                    didFinishProcessingLivePhotoToMovieFileAt outputFileURL: URL,
                    duration: CMTime,
                    photoDisplayTime: CMTime,
                    resolvedSettings: AVCaptureResolvedPhotoSettings,
                    error: Error?) {
        
        if let error = error {
            completion(false, nil, nil, nil, error)
            return
        }
        
        // 确保我们有照片数据
        guard let photoData = self.photoData else {
            completion(false, nil, nil, nil, NSError(domain: "LivePhotoCapture", code: 3, userInfo: [NSLocalizedDescriptionKey: "No photo data"]))
            return
        }
        
        // 创建UIImage用于预览
        let image = UIImage(data: photoData)
        
        // 返回数据而不是直接保存
        completion(true, photoData, outputFileURL, image, nil)
    }
} 