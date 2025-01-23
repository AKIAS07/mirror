import SwiftUI
import AVFoundation

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
    
    // 添加手势设置管理器
    @ObservedObject private var styleManager = BorderLightStyleManager.shared
    
    // 添加截图状态
    @StateObject private var captureState = CaptureState()
    
    // 添加放缩相关的绑定
    @Binding var currentScale: CGFloat
    @Binding var showScaleIndicator: Bool
    @Binding var currentIndicatorScale: CGFloat
    let onPinchChanged: (CGFloat) -> Void
    let onPinchEnded: (CGFloat) -> Void
    
    // 添加震动反馈生成器
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
    
    // 添加截图处理相关的状态
    @State private var lastScreenshotTime: Date = Date()
    private let screenshotDebounceInterval: TimeInterval = 0.5
    
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
         onPinchEnded: @escaping (CGFloat) -> Void) {
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
                    
                    // 画面
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
                            // 根据手势设置处理点击事件
                            .onTapGesture(count: styleManager.isDefaultGesture ? 2 : 1) {
                                print("------------------------")
                                print("\(styleManager.isDefaultGesture ? "双击" : "单击")相机画面 - 捕捉截图")
                                print("当前模式：\(isMirrored ? "镜像模式" : "正常模式")")
                                print("当前缩放比例：\(currentScale)")
                                
                                // 捕捉当前画面并设置缩放比例
                                captureState.capturedImage = image
                                captureState.currentScale = currentScale
                                
                                // 显示操作按钮并隐藏控制区域
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    captureState.showButtons = true
                                    isControlAreaVisible = false
                                }
                                
                                // 触发震动反馈
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.prepare()
                                generator.impactOccurred()
                                
                                print("------------------------")
                            }
                    }
                    
                    // 添加缩放提示
                    if showScaleIndicator {
                        ScaleIndicatorView(scale: currentIndicatorScale)
                            .position(x: geometry.size.width/2, y: geometry.size.height/2)
                            .animation(.easeInOut(duration: 0.2), value: currentIndicatorScale)
                    }
                    
                    // 添加截图操作按钮
                    VStack {
                        Spacer()
                        CaptureActionsView(captureState: captureState) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isControlAreaVisible = true
                            }
                        }
                        .padding(.bottom, 180) // 确保不会被底部控制栏遮挡
                    }
                } else {
                    RestartCameraView(action: restartAction)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                CameraContainerFrame.frame = containerFrame
                print("相机容器 - 设置 Frame:", containerFrame)
            }
            .onChange(of: geometry.size) { _ in
                CameraContainerFrame.frame = containerFrame
                print("相机容器 - 更新 Frame:", containerFrame)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        // 根据手势设置处理点击事件
        .onTapGesture(count: styleManager.isDefaultGesture ? 1 : 2) {
            withAnimation(.easeInOut(duration: 0.2)) {
                containerSelected.toggle()
                
                if containerSelected {
                    // 设置为最大亮度
                    UIScreen.main.brightness = 1.0
                    print("提高亮度至最大")
                    // 触发震动反馈
                    feedbackGenerator.impactOccurred(intensity: 1.0)
                    isLighted = true
                } else {
                    // 恢复原始亮度
                    UIScreen.main.brightness = previousBrightness
                    print("恢复原始亮度：\(previousBrightness)")
                    isLighted = false
                }
            }
            print("选中状态：\(containerSelected)")
            print("屏幕点亮状态：\(isLighted)")
        }
        .onAppear {
            setupVideoProcessing()
            // 预准备震动反馈
            feedbackGenerator.prepare()
        }
        .onDisappear {
            // 删除在视图消失时恢复原始亮度的操作
            print("主页面视图消失")
        }
    }
    
    private func setupVideoProcessing() {
        let processor = MainVideoProcessor()
        // 根据isMirrored设置初始模式
        processor.setMode(isMirrored ? .modeA : .modeB)
        processor.isMirrored = isMirrored
        processor.imageHandler = { image in
            DispatchQueue.main.async {
                self.processedImage = image
            }
        }
        
        // 创建并保存观察者
        let observer = CameraObserver(processor: processor)
        self.observer = observer
        
        // 添加观察者
        if let connection = cameraManager.videoOutput.connection(with: .video) {
            connection.addObserver(observer, forKeyPath: "videoMirrored", options: [.new], context: nil)
        }
        
        cameraManager.videoOutputDelegate = processor
    }
} 