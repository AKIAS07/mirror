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
        case .live: return "livephoto"
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
                                .fill(Color.white)
                                .frame(width: buttonType.size, height: buttonType.size)
                        } else if buttonType == .zoom {
                            // 自定义焦距按钮显示，使用舍入到50的倍数
                            let percentage = Int(currentScale * 100)
                            let roundedPercentage = Int(round(Double(percentage) / 50.0) * 50)
                            let zoomText = currentScale <= 1.0 ? "100" : 
                                          currentScale >= 10.0 ? "1000" : 
                                          "\(roundedPercentage)"
                            Text(zoomText)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: buttonType.size, height: buttonType.size)
                        } else {
                            Image(systemName: buttonType.icon)
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                                .frame(width: buttonType.size, height: buttonType.size)
                        }
                    }
                }
                .scaleEffect(isDragging ? 0.95 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
            }
        }
    }
    
    private func handleButtonTap(_ buttonType: ToolbarButtonType) {
        feedbackGenerator.impactOccurred()
        
        switch buttonType {
        case .capture:
            // 隐藏所有控制界面
            withAnimation {
                isVisible = false
            }
            
            // 触发截图
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                captureState.isCapturing = true
                
                // 发送闪光动画通知
                NotificationCenter.default.post(
                    name: NSNotification.Name("TriggerFlashAnimation"),
                    object: nil
                )
                
                // 截图完成后的回调
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    captureState.showButtons = true
                    captureState.isCapturing = false
                }
            }
            
        case .light:
            withAnimation(.easeInOut(duration: 0.2)) {
                containerSelected.toggle()
                
                if containerSelected {
                    UIScreen.main.brightness = 1.0
                    print("灯光按钮：提高亮度至最大")
                    feedbackGenerator.impactOccurred(intensity: 1.0)
                    isLighted = true
                } else {
                    UIScreen.main.brightness = previousBrightness
                    print("灯光按钮：恢复原始亮度：\(previousBrightness)")
                    isLighted = false
                }
            }
            print("灯光按钮：选中状态：\(containerSelected)")
            print("灯光按钮：屏幕点亮状态：\(isLighted)")
            
        case .live:
            print("Live 按钮点击")
        case .camera:
            // 切换前后摄像头
            cameraManager.switchCamera()
            print("切换摄像头：\(cameraManager.isFront ? "前置" : "后置")")
            
        case .zoom:
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
            
            // 使用舍入到50的倍数来显示日志
            let percentage = Int(nextScale * 100)
            let roundedPercentage = Int(round(Double(percentage) / 50.0) * 50)
            print("焦距按钮：缩放比例更新为 \(roundedPercentage)%")
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