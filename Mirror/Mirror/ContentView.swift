//
//  ContentView.swift
//  Mirror
//
//  Created by 林喵 on 2024/12/16.
//

import SwiftUI
import AVFoundation
import UIKit

struct BorderStyle {
    static let normalColor = Color.green
    static let selectedColor = Color.white
    static let normalWidth: CGFloat = 1
    static let selectedWidth: CGFloat = 50
}

struct CircleButton: View {
    let systemName: String
    let title: String
    let action: () -> Void
    let deviceOrientation: UIDeviceOrientation
    
    var body: some View {
        Button(action: action) {
            if systemName.isEmpty {
                // 只显示文字，用于焦距按钮
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            } else {
                // 显示图标，用于其他按钮
                Image(systemName: systemName)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .rotationEffect(getIconRotationAngle(deviceOrientation))
                    .frame(width: 60, height: 60)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
        }
    }
    
    // 获取图标旋转角度
    private func getIconRotationAngle(_ orientation: UIDeviceOrientation) -> Angle {
        switch orientation {
        case .landscapeLeft:
            return .degrees(90)
        case .landscapeRight:
            return .degrees(-90)
        default:
            return .degrees(0)
        }
    }
}

// 添加一个观察者类来处理 KVO
class CameraObserver: NSObject {
    let processor: MainVideoProcessor
    private var lastLogTime: Date = Date()
    private let logInterval: TimeInterval = 1.0
    private var previousMirrorState: Bool = false
    
    init(processor: MainVideoProcessor) {
        self.processor = processor
        super.init()
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "videoMirrored",
           let connection = object as? AVCaptureConnection {
            let currentTime = Date()
            
            // 在状态真正发生变化且超过时间间隔时输出日志
            if connection.isVideoMirrored != previousMirrorState && 
               currentTime.timeIntervalSince(lastLogTime) >= logInterval {
                print("镜像状态更新：\(connection.isVideoMirrored)")
                lastLogTime = currentTime
                previousMirrorState = connection.isVideoMirrored
                
                // 更新处理器的模式
                processor.setMode(connection.isVideoMirrored ? .modeA : .modeB)
            }
            
            // 更新处理器状态
            processor.isMirrored = connection.isVideoMirrored
        }
    }
}

// 添加共享布局常量
struct CameraLayoutConfig {
    static let horizontalPadding: CGFloat = 10  // 左右边距
    static let verticalPadding: CGFloat = 50   // 上下边距
    static let cornerRadius: CGFloat = 20       // 圆角半径
    static let bottomOffset: CGFloat = 300      // 底部偏移
    static let verticalOffset: CGFloat = -50    // 垂直偏移
}

// 添加一个结构体来存储容器位置信息
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
    @State private var previousBrightness: CGFloat = UIScreen.main.brightness
    @State private var containerSelected: Bool
    @Binding var isLighted: Bool
    
    let cameraManager: CameraManager
    
    // 添加放缩相关的绑定
    @Binding var currentScale: CGFloat
    @Binding var showScaleIndicator: Bool
    @Binding var currentIndicatorScale: CGFloat
    let onPinchChanged: (CGFloat) -> Void
    let onPinchEnded: (CGFloat) -> Void
    
    // 添加震动反馈生成器
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
    
    init(session: AVCaptureSession, 
         isMirrored: Bool, 
         isActive: Bool, 
         deviceOrientation: UIDeviceOrientation, 
         restartAction: @escaping () -> Void, 
         cameraManager: CameraManager, 
         isSelected: Bool,
         isLighted: Binding<Bool>,
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
        _containerSelected = State(initialValue: isSelected)
        _isLighted = isLighted
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
                    }
                    
                    // 边框视图布局 - 不应用缩放效果
                    GeometryReader { borderGeometry in
                        Rectangle()
                            .stroke(containerSelected ? BorderStyle.selectedColor : BorderStyle.normalColor,
                                   lineWidth: containerSelected ? BorderStyle.selectedWidth : BorderStyle.normalWidth)
                            .frame(width: geometry.size.width - (CameraLayoutConfig.horizontalPadding * 2), 
                                   height: availableHeight - CameraLayoutConfig.bottomOffset)
                            .clipShape(RoundedRectangle(cornerRadius: CameraLayoutConfig.cornerRadius))
                            .offset(y: CameraLayoutConfig.verticalOffset)
                            .position(x: geometry.size.width/2, y: geometry.size.height/2)
                    }
                    
                    // 添加缩放提示
                    if showScaleIndicator {
                        ScaleIndicatorView(scale: currentIndicatorScale)
                            .position(x: geometry.size.width/2, y: geometry.size.height/2)
                            .animation(.easeInOut(duration: 0.2), value: currentIndicatorScale)
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
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                containerSelected.toggle()
                
                if containerSelected {
                    // 保存当前亮度并设置为最大
                    previousBrightness = UIScreen.main.brightness
                    UIScreen.main.brightness = 1.0
                    print("主页面中 - 提高亮度至最大")
                    print("原始亮度：\(previousBrightness)")
                    // 触发震动反馈
                    feedbackGenerator.impactOccurred(intensity: 1.0)
                    isLighted = true
                } else {
                    // 恢复原始亮度
                    UIScreen.main.brightness = previousBrightness
                    print("主页面取消选中 - 恢复原始亮度：\(previousBrightness)")
                    isLighted = false
                }
            }
            print("主页面选中状态：\(containerSelected)")
            print("屏幕点亮状态：\(isLighted)")
        }
        .onAppear {
            setupVideoProcessing()
            // 预准备震动反馈
            feedbackGenerator.prepare()
        }
        .onDisappear {
            // 确保在视图消失前恢复原始亮度
            if containerSelected {
                UIScreen.main.brightness = previousBrightness
                print("主页面视图消失 - 恢复原始亮度：\(previousBrightness)")
            }
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

// 添加主页面专用的视图处理器
class MainVideoProcessor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    var imageHandler: ((UIImage) -> Void)?
    let context = CIContext()
    var isMirrored: Bool = false
    private var previousOrientation: UIDeviceOrientation = .unknown
    private var previousMirrorState: Bool = false
    private var lastLogTime: Date = Date()
    private let logInterval: TimeInterval = 1.0
    private var currentMode: CameraMode = .modeB
    
    enum CameraMode {
        case modeA
        case modeB
    }
    
    // 添加设置模式的方法
    func setMode(_ mode: CameraMode) {
        let previousMode = currentMode
        currentMode = mode
        
        // 记录模式变化
        if previousMode != currentMode {
            let currentTime = Date()
            if currentTime.timeIntervalSince(lastLogTime) >= logInterval {
                print("------------------------")
                print("模式切换")
                print("当前模式：\(currentMode == .modeA ? "模式A" : "模式B")")
                print("------------------------")
                lastLogTime = currentTime
            }
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        connection.videoOrientation = .portrait
        connection.isVideoMirrored = false  // 确保连接不自动镜像
        
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        var processedImage = ciImage
        let deviceOrientation = UIDevice.current.orientation
        let currentTime = Date()
        
        // 设备方向变化日志
        if deviceOrientation != previousOrientation && 
           currentTime.timeIntervalSince(lastLogTime) >= logInterval {
            print("------------------------")
            print("设备方向变化")
            print("当前模式：\(currentMode == .modeA ? "模式A" : "模式B")")
            switch deviceOrientation {
            case .portrait:
                print("方向：竖屏(1)")
            case .portraitUpsideDown:
                print("方向：倒置竖屏(2)")
            case .landscapeRight:
                print("方向：向右横屏(3)")
            case .landscapeLeft:
                print("方向：向左横屏(4)")
            default:
                print("方向：其他")
            }
            print("------------------------")
            previousOrientation = deviceOrientation
            lastLogTime = currentTime
        }
        
        // 根据当前模式处理图像
        switch currentMode {
        case .modeA:
            // 模式A：应用水平翻转（镜像效果）
            processedImage = processedImage.transformed(by: CGAffineTransform(scaleX: -1, y: 1))
            
        case .modeB:
            // 模式B：在设备方向为3或4时进行180度旋转
            if deviceOrientation == .landscapeLeft || deviceOrientation == .landscapeRight {
                let rotationTransform = CGAffineTransform(translationX: ciImage.extent.width, y: ciImage.extent.height)
                    .rotated(by: .pi)
                processedImage = processedImage.transformed(by: rotationTransform)
            }
        }
        
        if let cgImage = context.createCGImage(processedImage, from: processedImage.extent) {
            let uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
            DispatchQueue.main.async {
                self.imageHandler?(uiImage)
            }
        }
    }
}

// 修改统一启动提示视图
struct RestartCameraView: View {
    let action: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("摄像头已关闭")
                        .foregroundColor(.white)
                        .font(.title2)
                    
                    Image(systemName: "camera.circle")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                }
                .position(x: geometry.size.width/2, y: geometry.size.height/2)  // 使用绝对定位确保居中
            }
            .onTapGesture {
                action()
            }
        }
    }
}

// 修改背景遮罩视图
struct BackgroundMaskView: View {
    let isSelected: Bool
    let isLighted: Bool
    
    var body: some View {
        GeometryReader { geometry in
            let availableHeight = geometry.size.height
            
            ZStack {
                // 修改背景遮罩颜色逻辑
                Color.white.opacity(0.0)
                    .edgesIgnoringSafeArea(.all)
                
                Path { path in
                    path.addRect(CGRect(x: 0, y: 0, width: geometry.size.width, height: geometry.size.height))
                    
                    let holeWidth = geometry.size.width - (CameraLayoutConfig.horizontalPadding * 2)
                    let holeHeight = availableHeight - CameraLayoutConfig.bottomOffset
                    let holeX = CameraLayoutConfig.horizontalPadding
                    let holeY = (availableHeight - holeHeight) / 2 + CameraLayoutConfig.verticalOffset
                    
                    let bezierPath = UIBezierPath(roundedRect: CGRect(x: holeX,
                                                                     y: holeY,
                                                                     width: holeWidth,
                                                                     height: holeHeight),
                                                cornerRadius: CameraLayoutConfig.cornerRadius)
                    path.addPath(Path(bezierPath.cgPath))
                }
                .fill(style: FillStyle(eoFill: true))
                // 修改遮罩颜色：根据 isLighted 状态改变
                .foregroundColor(isLighted ? Color.white.opacity(1.0) : Color.black.opacity(1.0))
                
                // 保留黄色矩形但设置为隐藏
                Rectangle()
                    .fill(.yellow.opacity(0.0)) // 将透明度设置为0来隐藏
                    .frame(width: geometry.size.width - (CameraLayoutConfig.horizontalPadding * 2),
                           height: availableHeight - CameraLayoutConfig.bottomOffset)
                    .clipShape(RoundedRectangle(cornerRadius: CameraLayoutConfig.cornerRadius))
                    .offset(y: CameraLayoutConfig.verticalOffset)
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
}

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @State private var showingTwoOfMe = false
    @State private var isCameraActive = true
    @State private var showRestartHint = false
    @State private var deviceOrientation = UIDevice.current.orientation
    @State private var ModeASelected = false
    @State private var previousBrightness: CGFloat = UIScreen.main.brightness
    @State private var ModeBSelected = false
    @State private var isLighted = false
    
    // 添加放缩相关的状态变量
    @State private var currentScale: CGFloat = 1.0
    @State private var baseScale: CGFloat = 1.0
    @State private var showScaleLimitMessage = false
    @State private var scaleLimitMessage = ""
    @State private var showScaleIndicator = false
    @State private var currentIndicatorScale: CGFloat = 1.0
    
    // 添加放缩限制常量
    private let minScale: CGFloat = 1.0     // 最小100%
    private let maxScale: CGFloat = 10.0    // 最大1000%
    
    // 添加震动反馈生成器
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
    
    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height
            let buttonSpacing: CGFloat = 40
            
            ZStack {
                if cameraManager.permissionGranted {
                    if cameraManager.isMirrored {
                        // 模式A视图
                        GeometryReader { geometry in
                            CameraContainer(
                                session: cameraManager.session,
                                isMirrored: cameraManager.isMirrored,
                                isActive: isCameraActive,
                                deviceOrientation: deviceOrientation,
                                restartAction: restartCamera,
                                cameraManager: cameraManager,
                                isSelected: ModeASelected,
                                isLighted: $isLighted,
                                currentScale: $currentScale,
                                showScaleIndicator: $showScaleIndicator,
                                currentIndicatorScale: $currentIndicatorScale,
                                onPinchChanged: handlePinchGesture,
                                onPinchEnded: handlePinchEnd
                            )
                        }
                    } else {
                        // 模式B视图
                        GeometryReader { geometry in
                            CameraContainer(
                                session: cameraManager.session,
                                isMirrored: cameraManager.isMirrored,
                                isActive: isCameraActive,
                                deviceOrientation: deviceOrientation,
                                restartAction: restartCamera,
                                cameraManager: cameraManager,
                                isSelected: ModeBSelected,
                                isLighted: $isLighted,
                                currentScale: $currentScale,
                                showScaleIndicator: $showScaleIndicator,
                                currentIndicatorScale: $currentIndicatorScale,
                                onPinchChanged: handlePinchGesture,
                                onPinchEnded: handlePinchEnd
                            )
                        }
                    }
                    
                    // 更新背景遮罩视图，确保正确传递选中状态
                    BackgroundMaskView(isSelected: cameraManager.isMirrored ? ModeASelected : ModeBSelected, isLighted: isLighted)
                        .allowsHitTesting(false)
                        .onChange(of: ModeASelected) { _ in
                            // 添加调试日志
                            print("遮罩状态更新 - 模式A选中状态：\(ModeASelected)")
                        }
                        .onChange(of: ModeBSelected) { _ in
                            // 添加调试日志
                            print("遮罩状态更新 - 模式B选中状态：\(ModeBSelected)")
                        }
                    
                    // 菱形按钮布局
                    ZStack {
                        // 添加透明容器
                        Rectangle()
                            .fill(Color.clear)  // 完全透明
                            .frame(width: buttonSpacing * 3, height: 60)  // 修改容器尺寸以适应三个按钮
                            .overlay(
                                HStack(spacing: buttonSpacing) {  // 使用 HStack 水平排列按钮
                                    // 左按钮 - 模式A
                                    CircleButton(
                                        systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right",
                                        title: "",
                                        action: {
                                            // 切换到模式A前确保恢复亮度
                                            if ModeBSelected {
                                                UIScreen.main.brightness = previousBrightness
                                                print("切换到模式A - 恢复原始亮度：\(previousBrightness)")
                                                ModeBSelected = false
                                            }
                                            
                                            // 设置为模式A
                                            if let processor = cameraManager.videoOutputDelegate as? MainVideoProcessor {
                                                processor.setMode(.modeA)
                                            }
                                            cameraManager.isMirrored = true
                                            
                                            // 打印区域信息
                                            print("------------------------")
                                            print("切换到模式A")
                                            print("显示区域信息：")
                                            let mirrorWidth = geometry.size.width - 40
                                            let mirrorHeight = geometry.size.height - 200
                                            print("宽度：\(mirrorWidth)pt")
                                            print("高度：\(mirrorHeight)pt")
                                            print("左边距：20pt")
                                            print("右边距：20pt")
                                            print("上边距：100pt")
                                            print("下边距：100pt")
                                            print("圆角：20pt")
                                            print("当前缩放比例：\(Int(currentScale * 100))%")
                                            print("------------------------")
                                            print("容器信息：")
                                            print("容器尺寸：width=\(geometry.size.width), height=\(geometry.size.height)")
                                            print("------------------------")
                                        },
                                        deviceOrientation: deviceOrientation
                                    )
                                    
                                    // 中间按钮 - Two of Me
                                    CircleButton(
                                        systemName: "rectangle.split.2x1",
                                        title: "",
                                        action: {
                                            // 在进入 Two of Me 模式前，确保恢复原始亮度
                                            if cameraManager.isMirrored {
                                                if ModeASelected {
                                                    UIScreen.main.brightness = previousBrightness
                                                    print("进入 Two of Me 前 - 模式A恢复原始亮度：\(previousBrightness)")
                                                    ModeASelected = false
                                                }
                                            } else {
                                                if ModeBSelected {
                                                    UIScreen.main.brightness = previousBrightness
                                                    print("进入 Two of Me 前 - 模式B恢复原始亮度：\(previousBrightness)")
                                                    ModeBSelected = false
                                                }
                                            }
                                            
                                            // 确保在显示 TwoOfMe 页面前恢复原始亮度
                                            UIScreen.main.brightness = previousBrightness
                                            print("进入 Two of Me 前 - 强制恢复原始亮度：\(previousBrightness)")
                                            
                                            print("进入 Two of Me 模式")
                                            showingTwoOfMe = true
                                        },
                                        deviceOrientation: deviceOrientation
                                    )
                                    
                                    // 右按钮 - 模式B
                                    CircleButton(
                                        systemName: "camera",
                                        title: "",
                                        action: {
                                            // 切换到模式B前确保恢复亮度
                                            if ModeASelected {
                                                UIScreen.main.brightness = previousBrightness
                                                print("切换到模式B - 恢复原始亮度：\(previousBrightness)")
                                                ModeASelected = false
                                            }
                                            
                                            // 设置为模式B
                                            if let processor = cameraManager.videoOutputDelegate as? MainVideoProcessor {
                                                processor.setMode(.modeB)
                                            }
                                            cameraManager.isMirrored = false
                                            
                                            // 打印区域信息
                                            print("------------------------")
                                            print("切换到模式B")
                                            print("显示区域信息：")
                                            let normalWidth = geometry.size.width - 40
                                            let normalHeight = geometry.size.height - 200
                                            print("宽度：\(normalWidth)pt")
                                            print("高度：\(normalHeight)pt")
                                            print("左边距：20pt")
                                            print("右边距：20pt")
                                            print("上边距：100pt")
                                            print("下边距：100pt")
                                            print("圆角：20pt")
                                            print("当前缩放比例：\(Int(currentScale * 100))%")
                                            print("------------------------")
                                            print("容器信息：")
                                            print("容器尺寸：width=\(geometry.size.width), height=\(geometry.size.height)")
                                            print("------------------------")
                                        },
                                        deviceOrientation: deviceOrientation
                                    )
                                }
                            )
                    }
                    .position(x: screenWidth/2, y: screenHeight - 100)  // 调整位置到屏幕底部
                    .zIndex(2) // 确保按钮在最上层
                } else {
                    // 权限请求视图
                    ZStack {
                        Color.black.edgesIgnoringSafeArea(.all)
                        
                        VStack {
                            Image(systemName: "camera.fill")
                                .foregroundColor(.white)
                                .font(.largeTitle)
                            Text("使用此APP需要您开启相机权限")
                                .foregroundColor(.white)
                                .padding()
                            Button(action: {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                Text("授权相机")
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.yellow)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                NotificationCenter.default.addObserver(
                    forName: UIDevice.orientationDidChangeNotification,
                    object: nil,
                    queue: .main) { _ in
                        let newOrientation = UIDevice.current.orientation
                        deviceOrientation = newOrientation
                        print("设备方向化：\(newOrientation.rawValue)")
                        
                        if !cameraManager.isMirrored && newOrientation == .landscapeLeft {
                            print("正常模式下向左横屏，旋转摄像头画面180度")
                        }
                    }
                
                UIDevice.current.beginGeneratingDeviceOrientationNotifications()
                
                print("主页面加载")
                print("屏幕尺寸：width=\(screenWidth), height=\(screenHeight)")
                print("------------------------")
                cameraManager.checkPermission()
                
                // 添加应用程序生命周期通知监听
                NotificationCenter.default.addObserver(
                    forName: UIApplication.willResignActiveNotification,
                    object: nil,
                    queue: .main) { _ in
                        print("应用进后台")
                        handleAppBackground()
                    }
                
                NotificationCenter.default.addObserver(
                    forName: UIApplication.didBecomeActiveNotification,
                    object: nil,
                    queue: .main) { _ in
                        print("应用回到前台")
                        handleAppForeground()
                    }
                
                // 预准备震动反馈
                feedbackGenerator.prepare()
            }
            .onDisappear {
                UIDevice.current.endGeneratingDeviceOrientationNotifications()
                NotificationCenter.default.removeObserver(self)
                
                print("主页面退出")
                print("------------------------")
                
                // 移除应用程序生命周期通知监听
                NotificationCenter.default.removeObserver(self, 
                    name: UIApplication.willResignActiveNotification, 
                    object: nil)
                NotificationCenter.default.removeObserver(self, 
                    name: UIApplication.didBecomeActiveNotification, 
                    object: nil)
            }
            // 添加应用程序生命周期通知监听
            .onChange(of: UIApplication.shared.applicationState) { newState in
                if newState == .active {
                    // 应用回到前台时，检查是否需要恢复最大亮度
                    if cameraManager.isMirrored {
                        if ModeASelected {
                            UIScreen.main.brightness = 1.0
                            print("应用回到前台 - 镜像模式恢复最大亮度")
                        }
                    } else {
                        if ModeBSelected {
                            UIScreen.main.brightness = 1.0
                            print("应用回到前台 - 正常模式恢复最大亮度")
                        }
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingTwoOfMe) {
            handleTwoOfMeDismiss()
        } content: {
            TwoOfMeScreens()
                .transition(.move(edge: .trailing))  // 从右边进入
        }
    }
    
    // 处理应用进入后台
    private func handleAppBackground() {
        if cameraManager.permissionGranted {
            cameraManager.safelyStopSession()
            isCameraActive = false
            print("相机会话已停止")
        }
    }
    
    // 处理应用回到前台
    private func handleAppForeground() {
        // 不需要在这里重新检查权限，因为CameraManager会自动处理
        if !isCameraActive && cameraManager.permissionGranted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.restartCamera()
            }
        } else if !cameraManager.permissionGranted {
            print("相机权限未授权，显示权限请求界面")
            isCameraActive = false
            showRestartHint = false
        } else {
            print("显示重启相机提示")
            showRestartHint = true
        }
    }
    
    private func handleTwoOfMeDismiss() {
        if cameraManager.permissionGranted {
            cameraManager.safelyStopSession()
            cameraManager.isMirrored = false
            isCameraActive = false
            showRestartHint = true
        }
    }
    
    private func restartCamera() {
        if !cameraManager.permissionGranted {
            print("无相机权限，无法重启相机")
            return
        }
        
        print("重启相机会话")
        DispatchQueue.global(qos: .userInitiated).async {
            self.cameraManager.session.startRunning()
            DispatchQueue.main.async {
                self.isCameraActive = true
                self.showRestartHint = false
                print("相机会话已重启")
            }
        }
    }
    
    // 添加放缩处理函数
    private func handlePinchGesture(scale: CGFloat) {
        let newScale = baseScale * scale
        
        if newScale >= maxScale && scale > 1.0 {
            currentScale = maxScale
            if !showScaleLimitMessage {
                print("------------------------")
                print("已放大至最大尺寸")
                print("------------------------")
                showScaleLimitMessage = true
                scaleLimitMessage = "已放大至最大尺寸"
            }
        } else if newScale <= minScale && scale < 1.0 {
            currentScale = minScale
            if !showScaleLimitMessage {
                print("------------------------")
                print("已缩小至最小尺寸")
                print("------------------------")
                showScaleLimitMessage = true
                scaleLimitMessage = "已缩小至最小尺寸"
            }
        } else {
            currentScale = min(max(newScale, minScale), maxScale)
            showScaleLimitMessage = false
            
            // 更新缩放提示
            currentIndicatorScale = currentScale
            showScaleIndicator = true
            
            // 打印日志
            let currentPercentage = Int(currentScale * 100)
            print("------------------------")
            print("双指缩放")
            print("当前比例：\(currentPercentage)%")
            print("------------------------")
        }
    }
    
    private func handlePinchEnd(scale: CGFloat) {
        baseScale = currentScale
        showScaleLimitMessage = false
        
        // 延迟隐藏缩放提示
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showScaleIndicator = false
        }
        
        print("------------------------")
        print("双指手势结束")
        print("最终画面比例：\(Int(baseScale * 100))%")
        print("------------------------")
    }
}

#Preview {
    ContentView()
}
