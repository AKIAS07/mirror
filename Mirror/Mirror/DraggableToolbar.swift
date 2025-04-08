import SwiftUI

// 工具栏位置枚举
enum ToolbarPosition {
    case top
    case left
    case right
    case leftBottom  // 新增左下位置
    case rightBottom // 新增右下位置
    
    // 获取下一个位置
    func next(for dragDirection: DragDirection) -> ToolbarPosition {
        switch (self, dragDirection) {
        case (.top, .left): return .left
        case (.top, .right): return .right
        case (.left, .right): return .top
        case (.right, .left): return .top
        case (.left, .down): return .leftBottom
        case (.right, .down): return .rightBottom
        case (.leftBottom, .right): return .rightBottom
        case (.rightBottom, .left): return .leftBottom
        case (.leftBottom, .up): return .left    // 新增：左下向上 -> 左侧
        case (.rightBottom, .up): return .right  // 新增：右下向上 -> 右侧
        default: return self
        }
    }
}

// 拖动方向枚举
enum DragDirection {
    case left
    case right
    case up
    case down
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

// 在 ToolbarButtonType 枚举后添加新的按钮类型枚举
enum UtilityButtonType: Int, CaseIterable {
    case add = 0
    case drag
    case close
    
    var icon: String {
        switch self {
        case .add: return "plus"
        case .drag: return "arrow.up.and.down.and.arrow.left.and.right"
        case .close: return "xmark"
        }
    }
    
    var size: CGFloat {
        return 25  // 减小按钮尺寸（原值为30）
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
    private let buttonSpacing: CGFloat = 25  // 原值
    private let utilityButtonSpacing: CGFloat = 15  // 新增：工具按钮的间距更小
    private let edgeThreshold: CGFloat = 80
    private let verticalToolbarWidth: CGFloat = 70  // 新增：垂直布局时的宽度
    
    // 添加设备方向
    @ObservedObject private var orientationManager = DeviceOrientationManager.shared
    
    // 添加触觉反馈生成器
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    
    // 添加新状态来跟踪是否已移动位置
    @State private var hasMovedPosition = false
    
    var body: some View {
        GeometryReader { geometry in
            let isVertical = orientationManager.currentOrientation == .portrait || orientationManager.currentOrientation == .portraitUpsideDown
            
            HStack(spacing: 0) {
                if position == .left || position == .leftBottom {
                    toolbarContent(isVertical: true, geometry: geometry)
                }
                
                if position == .top {
                    toolbarContent(isVertical: false, geometry: geometry)
                }
                
                if position == .right || position == .rightBottom {
                    toolbarContent(isVertical: true, geometry: geometry)
                }
            }
            .position(calculatePosition(in: geometry))
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: position)
            .animation(.easeInOut(duration: 0.2), value: dragOffset)
            .ignoresSafeArea(.all, edges: .top)
        }
    }
    
    private func handleDragChange(_ value: DragGesture.Value, in geometry: GeometryProxy) {
        isDragging = true
        
        // 如果已经移动过位置，直接返回
        if hasMovedPosition {
            return
        }
        
        // 计算拖动方向和距离
        let horizontalMovement = value.translation.width
        let verticalMovement = value.translation.height
        
        // 根据水平和垂直移动的绝对值来判断主要移动方向
        if abs(horizontalMovement) > abs(verticalMovement) {
            dragDirection = horizontalMovement > 0 ? .right : .left
        } else {
            dragDirection = verticalMovement > 0 ? .down : .up
        }
        
        // 更新拖动偏移
        dragOffset = value.translation
        
        // 设置移动阈值
        let threshold: CGFloat = 50
        
        // 打印调试信息
        print("------------------------")
        print("拖拽调试信息：")
        print("当前位置：\(position)")
        print("水平移动：\(horizontalMovement)")
        print("垂直移动：\(verticalMovement)")
        print("拖拽方向：\(dragDirection)")
        print("------------------------")
        
        // 根据当前位置和拖动方向决定切换位置
        switch position {
        case .left:
            if dragDirection == .right && horizontalMovement > threshold {  // 向右拖动 -> 到顶部
                print("左侧向右拖动，切换到顶部")
                moveToPosition(.top)
            } else if dragDirection == .up && verticalMovement < -threshold {  // 向上拖动 -> 到顶部
                print("左侧向上拖动，切换到顶部")
                moveToPosition(.top)
            } else if dragDirection == .down && verticalMovement > threshold {  // 向下拖动 -> 到左下
                print("左侧向下拖动，切换到左下")
                moveToPosition(.leftBottom)
            }
        case .right:
            if dragDirection == .left && horizontalMovement < -threshold {  // 向左拖动 -> 到顶部
                print("右侧向左拖动，切换到顶部")
                moveToPosition(.top)
            } else if dragDirection == .up && verticalMovement < -threshold {  // 向上拖动 -> 到顶部
                print("右侧向上拖动，切换到顶部")
                moveToPosition(.top)
            } else if dragDirection == .down && verticalMovement > threshold {  // 向下拖动 -> 到右下
                print("右侧向下拖动，切换到右下")
                moveToPosition(.rightBottom)
            }
        case .leftBottom:
            if dragDirection == .right && horizontalMovement > threshold {  // 向右拖动 -> 到右下
                print("左下向右拖动，切换到右下")
                moveToPosition(.rightBottom)
            } else if dragDirection == .up && verticalMovement < -threshold {  // 向上拖动 -> 到左侧
                print("左下向上拖动，切换到左侧")
                moveToPosition(.left)
            }
        case .rightBottom:
            if dragDirection == .left && horizontalMovement < -threshold {  // 向左拖动 -> 到左下
                print("右下向左拖动，切换到左下")
                moveToPosition(.leftBottom)
            } else if dragDirection == .up && verticalMovement < -threshold {  // 向上拖动 -> 到右侧
                print("右下向上拖动，切换到右侧")
                moveToPosition(.right)
            }
        case .top:
            if dragDirection == .right && horizontalMovement > threshold {  // 向右拖动 -> 到右侧
                print("顶部向右拖动，切换到右侧")
                moveToPosition(.right)
            } else if dragDirection == .left && horizontalMovement < -threshold {  // 向左拖动 -> 到左侧
                print("顶部向左拖动，切换到左侧")
                moveToPosition(.left)
            }
        }
    }
    
    private func handleDragEnd(_ value: DragGesture.Value, in geometry: GeometryProxy) {
        isDragging = false
        dragDirection = .none
        hasMovedPosition = false  // 重置移动状态
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            dragOffset = .zero
        }
    }
    
    private func moveToPosition(_ newPosition: ToolbarPosition) {
        if position != newPosition && !hasMovedPosition {
            feedbackGenerator.impactOccurred()
            hasMovedPosition = true
            
            // 记录位置变化
            ViewActionLogger.shared.logToolbarPositionChange(from: position, to: newPosition)
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                position = newPosition
                dragOffset = .zero
            }
        }
    }
    
    private func toolbarContent(isVertical: Bool, geometry: GeometryProxy) -> some View {
        Group {
            if isVertical {
                HStack(spacing: 0) {
                    if position == .right || position == .rightBottom {
                        // 右侧或右下时，工具按钮在左边
                        utilityButtonsContainer(isVertical: true)
                    }
                    
                    // 主按钮容器
                    mainButtonsContainer(isVertical: true)
                    
                    if position == .left || position == .leftBottom {
                        // 左侧或左下时，工具按钮在右边
                        utilityButtonsContainer(isVertical: true)
                    }
                }
            } else {
                // 顶部工具栏时，垂直排列两个容器
                VStack(spacing: 0) {
                    mainButtonsContainer(isVertical: false)
                    utilityButtonsContainer(isVertical: false)
                }
            }
        }
    }
    
    private func mainButtonsContainer(isVertical: Bool) -> some View {
        VStack {
            if isVertical {
                VStack(spacing: buttonSpacing) {
                    toolbarButtons()
                }
                .padding(.vertical, 10)  // 垂直布局时的内边距
            } else {
                // 顶部布局时，使用 Spacer 将按钮推到下方
                Spacer()
                    .frame(height: 100)  // 增加上方空间到50点
                
                HStack(spacing: buttonSpacing) {
                    toolbarButtons()
                }
                .padding(.bottom, 15)  // 底部留出一定空间
            }
        }
        .padding(.horizontal, isVertical ? 5 : 20)  // 水平内边距保持不变
        .frame(
            width: isVertical ? nil : UIScreen.main.bounds.width-60,  // 顶部时宽度为屏幕宽度
            height: isVertical ? nil : 150  // 保持高度为150
        )
        .background(
            RoundedRectangle(cornerRadius: isVertical ? 0 : 0)
                .fill(Color.black.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: isVertical ? 0 : 0)
                        .stroke(Color.white.opacity(isDragging ? 0.3 : 0), lineWidth: 2)
                )
        )
    }
    
    private func utilityButtonsContainer(isVertical: Bool) -> some View {
        Group {
            if isVertical {
                VStack(spacing: utilityButtonSpacing) {  // 使用更小的间距
                    utilityButtonsContent()
                }
                .padding(.vertical, 5)  // 减小垂直内边距
                .padding(.horizontal, 5)  // 减小水平内边距
                .background(
                    RoundedRectangle(cornerRadius: 0)
                        .fill(Color.yellow.opacity(0.2))
                )
                .frame(width: 40)  // 限制垂直布局时的宽度
            } else {
                HStack(spacing: utilityButtonSpacing) {  // 使用更小的间距
                    utilityButtonsContent()
                }
                .padding(.vertical, 5)  // 减小垂直内边距
                .padding(.horizontal, 10)  // 减小水平内边距
                .background(
                    RoundedRectangle(cornerRadius: 0)
                        .fill(Color.yellow.opacity(0.2))
                )
                .frame(height: 40)  // 限制水平布局时的高度
            }
        }
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
        // 记录操作
        switch buttonType {
        case .live:
            ViewActionLogger.shared.logAction(.toolbarAction(.live))
        case .light:
            ViewActionLogger.shared.logAction(.toolbarAction(.light))
        case .capture:
            ViewActionLogger.shared.logAction(.toolbarAction(.capture))
        case .camera:
            ViewActionLogger.shared.logAction(.toolbarAction(.camera))
        case .zoom:
            ViewActionLogger.shared.logAction(.toolbarAction(.zoom))
        }
        
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
                                orientation: orientationManager.currentOrientation,
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
                    // 使用系统相机的拍照功能
                    self.cameraManager.capturePhoto { image in
                        if let image = image {
                            DispatchQueue.main.async {
                                self.captureManager.showPreview(
                                    image: image, 
                                    scale: self.currentScale,
                                    orientation: orientationManager.currentOrientation,
                                    cameraManager: self.cameraManager
                                )
                                
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
                y: toolbarHeight
            )
        case .left:
            return CGPoint(
                x: (verticalToolbarWidth / 2) + 17,
                y: geometry.size.height * 0.3
            )
        case .right:
            return CGPoint(
                x: geometry.size.width - (verticalToolbarWidth / 2) - 17,
                y: geometry.size.height * 0.3
            )
        case .leftBottom:
            return CGPoint(
                x: (verticalToolbarWidth / 2) + 17,
                y: geometry.size.height * 0.3 + 200  // 在左侧位置下方100pt
            )
        case .rightBottom:
            return CGPoint(
                x: geometry.size.width - (verticalToolbarWidth / 2) - 17,
                y: geometry.size.height * 0.3 + 200  // 在右侧位置下方100pt
            )
        }
    }
    
    private func utilityButtonsContent() -> some View {
        ForEach(UtilityButtonType.allCases, id: \.rawValue) { buttonType in
            Group {
                if buttonType == .drag {
                    // 拖拽按钮添加拖拽手势
                    GeometryReader { geometry in
                        Image(systemName: buttonType.icon)
                            .font(.system(size: 16))
                            .foregroundColor(restartManager.isCameraActive ? .white : .gray)
                            .frame(width: buttonType.size, height: buttonType.size)
                            .gesture(
                                DragGesture(minimumDistance: 10)
                                    .onChanged { value in
                                        handleDragChange(value, in: geometry)
                                    }
                                    .onEnded { value in
                                        handleDragEnd(value, in: geometry)
                                    }
                            )
                            .disabled(!restartManager.isCameraActive)
                            .scaleEffect(isDragging ? 0.95 : 1.0)
                    }
                    .frame(width: buttonType.size, height: buttonType.size)
                } else {
                    Button(action: {
                        handleUtilityButtonTap(buttonType)
                    }) {
                        Image(systemName: buttonType.icon)
                            .font(.system(size: 16))
                            .foregroundColor(restartManager.isCameraActive ? .white : .gray)
                            .frame(width: buttonType.size, height: buttonType.size)
                    }
                    .disabled(!restartManager.isCameraActive)
                    .scaleEffect(isDragging ? 0.95 : 1.0)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
        }
    }
    
    // 修改工具按钮处理函数
    private func handleUtilityButtonTap(_ buttonType: UtilityButtonType) {
        feedbackGenerator.impactOccurred()
        
        switch buttonType {
        case .add:
            ViewActionLogger.shared.logAction(.utilityAction(.add))
            print("------------------------")
            print("工具栏：点击添加按钮")
            print("------------------------")
            
        case .drag:
            ViewActionLogger.shared.logAction(.utilityAction(.drag))
            print("------------------------")
            print("工具栏：点击拖拽按钮")
            print("------------------------")
            
        case .close:
            ViewActionLogger.shared.logAction(.utilityAction(.close))
            print("------------------------")
            print("工具栏：点击关闭按钮")
            print("------------------------")
            
            // 调用 handleRestartViewAppear 方法
            restartManager.handleRestartViewAppear(cameraManager: cameraManager)
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
        case "leftBottom": self = .leftBottom
        case "rightBottom": self = .rightBottom
        default: return nil
        }
    }
    
    var rawValue: String {
        switch self {
        case .top: return "top"
        case .left: return "left"
        case .right: return "right"
        case .leftBottom: return "leftBottom"
        case .rightBottom: return "rightBottom"
        }
    }
} 