import SwiftUI

// 工具栏位置枚举
enum ToolbarPosition {
    case top
    case left
    case right
    
    // 获取下一个位置
    func next(for dragDirection: DragDirection) -> ToolbarPosition {
        switch (self, dragDirection) {
        case (.top, .left): return .left
        case (.top, .right): return .right
        case (.left, .right): return .top
        case (.right, .left): return .top
        default: return self
        }
    }
}

// 拖动方向枚举
enum DragDirection {
    case left
    case right
    case none
}

// 添加按钮类型枚举
enum ToolbarButtonType: Int, CaseIterable {
    case live = 0
    case light
    case capture
    case camera  // 改为摄像头切换按钮
    case zoom
    
    var icon: String {
        switch self {
        case .live: return "livephoto"  // 改为根据状态动态获取
        case .light: return "lightbulb"
        case .capture: return "circle.fill"
        case .camera: return "camera.rotate"  // 使用摄像头切换图标
        case .zoom: return "1.circle"  // 默认显示1倍
        }
    }
    
    var size: CGFloat {
        switch self {
        case .capture: return 50 // 拍照按钮稍大
        default: return 40
        }
    }
    
    var isSystemIcon: Bool {
        return true
    }
}

struct DraggableToolbar: View {
    @AppStorage("toolbarPosition") private var position: ToolbarPosition = .top {
        didSet {
            print("工具条位置已更新：\(position)")
        }
    }
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var dragDirection: DragDirection = .none
    @State private var showPositionIndicator = false
    @ObservedObject var captureState: CaptureState
    @StateObject private var captureManager = CaptureManager.shared
    @StateObject private var restartManager = ContentRestartManager.shared  // 添加 RestartManager
    @Binding var isVisible: Bool
    
    // 添加边框灯状态绑定
    @Binding var containerSelected: Bool
    @Binding var isLighted: Bool
    let previousBrightness: CGFloat
    
    // 添加缩放相关的属性
    @Binding var currentScale: CGFloat
    @Binding var baseScale: CGFloat
    
    // 添加相机管理器
    let cameraManager: CameraManager
    
    // 工具栏尺寸常量
    private let toolbarHeight: CGFloat = 60
    private let toolbarWidth: CGFloat = UIScreen.main.bounds.width
    private let buttonSpacing: CGFloat = 25
    private let edgeThreshold: CGFloat = 80
    
    // 添加触觉反馈生成器
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    
    var body: some View {
        GeometryReader { geometry in
            let isVertical = position == .left || position == .right
            
            HStack(spacing: 0) {
                if position == .left {
                    toolbarContent(isVertical: true)
                }
                
                if position == .top {
                    toolbarContent(isVertical: false)
                }
                
                if position == .right {
                    toolbarContent(isVertical: true)
                }
            }
            .frame(
                width: isVertical ? toolbarHeight : toolbarWidth,
                height: isVertical ? geometry.size.height * 0.5 : toolbarHeight
            )
            .background(
                RoundedRectangle(cornerRadius: isVertical ? 0 : 30)
                    .fill(Color.black.opacity(0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: isVertical ? 0 : 30)
                            .stroke(Color.white.opacity(isDragging ? 0.3 : 0), lineWidth: 2)
                    )
            )
            .overlay(
                Group {
                    if showPositionIndicator {
                        positionIndicator
                    }
                }
            )
            .position(calculatePosition(in: geometry))
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        handleDragChange(value, in: geometry)
                    }
                    .onEnded { value in
                        handleDragEnd(value, in: geometry)
                    }
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: position)
            .animation(.easeInOut(duration: 0.2), value: dragOffset)
        }
    }
    
    private func handleDragChange(_ value: DragGesture.Value, in geometry: GeometryProxy) {
        isDragging = true
        
        // 计算拖动方向
        let horizontalMovement = value.translation.width
        dragDirection = horizontalMovement > 0 ? .right : .left
        
        // 更新拖动偏移
        dragOffset = value.translation
        
        // 显示位置指示器
        showPositionIndicator = true
        
        // 计算新位置
        let newPosition = value.location
        let currentPos = calculatePosition(in: geometry)
        
        // 边缘检测逻辑
        if !isNearCurrentPosition(newPosition, currentPos) {
            if shouldMoveToLeft(newPosition, in: geometry) {
                moveToPosition(.left)
            } else if shouldMoveToRight(newPosition, in: geometry) {
                moveToPosition(.right)
            } else if shouldMoveToTop(newPosition, in: geometry) {
                moveToPosition(.top)
            }
        }
    }
    
    private func handleDragEnd(_ value: DragGesture.Value, in geometry: GeometryProxy) {
        isDragging = false
        showPositionIndicator = false
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            dragOffset = .zero
        }
        
        // 延迟隐藏位置指示器
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showPositionIndicator = false
        }
    }
    
    private func moveToPosition(_ newPosition: ToolbarPosition) {
        if position != newPosition {
            feedbackGenerator.impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                position = newPosition
                dragOffset = .zero
            }
        }
    }
    
    private func isNearCurrentPosition(_ newPos: CGPoint, _ currentPos: CGPoint) -> Bool {
        let distance = sqrt(pow(newPos.x - currentPos.x, 2) + pow(newPos.y - currentPos.y, 2))
        return distance < 50
    }
    
    private func shouldMoveToLeft(_ pos: CGPoint, in geometry: GeometryProxy) -> Bool {
        return pos.x < edgeThreshold && position != .left
    }
    
    private func shouldMoveToRight(_ pos: CGPoint, in geometry: GeometryProxy) -> Bool {
        return pos.x > geometry.size.width - edgeThreshold && position != .right
    }
    
    private func shouldMoveToTop(_ pos: CGPoint, in geometry: GeometryProxy) -> Bool {
        return pos.y < geometry.size.height * 0.2 && position != .top
    }
    
    private var positionIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(position == .left ? Color.white : Color.white.opacity(0.3))
                .frame(width: 6, height: 6)
            Circle()
                .fill(position == .top ? Color.white : Color.white.opacity(0.3))
                .frame(width: 6, height: 6)
            Circle()
                .fill(position == .right ? Color.white : Color.white.opacity(0.3))
                .frame(width: 6, height: 6)
        }
        .padding(8)
        .background(Color.black.opacity(0.5))
        .cornerRadius(12)
        .offset(y: 30)
    }
    
    private func toolbarContent(isVertical: Bool) -> some View {
        Group {
            if isVertical {
                VStack(spacing: buttonSpacing) {
                    toolbarButtons()
                }
            } else {
                HStack(spacing: buttonSpacing) {
                    toolbarButtons()
                }
            }
        }
        .padding(.horizontal, isVertical ? 10 : 20)
        .padding(.vertical, isVertical ? 20 : 10)
    }
    
    private func toolbarButtons() -> some View {
        Group {
            ForEach(ToolbarButtonType.allCases, id: \.rawValue) { buttonType in
                Button(action: {
                    handleButtonTap(buttonType)
                }) {
                    Group {
                        if buttonType == .capture {
                            Circle()
                                .fill(restartManager.isCameraActive ? Color.white : Color.gray)
                                .frame(width: buttonType.size, height: buttonType.size)
                        } else if buttonType == .zoom {
                            let percentage = Int(currentScale * 100)
                            let roundedPercentage = Int(round(Double(percentage) / 50.0) * 50)
                            let zoomText = currentScale <= 1.0 ? "100" : 
                                          currentScale >= 10.0 ? "1000" : 
                                          "\(roundedPercentage)"
                            Text(zoomText)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(restartManager.isCameraActive ? .white : .gray)
                                .frame(width: buttonType.size, height: buttonType.size)
                        } else if buttonType == .live {
                            Image(systemName: cameraManager.isUsingSystemCamera ? "livephoto" : "livephoto.slash")
                                .font(.system(size: 22))
                                .foregroundColor(restartManager.isCameraActive ? (cameraManager.isUsingSystemCamera ? .yellow : .white) : .gray)
                                .frame(width: buttonType.size, height: buttonType.size)
                        } else {
                            Image(systemName: buttonType.icon)
                                .font(.system(size: 22))
                                .foregroundColor(restartManager.isCameraActive ? .white : .gray)
                                .frame(width: buttonType.size, height: buttonType.size)
                        }
                    }
                }
                .disabled(!restartManager.isCameraActive)  // 根据相机状态禁用按钮
                .scaleEffect(isDragging ? 0.95 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
            }
        }
    }
    
    private func handleButtonTap(_ buttonType: ToolbarButtonType) {
        feedbackGenerator.impactOccurred()
        
        switch buttonType {
        case .capture:
            print("------------------------")
            print("工具栏：点击拍照按钮")
            print("------------------------")
            
            // 隐藏所有控制界面
            withAnimation {
                isVisible = false
            }
            
            // 设置捕捉状态
            self.captureState.isCapturing = true
            
            // 触发闪光动画
            NotificationCenter.default.post(name: NSNotification.Name("TriggerFlashAnimation"), object: nil)
            
            // 根据是否使用系统相机决定拍摄方式
            if self.cameraManager.isUsingSystemCamera {
                print("使用系统相机拍摄 Live Photo")
                self.cameraManager.captureLivePhotoForPreview { success, identifier, imageURL, videoURL, image, error in
                    DispatchQueue.main.async {
                        self.captureState.isCapturing = false
                        
                        if success, let imageURL = imageURL, let videoURL = videoURL, let image = image {
                            print("[Live Photo 拍摄] 成功，准备预览")
                            self.captureManager.showLivePhotoPreview(
                                image: image,
                                videoURL: videoURL,
                                imageURL: imageURL,
                                identifier: identifier,
                                cameraManager: self.cameraManager
                            )
                            
                            print("------------------------")
                            print("[Live Photo 拍摄] 状态更新：")
                            print("标识符：\(identifier)")
                            print("图片 URL：\(imageURL.path)")
                            print("视频 URL：\(videoURL.path)")
                            print("------------------------")
                        } else {
                            print("[Live Photo 拍摄] 失败: \(error?.localizedDescription ?? "未知错误")")
                        }
                    }
                }
            } else {
                print("使用自定义相机拍摄普通照片")
                // 延迟捕捉普通照片，与点击屏幕行为保持一致
                DispatchQueue.main.asyncAfter(deadline: .now() + AppConfig.AnimationConfig.Capture.delay) {
                    // 直接使用当前处理好的图像，与点击屏幕行为保持一致
                    if let latestImage = self.cameraManager.latestProcessedImage {
                        DispatchQueue.main.async {
                            self.captureManager.showPreview(
                                image: latestImage, 
                                scale: self.currentScale,
                                cameraManager: self.cameraManager
                            )
                            
                            print("------------------------")
                            print("普通截图已捕捉")
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
            
        case .light:
            print("------------------------")
            print("工具栏：点击灯光按钮")
            print("当前选中状态：\(containerSelected)")
            print("当前屏幕亮度：\(UIScreen.main.brightness)")
            print("------------------------")

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
            
        case .live:
            print("------------------------")
            print("工具栏：点击 Live 按钮")
            print("切换前系统相机状态：\(cameraManager.isUsingSystemCamera)")
            // 切换系统相机
            cameraManager.toggleSystemCamera()
            print("切换后系统相机状态：\(cameraManager.isUsingSystemCamera)")
            print("------------------------")
            
        case .camera:
            print("------------------------")
            print("工具栏：点击摄像头切换按钮")
            print("切换前摄像头：\(cameraManager.isFront ? "前置" : "后置")")
            // 切换前后摄像头
            cameraManager.switchCamera()
            print("切换后摄像头：\(cameraManager.isFront ? "前置" : "后置")")
            print("------------------------")
            
        case .zoom:
            print("------------------------")
            print("工具栏：点击焦距按钮")
            print("当前缩放比例：\(Int(currentScale * 100))%")
            
            // 在预设的缩放值之间循环
            let nextScale: CGFloat
            switch currentScale {
            case 1.0:
                nextScale = 2.0  // 200%
            case 2.0:
                nextScale = 5.0  // 500%
            case 5.0:
                nextScale = 10.0 // 1000%
            default:
                nextScale = 1.0  // 100%
            }
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                currentScale = nextScale
                baseScale = nextScale
            }
            
            print("更新后缩放比例：\(Int(nextScale * 100))%")
            print("------------------------")
        }
    }
    
    private func calculatePosition(in geometry: GeometryProxy) -> CGPoint {
        switch position {
        case .top:
            let xOffset = min(max(dragOffset.width, -geometry.size.width/2), geometry.size.width/2)
            return CGPoint(
                x: geometry.size.width / 2 + xOffset,
                y: toolbarHeight / 2 + dragOffset.height
            )
        case .left:
            return CGPoint(
                x: toolbarHeight / 2,
                y: geometry.size.height * 0.3
            )
        case .right:
            return CGPoint(
                x: geometry.size.width - toolbarHeight / 2,
                y: geometry.size.height * 0.3
            )
        }
    }
}

#Preview {
    DraggableToolbar(
        captureState: CaptureState(),
        isVisible: .constant(true),
        containerSelected: .constant(false),
        isLighted: .constant(false),
        previousBrightness: UIScreen.main.brightness,
        currentScale: .constant(1.0),
        baseScale: .constant(1.0),
        cameraManager: CameraManager()  // 添加相机管理器
    )
}

// 添加 ToolbarPosition 的 RawRepresentable 实现
extension ToolbarPosition: RawRepresentable {
    typealias RawValue = String
    
    init?(rawValue: String) {
        switch rawValue {
        case "top": self = .top
        case "left": self = .left
        case "right": self = .right
        default: return nil
        }
    }
    
    var rawValue: String {
        switch self {
        case .top: return "top"
        case .left: return "left"
        case .right: return "right"
        }
    }
} 