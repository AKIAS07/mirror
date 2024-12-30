//
//  ContentView.swift
//  Mirror
//
//  Created by 林喵 on 2024/12/16.
//

import SwiftUI
import AVFoundation

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
    
    var body: some View {
        Button(action: action) {
            if systemName.isEmpty {
                // 只显示文字，用于焦距按钮
                Text(title)
                    .font(.system(size: 20, weight: .bold))  // 调整文字大小和粗细
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            } else {
                // 显示图标，用于其他按钮
                Image(systemName: systemName)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
        }
    }
}

// 添加一个观察者类来处理 KVO
class CameraObserver: NSObject {
    let processor: MainVideoProcessor
    private var lastLogTime: Date = Date()
    private let logInterval: TimeInterval = 1.0
    private var previousMirrorState: Bool = false  // 添加踪
    
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
            }
            
            // 更新处理器状态，但不输出日志
            processor.isMirrored = connection.isVideoMirrored
        }
    }
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
    @State private var containerSelected: Bool  // 重命名为 containerSelected
    
    let cameraManager: CameraManager
    
    // 添加震动反馈生成器
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
    
    init(session: AVCaptureSession, isMirrored: Bool, isActive: Bool, deviceOrientation: UIDeviceOrientation, restartAction: @escaping () -> Void, cameraManager: CameraManager, isSelected: Bool) {
        self.session = session
        self.isMirrored = isMirrored
        self.isActive = isActive
        self.deviceOrientation = deviceOrientation
        self.restartAction = restartAction
        self.cameraManager = cameraManager
        _containerSelected = State(initialValue: isSelected)  // 使用重命名后的属性
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if isActive {
                    // 画面
                    if let image = processedImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .ignoresSafeArea()
                    }
                    
                    // 修改边框视图布局
                    GeometryReader { borderGeometry in
                        Rectangle()
                            .stroke(containerSelected ? BorderStyle.selectedColor : BorderStyle.normalColor,
                                   lineWidth: containerSelected ? BorderStyle.selectedWidth : BorderStyle.normalWidth)
                            .frame(
                                width: UIScreen.main.bounds.width,
                                height: UIScreen.main.bounds.height
                            )
                            .position(
                                x: UIScreen.main.bounds.width/2,
                                y: UIScreen.main.bounds.height/2
                            )
                            .ignoresSafeArea()
                            .onAppear {
                                print("------------------------")
                                print("边框容器信息：")
                                print("边框尺寸：width=\(UIScreen.main.bounds.width), height=\(UIScreen.main.bounds.height)")
                                print("边框坐标：x=\(borderGeometry.frame(in: .global).origin.x), y=\(borderGeometry.frame(in: .global).origin.y)")
                                print("屏幕尺寸：width=\(UIScreen.main.bounds.width), height=\(UIScreen.main.bounds.height)")
                                print("------------------------")
                            }
                    }
                } else {
                    RestartCameraView(action: restartAction)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            print("------------------------")
                            print("ZStack 容器信息：")
                            print("ZStack 尺寸：width=\(proxy.size.width), height=\(proxy.size.height)")
                            print("ZStack 坐标：x=\(proxy.frame(in: .global).origin.x), y=\(proxy.frame(in: .global).origin.y)")
                            print("------------------------")
                        }
                }
            )
            .onAppear {
                print("容器尺寸：width=\(geometry.size.width), height=\(geometry.size.height)")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                containerSelected.toggle()  // 使用 containerSelected
                
                if containerSelected {  // 使用 containerSelected
                    // 保存当前亮度并设置为最大
                    previousBrightness = UIScreen.main.brightness
                    UIScreen.main.brightness = 1.0
                    print("主页面中 - 提高亮度至最大")
                    print("原始亮度：\(previousBrightness)")
                    // 触发震动反馈
                    feedbackGenerator.impactOccurred(intensity: 1.0)
                } else {
                    // 恢复原始亮度
                    UIScreen.main.brightness = previousBrightness
                    print("主页面取消选中 - 恢复原始亮度：\(previousBrightness)")
                }
            }
            print("主页面选中状态：\(containerSelected)")  // 使用 containerSelected
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
    
    private func getRotationAngle() -> Angle {
        if !isMirrored && deviceOrientation == .landscapeLeft {
            return .degrees(180)
        }
        return .degrees(0)
    }
    
    // 修改视频处理设置
    private func setupVideoProcessing() {
        let processor = MainVideoProcessor()
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
    private var lastLogTime: Date = Date()  // 添加时间控制
    private let logInterval: TimeInterval = 1.0  // 日志输出最小间隔（秒）
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        connection.videoOrientation = .portrait
        connection.isVideoMirrored = false
        
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        var processedImage = ciImage
        let deviceOrientation = UIDevice.current.orientation
        let currentTime = Date()
        
        // 只在状态变化且超过最小间隔输出日志
        if isMirrored != previousMirrorState && 
           currentTime.timeIntervalSince(lastLogTime) >= logInterval {
            print("镜像状态：\(isMirrored ? "开启" : "关闭")")
            previousMirrorState = isMirrored
            lastLogTime = currentTime
        }
        
        if isMirrored {
            processedImage = processedImage.transformed(by: CGAffineTransform(scaleX: -1, y: 1))
        }
        
        // 只在设备向改变且为横屏时输出日志
        if !isMirrored && (deviceOrientation == .landscapeLeft || deviceOrientation == .landscapeRight) {
            if deviceOrientation != previousOrientation && 
               currentTime.timeIntervalSince(lastLogTime) >= logInterval {
                print("设备方向\(deviceOrientation == .landscapeLeft ? "向左横屏" : "向右横屏")")
                print("摄像头画面旋转180度")
                previousOrientation = deviceOrientation
                lastLogTime = currentTime
            }
            
            let rotationTransform = CGAffineTransform(translationX: ciImage.extent.width, y: ciImage.extent.height)
                .rotated(by: .pi)
            processedImage = processedImage.transformed(by: rotationTransform)
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

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @State private var showingTwoOfMe = false
    @State private var isCameraActive = true
    @State private var showRestartHint = false
    @State private var deviceOrientation = UIDevice.current.orientation
    @State private var currentZoomLevel = 1
    @State private var isSelected = false
    @State private var previousBrightness: CGFloat = UIScreen.main.brightness
    @State private var normalModeSelected = false
    
    // 焦距选项
    private let zoomLevels = [1, 2, 4]
    
    // 添加震动反馈生成器
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
    
    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height
            let buttonSpacing: CGFloat = 80
            
            ZStack {
                if cameraManager.permissionGranted {
                    if cameraManager.isMirrored {
                        // 镜像模式图
                        GeometryReader { geometry in
                            if isCameraActive {  // 添加条件判断
                                ZStack {
                                    CameraView(session: $cameraManager.session, isMirrored: $cameraManager.isMirrored)
                                        .ignoresSafeArea()
                                        .onAppear {
                                            print("------------------------")
                                            print("镜像模式容器信息：")
                                            print("容器尺寸：width=\(geometry.size.width), height=\(geometry.size.height)")
                                            print("容器坐标：x=\(geometry.frame(in: .global).origin.x), y=\(geometry.frame(in: .global).origin.y)")
                                            print("屏幕尺寸：width=\(UIScreen.main.bounds.width), height=\(UIScreen.main.bounds.height)")
                                            print("安全区域：\(geometry.safeAreaInsets)")
                                            print("------------------------")
                                        }
                                    
                                    Rectangle()
                                        .stroke(isSelected ? BorderStyle.selectedColor : BorderStyle.normalColor, 
                                               lineWidth: isSelected ? BorderStyle.selectedWidth : BorderStyle.normalWidth)
                                        .ignoresSafeArea()
                                }
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isSelected.toggle()
                                        
                                        if isSelected {
                                            previousBrightness = UIScreen.main.brightness
                                            UIScreen.main.brightness = 1.0
                                            print("镜像模式选中 - 提高亮度至最大")
                                            print("原始亮度：\(previousBrightness)")
                                            feedbackGenerator.impactOccurred(intensity: 1.0)
                                        } else {
                                            UIScreen.main.brightness = previousBrightness
                                            print("镜像模式取消选中 - 恢复原始亮度：\(previousBrightness)")
                                        }
                                    }
                                    print("镜像模式选中状态：\(isSelected)")
                                }
                                .onDisappear {
                                    // 在切换模式前恢复原始亮度
                                    if isSelected {
                                        UIScreen.main.brightness = previousBrightness
                                        print("镜像模式切换到正常模式 - 恢复原始亮度：\(previousBrightness)")
                                    }
                                    isSelected = false  // 重置选中状态
                                }
                                .onAppear {
                                    // 如果是选中状态，恢复最大亮度
                                    if isSelected {
                                        UIScreen.main.brightness = 1.0
                                        print("镜像模式恢复 - 提高亮度至最大")
                                    }
                                }
                            } else {
                                RestartCameraView(action: restartCamera)
                            }
                        }
                    } else {
                        // 正常模式视图
                        GeometryReader { geometry in
                            CameraContainer(
                                session: cameraManager.session,
                                isMirrored: cameraManager.isMirrored,
                                isActive: isCameraActive,
                                deviceOrientation: deviceOrientation,
                                restartAction: restartCamera,
                                cameraManager: cameraManager,
                                isSelected: normalModeSelected
                            )
                            .onAppear {
                                print("------------------------")
                                print("正常模式容器信息：")
                                print("容器尺寸：width=\(geometry.size.width), height=\(geometry.size.height)")
                                print("器坐标：x=\(geometry.frame(in: .global).origin.x), y=\(geometry.frame(in: .global).origin.y)")
                                print("屏幕尺寸：width=\(UIScreen.main.bounds.width), height=\(UIScreen.main.bounds.height)")
                                print("安全区域：\(geometry.safeAreaInsets)")
                                print("------------------------")
                                isSelected = normalModeSelected
                                // 如果是选中状态，设置最大亮度
                                if normalModeSelected {
                                    previousBrightness = UIScreen.main.brightness
                                    UIScreen.main.brightness = 1.0
                                    print("正常模式恢复 - 提高亮度至最大")
                                }
                                // 如果是选中状态，恢复最大亮度
                                if normalModeSelected {
                                    UIScreen.main.brightness = 1.0
                                    print("正常模式恢复 - 提高亮度至最大")
                                }
                            }
                            .onDisappear {
                                // 在切换模式前恢复原始亮度
                                if normalModeSelected {
                                    UIScreen.main.brightness = previousBrightness
                                    print("正常模式切换到像模式 - 恢复原始亮度：\(previousBrightness)")
                                }
                                normalModeSelected = false  // 重置选中状态
                            }
                        }
                    }
                    
                    // 菱形按钮布局
                    ZStack {
                        // 添加透明容器
                        Rectangle()
                            .fill(Color.clear)  // 完全透明
                            .frame(width: buttonSpacing * 2, height: buttonSpacing * 2)  // 使用按钮间距创建正方形区域
                            .overlay(
                                ZStack {
                                    // 上按钮（焦距调整）
                                    CircleButton(
                                        systemName: "",
                                        title: "\(currentZoomLevel)x",
                                        action: {
                                            adjustZoom()
                                            print("调整焦距：\(currentZoomLevel)x")
                                        }
                                    )
                                    .offset(y: -buttonSpacing)
                                    
                                    HStack(spacing: buttonSpacing) {
                                        // 左按钮 - 镜模式
                                        CircleButton(
                                            systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right",
                                            title: "",
                                            action: {
                                                // 切换到镜像模式前确保恢复亮度
                                                if normalModeSelected {
                                                    UIScreen.main.brightness = previousBrightness
                                                    print("切换到镜像模式 - 恢复原始亮度：\(previousBrightness)")
                                                    normalModeSelected = false
                                                }
                                                print("切换到镜像模式")
                                                cameraManager.isMirrored = true
                                            }
                                        )
                                        
                                        // 右按钮 - 正常模式
                                        CircleButton(
                                            systemName: "camera",
                                            title: "",
                                            action: {
                                                // 切换到正常模式前确保恢复亮度
                                                if isSelected {
                                                    UIScreen.main.brightness = previousBrightness
                                                    print("切换到正常模式 - 恢复原始亮度：\(previousBrightness)")
                                                    isSelected = false
                                                }
                                                print("切换到正常模式")
                                                cameraManager.isMirrored = false
                                            }
                                        )
                                    }
                                    
                                    // 中间钮
                                    CircleButton(
                                        systemName: "rectangle.split.2x1",
                                        title: "",
                                        action: {
                                            // 在进入 Two of Me 模式前，确保恢复原始亮度
                                            if cameraManager.isMirrored {
                                                if isSelected {
                                                    UIScreen.main.brightness = previousBrightness
                                                    print("进入 Two of Me 前 - 镜像模式恢复原始亮度：\(previousBrightness)")
                                                    isSelected = false
                                                }
                                            } else {
                                                if normalModeSelected {
                                                    UIScreen.main.brightness = previousBrightness
                                                    print("进入 Two of Me 前 - 正常模式恢复原始亮度：\(previousBrightness)")
                                                    normalModeSelected = false
                                                }
                                            }
                                            
                                            // 确保在显示 TwoOfMe 页面前恢复原始亮度
                                            UIScreen.main.brightness = previousBrightness
                                            print("进入 Two of Me 前 - 强制恢复原始亮度：\(previousBrightness)")
                                            
                                            print("进入 Two of Me 模式")
                                            showingTwoOfMe = true
                                        }
                                    )
                                    .offset(y: buttonSpacing)
                                }
                            )
                            .rotationEffect(getButtonsRotationAngle())  // 添加旋转效果
                    }
                    .position(x: screenWidth/2, y: screenHeight - 150)
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
                        if isSelected {
                            UIScreen.main.brightness = 1.0
                            print("应用回到前台 - 镜像模式恢复最大亮度")
                        }
                    } else {
                        if normalModeSelected {
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
                // 重置焦距为1x
                self.currentZoomLevel = 1
                self.cameraManager.setZoom(level: CGFloat(1))
                print("相机会话已重启")
                print("焦距已重置为1x")
            }
        }
    }
    
    // 调整焦距的函数
    private func adjustZoom() {
        // 获取当前焦距在数组中的索引
        if let currentIndex = zoomLevels.firstIndex(of: currentZoomLevel) {
            // 计算下一个焦距的索引（循环）
            let nextIndex = (currentIndex + 1) % zoomLevels.count
            // 更新焦距
            currentZoomLevel = zoomLevels[nextIndex]
            // 设置相机焦距（转换为 CGFloat）
            cameraManager.setZoom(level: CGFloat(currentZoomLevel))
        }
    }
    
    // 添加获取按钮旋转角度的函数
    private func getButtonsRotationAngle() -> Angle {
        switch deviceOrientation {
        case .landscapeLeft:
            return .degrees(90)
        case .landscapeRight:
            return .degrees(-90)
        default:
            return .degrees(0)
        }
    }
}

#Preview {
    ContentView()
}
