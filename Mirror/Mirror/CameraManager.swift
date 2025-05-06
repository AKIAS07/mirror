import AVFoundation
import SwiftUI
import Photos
import UIKit

class CameraManager: ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var permissionGranted = false
    @Published var isUsingSystemCamera = false
    @Published var isCapturingLivePhoto = false
    @Published var isMirrored = false
    @Published var isFront = true
    @Published var isBack = false
    @Published var currentScale: CGFloat = 1.0  // 添加缩放比例属性
    @Published var isMirroredScreenFront = true  // 新增：控制 Mirrored 屏幕的摄像头状态
    private var currentCameraInput: AVCaptureDeviceInput?
    private var currentDeviceOrientation: UIDeviceOrientation = .portrait
    
    // 添加后置摄像头状态的计算属性
    var isUsingBackCamera: Bool {
        return isBack && !isFront
    }
    
    let videoOutput = AVCaptureVideoDataOutput()
    private var isSettingUpCamera = false
    private var photoOutput: AVCapturePhotoOutput?
    private var livePhotoCaptureProcessor: AVCapturePhotoCaptureDelegate?
    private var photoCaptureProcessor: PhotoCaptureProcessor?
    var latestProcessedImage: UIImage?
    @Published var livePhotoIdentifier: String = ""
    private var tempImageURL: URL?
    private var tempVideoURL: URL?
    
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
        
        // 添加设备方向监听
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceOrientationDidChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func deviceOrientationDidChange() {
        currentDeviceOrientation = UIDevice.current.orientation
        updatePhotoOrientation()
    }
    
    // 添加一个变量来存储最后一个有效的拍摄方向
    private var lastValidVideoOrientation: AVCaptureVideoOrientation = .portrait
    
    private func updatePhotoOrientation() {
        guard let photoOutput = photoOutput,
              let photoConnection = photoOutput.connection(with: .video) else { return }
        
        var orientation: AVCaptureVideoOrientation
        
        switch currentDeviceOrientation {
        case .portrait:
            orientation = .portrait
            lastValidVideoOrientation = orientation
        case .portraitUpsideDown:
            orientation = .portraitUpsideDown
            lastValidVideoOrientation = orientation
        case .landscapeLeft:
            orientation = .landscapeRight
            lastValidVideoOrientation = orientation
        case .landscapeRight:
            orientation = .landscapeLeft
            lastValidVideoOrientation = orientation
        case .faceUp, .faceDown:
            // 当设备面朝上或面朝下时，保持上一次有效的方向
            orientation = lastValidVideoOrientation
        default:
            // 对于其他未知方向，仍然使用最后一个有效方向
            orientation = lastValidVideoOrientation
        }
        
        photoConnection.videoOrientation = orientation
    }
    
    deinit {
        cleanupResources()
        NotificationCenter.default.removeObserver(self)
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
        print("========================")
        print("[相机重启] 开始")
        print("------------------------")
        print("重启前状态：")
        print("- 镜像模式(A模式)：\(isMirrored)")
        print("- 系统相机：\(isUsingSystemCamera)")
        print("- 摄像头：\(isFront ? "前置" : "后置")")
        
        if session.isRunning {
            print("[相机重启] 会话正在运行，先停止当前会话")
            stopSession()
            Thread.sleep(forTimeInterval: 0.2) // 确保会话完全停止
        }
        
        if isSettingUpCamera {
            print("[相机重启] 正在设置中，跳过重启")
            return
        }
        
        // 清理当前的处理器
        livePhotoCaptureProcessor = nil
        photoCaptureProcessor = nil
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            print("[相机重启] 重启中...")
            self.setupCamera()
            
            DispatchQueue.main.async {
                print("------------------------")
                print("[相机重启] 完成")
                print("重启后状态：")
                print("- 镜像模式(A模式)：\(self.isMirrored)")
                print("- 系统相机：\(self.isUsingSystemCamera)")
                print("- 摄像头：\(self.isFront ? "前置" : "后置")")
                print("========================")
            }
        }
    }
    
    func setupCamera() {
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
            
            // 在主队列中启动会话
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if !self.session.isRunning {
                    print("------------------------")
                    print("[相机设置] 启动会话")
                    print("------------------------")
                    self.session.startRunning()
                }
                self.isSettingUpCamera = false
            }
            
        } catch {
            print("------------------------")
            print("[相机设置] 错误：\(error.localizedDescription)")
            print("------------------------")
            session.commitConfiguration()
            isSettingUpCamera = false
        }
    }
    
    // 修改 configureSystemCamera 方法
    private func configureSystemCamera() throws {
        print("========================")
        print("[系统相机配置] 详细状态")
        print("------------------------")
        print("1. 相机状态：")
        print("- 是否镜像模式：\(isMirrored)")
        print("- 摄像头：\(isFront ? "前置" : "后置")")
        print("- 会话预设：\(session.sessionPreset.rawValue)")
        
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
            
            // 配置照片输出
            photoOutput = AVCapturePhotoOutput()
            if let photoOutput = photoOutput {
                if session.canAddOutput(photoOutput) {
                    session.addOutput(photoOutput)
                    
                    // 配置 HEIF 支持
                    if #available(iOS 11.0, *) {
                        if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                            print("[系统相机设置] 支持 HEIF/HEVC 编码")
                            print("可用的编码类型：\(photoOutput.availablePhotoCodecTypes)")
                        } else {
                            print("[系统相机设置] 不支持 HEIF/HEVC 编码")
                        }
                    }
                    
                    // 设置照片输出的镜像状态
                    if let photoConnection = photoOutput.connection(with: .video) {
                        if photoConnection.isVideoMirroringSupported {
                            photoConnection.isVideoMirrored = isMirrored
                        }
                        photoConnection.videoOrientation = .portrait
                    }
                    
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
            
            // 添加视频输出
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
                
                // 设置视频输出代理
                if let delegate = videoOutputDelegate {
                    let queue = DispatchQueue(label: "videoQueue", qos: .userInteractive)
                    videoOutput.setSampleBufferDelegate(delegate, queue: queue)
                }
            }
        }
    }
    
    // 添加自定义相机配置方法
    private func configureCustomCamera() throws {
        // 使用与系统相机相同的配置
        session.sessionPreset = .photo
        
        // 设置视频输入
        let cameraPosition: AVCaptureDevice.Position = isFront ? .front : .back
        print("[自定义相机设置] 获取\(isFront ? "前置" : "后置")相机")
        
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
            print("[自定义相机设置] 添加视频输入成功")
        }
        
        // 配置照片输出
        photoOutput = AVCapturePhotoOutput()
        if let photoOutput = photoOutput {
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
                
                print("[自定义相机设置] 照片输出配置：")
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
            currentScale = zoom  // 更新当前缩放比例
            
            device.unlockForConfiguration()
            
            print("相机焦距已调整：\(zoom)x")
            print("设备支持的最大焦距：\(device.activeFormat.videoMaxZoomFactor)x")
        } catch {
            print("设置焦距失败：\(error.localizedDescription)")
        }
    }
    
    func switchCamera() {
        print("========================")
        print("[切换摄像头] 状态变化")
        print("------------------------")
        print("切换前：")
        print("- 前置/后置：\(isFront ? "前置" : "后置")")
        print("- 镜像状态：\(isMirrored)")
        print("- Live模式：\(isUsingSystemCamera)")
        
        isFront.toggle()
        isBack.toggle()
        
        print("切换后：")
        print("- 前置/后置：\(isFront ? "前置" : "后置")")
        print("- 镜像状态：\(isMirrored)")
        print("- Live模式：\(isUsingSystemCamera)")
        print("========================")
        
        restartCamera()
    }
    
    func toggleSystemCamera() {
        print("========================")
        print("[切换Live模式] 状态变化")
        print("------------------------")
        print("切换前：")
        print("- Live模式：\(isUsingSystemCamera)")
        print("- 前置/后置：\(isFront ? "前置" : "后置")")
        print("- 镜像状态：\(isMirrored)")
        
        isUsingSystemCamera.toggle()
        
        print("切换后：")
        print("- Live模式：\(isUsingSystemCamera)")
        print("- 前置/后置：\(isFront ? "前置" : "后置")")
        print("- 镜像状态：\(isMirrored)")
        print("========================")
        
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
        
        // 更新拍摄方向
        updatePhotoOrientation()
        print("[系统相机] 当前设备方向：\(currentDeviceOrientation.rawValue)，使用的拍摄方向：\(lastValidVideoOrientation.rawValue)")
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
        
        // 创建照片捕获处理器
        let processor = PhotoCaptureProcessor(completion: completion, isMirrored: isMirrored)
        
        // 保持对处理器的引用
        photoCaptureProcessor = processor
        
        // 开始捕获照片
        photoOutput.capturePhoto(with: settings, delegate: processor)
    }
    
    // 修改 captureLivePhotoForPreview 方法
    func captureLivePhotoForPreview(completion: @escaping (Bool, String, URL?, URL?, UIImage?, Error?) -> Void) {
        print("------------------------")
        print("[Live Photo拍摄] 开始")
        print("------------------------")
        
        // 添加 0.5 秒延迟
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else {
                completion(false, "", nil, nil, nil, NSError(domain: "CameraManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "相机管理器已释放"]))
                return
            }
            
            guard let photoOutput = self.photoOutput else {
                let error = NSError(domain: "CameraManager", 
                                   code: 1, 
                                   userInfo: [NSLocalizedDescriptionKey: "PhotoOutput未初始化"])
                print("[Live Photo拍摄] 错误：PhotoOutput未初始化")
                completion(false, "", nil, nil, nil, error)
                return
            }
            
            // 更新拍摄方向（现在会保持设备面朝上时的之前有效方向）
            self.updatePhotoOrientation()
            
            // 检查是否支持 Live Photo
            print("[Live Photo拍摄] 检查设备支持情况：")
            print("是否支持Live Photo：\(photoOutput.isLivePhotoCaptureSupported)")
            print("Live Photo是否已启用：\(photoOutput.isLivePhotoCaptureEnabled)")
            print("当前设备方向：\(self.currentDeviceOrientation.rawValue)，使用的拍摄方向：\(self.lastValidVideoOrientation.rawValue)")
            
            guard photoOutput.isLivePhotoCaptureSupported else {
                let error = NSError(domain: "CameraManager", 
                                   code: 2, 
                                   userInfo: [NSLocalizedDescriptionKey: "设备不支持Live Photo"])
                print("[Live Photo拍摄] 错误：设备不支持Live Photo")
                completion(false, "", nil, nil, nil, error)
                return
            }
            
            // 生成唯一标识符
            let identifier = UUID().uuidString
            print("[Live Photo拍摄] 生成标识符：\(identifier)")
            
            // 创建临时文件路径
            let tempDir = FileManager.default.temporaryDirectory
            let imageURL = tempDir.appendingPathComponent("\(identifier).heic")
            let videoURL = tempDir.appendingPathComponent("\(identifier).mov")
            
            print("[Live Photo拍摄] 临时文件路径：")
            print("图片路径：\(imageURL.path)")
            print("视频路径：\(videoURL.path)")
            
            // 修改拍摄设置
            var settings: AVCapturePhotoSettings
            
            // 根据 iOS 版本设置 HEIF 格式
            if #available(iOS 11.0, *) {
                if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                    settings = AVCapturePhotoSettings(format: [
                        AVVideoCodecKey: AVVideoCodecType.hevc
                    ])
                    print("[Live Photo拍摄] 使用 HEIF/HEVC 编码")
                } else {
                    settings = AVCapturePhotoSettings()
                    print("[Live Photo拍摄] 设备不支持 HEIF/HEVC，使用默认编码")
                }
            } else {
                settings = AVCapturePhotoSettings()
                print("[Live Photo拍摄] iOS 版本低于11.0，使用默认编码")
            }
            
            // 设置 Live Photo 视频路径
            settings.livePhotoMovieFileURL = videoURL
            
            // 配置 Live Photo 设置
            settings.isHighResolutionPhotoEnabled = true
            
            // 设置基本的质量参数
            if #available(iOS 13.0, *) {
                settings.photoQualityPrioritization = .balanced
                print("[Live Photo拍摄] 使用平衡质量模式")
            }
            
            photoOutput.isLivePhotoCaptureEnabled = true
            
            // 设置视频编码
            if #available(iOS 11.0, *) {
                settings.livePhotoVideoCodecType = .hevc
                print("[Live Photo拍摄] 视频编码：HEVC")
            }
            
            print("[Live Photo拍摄] 文件设置：")
            if #available(iOS 11.0, *) {
                print("图片编码类型：\(settings.availablePreviewPhotoPixelFormatTypes.first ?? 0)")
                print("视频编码类型：\(settings.livePhotoVideoCodecType.rawValue)")
            }
            
            // 检查会话状态
            print("[Live Photo拍摄] 会话状态：")
            print("会话是否在运行：\(self.session.isRunning)")
            print("当前会话预设：\(self.session.sessionPreset.rawValue)")
            
            // 检查相机输入状态
            if let currentInput = self.currentCameraInput {
                print("[Live Photo拍摄] 相机输入状态：")
                print("设备位置：\(currentInput.device.position.rawValue)")
                print("设备格式：\(currentInput.device.activeFormat.description)")
            }
            
            // 创建处理器时传入文件路径
            let processor = LivePhotoPreviewProcessor(
                identifier: identifier,
                imageURL: imageURL,
                videoURL: videoURL
            ) { success, error in
                print("[Live Photo拍摄] 处理完成")
                print("处理结果：\(success ? "成功" : "失败")")
                if let error = error {
                    print("错误信息：\(error.localizedDescription)")
                    completion(false, identifier, nil, nil, nil, error)
                    return
                }
                
                if success {
                    do {
                        let imageData = try Data(contentsOf: imageURL)
                        if let image = UIImage(data: imageData) {
                            print("[Live Photo拍摄] 成功创建图片对象")
                            completion(true, identifier, imageURL, videoURL, image, nil)
                        } else {
                            throw NSError(domain: "CameraManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "无法创建图片对象"])
                        }
                    } catch {
                        print("[Live Photo拍摄] 处理图片时出错：\(error.localizedDescription)")
                        completion(false, identifier, nil, nil, nil, error)
                    }
                }
            }
            
            self.livePhotoCaptureProcessor = processor
            
            print("[Live Photo拍摄] 开始捕获")
            photoOutput.capturePhoto(with: settings, delegate: processor)
        }
    }
    
    func updateLatestProcessedImage(_ image: UIImage) {
        self.latestProcessedImage = image
    }
    
    // 新增：切换 Mirrored 屏幕的摄像头
    func switchMirroredScreenCamera() {
        print("========================")
        print("[切换Mirrored屏摄像头] 状态变化")
        print("------------------------")
        print("切换前：")
        print("- Mirrored屏前置/后置：\(isMirroredScreenFront ? "前置" : "后置")")
        print("- Original屏前置/后置：\(isFront ? "前置" : "后置")")
        
        isMirroredScreenFront.toggle()
        
        print("切换后：")
        print("- Mirrored屏前置/后置：\(isMirroredScreenFront ? "前置" : "后置")")
        print("- Original屏前置/后置：\(isFront ? "前置" : "后置")")
        print("========================")
        
        restartCamera()
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
    private let isMirrored: Bool
    
    init(completion: @escaping (UIImage?) -> Void, isMirrored: Bool) {
        self.completion = completion
        self.isMirrored = isMirrored
        super.init()
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("[系统相机] 拍照失败：\(error.localizedDescription)")
            completion(nil)
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              var image = UIImage(data: imageData) else {
            print("[系统相机] 错误：无法从照片数据创建图像")
            completion(nil)
            return
        }
        
        // 在 modeA (isMirrored = true) 下进行水平翻转处理
        if isMirrored {
            print("[系统相机] 模式A - 执行水平翻转")
            UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
            let context = UIGraphicsGetCurrentContext()!
            context.translateBy(x: image.size.width, y: 0)
            context.scaleBy(x: -1, y: 1)
            image.draw(in: CGRect(origin: .zero, size: image.size))
            if let flippedImage = UIGraphicsGetImageFromCurrentImageContext() {
                image = flippedImage
            }
            UIGraphicsEndImageContext()
        }
        
        print("[系统相机] 拍照成功")
        completion(image)
    }
}

// 修改 LivePhotoPreviewProcessor 类
class LivePhotoPreviewProcessor: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (Bool, Error?) -> Void
    private let identifier: String
    private var photoData: Data?
    private let tempImageURL: URL
    private let tempVideoURL: URL
    
    init(identifier: String, imageURL: URL, videoURL: URL, completion: @escaping (Bool, Error?) -> Void) {
        self.identifier = identifier
        self.tempImageURL = imageURL
        self.tempVideoURL = videoURL
        self.completion = completion
        super.init()
        print("[LivePhotoProcessor] 初始化处理器：\(identifier)")
        print("[LivePhotoProcessor] 图片保存路径：\(imageURL.path)")
        print("[LivePhotoProcessor] 视频保存路径：\(videoURL.path)")
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        print("[LivePhotoProcessor] 照片处理完成")
        
        if let error = error {
            print("[LivePhotoProcessor] 处理照片时出错：\(error.localizedDescription)")
            completion(false, error)
            return
        }
        
        // 检查和输出照片格式信息
        print("[LivePhotoProcessor] 照片格式信息：")
        if #available(iOS 11.0, *) {
            let fileType = photo.fileDataRepresentation()?.first
            print("文件类型标识：\(String(describing: fileType))")
        }
        
        guard let photoData = photo.fileDataRepresentation() else {
            print("[LivePhotoProcessor] 无法获取照片数据")
            completion(false, NSError(domain: "LivePhotoProcessor", 
                                   code: 1, 
                                   userInfo: [NSLocalizedDescriptionKey: "无法获取照片数据"]))
            return
        }
        
        print("[LivePhotoProcessor] 成功获取照片数据：\(photoData.count) 字节")
        
        do {
            try photoData.write(to: tempImageURL)
            print("[LivePhotoProcessor] 成功写入照片文件：\(tempImageURL.path)")
            self.photoData = photoData
        } catch {
            print("[LivePhotoProcessor] 写入照片文件失败：\(error.localizedDescription)")
            completion(false, error)
        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput,
                    didFinishProcessingLivePhotoToMovieFileAt outputFileURL: URL,
                    duration: CMTime,
                    photoDisplayTime: CMTime,
                    resolvedSettings: AVCaptureResolvedPhotoSettings,
                    error: Error?) {
        print("[LivePhotoProcessor] Live Photo视频处理完成")
        print("视频时长：\(duration.seconds)秒")
        print("照片显示时间：\(photoDisplayTime.seconds)秒")
        
        if let error = error {
            print("[LivePhotoProcessor] 处理视频时出错：\(error.localizedDescription)")
            completion(false, error)
            return
        }
        
        // 检查文件是否存在
        let imageExists = FileManager.default.fileExists(atPath: tempImageURL.path)
        let videoExists = FileManager.default.fileExists(atPath: tempVideoURL.path)
        
        print("[LivePhotoProcessor] 文件检查：")
        print("图片文件存在：\(imageExists)")
        print("视频文件存在：\(videoExists)")
        
        if imageExists && videoExists {
            print("[LivePhotoProcessor] 所有文件就绪")
            completion(true, nil)
        } else {
            print("[LivePhotoProcessor] 文件不完整")
            completion(false, NSError(domain: "LivePhotoProcessor", code: 2, userInfo: [NSLocalizedDescriptionKey: "文件不完整"]))
        }
    }
} 