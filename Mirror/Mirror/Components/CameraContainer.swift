import SwiftUI
import AVFoundation
import MediaPlayer

struct CameraContainerFrame {
    static var frame: CGRect = .zero
}

struct CameraContainer: View {
    let session: AVCaptureSession
    let isMirrored: Bool
    let isActive: Bool
    let deviceOrientation: UIDeviceOrientation
    let restartAction: () -> Void
    @State private var processedImage: UIImage?
    @State private var observer: CameraObserver?
    let previousBrightness: CGFloat
    @Binding var containerSelected: Bool
    @Binding var isLighted: Bool
    @Binding var isControlAreaVisible: Bool
    
    let cameraManager: CameraManager
    @StateObject private var captureManager = CaptureManager.shared
    
    @ObservedObject private var styleManager = BorderLightStyleManager.shared
    
    @Binding var currentScale: CGFloat
    @Binding var showScaleIndicator: Bool
    @Binding var currentIndicatorScale: CGFloat
    let onPinchChanged: (CGFloat) -> Void
    let onPinchEnded: (CGFloat) -> Void
    let minScale: CGFloat
    
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
    
    @State private var lastScreenshotTime: Date = Date()
    private let screenshotDebounceInterval: TimeInterval = AppConfig.Debounce.screenshot
    
    let captureState: CaptureState
    
    @State private var captureTimer: Timer?
    private let captureDelay: TimeInterval = AppConfig.AnimationConfig.Capture.delay
    
    @State private var showIconAnimation: Bool = false
    @State private var flashAnimationObserver: NSObjectProtocol? = nil
    
    // 添加允许的设备方向
    private let allowedOrientations: [UIDeviceOrientation] = [
        .portrait,
        .portraitUpsideDown,
        .landscapeLeft,
        .landscapeRight
    ]
    
    // 添加最后一个有效方向状态
    @State private var lastValidOrientation: UIDeviceOrientation = .portrait
    
    @StateObject private var dayNightManager = DayNightManager.shared
    
    init(session: AVCaptureSession, 
         isMirrored: Bool, 
         isActive: Bool, 
         deviceOrientation: UIDeviceOrientation, 
         restartAction: @escaping () -> Void, 
         cameraManager: CameraManager,
         previousBrightness: CGFloat,
         isSelected: Binding<Bool>,
         isLighted: Binding<Bool>,
         isControlAreaVisible: Binding<Bool>,
         currentScale: Binding<CGFloat>,
         showScaleIndicator: Binding<Bool>,
         currentIndicatorScale: Binding<CGFloat>,
         onPinchChanged: @escaping (CGFloat) -> Void,
         onPinchEnded: @escaping (CGFloat) -> Void,
         minScale: CGFloat = 0.6,
         captureState: CaptureState = CaptureState()) {
        self.session = session
        self.isMirrored = isMirrored
        self.isActive = isActive
        self.deviceOrientation = deviceOrientation
        self.restartAction = restartAction
        self.cameraManager = cameraManager
        self.previousBrightness = previousBrightness
        _containerSelected = isSelected
        _isLighted = isLighted
        _isControlAreaVisible = isControlAreaVisible
        _currentScale = currentScale
        _showScaleIndicator = showScaleIndicator
        _currentIndicatorScale = currentIndicatorScale
        self.onPinchChanged = onPinchChanged
        self.onPinchEnded = onPinchEnded
        self.minScale = minScale
        self.captureState = captureState
        
        // 添加方向更新通知监听
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("DeviceOrientationDidChange"),
            object: nil,
            queue: .main
        ) { notification in
            if let newOrientation = notification.userInfo?["orientation"] as? UIDeviceOrientation {
                print("[相机容器] 收到设备方向更新通知：\(newOrientation.rawValue)")
                // 更新相机预览方向
                if let connection = session.connections.first {
                    let videoOrientation = AVCaptureVideoOrientation(deviceOrientation: newOrientation) ?? .portrait
                    if connection.isVideoOrientationSupported {
                        connection.videoOrientation = videoOrientation
                    }
                }
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let availableHeight = geometry.size.height
            let containerFrame = CGRect(
                x: 0,
                y: 0,
                width: geometry.size.width,
                height: availableHeight
            )
            
            ZStack {
                if isActive {
                    if cameraManager.isUsingSystemCamera {
                        SystemCameraView(
                            session: session,
                            isMirrored: isMirrored,
                            deviceOrientation: deviceOrientation,
                            isSystemCamera: cameraManager.isUsingSystemCamera,
                            isBackCamera: cameraManager.isUsingBackCamera,
                            currentScale: currentScale,
                            onPinchChanged: onPinchChanged,
                            onPinchEnded: onPinchEnded,
                            styleManager: styleManager,
                            captureState: captureState,
                            processedImage: processedImage,
                            showIconAnimation: $showIconAnimation,
                            isControlAreaVisible: $isControlAreaVisible,
                            cameraManager: cameraManager,
                            captureManager: captureManager,
                            dayNightManager: dayNightManager
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .edgesIgnoringSafeArea(.all)
                        .position(x: geometry.size.width/2, y: geometry.size.height/2)
                    } else {
                        if let image = processedImage {
                            ZStack {
                                // 使用 DayNightManager 的背景颜色
                                dayNightManager.backgroundColor
                                    .edgesIgnoringSafeArea(.all)
                                
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .edgesIgnoringSafeArea(.all)
                                    .scaleEffect(currentScale, anchor: .center)
                                    .rotationEffect(Angle(degrees: shouldRotateCamera(orientation: deviceOrientation) ? 180 : 0))
                                    .position(x: geometry.size.width/2, y: geometry.size.height/2)
                                    .simultaneousGesture(
                                        MagnificationGesture()
                                            .onChanged { scale in
                                                onPinchChanged(scale)
                                                
                                                // 记录缩放操作
                                                ViewActionLogger.shared.logZoomAction(scale: currentScale)
                                            }
                                            .onEnded { scale in
                                                onPinchEnded(scale)
                                                
                                                // 记录最终缩放比例
                                                ViewActionLogger.shared.logZoomAction(scale: currentScale)
                                            }
                                    )
                                    .onTapGesture(count: styleManager.isDefaultGesture ? 2 : 1) {
                                        print("------------------------")
                                        print("\(styleManager.isDefaultGesture ? "双击" : "单击")相机画面 - 准备捕捉截图")
                                        print("当前模式：\(isMirrored ? "镜像模式" : "正常模式")")
                                        print("当前缩放比例：\(currentScale)")
                                        
                                        // 记录点击操作
                                        ViewActionLogger.shared.logAction(
                                            .gestureAction(styleManager.isDefaultGesture ? .doubleTap : .tap),
                                            additionalInfo: [
                                                "模式": isMirrored ? "镜像" : "正常",
                                                "缩放比例": "\(Int(currentScale * 100))%"
                                            ]
                                        )
                                        
                                        // 设置捕捉状态
                                        captureState.isCapturing = true
                                        
                                        // 触发震动反馈
                                        let generator = UIImpactFeedbackGenerator(style: .medium)
                                        generator.prepare()
                                        generator.impactOccurred()
                                        
                                        // 立即显示闪光动画
                                        withAnimation {
                                            showIconAnimation = true
                                        }
                                        
                                        // 延迟隐藏闪光动画
                                        DispatchQueue.main.asyncAfter(deadline: .now() + AppConfig.AnimationConfig.Flash.displayDuration) {
                                            withAnimation {
                                                showIconAnimation = false
                                            }
                                        }
                                        
                                        // 根据是否使用系统相机决定拍摄方式
                                        if cameraManager.isUsingSystemCamera {
                                            print("点击屏幕 - 使用系统相机拍摄 Live Photo")
                                            cameraManager.captureLivePhotoForPreview { success, identifier, imageURL, videoURL, image, error in
                                                DispatchQueue.main.async {
                                                    captureState.isCapturing = false
                                                    
                                                    if success, let imageURL = imageURL, let videoURL = videoURL, let image = image {
                                                        print("[Live Photo 拍摄] 成功，准备预览")
                                                        print("- 图片URL：\(imageURL.path)")
                                                        print("- 视频URL：\(videoURL.path)")
                                                        print("- 标识符：\(identifier)")
                                                        print("- 设备方向：\(self.deviceOrientation.rawValue)")
                                                        print("- 缩放比例：\(self.currentScale)")
                                                        
                                                        self.captureManager.showLivePhotoPreview(
                                                            image: image,
                                                            videoURL: videoURL,
                                                            imageURL: imageURL,
                                                            identifier: identifier,
                                                            orientation: self.deviceOrientation,
                                                            cameraManager: self.cameraManager,
                                                            scale: self.currentScale,
                                                            isMirrored: self.cameraManager.isMirrored,
                                                            isFront: self.cameraManager.isFront,
                                                            isBack: !self.cameraManager.isFront
                                                        )
                                                        
                                                        // 隐藏控制区域
                                                        withAnimation(.easeInOut(duration: 0.3)) {
                                                            self.isControlAreaVisible = false
                                                        }
                                                        
                                                        print("------------------------")
                                                        print("Live Photo 已捕捉")
                                                        print("------------------------")
                                                    } else {
                                                        print("[Live Photo 拍摄] 失败")
                                                        print("- 成功状态：\(success)")
                                                        print("- 图片URL：\(String(describing: imageURL))")
                                                        print("- 视频URL：\(String(describing: videoURL))")
                                                        print("- 错误信息：\(String(describing: error?.localizedDescription))")
                                                    }
                                                }
                                            }
                                        } else {
                                            print("点击屏幕 - 使用自定义相机拍摄普通照片")
                                            // 延迟捕捉普通照片
                                            DispatchQueue.main.asyncAfter(deadline: .now() + AppConfig.AnimationConfig.Capture.delay) {
                                                // 使用系统相机的拍照功能
                                                self.cameraManager.capturePhoto { image in
                                                    if let image = image {
                                                        DispatchQueue.main.async {
                                                            self.captureManager.showPreview(
                                                                image: image, 
                                                                scale: self.currentScale,
                                                                orientation: self.deviceOrientation,
                                                                cameraManager: self.cameraManager
                                                            )
                                                            
                                                            // 隐藏控制区域
                                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                                self.isControlAreaVisible = false
                                                            }
                                                            
                                                            print("------------------------")
                                                            print("普通照片已捕捉")
                                                            print("------------------------")
                                                        }
                                                    } else {
                                                        DispatchQueue.main.async {
                                                            self.captureState.isCapturing = false
                                                            print("普通照片拍摄失败 - 无可用图像")
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                            }
                        }
                    }
                    
                    // 打印 CameraContainer 的位置信息
                    Color.clear.onAppear {
                        let x = CameraLayoutConfig.horizontalPadding
                        let y = CameraLayoutConfig.verticalOffset
                        print("========================")
                        print("CameraContainer 位置信息：")
                        print("左上角坐标：(\(x), \(y))")
                        print("尺寸：\(geometry.size.width) x \(geometry.size.height)")
                        print("========================")
                    }
                    
                    // 添加缩放提示
                    if showScaleIndicator {
                        ScaleIndicatorView(
                            scale: currentScale,
                            deviceOrientation: deviceOrientation,
                            isMinScale: abs(currentScale - minScale) < 0.01
                        )
                        .position(x: geometry.size.width/2, y: geometry.size.height/2)
                        .animation(.easeInOut(duration: 0.2), value: currentScale)
                        .zIndex(4)
                    }
                    
                    // 添加截图操作按钮
                    VStack {
                        Spacer()
                        CaptureActionsView(captureManager: captureManager, cameraManager: cameraManager) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isControlAreaVisible = true
                            }
                            // 添加相机重启
                            print("------------------------")
                            print("[相机容器] 请求重启相机")
                            print("当前状态：")
                            print("- 镜像模式(A模式)：\(cameraManager.isMirrored)")
                            print("- 系统相机：\(cameraManager.isUsingSystemCamera)")
                            print("- 摄像头：\(cameraManager.isFront ? "前置" : "后置")")
                            print("------------------------")
                            cameraManager.restartCamera()
                        }
                        .padding(.bottom, 180) // 确保不会被底部控制栏遮挡
                    }
                    
                    // 添加闪光动画
                    if showIconAnimation && AppConfig.AnimationConfig.Flash.isEnabled {
                        FlashAnimationView()
                            .zIndex(6)
                    }
                } else {
                    RestartCameraView(action: restartAction, cameraManager: cameraManager)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                CameraContainerFrame.frame = containerFrame
                print("相机容器 - 设置 Frame:", containerFrame)
                
                setupVideoProcessing()
                feedbackGenerator.prepare()
                
                // 添加闪光动画通知监听
                flashAnimationObserver = NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("TriggerFlashAnimation"),
                    object: nil,
                    queue: .main
                ) { _ in
                    // 显示闪光动画
                    withAnimation {
                        showIconAnimation = true
                    }
                    
                    // 延迟隐藏闪光动画
                    DispatchQueue.main.asyncAfter(deadline: .now() + AppConfig.AnimationConfig.Flash.displayDuration) {
                        withAnimation {
                            showIconAnimation = false
                        }
                    }
                }
                
                // 添加设备方向变化通知监听
                NotificationCenter.default.addObserver(
                    forName: UIDevice.orientationDidChangeNotification,
                    object: nil,
                    queue: .main) { _ in
                        let newOrientation = UIDevice.current.orientation
                        
                        print("========================")
                        print("[设备方向] 变化检测")
                        print("------------------------")
                        print("新方向：\(getOrientationDescription(newOrientation))")
                        print("允许的方向：\(allowedOrientations.contains(newOrientation))")
                        print("------------------------")
                        
                        // 只处理允许的方向
                        if allowedOrientations.contains(newOrientation) {
                            lastValidOrientation = newOrientation
                            
                            // 检查是否需要旋转
                            let needRotation = shouldRotateCamera(orientation: newOrientation)
                            print("旋转检查结果：\(needRotation ? "需要旋转" : "不需要旋转")")
                            
                            if needRotation {
                                if newOrientation == .landscapeLeft {
                                    print("执行操作：向左横屏旋转180度")
                                } else if newOrientation == .landscapeRight {
                                    print("执行操作：向右横屏旋转180度")
                                }
                            }
                        } else {
                            print("当前方向不被允许，保持上一个有效方向")
                            print("上一个有效方向：\(getOrientationDescription(lastValidOrientation))")
                        }
                        print("========================")
                    }
            }
            .onChange(of: geometry.size) { _ in
                CameraContainerFrame.frame = containerFrame
                print("相机容器 - 更新 Frame:", containerFrame)
            }
            .onDisappear {
                // 移除通知监听
                if let observer = flashAnimationObserver {
                    NotificationCenter.default.removeObserver(observer)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .onTapGesture(count: styleManager.isDefaultGesture ? 1 : 2) {
            withAnimation(.easeInOut(duration: 0.2)) {
                containerSelected.toggle()
                
                if containerSelected {
                    UIScreen.main.brightness = 1.0
                    print("提高亮度至最大")
                    feedbackGenerator.impactOccurred(intensity: 1.0)
                    isLighted = true
                } else {
                    UIScreen.main.brightness = previousBrightness
                    print("恢复原始亮度：\(previousBrightness)")
                    isLighted = false
                }
            }
            print("选中状态：\(containerSelected)")
            print("屏幕点亮状态：\(isLighted)")
        }
    }
    
    private func setupVideoProcessing() {
        if !cameraManager.isUsingSystemCamera {
            let processor = MainVideoProcessor()
            processor.setMode(isMirrored ? .modeA : .modeB)
            processor.isMirrored = isMirrored
            processor.imageHandler = { image in
                DispatchQueue.main.async {
                    if !captureState.showButtons || captureState.isCapturing {
                        self.processedImage = image
                        // 更新 CameraManager 中的最新图像
                        self.cameraManager.updateLatestProcessedImage(image)
                    }
                }
            }
            
            let observer = CameraObserver(processor: processor)
            self.observer = observer
            
            if let connection = cameraManager.videoOutput.connection(with: .video) {
                connection.addObserver(observer, forKeyPath: "videoMirrored", options: [.new], context: nil)
            }
            
            cameraManager.videoOutputDelegate = processor
        }
    }
    
    // 修改 shouldRotateCamera 方法，添加更详细的调试信息
    private func shouldRotateCamera(orientation: UIDeviceOrientation) -> Bool {
        // 1. 检查是否在模式A（镜像模式）
        let isModeA = isMirrored
        
        // 2. 检查是否横屏
        let isLandscape = orientation == .landscapeLeft || orientation == .landscapeRight
        
        // 3. 获取摄像头状态
        let isFrontCamera = cameraManager.isFront
        
        // 4. 根据模式和摄像头状态决定是否旋转
        let shouldRotate: Bool
        if isModeA {
            // 模式A：后置摄像头横屏时旋转
            shouldRotate = isLandscape && !isFrontCamera
        } else {
            // 模式B：前置摄像头横屏时旋转
            shouldRotate = isLandscape && isFrontCamera
        }
        
        // print("4. 旋转决策：")
        // print("- 模式A：\(isModeA)")
        // print("- 横屏：\(isLandscape)")
        // print("- 前置摄像头：\(isFrontCamera)")
        // print("- 最终结果：\(shouldRotate ? "需要旋转" : "不需要旋转")")
        // print("========================")
        
        return shouldRotate
    }
    
    // 添加方向描述辅助方法
    private func getOrientationDescription(_ orientation: UIDeviceOrientation) -> String {
        switch orientation {
        case .portrait:
            return "竖直"
        case .portraitUpsideDown:
            return "竖直倒置"
        case .landscapeLeft:
            return "向左横屏"
        case .landscapeRight:
            return "向右横屏"
        case .faceUp:
            return "面朝上"
        case .faceDown:
            return "面朝下"
        default:
            return "未知方向"
        }
    }
}

// 添加SystemCameraView结构体
struct SystemCameraView: View {
    let session: AVCaptureSession
    let isMirrored: Bool
    let deviceOrientation: UIDeviceOrientation
    let isSystemCamera: Bool
    let isBackCamera: Bool
    let currentScale: CGFloat
    let onPinchChanged: (CGFloat) -> Void
    let onPinchEnded: (CGFloat) -> Void
    let styleManager: BorderLightStyleManager
    let captureState: CaptureState
    let processedImage: UIImage?
    @Binding var showIconAnimation: Bool
    @Binding var isControlAreaVisible: Bool
    let cameraManager: CameraManager
    let captureManager: CaptureManager
    let dayNightManager: DayNightManager
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 使用 DayNightManager 的背景颜色
                dayNightManager.backgroundColor
                    .edgesIgnoringSafeArea(.all)
                
                if let image = processedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .edgesIgnoringSafeArea(.all)
                        .scaleEffect(currentScale, anchor: .center)
                        .rotationEffect(Angle(degrees: shouldRotateCamera(orientation: deviceOrientation) ? 180 : 0))
                        .position(x: geometry.size.width/2, y: geometry.size.height/2)
                        .simultaneousGesture(
                            MagnificationGesture()
                                .onChanged { scale in
                                    onPinchChanged(scale)
                                    ViewActionLogger.shared.logZoomAction(scale: currentScale)
                                }
                                .onEnded { scale in
                                    onPinchEnded(scale)
                                    ViewActionLogger.shared.logZoomAction(scale: currentScale)
                                }
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .edgesIgnoringSafeArea(.all)
        }
        .onAppear {
            print("------------------------")
            print("[CameraContainer] 切换到系统相机模式")
            print("Frame: \(CameraContainerFrame.frame)")
            print("------------------------")
        }
        .onTapGesture(count: styleManager.isDefaultGesture ? 2 : 1) {
            print("------------------------")
            print("\(styleManager.isDefaultGesture ? "双击" : "单击")相机画面 - 准备捕捉截图")
            print("当前模式：\(isMirrored ? "镜像模式" : "正常模式")")
            print("当前缩放比例：\(currentScale)")
            
            // 记录点击操作
            ViewActionLogger.shared.logAction(
                .gestureAction(styleManager.isDefaultGesture ? .doubleTap : .tap),
                additionalInfo: [
                    "模式": isMirrored ? "镜像" : "正常",
                    "缩放比例": "\(Int(currentScale * 100))%"
                ]
            )
            
            // 设置捕捉状态
            captureState.isCapturing = true
            
            // 触发震动反馈
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
            
            // 立即显示闪光动画
            withAnimation {
                showIconAnimation = true
            }
            
            // 延迟隐藏闪光动画
            DispatchQueue.main.asyncAfter(deadline: .now() + AppConfig.AnimationConfig.Flash.displayDuration) {
                withAnimation {
                    showIconAnimation = false
                }
            }
            
            // 使用系统相机拍摄 Live Photo
            print("点击屏幕 - 使用系统相机拍摄 Live Photo")
            cameraManager.captureLivePhotoForPreview { success, identifier, imageURL, videoURL, image, error in
                DispatchQueue.main.async {
                    captureState.isCapturing = false
                    
                    if success, let imageURL = imageURL, let videoURL = videoURL, let image = image {
                        print("[Live Photo 拍摄] 成功，准备预览")
                        print("- 图片URL：\(imageURL.path)")
                        print("- 视频URL：\(videoURL.path)")
                        print("- 标识符：\(identifier)")
                        print("- 设备方向：\(self.deviceOrientation.rawValue)")
                        print("- 缩放比例：\(self.currentScale)")
                        
                        self.captureManager.showLivePhotoPreview(
                            image: image,
                            videoURL: videoURL,
                            imageURL: imageURL,
                            identifier: identifier,
                            orientation: self.deviceOrientation,
                            cameraManager: self.cameraManager,
                            scale: self.currentScale,
                            isMirrored: self.cameraManager.isMirrored,
                            isFront: self.cameraManager.isFront,
                            isBack: !self.cameraManager.isFront
                        )
                        
                        // 隐藏控制区域
                        withAnimation(.easeInOut(duration: 0.3)) {
                            self.isControlAreaVisible = false
                        }
                        
                        print("------------------------")
                        print("Live Photo 已捕捉")
                        print("------------------------")
                    } else {
                        print("[Live Photo 拍摄] 失败")
                        print("- 成功状态：\(success)")
                        print("- 图片URL：\(String(describing: imageURL))")
                        print("- 视频URL：\(String(describing: videoURL))")
                        print("- 错误信息：\(String(describing: error?.localizedDescription))")
                    }
                }
            }
        }
    }
    
    // 判断是否需要旋转摄像头
    private func shouldRotateCamera(orientation: UIDeviceOrientation) -> Bool {
        // 1. 检查是否在模式A（镜像模式）
        let isModeA = isMirrored
        
        // 2. 检查是否横屏
        let isLandscape = orientation == .landscapeLeft || orientation == .landscapeRight
        
        // 3. 获取摄像头状态
        let isFrontCamera = !isBackCamera
        
        // 4. 根据模式和摄像头状态决定是否旋转
        let shouldRotate: Bool
        if isModeA {
            // 模式A：后置摄像头横屏时旋转
            shouldRotate = isLandscape && !isFrontCamera
        } else {
            // 模式B：前置摄像头横屏时旋转
            shouldRotate = isLandscape && isFrontCamera
        }
        
        return shouldRotate
    }
}

// 添加 AVCaptureVideoOrientation 扩展
private extension AVCaptureVideoOrientation {
    init?(deviceOrientation: UIDeviceOrientation) {
        switch deviceOrientation {
        case .portrait: self = .portrait
        case .portraitUpsideDown: self = .portraitUpsideDown
        case .landscapeLeft: self = .landscapeRight
        case .landscapeRight: self = .landscapeLeft
        default: return nil
        }
    }
} 
