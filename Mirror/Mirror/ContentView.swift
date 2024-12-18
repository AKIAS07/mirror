//
//  ContentView.swift
//  Mirror
//
//  Created by 林喵 on 2024/12/16.
//

import SwiftUI
import AVFoundation

struct CircleButton: View {
    let systemName: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemName)
                    .font(.system(size: 24))
                Text(title)
                    .font(.system(size: 12))
            }
            .foregroundColor(.white)
            .frame(width: 60, height: 60)
            .background(Color.black.opacity(0.5))
            .clipShape(Circle())
        }
    }
}

// 添加一个观察者类来处理 KVO
class CameraObserver: NSObject {
    let processor: MainVideoProcessor
    private var lastLogTime: Date = Date()
    private let logInterval: TimeInterval = 1.0
    private var previousMirrorState: Bool = false  // 添加状态追踪
    
    init(processor: MainVideoProcessor) {
        self.processor = processor
        super.init()
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "videoMirrored",
           let connection = object as? AVCaptureConnection {
            let currentTime = Date()
            
            // 只在状态真正发生变化且超过时间间隔时输出日志
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
    @State private var isSelected = false
    @State private var previousBrightness: CGFloat = UIScreen.main.brightness
    @State private var processedImage: UIImage?
    @State private var observer: CameraObserver?
    
    let cameraManager: CameraManager
    
    // 添加震动反馈生成器
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
    
    var body: some View {
        ZStack {
            if isActive {
                if let image = processedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .ignoresSafeArea()
                }
                
                // 修改边框样式
                Rectangle()
                    .stroke(isSelected ? Color.white : Color.green, 
                           lineWidth: isSelected ? 20 : 1)
                    .ignoresSafeArea()
                
                // 方向指示图标
                Image(systemName: "arrow.up.forward.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
                    .background(Circle().fill(Color.black.opacity(0.3)))
                    .scaleEffect(x: isMirrored ? -1 : 1, y: 1)
                    .rotationEffect(getRotationAngle())
                    .position(x: UIScreen.main.bounds.width/2, y: UIScreen.main.bounds.height/2)
            } else {
                // 黑色背景和重启提示
                Color.black
                    .ignoresSafeArea()
                    .overlay(
                        VStack(spacing: 20) {
                            Text("请点击屏幕重新开启摄像头")
                                .foregroundColor(.white)
                                .font(.title2)
                            
                            Image(systemName: "camera.circle")
                                .font(.system(size: 50))
                                .foregroundColor(.white)
                        }
                    )
                    .onTapGesture {
                        restartAction()
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isSelected.toggle()
                
                if isSelected {
                    // 保存当前亮度并设置为最大
                    previousBrightness = UIScreen.main.brightness
                    UIScreen.main.brightness = 1.0
                    print("主页面选中 - 提高亮度至最大")
                    print("原始亮度：\(previousBrightness)")
                    // 触发震动反馈
                    feedbackGenerator.impactOccurred(intensity: 1.0)
                } else {
                    // 恢复原始亮度
                    UIScreen.main.brightness = previousBrightness
                    print("主页面取消选中 - 恢复原始亮度：\(previousBrightness)")
                }
            }
            print("主页面选中状态：\(isSelected)")
        }
        .onAppear {
            setupVideoProcessing()
            // 预准备震动反馈
            feedbackGenerator.prepare()
        }
        .onDisappear {
            // 确保在视图消失时恢复原始亮度
            if isSelected {
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
        
        // 只在状态变化且超过最小间隔时输出日志
        if isMirrored != previousMirrorState && 
           currentTime.timeIntervalSince(lastLogTime) >= logInterval {
            print("镜像状态：\(isMirrored ? "开启" : "关闭")")
            previousMirrorState = isMirrored
            lastLogTime = currentTime
        }
        
        if isMirrored {
            processedImage = processedImage.transformed(by: CGAffineTransform(scaleX: -1, y: 1))
        }
        
        // 只在设备方向改变且为横屏时输出日志
        if !isMirrored && (deviceOrientation == .landscapeLeft || deviceOrientation == .landscapeRight) {
            if deviceOrientation != previousOrientation && 
               currentTime.timeIntervalSince(lastLogTime) >= logInterval {
                print("设备方向：\(deviceOrientation == .landscapeLeft ? "向左横屏" : "向右横屏")")
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

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @State private var showingTwoOfMe = false
    @State private var isCameraActive = true
    @State private var showRestartHint = false
    @State private var deviceOrientation = UIDevice.current.orientation
    @State private var currentZoomLevel = 1  // 添加焦距等级状态
    
    // 焦距选项
    private let zoomLevels = [1, 2, 4]
    
    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height
            let buttonSpacing: CGFloat = 80
            
            ZStack {
                if cameraManager.permissionGranted {
                    if cameraManager.isMirrored {
                        // 普通自拍摄像头视图
                        GeometryReader { geometry in
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
                                
                                // 将边框移到 ZStack 中，确保它覆盖在 CameraView 上面
                                Rectangle()
                                    .stroke(Color.green, lineWidth: 1)
                                    .ignoresSafeArea()
                            }
                        }
                    } else {
                        // 使用 VideoProcessor 的视图
                        GeometryReader { geometry in
                            CameraContainer(
                                session: cameraManager.session,
                                isMirrored: cameraManager.isMirrored,
                                isActive: isCameraActive,
                                deviceOrientation: deviceOrientation,
                                restartAction: restartCamera,
                                cameraManager: cameraManager
                            )
                            .onAppear {
                                print("------------------------")
                                print("正常模式容器信息：")
                                print("容器尺寸：width=\(geometry.size.width), height=\(geometry.size.height)")
                                print("容器坐标：x=\(geometry.frame(in: .global).origin.x), y=\(geometry.frame(in: .global).origin.y)")
                                print("屏幕尺寸：width=\(UIScreen.main.bounds.width), height=\(UIScreen.main.bounds.height)")
                                print("安全区域：\(geometry.safeAreaInsets)")
                                print("------------------------")
                            }
                        }
                    }
                    
                    // 菱形按钮布局
                    ZStack {
                        // 上按钮（焦距调整）
                        CircleButton(
                            systemName: "camera.circle.fill",
                            title: "\(currentZoomLevel)x",
                            action: {
                                adjustZoom()
                                print("调整焦距：\(currentZoomLevel)x")
                            }
                        )
                        .offset(y: -buttonSpacing)
                        
                        HStack(spacing: buttonSpacing) {
                            // 左按钮 - 镜像模式
                            CircleButton(
                                systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right",
                                title: "左",
                                action: {
                                    print("切换到镜像模式")
                                    cameraManager.isMirrored = true
                                }
                            )
                            
                            // 右按钮 - 正常模式
                            CircleButton(
                                systemName: "camera",
                                title: "右",
                                action: {
                                    print("切换到正常模式")
                                    cameraManager.isMirrored = false
                                }
                            )
                        }
                        
                        // 中间按钮
                        CircleButton(
                            systemName: "rectangle.split.2x1",
                            title: "中",
                            action: {
                                print("进入 Two of Me 模式")
                                showingTwoOfMe = true
                            }
                        )
                        .offset(y: buttonSpacing)
                    }
                    .position(x: screenWidth/2, y: screenHeight - 150)
                } else {
                    // 权限请求视图
                    VStack {
                        Image(systemName: "camera.fill")
                            .foregroundColor(.red)
                            .font(.largeTitle)
                        Text("需要相机权限")
                            .padding()
                        Button(action: {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Text("授权相机")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(8)
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
                        print("应用进入后台")
                        handleAppBackground()
                    }
                
                NotificationCenter.default.addObserver(
                    forName: UIApplication.didBecomeActiveNotification,
                    object: nil,
                    queue: .main) { _ in
                        print("应用回到前台")
                        handleAppForeground()
                    }
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
        }
        .fullScreenCover(isPresented: $showingTwoOfMe) {
            handleTwoOfMeDismiss()
        } content: {
            TwoOfMeScreens()
        }
    }
    
    // 处理应用进入后台
    private func handleAppBackground() {
        cameraManager.session.stopRunning()
        isCameraActive = false
        print("相机会话已停")
    }
    
    // 处理应用回到前台
    private func handleAppForeground() {
        print("显示重启相机提示")
        showRestartHint = true
    }
    
    private func handleTwoOfMeDismiss() {
        cameraManager.session.stopRunning()
        cameraManager.isMirrored = false
        isCameraActive = false
        showRestartHint = true
    }
    
    private func restartCamera() {
        print("重启相机会话")
        DispatchQueue.global(qos: .userInitiated).async {
            cameraManager.session.startRunning()
            DispatchQueue.main.async {
                isCameraActive = true
                showRestartHint = false
                print("相机会话已重启")
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
}

#Preview {
    ContentView()
}
