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
    case reference  // 新增参考图标按钮
    case drag
    case brush      // 新增画笔图标按钮
    case close
    
    var icon: String {
        switch self {
        case .add: return "plus.circle"
        case .reference: return "ruler"  // 使用尺子图标
        case .drag: return "icon-star"  // 修改为使用自定义图标
        case .brush: return "pencil.tip.crop.circle"  // 使用画笔图标
        case .close: return "xmark.circle"
        }
    }
    
    var size: CGFloat {
        return 20  // 减小按钮尺寸（原值为30）
    }
    
    // 添加属性来判断是否为系统图标
    var isSystemIcon: Bool {
        switch self {
        case .drag: return false  // icon-star不是系统图标
        default: return true
        }
    }
}

// 添加工具栏主题观察者类
class ToolbarThemeObserver: NSObject {
    var styleManager = BorderLightStyleManager.shared
    
    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleThemeChange),
            name: NSNotification.Name("UpdateButtonColors"),
            object: nil
        )
    }
    
    @objc func handleThemeChange() {
        print("------------------------")
        print("[工具栏] 接收到主题颜色变化通知")
        print("当前主题颜色：\(styleManager.iconColor)")
        print("------------------------")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
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
    @StateObject private var proManager = ProManager.shared  // 添加 ProManager 引用
    @Binding var isVisible: Bool
    
    // 添加是否收缩的状态
    @State private var isCollapsed: Bool = false {
        didSet {
            print("------------------------")
            print("工具栏状态变化：\(isCollapsed ? "收缩" : "展开")")
            print("------------------------")
        }
    }
    
    // 添加化妆视图状态
    @Binding var showMakeupView: Bool
    // 添加控制添加按钮状态的变量
    @State private var isAddButtonEnabled: Bool = true
    
    // 添加边框灯状态绑定
    @Binding var containerSelected: Bool
    @Binding var isLighted: Bool
    let previousBrightness: CGFloat
    
    // 添加缩放相关的属性
    @Binding var currentScale: CGFloat
    @Binding var baseScale: CGFloat
    
    // 添加相机管理器
    let cameraManager: CameraManager
    
    // 添加参考格纹图显示状态
    @Binding var showReferenceGrid: Bool
    
    // 添加画布状态
    @State private var showDrawingCanvas = false
    @State private var isDrawingPinned = false
    
    // 添加工具条显示状态
    @State private var shouldHideToolbar: Bool = false
    
    // 工具栏尺寸常量
    private let toolbarHeight: CGFloat = 60
    private let toolbarWidth: CGFloat = UIScreen.main.bounds.width
    private let buttonSpacing: CGFloat = 25  // 原值
    private let utilityButtonSpacing: CGFloat = 15  // 新增：工具按钮的间距更小
    private let edgeThreshold: CGFloat = 80
    private let verticalToolbarWidth: CGFloat = 70  // 新增：垂直布局时的宽度
    
    // 添加设备方向
    @ObservedObject private var orientationManager = DeviceOrientationManager.shared
    
    // 添加主题样式管理器
    @ObservedObject private var styleManager = BorderLightStyleManager.shared
    
    // 添加主题变化观察者
    private let themeObserver = ToolbarThemeObserver()
    
    // 添加触觉反馈生成器
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    
    // 添加新状态来跟踪是否已移动位置
    @State private var hasMovedPosition = false
    
    // 添加按钮点击保护状态
    @State private var buttonCooldowns: [ToolbarButtonType: Bool] = [:]
    @State private var isProcessingLiveMode: Bool = false
    
    // 添加冷却时间常量
    private let buttonCooldownDuration: TimeInterval = 0.5  // 普通按钮冷却时间
    private let liveCooldownDuration: TimeInterval = 1.0    // Live按钮冷却时间

    // 添加权限管理器
    @ObservedObject private var permissionManager = PermissionManager.shared
    
    var body: some View {
        // 只有在相机权限已授权时才显示工具条
        if permissionManager.cameraPermissionGranted {
            GeometryReader { geometry in
                ZStack {
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
                    .opacity(shouldHideToolbar ? 0 : 1) // 添加透明度动画
                    .animation(.easeInOut(duration: 0.3), value: shouldHideToolbar)
                    
                    // 添加画布视图（带有iOS 15检查）
                    if #available(iOS 15.0, *) {
                        if showDrawingCanvas || isDrawingPinned {
                            DrawingCanvasView(isVisible: $showDrawingCanvas, isPinned: $isDrawingPinned)
                        }
                    }
                }
                .ignoresSafeArea(.all, edges: .top)
                .onChange(of: showMakeupView) { newValue in
                    if !newValue {
                        // 当化妆视图关闭时，重新启用添加按钮
                        isAddButtonEnabled = true
                    }
                }
                .onAppear {
                    // 添加通知监听器
                    NotificationCenter.default.addObserver(
                        forName: NSNotification.Name("HideToolbars"),
                        object: nil,
                        queue: .main
                    ) { _ in
                        withAnimation {
                            shouldHideToolbar = true
                        }
                    }
                    
                    NotificationCenter.default.addObserver(
                        forName: NSNotification.Name("ShowToolbars"),
                        object: nil,
                        queue: .main
                    ) { _ in
                        withAnimation {
                            shouldHideToolbar = false
                        }
                    }
                }
            }
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
            Group {
                if !isCollapsed {
                    RoundedRectangle(cornerRadius: isVertical ? 12 : 20)
                        .fill(Color.black.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: isVertical ? 12 : 20)
                                .stroke(Color.white.opacity(isDragging ? 0.3 : 0), lineWidth: 2)
                        )
                }
            }
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
                    Group {
                        if !isCollapsed {
                            RoundedRectangle(cornerRadius: 0)
                                .fill(Color.yellow.opacity(0))
                        }
                    }
                )
                .frame(width: 40)  // 限制垂直布局时的宽度
            } else {
                HStack(spacing: utilityButtonSpacing) {  // 使用更小的间距
                    utilityButtonsContent()
                }
                .padding(.vertical, 5)  // 减小垂直内边距
                .padding(.horizontal, 10)  // 减小水平内边距
                .background(
                    Group {
                        if !isCollapsed {
                            RoundedRectangle(cornerRadius: 0)
                                .fill(Color.yellow.opacity(0))
                        }
                    }
                )
                .frame(height: 40)  // 限制水平布局时的高度
            }
        }
    }
    
    private func toolbarButtons() -> some View {
        Group {
            ForEach(ToolbarButtonType.allCases, id: \.rawValue) { buttonType in
                if !isCollapsed || buttonType == .capture {
                    Button(action: {
                        // 检查按钮是否在冷却中
                        if buttonCooldowns[buttonType] == true {
                            print("------------------------")
                            print("按钮在冷却中，忽略点击")
                            print("按钮类型：\(buttonType)")
                            print("------------------------")
                            return
                        }
                        
                        // 如果是Live按钮且正在处理中，忽略点击
                        if buttonType == .live && isProcessingLiveMode {
                            print("------------------------")
                            print("Live模式切换正在处理中，忽略点击")
                            print("------------------------")
                            return
                        }
                        
                        // 如果是实况按钮且用户不是Pro会员，则显示升级弹窗
                        if buttonType == .live && !proManager.isPro {
                            proManager.showProUpgrade()
                            print("------------------------")
                            print("[实况按钮] 点击")
                            print("状态：需要升级")
                            print("动作：显示升级弹窗")
                            print("------------------------")
                        } else {
                            // 设置按钮冷却
                            buttonCooldowns[buttonType] = true
                            
                            // 处理按钮点击
                            handleButtonTap(buttonType)
                            
                            // 延迟重置按钮冷却状态
                            DispatchQueue.main.asyncAfter(deadline: .now() + (buttonType == .live ? liveCooldownDuration : buttonCooldownDuration)) {
                                buttonCooldowns[buttonType] = false
                            }
                        }
                    }) {
                        Group {
                            if buttonType == .capture {
                                Circle()
                                    .fill(restartManager.isCameraActive ? styleManager.iconColor : styleManager.iconColor.opacity(0.3))
                                    .frame(width: buttonType.size, height: buttonType.size)
                            } else if buttonType == .zoom {
                                let percentage = Int(currentScale * 100)
                                let roundedPercentage = Int(round(Double(percentage) / 50.0) * 50)
                                let zoomText = currentScale <= 1.0 ? "100" : 
                                              currentScale >= 10.0 ? "1000" : 
                                              "\(roundedPercentage)"
                                Text(zoomText)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(restartManager.isCameraActive ? styleManager.iconColor : styleManager.iconColor.opacity(0.3))
                                    .frame(width: buttonType.size, height: buttonType.size)
                            } else if buttonType == .live {
                                ZStack {
                                    Image(systemName: cameraManager.isUsingSystemCamera ? "livephoto" : "livephoto.slash")
                                        .font(.system(size: 22))
                                        .foregroundColor(restartManager.isCameraActive ? (cameraManager.isUsingSystemCamera ? styleManager.iconColor : styleManager.iconColor.opacity(0.3)) : styleManager.iconColor.opacity(0.3))
                                        .frame(width: buttonType.size, height: buttonType.size)
                                    
                                    // 如果不是Pro会员，显示锁定图标
                                    if !proManager.isPro {
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(styleManager.iconColor.opacity(0.8))
                                            .offset(y: -15)  // 将锁定图标向上偏移
                                    }
                                }
                            } else {
                                Image(systemName: buttonType.icon)
                                    .font(.system(size: 22))
                                    .foregroundColor(restartManager.isCameraActive ? styleManager.iconColor : styleManager.iconColor.opacity(0.3))
                                    .frame(width: buttonType.size, height: buttonType.size)
                            }
                        }
                        .rotationEffect(getRotationAngle(orientationManager.currentOrientation))
                        .animation(.easeInOut(duration: 0.3), value: orientationManager.currentOrientation)
                    }
                    .disabled(!restartManager.isCameraActive || buttonCooldowns[buttonType] == true)
                    .opacity(buttonCooldowns[buttonType] == true ? 0.5 : 1.0)
                    .scaleEffect(isDragging ? 0.95 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
                }
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
                                cameraManager: self.cameraManager,
                                scale: self.currentScale  // 使用 currentScale 而不是 cameraManager.currentScale
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
            
            // 设置处理状态
            isProcessingLiveMode = true
            
            // 延迟执行相机切换，确保上一次操作完成
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // 切换系统相机
                cameraManager.toggleSystemCamera()
                
                print("切换后系统相机状态：\(cameraManager.isUsingSystemCamera)")
                print("------------------------")
                
                // 重置处理状态
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isProcessingLiveMode = false
                }
            }
            
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
            if !isCollapsed || buttonType == .drag {
                Group {
                    if buttonType == .drag {
                        // 拖拽按钮添加拖拽手势
                        GeometryReader { geometry in
                            Group {
                                if buttonType.isSystemIcon {
                                    Image(systemName: buttonType.icon)
                                        .font(.system(size: 16))
                                        .foregroundColor(restartManager.isCameraActive ? styleManager.iconColor : styleManager.iconColor.opacity(0.3))
                                        .frame(width: buttonType.size, height: buttonType.size)
                                } else {
                                    Image(buttonType.icon)
                                        .resizable()
                                        .renderingMode(.template) // 添加template渲染模式
                                        .scaledToFit()
                                        .foregroundColor(restartManager.isCameraActive ? styleManager.iconColor : styleManager.iconColor.opacity(0.3))
                                        .frame(width: buttonType.size, height: buttonType.size)
                                }
                            }
                            .contentShape(Rectangle().size(CGSize(width: 44, height: 44)))  // 增加触控区域到 44x44
                            .rotationEffect(getRotationAngle(orientationManager.currentOrientation))
                            .animation(.easeInOut(duration: 0.3), value: orientationManager.currentOrientation)
                            .onTapGesture {
                                print("------------------------")
                                print("工具栏：单击拖拽按钮 (onTapGesture)")
                                print("切换收缩状态：\(isCollapsed ? "展开" : "收缩")")
                                print("------------------------")
                                
                                feedbackGenerator.impactOccurred()
                                ViewActionLogger.shared.logAction(.utilityAction(.drag))
                                
                                // 切换收缩状态
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    isCollapsed.toggle()
                                }
                            }
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 10)
                                    .onChanged { value in
                                        print("------------------------")
                                        print("工具栏：拖拽按钮拖动开始")
                                        print("拖拽距离：\(sqrt(pow(value.translation.width, 2) + pow(value.translation.height, 2)))")
                                        print("------------------------")
                                        
                                        handleDragChange(value, in: geometry)
                                    }
                                    .onEnded { value in
                                        print("------------------------")
                                        print("工具栏：拖拽按钮拖动结束")
                                        print("------------------------")
                                        
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
                            if buttonType.isSystemIcon {
                                Image(systemName: buttonType.icon)
                                    .font(.system(size: 16))
                                    .foregroundColor(buttonType == .add && !isAddButtonEnabled ? styleManager.iconColor.opacity(0.3) : (restartManager.isCameraActive ? styleManager.iconColor : styleManager.iconColor.opacity(0.3)))
                                    .frame(width: buttonType.size, height: buttonType.size)
                            } else {
                                Image(buttonType.icon)
                                    .resizable()
                                    .renderingMode(.template)
                                    .scaledToFit()
                                    .foregroundColor(buttonType == .add && !isAddButtonEnabled ? styleManager.iconColor.opacity(0.3) : (restartManager.isCameraActive ? styleManager.iconColor : styleManager.iconColor.opacity(0.3)))
                                    .frame(width: buttonType.size, height: buttonType.size)
                            }
                        }
                        .contentShape(Rectangle().size(CGSize(width: 44, height: 44)))  // 增加触控区域到 44x44
                        .rotationEffect(getRotationAngle(orientationManager.currentOrientation))
                        .animation(.easeInOut(duration: 0.3), value: orientationManager.currentOrientation)
                        .disabled(!restartManager.isCameraActive || (buttonType == .add && !isAddButtonEnabled))
                        .scaleEffect(isDragging ? 0.95 : 1.0)
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
            }
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
            print("显示化妆工具视图")
            print("------------------------")
            withAnimation(.easeInOut(duration: 0.2)) {
                showMakeupView = true
                isAddButtonEnabled = false  // 禁用添加按钮
            }
            
        case .reference:
            ViewActionLogger.shared.logAction(.utilityAction(.reference))
            print("------------------------")
            print("工具栏：点击参考图标按钮")
            print("切换参考格纹图显示状态：\(showReferenceGrid ? "隐藏" : "显示")")
            print("------------------------")
            withAnimation(.easeInOut(duration: 0.2)) {
                showReferenceGrid.toggle()
            }
            
        case .drag:
            // 注意：拖拽按钮的点击现在由onTapGesture处理
            print("------------------------")
            print("工具栏：点击拖拽按钮（此路径不应被执行）")
            print("------------------------")
            
        case .brush:
            if #available(iOS 15.0, *) {
                ViewActionLogger.shared.logAction(.utilityAction(.brush))
                print("------------------------")
                print("工具栏：点击画笔按钮")
                print("显示绘画画布")
                print("------------------------")
                withAnimation(.easeInOut(duration: 0.2)) {
                    showDrawingCanvas = true
                }
            } else {
                print("------------------------")
                print("工具栏：画笔功能需要 iOS 15.0 或更高版本")
                print("------------------------")
            }
            
        case .close:
            ViewActionLogger.shared.logAction(.utilityAction(.close))
            print("------------------------")
            print("工具栏：点击关闭按钮")
            print("------------------------")
            
            // 调用 handleRestartViewAppear 方法
            restartManager.handleRestartViewAppear(cameraManager: cameraManager)
        }
    }
    
    // 获取设备方向的旋转角度
    private func getRotationAngle(_ orientation: UIDeviceOrientation) -> Angle {
        switch orientation {
        case .landscapeLeft:
            return .degrees(90)
        case .landscapeRight:
            return .degrees(-90)
        case .portraitUpsideDown:
            return .degrees(180)
        default:
            return .degrees(0)
        }
    }
}

#Preview {
    DraggableToolbar(
        captureState: CaptureState(),
        isVisible: .constant(true),
        showMakeupView: .constant(false),
        containerSelected: .constant(false),
        isLighted: .constant(false),
        previousBrightness: UIScreen.main.brightness,
        currentScale: .constant(1.0),
        baseScale: .constant(1.0),
        cameraManager: CameraManager(),
        showReferenceGrid: .constant(false)  // 添加参考格纹图状态
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
