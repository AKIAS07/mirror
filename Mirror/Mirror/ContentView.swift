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
    static let selectedWidth: CGFloat = 40
}

// 添加动画配置常量
struct DragAnimationConfig {
    // 交互动画参数
    static let dragResponse: Double = 0.18
    static let dragDampingFraction: Double = 0.85
    static let dragBlendDuration: Double = 0.05
    
    // 结束动画参数
    static let endResponse: Double = 0.28
    static let endDampingFraction: Double = 0.82
    
    // 提示动画参数
    static let hintFadeDuration: Double = 0.2
    static let hintDisplayDuration: Double = 2.0
    
    // 拖拽阈值
    static let directionLockThreshold: CGFloat = 10.0
    static let dragThreshold: CGFloat = 20.0
}

// 添加箭头布局常量
struct ArrowLayoutConfig {
    static let arrowWidth: CGFloat = 50
    static let arrowHeight: CGFloat = 50
    static let arrowHalfWidth: CGFloat = arrowWidth / 2
    static let arrowPadding: CGFloat = 5  // 箭头到边缘的距离
}

struct CircleButton: View {
    let systemName: String
    let title: String
    let action: () -> Void
    let deviceOrientation: UIDeviceOrientation
    let isDisabled: Bool
    
    init(systemName: String, 
         title: String, 
         action: @escaping () -> Void, 
         deviceOrientation: UIDeviceOrientation,
         isDisabled: Bool = false) {
        self.systemName = systemName
        self.title = title
        self.action = action
        self.deviceOrientation = deviceOrientation
        self.isDisabled = isDisabled
    }
    
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
                    .foregroundColor(isDisabled ? .gray : .white)
                    .rotationEffect(getIconRotationAngle(deviceOrientation))
                    .frame(width: 60, height: 60)
                    .background(Color.black.opacity(isDisabled ? 0.3 : 0.5))
                    .clipShape(Circle())
            }
        }
        .disabled(isDisabled)
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
    static let horizontalPadding: CGFloat = 0  // 左右边距
    static let verticalPadding: CGFloat = 0   // 上下边距
    
    // 动态计算圆角半径
    static var cornerRadius: CGFloat {
        // 直接使用设备的物理圆角值
        return UIDevice.getCornerRadius()
    }
    
    // 所有视图使用相同的圆角值
    static var borderCornerRadius: CGFloat {
        return cornerRadius
    }
    
    static let bottomOffset: CGFloat = 0      // 底部偏移
    static let verticalOffset: CGFloat = 0    // 垂直偏移
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
    let previousBrightness: CGFloat
    @Binding var containerSelected: Bool
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
         previousBrightness: CGFloat,
         isSelected: Binding<Bool>,
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
        self.previousBrightness = previousBrightness
        _containerSelected = isSelected
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

// 添加提示状态枚举
enum DragHintState {
    case upAndRightLeft  // 显示上箭头和右箭头左箭头
    case downAndRightLeft  // 显示下箭头和右箭头左箭头
    case rightOnly   // 只显示右箭头
    case leftOnly    // 只显示左箭头
    case upOnly      // 只显示上箭头
    case downOnly    // 只显示下箭头
}

// 修改交互提示视图组件
struct DragHintView: View {
    let hintState: DragHintState
    
    var body: some View {
        HStack(spacing: 40) {
            switch hintState {
            case .upAndRightLeft:
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Image(systemName: "chevron.up")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
            case .downAndRightLeft:
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Image(systemName: "chevron.down")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
            case .rightOnly:
                Image(systemName: "chevron.right")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            case .leftOnly:
                Image(systemName: "chevron.left")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            case .upOnly:
                Image(systemName: "chevron.up")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            case .downOnly:
                Image(systemName: "chevron.down")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 15)
        .background(Color.black.opacity(0.7))
        .cornerRadius(15)
    }
}

struct DraggableArrow: View {
    let isExpanded: Bool
    let isLighted: Bool
    let screenWidth: CGFloat
    @Binding var isControlPanelVisible: Bool
    @Binding var showDragHint: Bool
    @Binding var dragHintState: DragHintState
    @Binding var dragOffset: CGFloat
    @Binding var dragVerticalOffset: CGFloat
    @Binding var containerOffset: CGFloat
    
    // 添加状态变量来跟踪拖拽方向
    @State private var dragDirection: DragDirection = .none
    // 添加状态变量来锁定方向判定
    @State private var isDirectionLocked = false
    @State private var lastDragTranslation: CGFloat = 0
    
    // 添加拖拽方向枚举
    private enum DragDirection {
        case none
        case vertical
        case horizontal
    }
    
    // 添加垂直拖动相关常量
    private let verticalDestination: CGFloat = 120.0  // 向上拖拽的目标位置
    private let verticalDragThreshold: CGFloat = 20.0  // 垂直拖拽的触发阈值
    
    // 处理垂直拖动
    private func handleVerticalDrag(value: DragGesture.Value) {
        if isControlPanelVisible {
            withAnimation(.interactiveSpring(
                response: DragAnimationConfig.dragResponse,
                dampingFraction: DragAnimationConfig.dragDampingFraction,
                blendDuration: DragAnimationConfig.dragBlendDuration
            )) {
                // 计算translation的增量
                let translationDelta = value.translation.height - lastDragTranslation
                
                // 更新位置 = 当前位置 + 增量
                dragVerticalOffset = min(0, max(-verticalDestination, dragVerticalOffset + translationDelta))
                
                // 根据拖拽方向来决定箭头方向，而不是根据位置
                if translationDelta < 0 {
                    // 向上拖动
                    dragHintState = .upOnly
                } else {
                    // 向下拖动
                    dragHintState = .downOnly
                }
                
                // 更新上一次的translation
                lastDragTranslation = value.translation.height
            }
            
            // 显示拖动提示（避免重复触发动画）
            if !showDragHint {
                withAnimation(.easeInOut(duration: DragAnimationConfig.hintFadeDuration)) {
                    showDragHint = true
                }
            }
        }
    }
    
    // 处理垂直拖动结束
    private func handleVerticalDragEnd(value: DragGesture.Value) {
        if isControlPanelVisible {
            let translation = value.translation.height
            let currentPosition = dragVerticalOffset
            let moveDistance = abs(translation)
            
            withAnimation(.spring(
                response: DragAnimationConfig.endResponse,
                dampingFraction: DragAnimationConfig.endDampingFraction
            )) {
                if moveDistance > DragAnimationConfig.dragThreshold {
                    // 移动距离超过阈值，根据移动方向决定最终位置
                    dragVerticalOffset = translation < 0 ? -verticalDestination : 0
                } else {
                    // 移动距离不足，回到最近的位置
                    dragVerticalOffset = currentPosition < -verticalDestination / 2 ? 
                        -verticalDestination : 0
                }
            }
        }
    }
    
    // 处理水平拖动
    private func handleHorizontalDrag(value: DragGesture.Value, velocity: CGFloat) {
        let translation = value.translation.width
        
        withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.8, blendDuration: 0.05)) {
            if isControlPanelVisible {
                // 容器当前显示，允许自由拖动
                dragOffset = translation
                containerOffset = translation
                dragHintState = translation > 0 ? .rightOnly : .leftOnly
            } else {
                // 容器当前隐藏，根据位置处理拖动
                if containerOffset < 0 {
                    // 从左侧隐藏状态拖动，使用相对于当前位置的偏移
                    dragOffset = -screenWidth + 60 + translation
                    containerOffset = -screenWidth + translation
                    dragHintState = .rightOnly
                } else {
                    // 从右侧隐藏状态拖动
                    dragOffset = max(0, min(screenWidth - 60, translation + screenWidth - 60))
                    containerOffset = max(0, min(screenWidth, translation + screenWidth))
                    dragHintState = .leftOnly
                }
            }
        }
    }
    
    // 处理水平拖动结束
    private func handleHorizontalDragEnd(value: DragGesture.Value) {
        let velocity = value.velocity.width
        let translation = value.translation.width
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if isControlPanelVisible {
                if abs(velocity) > 500 {  // 快速滑动
                    if velocity < 0 && translation < 0 {  // 向左滑动且位移为负
                        dragOffset = -(screenWidth - 60)
                        containerOffset = -screenWidth
                        isControlPanelVisible = false
                        print("快速向左滑动 - 隐藏到左侧")
                    } else if velocity > 0 && translation > 0 {  // 向右滑动且位移为正
                        dragOffset = screenWidth - 60
                        containerOffset = screenWidth
                        isControlPanelVisible = false
                        print("快速向右滑动 - 隐藏到右侧")
                    } else {
                        // 如果方向不一致，回到原位
                        dragOffset = 0
                        containerOffset = 0
                        print("方向不一致 - 回到中间")
                    }
                } else {  // 缓慢滑动
                    if abs(dragOffset) > screenWidth * 0.2 {  // 超过20%触发
                        if dragOffset < 0 {
                            dragOffset = -(screenWidth - 60)
                            containerOffset = -screenWidth
                            print("向左滑动足够 - 隐藏到左侧")
                        } else {
                            dragOffset = screenWidth - 60
                            containerOffset = screenWidth
                            print("向右滑动足够 - 隐藏到右侧")
                        }
                        isControlPanelVisible = false
                    } else {
                        dragOffset = 0
                        containerOffset = 0
                        print("滑动不足 - 回到中间")
                    }
                }
            } else {
                handleHiddenPanelDragEnd(value: value)
            }
        }
    }
    
    // 处理隐藏状态下的拖动结束
    private func handleHiddenPanelDragEnd(value: DragGesture.Value) {
        let velocity = value.velocity.width
        let translation = value.translation.width  // 使用实际的translation而不是dragOffset
        
        if containerOffset < 0 {  // 当前在左侧
            if velocity > 500 || translation > screenWidth * 0.2 {  // 快速向右滑或滑动距离足够
                dragOffset = 0
                containerOffset = 0
                isControlPanelVisible = true
                print("从左侧显示到中间 - 速度:\(velocity), 距离:\(translation)")
            } else {
                dragOffset = -(screenWidth - 60)
                containerOffset = -screenWidth
                print("保持在左侧隐藏 - 速度:\(velocity), 距离:\(translation)")
            }
        } else {  // 当前在右侧
            if velocity < -500 || -translation > screenWidth * 0.2 {  // 快速向左滑或滑动距离足够
                dragOffset = 0
                containerOffset = 0
                isControlPanelVisible = true
                print("从右侧显示到中间 - 速度:\(velocity), 距离:\(translation)")
            } else {
                dragOffset = screenWidth - 60
                containerOffset = screenWidth
                print("保持在右侧隐藏 - 速度:\(velocity), 距离:\(translation)")
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 黄色半透明背景
                Rectangle()
                    .fill(isExpanded ? Color.clear : Color.white.opacity(0.2))
                    .frame(width: geometry.size.width, height: 50)
                    .allowsHitTesting(false)
                
                // 箭头图标容器
                HStack {
                    // 箭头图标
                    Image(systemName: isExpanded ? "suit.diamond" : "suit.diamond.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: ArrowLayoutConfig.arrowWidth, height: ArrowLayoutConfig.arrowHeight)
                        .contentShape(Rectangle())
                        .padding(.leading, isControlPanelVisible ? 
                             geometry.size.width/2 - ArrowLayoutConfig.arrowHalfWidth : 
                             (containerOffset < 0 ? geometry.size.width - ArrowLayoutConfig.arrowWidth - ArrowLayoutConfig.arrowPadding : ArrowLayoutConfig.arrowPadding))
                        .onAppear {
                            let arrowWidth: CGFloat = ArrowLayoutConfig.arrowWidth
                            let arrowHeight: CGFloat = ArrowLayoutConfig.arrowHeight
                            let screenHeight = UIScreen.main.bounds.height
                            let containerHeight: CGFloat = 120
                            
                            // 计算箭头的中心坐标
                            let centerX = isControlPanelVisible ? 
                                geometry.size.width/2 : 
                                (containerOffset < 0 ? geometry.size.width - ArrowLayoutConfig.arrowHalfWidth - ArrowLayoutConfig.arrowPadding : ArrowLayoutConfig.arrowHalfWidth + ArrowLayoutConfig.arrowPadding)
                            let centerY = screenHeight - containerHeight - arrowHeight/2
                            
                            print("------------------------")
                            print("白色箭头初始位置")
                            print("箭头尺寸：\(arrowWidth) x \(arrowHeight)")
                            print("箭头中心坐标：(\(centerX), \(centerY))")
                            print("相对位置：\(isControlPanelVisible ? "居中" : (containerOffset < 0 ? "靠右" : "靠左"))")
                            print("------------------------")
                        }
                        .onTapGesture {
                            // 根据垂直位置和显示状态决定提示类型
                            if dragVerticalOffset == 0 {
                                // 容器在底部
                                dragHintState = isControlPanelVisible ? .upAndRightLeft :
                                    (containerOffset < 0 ? .rightOnly : .leftOnly)
                            } else if dragVerticalOffset == -verticalDestination {
                                // 容器在上方
                                dragHintState = isControlPanelVisible ? .downAndRightLeft :
                                    (containerOffset < 0 ? .rightOnly : .leftOnly)
                            }
                            
                            withAnimation(.easeInOut(duration: DragAnimationConfig.hintFadeDuration)) {
                                showDragHint = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + DragAnimationConfig.hintDisplayDuration) {
                                withAnimation(.easeInOut(duration: DragAnimationConfig.hintFadeDuration)) {
                                    showDragHint = false
                                }
                            }
                        }
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    if !isDirectionLocked {
                                        let horizontalAmount = abs(value.translation.width)
                                        let verticalAmount = abs(value.translation.height)
                                        
                                        if horizontalAmount > 10 || verticalAmount > 10 {
                                            dragDirection = horizontalAmount > verticalAmount ? .horizontal : .vertical
                                            isDirectionLocked = true
                                            print("锁定方向: \(dragDirection)")
                                        }
                                    }
                                    
                                    if isDirectionLocked {
                                        switch dragDirection {
                                        case .horizontal:
                                            handleHorizontalDrag(value: value, velocity: value.velocity.width)
                                            
                                            // 显示拖动提示
                                            if !showDragHint {
                                                withAnimation {
                                                    showDragHint = true
                                                }
                                            }
                                            
                                        case .vertical:
                                            handleVerticalDrag(value: value)
                                            
                                        case .none:
                                            break
                                        }
                                    }
                                }
                                .onEnded { value in
                                    print("------------------------")
                                    print("手势结束")
                                    print("最终移动 - 垂直: \(value.translation.height), 水平: \(value.translation.width)")
                                    print("当前方向: \(dragDirection)")
                                    
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showDragHint = false
                                    }
                                    
                                    if isDirectionLocked {
                                        switch dragDirection {
                                        case .horizontal:
                                            handleHorizontalDragEnd(value: value)
                                        case .vertical:
                                            handleVerticalDragEnd(value: value)
                                        case .none:
                                            break
                                        }
                                    }
                                    
                                    // 重置状态
                                    dragDirection = .none
                                    isDirectionLocked = false
                                    lastDragTranslation = 0
                                }
                        )
                    
                    Spacer()
                        .allowsHitTesting(false)
                }
            }
            .onChange(of: isControlPanelVisible) { _ in
                showDragHint = false
            }
        }
        .frame(height: 50)
    }
}

// 添加独立的边框视图组件
struct CameraBorderView: View {
    let isSelected: Bool
    let isLighted: Bool
    
    var body: some View {
        GeometryReader { geometry in
            let availableHeight = geometry.size.height
            let containerFrame = CGRect(
                x: CameraLayoutConfig.horizontalPadding,
                y: CameraLayoutConfig.verticalOffset,
                width: geometry.size.width - (CameraLayoutConfig.horizontalPadding * 2),
                height: availableHeight - CameraLayoutConfig.bottomOffset
            )
            
            RoundedRectangle(cornerRadius: CameraLayoutConfig.cornerRadius)
                .trim(from: 0, to: 1)
                .stroke(
                    isSelected ? BorderStyle.selectedColor : BorderStyle.normalColor,
                    style: StrokeStyle(
                        lineWidth: isSelected ? BorderStyle.selectedWidth : BorderStyle.normalWidth,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .frame(width: containerFrame.width, height: containerFrame.height)
                .position(x: geometry.size.width/2, y: geometry.size.height/2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// 添加UIDevice扩展，用于获取设备型号
extension UIDevice {
    static let modelName: String = {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        
        // 返回设备标识符
        return identifier
    }()
    
    // 获取设备圆角值
    static func getCornerRadius() -> CGFloat {
        let model = modelName
        
        // 获取设备原始圆角值
        let originalCornerRadius: CGFloat
        switch model {
        // iPhone 14 Pro Max, 14 Pro
        case "iPhone15,3", "iPhone15,2":
            originalCornerRadius = 55
        // iPhone 14 Plus, 14
        case "iPhone14,8", "iPhone14,7":
            originalCornerRadius = 47.33
        // iPhone 13 Pro Max, 12 Pro Max
        case "iPhone14,3", "iPhone13,4":
            originalCornerRadius = 53.33
        // iPhone 13 Pro, 12 Pro
        case "iPhone14,2", "iPhone13,3":
            originalCornerRadius = 47.33
        // iPhone 13, 12
        case "iPhone14,5", "iPhone13,2":
            originalCornerRadius = 47.33
        // iPhone 13 mini, 12 mini
        case "iPhone14,4", "iPhone13,1":
            originalCornerRadius = 44.0
        // iPhone 11 Pro Max
        case "iPhone12,5":
            originalCornerRadius = 39.0
        // iPhone 11 Pro
        case "iPhone12,3":
            originalCornerRadius = 39.0
        // iPhone 11
        case "iPhone12,1":
            originalCornerRadius = 41.5
        default:
            originalCornerRadius = 39.0
        }
        
        // 直接返回原始圆角值，不进行倍数计算
        return originalCornerRadius
    }
}

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @State private var showingTwoOfMe = false
    @State private var isCameraActive = true
    @State private var showRestartHint = false
    @State private var deviceOrientation = UIDevice.current.orientation
    @State private var ModeASelected = false
    // 在初始化时就记录初始亮度
    @State private var previousBrightness: CGFloat = {
        let brightness = UIScreen.main.brightness
        print("记录初始屏幕亮度：\(brightness)")
        return brightness
    }()
    @State private var ModeBSelected = false
    @State private var isLighted = false
    
    // 添加一个变量来追踪是否是用户手动调整的亮度
    @State private var isUserAdjustingBrightness = false
    
    // 添加放缩相关的状态变量
    @State private var currentScale: CGFloat = 1.0
    @State private var baseScale: CGFloat = 1.0
    @State private var showScaleLimitMessage = false
    @State private var scaleLimitMessage = ""
    @State private var showScaleIndicator = false
    @State private var currentIndicatorScale: CGFloat = 1.0
    @State private var isControlPanelVisible: Bool = true
    @State private var dragOffset: CGFloat = 0
    @State private var dragVerticalOffset: CGFloat = 0  // 添加垂直偏移量
    
    // 添加放缩限制常量
    private let minScale: CGFloat = 1.0     // 最小100%
    private let maxScale: CGFloat = 10.0    // 最大1000%
    private let verticalDestination: CGFloat = 120.0  // 向上拖拽的目标位置
    private let verticalDragThreshold: CGFloat = 20.0  // 垂直拖拽的触发阈值
    
    // 添加震动反馈生成器
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
    
    // 添加新的状态变量
    @State private var showArrowHint = false
    @State private var dragHintState: DragHintState = .upAndRightLeft
    
    // 添加黑色容器的独立偏移值
    @State private var containerOffset: CGFloat = 0
    
    // 添加设置面板状态
    @State private var showSettings = false
    
    // 添加帮助面板状态
    @State private var showHelp = false
    
    var body: some View {
        GeometryReader { geometry in
            
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
                                previousBrightness: previousBrightness,
                                isSelected: $ModeASelected,
                                isLighted: $isLighted,
                                currentScale: $currentScale,
                                showScaleIndicator: $showScaleIndicator,
                                currentIndicatorScale: $currentIndicatorScale,
                                onPinchChanged: handlePinchGesture,
                                onPinchEnded: handlePinchEnd
                            )
                        }
                        
                        // 添加独立的边框视图
                        CameraBorderView(isSelected: ModeASelected, isLighted: isLighted)
                            .zIndex(3)
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
                                previousBrightness: previousBrightness,
                                isSelected: $ModeBSelected,
                                isLighted: $isLighted,
                                currentScale: $currentScale,
                                showScaleIndicator: $showScaleIndicator,
                                currentIndicatorScale: $currentIndicatorScale,
                                onPinchChanged: handlePinchGesture,
                                onPinchEnded: handlePinchEnd
                            )
                        }
                        
                        // 添加独立的边框视图
                        CameraBorderView(isSelected: ModeBSelected, isLighted: isLighted)
                            .zIndex(3)
                    }
                    
                    // 控制面板
                    ZStack {
                        // 黑色容器
                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(Color.black.opacity(0.5))
                                .frame(width: isLighted ? geometry.size.width - 20 : geometry.size.width, height: 120)
                                .animation(.easeInOut(duration: 0.3), value: isLighted)
                                .overlay(
                                    HStack(spacing: 40) {
                                        // 左按钮 - 模式A
                                        CircleButton(
                                            systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right",
                                            title: "",
                                            action: {
                                                // 直接传递选中状态和亮度状态
                                                ModeASelected = ModeBSelected
                                                isLighted = ModeBSelected
                                                
                                                // 根据选中状态设置亮度
                                                if ModeBSelected {
                                                    // 如果之前是选中状态，保持最大亮度
                                                    UIScreen.main.brightness = 1.0
                                                    print("切换到模式A - 保持最大亮度")
                                                } else {
                                                    // 如果之前是未选中状态，保持原始亮度
                                                    UIScreen.main.brightness = previousBrightness
                                                    print("切换到模式A - 保持原始亮度：\(previousBrightness)")
                                                }
                                                
                                                // 设置为模式A
                                                if let processor = cameraManager.videoOutputDelegate as? MainVideoProcessor {
                                                    processor.setMode(.modeA)
                                                }
                                                cameraManager.isMirrored = true
                                                
                                                // 重置模式B的状态（移到最后）
                                                ModeBSelected = false
                                            },
                                            deviceOrientation: deviceOrientation,
                                            isDisabled: cameraManager.isMirrored
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
                                                // 直接传递选中状态和亮度状态
                                                ModeBSelected = ModeASelected
                                                isLighted = ModeASelected
                                                
                                                // 根据选中状态设置亮度
                                                if ModeASelected {
                                                    // 如果之前是选中状态，保持最大亮度
                                                    UIScreen.main.brightness = 1.0
                                                    print("切换到模式B - 保持最大亮度")
                                                } else {
                                                    // 如果之前是未选中状态，保持原始亮度
                                                    UIScreen.main.brightness = previousBrightness
                                                    print("切换到模式B - 保持原始亮度：\(previousBrightness)")
                                                }
                                                
                                                // 设置为模式B
                                                if let processor = cameraManager.videoOutputDelegate as? MainVideoProcessor {
                                                    processor.setMode(.modeB)
                                                }
                                                cameraManager.isMirrored = false
                                                
                                                // 重置模式A的状态（移到最后）
                                                ModeASelected = false
                                            },
                                            deviceOrientation: deviceOrientation,
                                            isDisabled: !cameraManager.isMirrored
                                        )
                                    }
                                )
                        }
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .offset(x: containerOffset, y: dragVerticalOffset)
                        .ignoresSafeArea(.all)
                        .zIndex(1)  // 确保黑色容器在上层

                        // 黄色容器
                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(Color.yellow.opacity(0.5))
                                .frame(width: isLighted ? geometry.size.width - 20 : geometry.size.width, height: 120)
                                .overlay(
                                    HStack(spacing: 40) {
                                        Spacer()
                                        
                                        // 设置按钮
                                        CircleButton(
                                            systemName: "gearshape.fill",
                                            title: "",
                                            action: {
                                                withAnimation(.easeInOut(duration: 0.2)) {
                                                    showSettings = true
                                                }
                                            },
                                            deviceOrientation: deviceOrientation
                                        )
                                        
                                        // 帮助按钮
                                        CircleButton(
                                            systemName: "questionmark.circle.fill",
                                            title: "",
                                            action: {
                                                withAnimation(.easeInOut(duration: 0.2)) {
                                                    showHelp = true
                                                }
                                            },
                                            deviceOrientation: deviceOrientation
                                        )
                                        
                                        Spacer()
                                    }
                                )
                        }
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .offset(x: containerOffset, y: dragVerticalOffset + 120)  // 保持在黑色容器下方
                        .animation(.easeInOut(duration: 0.3), value: isLighted)
                        .ignoresSafeArea(.all)
                        .zIndex(0)  // 确保黄色容器在下层

                        // 箭头放置在黑色容器上方
                        VStack {
                            Spacer()
                            DraggableArrow(isExpanded: !isControlPanelVisible, 
                                         isLighted: isLighted,
                                         screenWidth: geometry.size.width,
                                         isControlPanelVisible: $isControlPanelVisible,
                                         showDragHint: $showArrowHint,
                                         dragHintState: $dragHintState,
                                         dragOffset: $dragOffset,
                                         dragVerticalOffset: $dragVerticalOffset,
                                         containerOffset: $containerOffset)
                                .padding(.bottom, 120)
                        }
                        .offset(x: dragOffset, y: dragVerticalOffset)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .ignoresSafeArea(.all, edges: .bottom)
                    .zIndex(1)
                    
                    // 更新背景遮罩视图，确保正确传递选中状态
                    BackgroundMaskView(isSelected: cameraManager.isMirrored ? ModeASelected : ModeBSelected, isLighted: isLighted)
                        .allowsHitTesting(false)
                        .onChange(of: ModeASelected) { _ in
                            print("遮罩状态更新 - 模式A选中状态：\(ModeASelected)")
                        }
                        .onChange(of: ModeBSelected) { _ in
                            print("遮罩状态更新 - 模式B选中状态：\(ModeBSelected)")
                        }
                        .zIndex(2)
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
                
                // 添加提示视图到最顶层
                if showArrowHint {
                    DragHintView(hintState: dragHintState)
                        .position(x: geometry.size.width/2, y: geometry.size.height/2)
                        .transition(.opacity)
                        .zIndex(4)
                }
                
                // 添加设置面板
                if showSettings {
                    SettingsPanel(isPresented: $showSettings)
                        .zIndex(4)  // 确保设置面板显示在最上层
                }
                
                // 添加帮助面板
                if showHelp {
                    HelpPanel(isPresented: $showHelp)
                        .zIndex(4)  // 确保帮助面板显示在最上层
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                // 添加屏幕亮度变化通知监听
                NotificationCenter.default.addObserver(
                    forName: UIScreen.brightnessDidChangeNotification,
                    object: nil,
                    queue: .main) { _ in
                        let currentBrightness = UIScreen.main.brightness
                        
                        // 只有在非选中状态下才更新初始亮度
                        if !ModeASelected && !ModeBSelected {
                            previousBrightness = currentBrightness
                            print("用户调整了屏幕亮度，更新初始亮度：\(currentBrightness)")
                        }
                    }
                
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
                print("屏幕尺寸：width=\(geometry.size.width), height=\(geometry.size.height)")
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
                // 移除所有通知监听
                NotificationCenter.default.removeObserver(self)
                UIDevice.current.endGeneratingDeviceOrientationNotifications()
                
                print("主页面退出")
                print("------------------------")
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
