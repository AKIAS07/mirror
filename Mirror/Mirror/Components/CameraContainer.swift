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
    
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
    
    @State private var lastScreenshotTime: Date = Date()
    private let screenshotDebounceInterval: TimeInterval = AppConfig.Debounce.screenshot
    
    let captureState: CaptureState
    
    @State private var captureTimer: Timer?
    private let captureDelay: TimeInterval = AppConfig.AnimationConfig.Capture.delay
    
    @State private var showIconAnimation: Bool = false
    @State private var flashAnimationObserver: NSObjectProtocol? = nil
    
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
        self.captureState = captureState
    }
    
    var body: some View {
        GeometryReader { geometry in
            let availableHeight = geometry.size.height
            let containerFrame = CGRect(
                x: CameraLayoutConfig.horizontalPadding,
                y: CameraLayoutConfig.verticalOffset,
                width: geometry.size.width - (CameraLayoutConfig.horizontalPadding * 2),
                height: availableHeight - CameraLayoutConfig.bottomOffset
            )
            
            ZStack {
                if isActive {
                    if cameraManager.isUsingSystemCamera {
                        // 使用系统相机
                        ZStack {
                            Color.black // 添加黑色背景
                            
                            CameraView(session: .constant(cameraManager.session), isMirrored: .constant(cameraManager.isMirrored))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: CameraLayoutConfig.cornerRadius))
                                .padding(.horizontal, CameraLayoutConfig.horizontalPadding)
                                .padding(.top, CameraLayoutConfig.verticalOffset)
                                .padding(.bottom, CameraLayoutConfig.bottomOffset)
                                .scaleEffect(currentScale)
                                // 添加旋转变换
                                .rotationEffect(Angle(degrees: shouldRotateCamera ? 180 : 0))
                                // 添加缩放手势
                                .simultaneousGesture(
                                    MagnificationGesture()
                                        .onChanged { scale in
                                            onPinchChanged(scale)
                                        }
                                        .onEnded { scale in
                                            onPinchEnded(scale)
                                        }
                                )
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                                            captureManager.showLivePhotoPreview(
                                                image: image,
                                                videoURL: videoURL,
                                                imageURL: imageURL,
                                                identifier: identifier,
                                                cameraManager: cameraManager
                                            )
                                            
                                            // 在显示预览后处理相机停止
                                            ContentRestartManager.shared.handleRestartViewAppear(cameraManager: cameraManager)
                                            
                                            // 隐藏控制区域
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                isControlAreaVisible = false
                                            }
                                            
                                            print("------------------------")
                                            print("Live Photo 已捕捉")
                                            print("------------------------")
                                        } else {
                                            print("[Live Photo 拍摄] 失败: \(error?.localizedDescription ?? "未知错误")")
                                        }
                                    }
                                }
                            } else {
                                // 延迟捕捉普通照片
                                DispatchQueue.main.asyncAfter(deadline: .now() + AppConfig.AnimationConfig.Capture.delay) {
                                    // 捕捉当前画面
                                    if let latestImage = processedImage {
                                        captureManager.showPreview(
                                            image: latestImage, 
                                            scale: currentScale,
                                            cameraManager: cameraManager
                                        )
                                        
                                        // 在显示预览后处理相机停止
                                        ContentRestartManager.shared.handleRestartViewAppear(cameraManager: cameraManager)
                                        
                                        // 隐藏控制区域
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            isControlAreaVisible = false
                                        }
                                        
                                        print("------------------------")
                                        print("普通截图已捕捉")
                                        print("------------------------")
                                    }
                                }
                            }
                        }
                    } else {
                        // 使用自定义相机
                        if let image = processedImage {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geometry.size.width - (CameraLayoutConfig.horizontalPadding * 2), 
                                       height: availableHeight - CameraLayoutConfig.bottomOffset)
                                .clipShape(RoundedRectangle(cornerRadius: CameraLayoutConfig.cornerRadius))
                                .scaleEffect(currentScale)
                                .offset(y: CameraLayoutConfig.verticalOffset)
                                .simultaneousGesture(
                                    MagnificationGesture()
                                        .onChanged { scale in
                                            onPinchChanged(scale)
                                        }
                                        .onEnded { scale in
                                            onPinchEnded(scale)
                                        }
                                )
                                .onTapGesture(count: styleManager.isDefaultGesture ? 2 : 1) {
                                    print("------------------------")
                                    print("\(styleManager.isDefaultGesture ? "双击" : "单击")相机画面 - 准备捕捉截图")
                                    print("当前模式：\(isMirrored ? "镜像模式" : "正常模式")")
                                    print("当前缩放比例：\(currentScale)")
                                    
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
                                                    captureManager.showLivePhotoPreview(
                                                        image: image,
                                                        videoURL: videoURL,
                                                        imageURL: imageURL,
                                                        identifier: identifier,
                                                        cameraManager: cameraManager
                                                    )
                                                    
                                                    // 在显示预览后处理相机停止
                                                    ContentRestartManager.shared.handleRestartViewAppear(cameraManager: cameraManager)
                                                    
                                                    // 隐藏控制区域
                                                    withAnimation(.easeInOut(duration: 0.3)) {
                                                        isControlAreaVisible = false
                                                    }
                                                    
                                                    print("------------------------")
                                                    print("Live Photo 已捕捉")
                                                    print("------------------------")
                                                } else {
                                                    print("[Live Photo 拍摄] 失败: \(error?.localizedDescription ?? "未知错误")")
                                                }
                                            }
                                        }
                                    } else {
                                        // 延迟捕捉普通照片
                                        DispatchQueue.main.asyncAfter(deadline: .now() + AppConfig.AnimationConfig.Capture.delay) {
                                            // 捕捉当前画面
                                            if let latestImage = processedImage {
                                                captureManager.showPreview(
                                                    image: latestImage, 
                                                    scale: currentScale,
                                                    cameraManager: cameraManager
                                                )
                                                
                                                // 在显示预览后处理相机停止
                                                ContentRestartManager.shared.handleRestartViewAppear(cameraManager: cameraManager)
                                                
                                                // 隐藏控制区域
                                                withAnimation(.easeInOut(duration: 0.3)) {
                                                    isControlAreaVisible = false
                                                }
                                                
                                                print("------------------------")
                                                print("普通截图已捕捉")
                                                print("------------------------")
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
                            deviceOrientation: deviceOrientation
                        )
                        .position(x: geometry.size.width/2, y: geometry.size.height/2)
                        .animation(.easeInOut(duration: 0.2), value: currentScale)
                        .zIndex(4)
                    }
                    
                    // 添加截图操作按钮
                    VStack {
                        Spacer()
                        CaptureActionsView(captureState: captureState, cameraManager: cameraManager) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isControlAreaVisible = true
                            }
                            // 添加相机重启
                            ContentRestartManager.shared.restartCamera(cameraManager: cameraManager)
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
    
    // 在 CameraContainer 结构体内添加计算属性
    private var shouldRotateCamera: Bool {
        // 在模式B且使用系统相机时，检查是否为横屏
        !isMirrored && cameraManager.isUsingSystemCamera && 
        (deviceOrientation == .landscapeLeft || deviceOrientation == .landscapeRight)
    }
} 