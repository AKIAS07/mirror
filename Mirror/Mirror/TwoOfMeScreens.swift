import SwiftUI
import AVFoundation

// 定义屏幕ID
enum ScreenID {
    case original
    case mirrored
    
    var debugColor: Color {
        switch self {
        case .original:
            return Color.yellow.opacity(0.0)
        case .mirrored:
            return Color.red.opacity(0.0)
        }
    }
    
    var debugName: String {
        switch self {
        case .original:
            return "Original"
        case .mirrored:
            return "Mirrored"
        }
    }
}

struct ScreenContainer: View {
    let screenID: ScreenID
    let content: AnyView
    
    var body: some View {
        ZStack {
            // 底层：相机内容
            content
                .frame(height: UIScreen.main.bounds.height / 2)
            
            // 调试颜色层
            Rectangle()
                .fill(screenID.debugColor)
                .frame(height: UIScreen.main.bounds.height / 2)
        }
    }
}

struct ButtonContainer: View {
    let width: CGFloat
    let onSwapTapped: () -> Void
    
    var body: some View {
        // 黑色容器
        ZStack {
            // 背景
            Rectangle()
                .fill(Color.black)
                .frame(width: width, height: 60)
            
            // 交换图标按钮（扩大点击区域）
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 24, weight: .bold))  // 加大图标
                .foregroundColor(.white)
                .frame(width: 60, height: 60)  // 扩大框架
                .contentShape(Rectangle())  // 扩大点击区域
                .onTapGesture {
                    print("------------------------")
                    print("交换按钮被点击")
                    print("点击区域：60x60pt")
                    print("------------------------")
                    onSwapTapped()
                }
                .background(
                    // 可选：添加一个微弱的发光效果
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 40, height: 40)
                        .blur(radius: 5)
                )
        }
    }
}

// 修改边框容器视图
struct EdgeBorderContainer: View {
    let screenWidth: CGFloat
    let centerY: CGFloat
    let showTopBorder: Bool
    let showBottomBorder: Bool
    let showLeftBorder: Bool
    let showRightBorder: Bool
    
    // 添加动画状态
    @State private var topOpacity: Double = 0.0
    @State private var bottomOpacity: Double = 0.0
    @State private var leftOpacity: Double = 0.0
    @State private var rightOpacity: Double = 0.0
    
    var body: some View {
        Group {
            // 上边框
            Rectangle()
                .fill(Color.white)
                .opacity(topOpacity)  // 使用动画状态
                .frame(width: screenWidth, height: 20)
                .position(x: screenWidth/2, y: 10)
                .onChange(of: showTopBorder) { newValue in
                    handleBorderChange(newValue: newValue, binding: $topOpacity)
                }
            
            // 下边框
            Rectangle()
                .fill(Color.white)
                .opacity(bottomOpacity)
                .frame(width: screenWidth, height: 20)
                .position(x: screenWidth/2, y: centerY - 10)
                .onChange(of: showBottomBorder) { newValue in
                    handleBorderChange(newValue: newValue, binding: $bottomOpacity)
                }
            
            // 左边框
            Rectangle()
                .fill(Color.white)
                .opacity(leftOpacity)
                .frame(width: 20, height: centerY)
                .position(x: 10, y: centerY/2)
                .onChange(of: showLeftBorder) { newValue in
                    handleBorderChange(newValue: newValue, binding: $leftOpacity)
                }
            
            // 右边框
            Rectangle()
                .fill(Color.white)
                .opacity(rightOpacity)
                .frame(width: 20, height: centerY)
                .position(x: screenWidth - 10, y: centerY/2)
                .onChange(of: showRightBorder) { newValue in
                    handleBorderChange(newValue: newValue, binding: $rightOpacity)
                }
        }
        .zIndex(2)
        .animation(.easeInOut(duration: 0.3), value: topOpacity)
        .animation(.easeInOut(duration: 0.3), value: bottomOpacity)
        .animation(.easeInOut(duration: 0.3), value: leftOpacity)
        .animation(.easeInOut(duration: 0.3), value: rightOpacity)
    }
    
    // 处理边框显示/隐藏的函数
    private func handleBorderChange(newValue: Bool, binding: Binding<Double>) {
        if newValue {
            // 显示边框
            withAnimation(.easeIn(duration: 0.3)) {
                binding.wrappedValue = 1.0
            }
            // 1秒后隐藏
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeOut(duration: 0.3)) {
                    binding.wrappedValue = 0.0
                }
            }
        } else {
            // 立即隐藏
            withAnimation(.easeOut(duration: 0.3)) {
                binding.wrappedValue = 0.0
            }
        }
    }
}

struct TwoOfMeScreens: View {
    @StateObject private var cameraManager = CameraManager()
    @State private var originalImage: UIImage?
    @State private var mirroredImage: UIImage?
    @State private var containerWidth: CGFloat = 0
    @State private var showContainer = false
    @State private var isScreensSwapped = false
    @State private var isOriginalPaused = false  // Original画面定格状态
    @State private var isMirroredPaused = false  // Mirrored画面定格状态
    @State private var pausedOriginalImage: UIImage?  // 存储Original定格画面
    @State private var pausedMirroredImage: UIImage?  // 存储Mirrored定格画面
    
    // 触控区域可点击状态
    @State private var isZone1Enabled = true
    @State private var isZone2Enabled = true
    @State private var isZone3Enabled = true
    
    // 添加计算属性来获取当前布局状态描述
    private var layoutDescription: String {
        if !isScreensSwapped {
            return "Original在上，Mirrored在下"
        } else {
            return "Mirrored在上，Original在下"
        }
    }
    
    // Original 屏幕的��态
    @State private var originalScale: CGFloat = 1.0
    @State private var currentScale: CGFloat = 1.0  // 保持原来的名字
    
    // Mirrored 屏幕的状态
    @State private var mirroredScale: CGFloat = 1.0
    @State private var currentMirroredScale: CGFloat = 1.0
    
    @State private var lastScale: CGFloat = 1.0  // 添加记录上次缩放值的状态
    @State private var lastOutputTime: Date = Date()  // 添加上次输出时间记录
    private let outputInterval: TimeInterval = 0.2  // 设置输出时间间隔（秒）
    
    // 添加缩放限制常量
    private let minScale: CGFloat = 1.0     // 最小100%
    private let maxScale: CGFloat = 10.0    // 最大1000%
    
    @State private var showScaleLimitMessage = false  // 添加限制提示状态
    @State private var scaleLimitMessage = ""  // 添加限制提示信息
    
    // 添加拖动相关的状态和常量
    @State private var originalOffset: CGSize = .zero
    @State private var mirroredOffset: CGSize = .zero

    
    // 添加获取拖动方向的辅助函数
    private func getDragDirection(translation: CGSize) -> String {
        let angle = atan2(translation.height, translation.width)
        let degrees = angle * 180 / .pi
        
        switch degrees {
        case -45...45:
            return "向右"
        case 45...135:
            return "向下"
        case -135...(-45):
            return "向上"
        default:
            return "向左"
        }
    }
    
    // 封装缩放处理方法
    private func handlePinchGesture(
        scale: CGFloat,
        screenID: ScreenID,
        baseScale: CGFloat,
        currentScale: inout CGFloat
    ) {
        let newScale = baseScale * scale
        
        // 检查缩放限制
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
            
            let now = Date()
            if now.timeIntervalSince(lastOutputTime) >= outputInterval {
                print("------------------------")
                print("触控区\(screenID == .original ? "2" : "3")双指手势\(scale > 1.0 ? "拉开" : "靠近")")
                print("画面比例：\(Int(currentScale * 100))%")
                print("------------------------")
                lastOutputTime = now
            }
        }
    }
    
    // 封装手势结束处理方法
    private func handlePinchEnd(
        screenID: ScreenID,
        currentScale: CGFloat,
        baseScale: inout CGFloat
    ) {
        baseScale = currentScale
        showScaleLimitMessage = false
        print("------------------------")
        print("触控区\(screenID == .original ? "2" : "3")双指手势结束")
        print("最终画面比例：\(Int(baseScale * 100))%")
        print("------------------------")
    }
    
    // 添加计算最大可拖动范围的方法
    private func calculateMaxOffset(for scale: CGFloat, screenWidth: CGFloat, screenHeight: CGFloat) -> CGSize {
        // 计算放大后的图片尺寸
        let scaledWidth = screenWidth * scale
        let scaledHeight = (screenHeight / 2) * scale
        
        // 计算可拖动的最距离（图片边缘刚好到屏幕边缘）
        let maxHorizontalOffset = (scaledWidth - screenWidth) / 2
        let maxVerticalOffset = (scaledHeight - screenHeight / 2) / 2
        
        return CGSize(width: maxHorizontalOffset, height: maxVerticalOffset)
    }
    
    // 添加中心点相关属性
    private var screenCenter: CGPoint {
        CGPoint(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 4)  // Original屏幕中心
    }
    
    // 添加计算并应用中心对齐偏移的方法
    private func centerImage(at scale: CGFloat) {
        // 计算当前缩放比例下的最大可拖动范围
        let maxOffset = calculateMaxOffset(
            for: scale,
            screenWidth: UIScreen.main.bounds.width,
            screenHeight: UIScreen.main.bounds.height
        )
        
        // 重置偏移值为0（使图片回到中心）
        originalOffset = .zero
        
        print("------------------------")
        print("图片已自动居中")
        print("屏幕中心：x=\(Int(screenCenter.x)), y=\(Int(screenCenter.y))")
        print("最大可移动范围：\(Int(maxOffset.width))pt")
        print("------------------------")
    }
    
    // 添加判断图片是否超出边界的方法
    private func isImageOutOfBounds(scale: CGFloat, offset: CGSize, screenWidth: CGFloat, screenHeight: CGFloat) -> Bool {
        let maxOffset = calculateMaxOffset(
            for: scale,
            screenWidth: screenWidth,
            screenHeight: screenHeight
        )
        
        // 检查当前偏移是否超出新的最大偏移范围
        return abs(offset.width) > maxOffset.width || abs(offset.height) > maxOffset.height
    }
    
    // 添加设备方向状态
    @State private var deviceOrientation: UIDeviceOrientation = .portrait
    
    // 修改设备方向监听的代码
    private func startOrientationObserving() {
        // 确保以接收设备方向变化通知
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        
        NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [self] _ in
            // 立即更新设备方向状态
            deviceOrientation = UIDevice.current.orientation
            
            print("------------------------")
            print("设备方向改变")
            print("当前方向：\(getOrientationDescription(deviceOrientation))")
            print("------------------------")
        }
    }
    
    // 修改方向描述辅助方法，添加倒置竖屏的描述
    private func getOrientationDescription(_ orientation: UIDeviceOrientation) -> String {
        switch orientation {
        case .portrait:
            return "竖直"
        case .portraitUpsideDown:  // 添加倒置竖屏的描述
            return "倒置竖屏"
        case .landscapeLeft:
            return "向左横屏"
        case .landscapeRight:
            return "向右横屏"
        default:
            return "其他"
        }
    }
    
    // 修改获取旋转角度的方法
    private func getRotationAngle(_ orientation: UIDeviceOrientation) -> Angle {
        switch orientation {
        case .landscapeLeft:
            return .degrees(90)
        case .landscapeRight:
            return .degrees(-90)
        case .portraitUpsideDown:  // 添加倒置竖屏的处理
            return .degrees(180)
        default:
            return .degrees(0)
        }
    }
    
    // 添加拖动会话控制相关的状态变量
    @State private var isDragging: Bool = false        // 是否正在拖动
    @State private var dragSessionStarted: Bool = false // 当前拖动会话是否已开始
    @State private var initialDragLocation: CGPoint = .zero  // 录始置
    
    // 修改获取旋转后动偏移的方法
    private func getRotatedTranslation(_ translation: CGSize, for orientation: UIDeviceOrientation) -> CGSize {
        switch orientation {
        case .portrait:
            return translation
        case .portraitUpsideDown:
            return CGSize(width: -translation.width, height: -translation.height)
        case .landscapeLeft:
            return CGSize(width: translation.height, height: -translation.width)
        case .landscapeRight:
            return CGSize(width: -translation.height, height: translation.width)
        default:
            return translation
        }
    }
    
    // 添加拖动阻尼系数
    private let dragDampingFactor: CGFloat = 0.3  // 值越小，移动越不灵敏（0.0-1.0）
    
    // 添加记录初始触摸位置和初始偏移的状态
    @State private var initialTouchLocation: CGPoint = .zero
    @State private var initialOffset: CGSize = .zero
    
    // 添加一个状态变量来跟踪是否已经开始拖动
    @State private var dragStarted: Bool = false
    
    // 添加边框显示状态
    @State private var showTopBorder: Bool = false
    @State private var showBottomBorder: Bool = false
    @State private var showLeftBorder: Bool = false
    @State private var showRightBorder: Bool = false
    
    // 添加边缘检测方法
    private func detectEdges(
        offset: CGSize,
        maxOffset: CGSize,
        orientation: UIDeviceOrientation
    ) -> (left: Bool, right: Bool, top: Bool, bottom: Bool) {
        let threshold: CGFloat = 5.0
        
        // 计算基本边缘检测（竖屏状态）
        let baseDetection = (
            left: abs(offset.width - maxOffset.width) < threshold,
            right: abs(offset.width + maxOffset.width) < threshold,
            top: abs(offset.height - maxOffset.height) < threshold,
            bottom: abs(offset.height + maxOffset.height) < threshold
        )
        
        // 根据设备方向返回对应的边缘状态
        switch orientation {
        case .landscapeLeft:
            return (
                left: baseDetection.bottom,   // 上边变左边
                right: baseDetection.top,     // 下边变右边
                top: baseDetection.left,      // 右边变上边
                bottom: baseDetection.right   // 左边变下边
            )
        case .landscapeRight:
            return (
                left: baseDetection.top,      // 下边变左边
                right: baseDetection.bottom,  // 上边变右边
                top: baseDetection.right,     // 左边变上边
                bottom: baseDetection.left    // 右边变下边
            )
        case .portraitUpsideDown:
            return (
                left: baseDetection.right,    // 左右相反
                right: baseDetection.left,    // 左右相反
                top: baseDetection.bottom,    // 上下相反
                bottom: baseDetection.top     // 上下相反
            )
        default:
            return baseDetection
        }
    }
    
    // 修改拖拽处理方法中的边缘检测部分
    private func handleDragGesture(
        value: DragGesture.Value,
        screenWidth: CGFloat,
        screenHeight: CGFloat,
        centerY: CGFloat
    ) {
        if isZone2Enabled && currentScale > 1.0 {
            // 在拖动开始时记录初始状态和打印日志
            if !dragStarted {
                dragStarted = true
                
                // 记录初始态
                initialTouchLocation = value.startLocation
                initialOffset = originalOffset
                
                print("------------------------")
                print("Original画面拖动开始")
                print("手指位置：x=\(Int(value.startLocation.x))pt, y=\(Int(value.startLocation.y))pt")
                print("画面比例：\(Int(currentScale * 100))%")
                print("设备方向：\(getOrientationDescription(deviceOrientation))")
                print("------------------------")
            }
            
            // 根据设备方向调整移动方向
            var translation = value.translation
            switch deviceOrientation {
            case .landscapeLeft:
                translation = CGSize(
                    width: value.translation.height,
                    height: -value.translation.width
                )
            case .landscapeRight:
                translation = CGSize(
                    width: -value.translation.height,
                    height: value.translation.width
                )
            case .portraitUpsideDown:
                translation = CGSize(
                    width: -value.translation.width,
                    height: -value.translation.height
                )
            default:
                break
            }
            
            // 计算和应用新的偏移值
            let newOffset = CGSize(
                width: initialOffset.width + translation.width,
                height: initialOffset.height + translation.height
            )
            
            let maxOffset = calculateMaxOffset(
                for: currentScale,
                screenWidth: screenWidth,
                screenHeight: screenHeight
            )
            
            originalOffset = CGSize(
                width: max(min(newOffset.width, maxOffset.width), -maxOffset.width),
                height: max(min(newOffset.height, maxOffset.height), -maxOffset.height)
            )
            
            // 使用封装的边缘检测方法
            let edges = detectEdges(
                offset: originalOffset,
                maxOffset: maxOffset,
                orientation: deviceOrientation
            )
            
            // 更新边框状态
            showLeftBorder = edges.left
            showRightBorder = edges.right
            showTopBorder = edges.top
            showBottomBorder = edges.bottom
            
            // 打印调试信息
            print("------------------------")
            print("边缘检测状态")
            print("设备方向：\(getOrientationDescription(deviceOrientation))")
            if edges.left { print("  左边缘重合") }
            if edges.right { print("  右边缘重合") }
            if edges.top { print("  下边缘重合") }
            if edges.bottom { print("  上边缘重合") }
            print("------------------------")
        }
    }
    
    // 添加拖拽结束处理方法
    private func handleDragEnd() {
        // ���置拖动状态
        dragStarted = false
        
        print("------------------------")
        print("Original画面拖动结束")
        print("最终偏：x=\(Int(originalOffset.width))pt, y=\(Int(originalOffset.height))pt")
        print("画面比例：\(Int(currentScale * 100))%")
        print("------------------------")
    }
    
    // 添加 Mirrored 屏幕的拖拽相关状态
    @State private var mirroredDragStarted: Bool = false
    @State private var mirroredInitialTouchLocation: CGPoint = .zero
    @State private var mirroredInitialOffset: CGSize = .zero

    // 添加 Mirrored 屏幕的边框状态
    @State private var showMirroredTopBorder: Bool = false
    @State private var showMirroredBottomBorder: Bool = false
    @State private var showMirroredLeftBorder: Bool = false
    @State private var showMirroredRightBorder: Bool = false

    // 添加 Mirrored 屏幕的拖拽处理方法
    private func handleMirroredDragGesture(
        value: DragGesture.Value,
        screenWidth: CGFloat,
        screenHeight: CGFloat,
        centerY: CGFloat
    ) {
        if isZone3Enabled && currentMirroredScale > 1.0 {
            // 在拖动开始时记录初始状态和打印日志
            if !mirroredDragStarted {
                mirroredDragStarted = true
                
                // 记录初始状态
                mirroredInitialTouchLocation = value.startLocation
                mirroredInitialOffset = mirroredOffset
                
                print("------------------------")
                print("Mirrored画面拖动开始")
                print("手指位置：x=\(Int(value.startLocation.x))pt, y=\(Int(value.startLocation.y))pt")
                print("画面比例：\(Int(currentMirroredScale * 100))%")
                print("设备方向：\(getOrientationDescription(deviceOrientation))")
                print("------------------------")
            }
            
            // 根据设备方向调整移动方向
            var translation = value.translation
            switch deviceOrientation {
            case .landscapeLeft:
                translation = CGSize(
                    width: value.translation.height,
                    height: -value.translation.width
                )
            case .landscapeRight:
                translation = CGSize(
                    width: -value.translation.height,
                    height: value.translation.width
                )
            case .portraitUpsideDown:
                translation = CGSize(
                    width: -value.translation.width,
                    height: -value.translation.height
                )
            default:
                break
            }
            
            // 计算和应用新的偏移值
            let newOffset = CGSize(
                width: mirroredInitialOffset.width + translation.width,
                height: mirroredInitialOffset.height + translation.height
            )
            
            let maxOffset = calculateMaxOffset(
                for: currentMirroredScale,
                screenWidth: screenWidth,
                screenHeight: screenHeight
            )
            
            mirroredOffset = CGSize(
                width: max(min(newOffset.width, maxOffset.width), -maxOffset.width),
                height: max(min(newOffset.height, maxOffset.height), -maxOffset.height)
            )
            
            // 使用边缘检测方法
            let edges = detectEdges(
                offset: mirroredOffset,
                maxOffset: maxOffset,
                orientation: deviceOrientation
            )
            
            // 更新边框状态
            showMirroredLeftBorder = edges.left
            showMirroredRightBorder = edges.right
            showMirroredTopBorder = edges.top
            showMirroredBottomBorder = edges.bottom
            
            // 打印调试信息
            print("------------------------")
            print("Mirrored边缘检测状态")
            print("设备方向：\(getOrientationDescription(deviceOrientation))")
            if edges.left { print("  左边缘重合") }
            if edges.right { print("  右边缘重合") }
            if edges.top { print("  下边框重合") }
            if edges.bottom { print("  上边缘重合") }
            print("------------------------")
        }
    }

    // 添加 Mirrored 拖拽结束处理方法
    private func handleMirroredDragEnd() {
        // 重置拖动状态
        mirroredDragStarted = false
        
        print("------------------------")
        print("Mirrored画面拖动结束")
        print("最终偏移：x=\(Int(mirroredOffset.width))pt, y=\(Int(mirroredOffset.height))pt")
        print("画面比例：\(Int(currentMirroredScale * 100))%")
        print("------------------------")
    }
    
    // 添加 Mirrored 屏幕的中心点矫正方法
    private func centerMirroredImage(at scale: CGFloat) {
        // 计算当前缩放比例下的最大可拖动范围
        let maxOffset = calculateMaxOffset(
            for: scale,
            screenWidth: UIScreen.main.bounds.width,
            screenHeight: UIScreen.main.bounds.height
        )
        
        // 重置偏移值为0（使图片回到中心）
        mirroredOffset = .zero
        
        print("------------------------")
        print("Mirrored图片已自动居中")
        print("屏幕中心：x=\(Int(screenCenter.x)), y=\(Int(screenCenter.y))")
        print("最大可移动范围：\(Int(maxOffset.width))pt")
        print("------------------------")
    }
    
    // 添加计时器相关状态
    @State private var hideContainerTimer: Timer?
    
    // 添加容器管理方法
    private func handleContainerVisibility(showContainer: Bool) {
        if showContainer {
            // 显示容器
            self.showContainer = true
            withAnimation(.linear(duration: 0.5)) {
                containerWidth = UIScreen.main.bounds.width
            }
            
            // 取消现有计时器
            hideContainerTimer?.invalidate()
            
            // 创建新计时器，3秒后自动隐藏
            hideContainerTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [self] _ in
                hideContainer()
            }
        } else {
            hideContainer()
        }
    }
    
    // 隐藏容器的方法
    private func hideContainer() {
        withAnimation(.linear(duration: 0.5)) {
            containerWidth = 0
        }
        // 等待动画完成后隐藏容器
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showContainer = false
        }
    }
    
    // 处理交换按钮点击
    private func handleSwapButtonTap() {
        print("------------------------")
        print("执行交换操作")
        print("当前布局：\(layoutDescription)")
        
        // 执行交换
        withAnimation {
            isScreensSwapped.toggle()
        }
        
        // 延迟打印换后状态
        DispatchQueue.main.async {
            print("交换完成")
            print("新布局：\(layoutDescription)")
            print("------------------------")
        }
        
        // 立即隐藏容器
        hideContainer()
    }
    
    // 添加边框灯管理器
    @StateObject private var borderLightManager = BorderLightManager()
    
    // 修改处理屏幕点击的方法
    private func handleScreenTap(screenID: ScreenID) {
        borderLightManager.toggleBorderLight(for: screenID)
    }
    
    // 添加点击时间跟踪
    @State private var lastTapTime: Date = Date()
    @State private var tapCount: Int = 0
    
    // 修改单击处理方法
    private func handleSingleTap(screenID: ScreenID) {
        let now = Date()
        let timeSinceLastTap = now.timeIntervalSince(lastTapTime)
        
        if timeSinceLastTap > 0.3 {  // 如果距离上次点击超过300ms，认为是新的单击
            tapCount = 1
            // 延迟处理单击，给长按和双击留出判断时间
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {  // 修改这里，从0.3改为0.6秒
                if self.tapCount == 1 {  // 如果在延迟期间没有发生第二次点击
                    handleScreenTap(screenID: screenID)
                }
            }
        } else {  // 300ms内的第二次点击
            tapCount += 1
        }
        lastTapTime = now
    }
    
    // 修改双击处理方法
    private func handleDoubleTap(screenID: ScreenID) {
        tapCount = 0  // 重置点击计数
        
        switch screenID {
        case .original:
            if isZone2Enabled {
                togglePauseState(for: .original)
            }
        case .mirrored:
            if isZone3Enabled {
                togglePauseState(for: .mirrored)
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let screenBounds = UIScreen.main.bounds
            let screenHeight = screenBounds.height
            let screenWidth = screenBounds.width
            let centerY = screenHeight / 2
            
            ZStack {
                // 背景
                Color.black.edgesIgnoringSafeArea(.all)
                
                // 上下分屏布局
                VStack(spacing: 0) {
                    // 根据交换状态决定显示个屏幕
                    if !isScreensSwapped {
                        // Original 屏幕在上
                        ScreenContainer(
                            screenID: .original,
                            content: AnyView(
                                ZStack {
                                    if let image = isOriginalPaused ? pausedOriginalImage : originalImage {
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: deviceOrientation.isLandscape ? screenHeight / 2 : screenWidth,
                                                   height: centerY)
                                            .scaleEffect(isOriginalPaused ? currentScale : currentScale)
                                            .offset(isOriginalPaused ? originalOffset : .zero)
                                            .rotationEffect(isOriginalPaused ? getRotationAngle(deviceOrientation) : .zero)
                                            .animation(.easeInOut(duration: 0.3), value: deviceOrientation)
                                            .clipped()
                                            .gesture(isOriginalPaused && currentScale > 1.0 ?
                                                DragGesture()
                                                    .onChanged { value in
                                                        handleDragGesture(
                                                            value: value,
                                                            screenWidth: screenWidth,
                                                            screenHeight: screenHeight,
                                                            centerY: centerY
                                                        )
                                                    }
                                                    .onEnded { _ in
                                                        handleDragEnd()
                                                    }
                                                : nil
                                            )
                                            .zIndex(1)
                                        
                                        // 添加边框容器
                                        if isOriginalPaused {
                                            EdgeBorderContainer(
                                                screenWidth: screenWidth,
                                                centerY: centerY,
                                                showTopBorder: showTopBorder,
                                                showBottomBorder: showBottomBorder,
                                                showLeftBorder: showLeftBorder,
                                                showRightBorder: showRightBorder
                                            )
                                        }
                                    }
                                    
                                    // 添加边框灯效果
                                    if borderLightManager.showOriginalHighlight {
                                        BorderLightView(
                                            screenWidth: screenWidth,
                                            centerY: centerY
                                        )
                                        .zIndex(2)
                                    }
                                }
                            )
                        )
                        
                        Rectangle()
                            .fill(Color.gray)
                            .frame(height: 1)
                        
                        // Mirrored 屏幕在下
                        ScreenContainer(
                            screenID: .mirrored,
                            content: AnyView(
                                ZStack {
                                    if let image = isMirroredPaused ? pausedMirroredImage : mirroredImage {
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: deviceOrientation.isLandscape ? screenHeight / 2 : screenWidth,
                                                   height: centerY)
                                            .scaleEffect(isMirroredPaused ? currentMirroredScale : currentMirroredScale)
                                            .offset(isMirroredPaused ? mirroredOffset : .zero)
                                            .rotationEffect(isMirroredPaused ? getRotationAngle(deviceOrientation) : .zero)
                                            .animation(.easeInOut(duration: 0.3), value: deviceOrientation)
                                            .clipped()
                                            .gesture(isMirroredPaused && currentMirroredScale > 1.0 ?
                                                DragGesture()
                                                    .onChanged { value in
                                                        handleMirroredDragGesture(
                                                            value: value,
                                                            screenWidth: screenWidth,
                                                            screenHeight: screenHeight,
                                                            centerY: centerY
                                                        )
                                                    }
                                                    .onEnded { _ in
                                                        handleMirroredDragEnd()
                                                    }
                                                : nil
                                            )
                                            .simultaneousGesture(  // 双指缩放手势
                                                MagnificationGesture()
                                                    .onChanged { scale in
                                                        if isZone3Enabled {
                                                            handlePinchGesture(
                                                                scale: scale,
                                                                screenID: .mirrored,
                                                                baseScale: mirroredScale,
                                                                currentScale: &currentMirroredScale
                                                            )
                                                        }
                                                    }
                                                    .onEnded { scale in
                                                        if isZone3Enabled {
                                                            handlePinchEnd(
                                                                screenID: .mirrored,
                                                                currentScale: currentMirroredScale,
                                                                baseScale: &mirroredScale
                                                            )
                                                        }
                                                    }
                                            )
                                            .zIndex(1)
                                        
                                        // 添加边框容器
                                        if isMirroredPaused {
                                            EdgeBorderContainer(
                                                screenWidth: screenWidth,
                                                centerY: centerY,
                                                showTopBorder: showMirroredTopBorder,
                                                showBottomBorder: showMirroredBottomBorder,
                                                showLeftBorder: showMirroredLeftBorder,
                                                showRightBorder: showMirroredRightBorder
                                            )
                                        }
                                    }
                                    
                                    // 添加边框灯效果
                                    if borderLightManager.showMirroredHighlight {
                                        BorderLightView(
                                            screenWidth: screenWidth,
                                            centerY: centerY
                                        )
                                        .zIndex(2)
                                    }
                                }
                            )
                        )
                    } else {
                        // Mirrored 屏幕在上
                        ScreenContainer(
                            screenID: .mirrored,
                            content: AnyView(
                                ZStack {
                                    if let image = isMirroredPaused ? pausedMirroredImage : mirroredImage {
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: deviceOrientation.isLandscape ? screenHeight / 2 : screenWidth,
                                                   height: centerY)
                                            .scaleEffect(isMirroredPaused ? currentMirroredScale : currentMirroredScale)
                                            .offset(isMirroredPaused ? mirroredOffset : .zero)
                                            .rotationEffect(isMirroredPaused ? getRotationAngle(deviceOrientation) : .zero)
                                            .animation(.easeInOut(duration: 0.3), value: deviceOrientation)
                                            .clipped()
                                            .gesture(isMirroredPaused && currentMirroredScale > 1.0 ?
                                                DragGesture()
                                                    .onChanged { value in
                                                        handleMirroredDragGesture(
                                                            value: value,
                                                            screenWidth: screenWidth,
                                                            screenHeight: screenHeight,
                                                            centerY: centerY
                                                        )
                                                    }
                                                    .onEnded { _ in
                                                        handleMirroredDragEnd()
                                                    }
                                                : nil
                                            )
                                            .simultaneousGesture(  // 双指缩放手势
                                                MagnificationGesture()
                                                    .onChanged { scale in
                                                        if isZone3Enabled {
                                                            handlePinchGesture(
                                                                scale: scale,
                                                                screenID: .mirrored,
                                                                baseScale: mirroredScale,
                                                                currentScale: &currentMirroredScale
                                                            )
                                                        }
                                                    }
                                                    .onEnded { scale in
                                                        if isZone3Enabled {
                                                            handlePinchEnd(
                                                                screenID: .mirrored,
                                                                currentScale: currentMirroredScale,
                                                                baseScale: &mirroredScale
                                                            )
                                                        }
                                                    }
                                            )
                                            .zIndex(1)
                                        
                                        // 添加边框容器
                                        if isMirroredPaused {
                                            EdgeBorderContainer(
                                                screenWidth: screenWidth,
                                                centerY: centerY,
                                                showTopBorder: showMirroredTopBorder,
                                                showBottomBorder: showMirroredBottomBorder,
                                                showLeftBorder: showMirroredLeftBorder,
                                                showRightBorder: showMirroredRightBorder
                                            )
                                        }
                                    }
                                    
                                    // 添加边框灯效果
                                    if borderLightManager.showMirroredHighlight {
                                        BorderLightView(
                                            screenWidth: screenWidth,
                                            centerY: centerY
                                        )
                                        .zIndex(2)
                                    }
                                }
                            )
                        )
                        
                        Rectangle()
                            .fill(Color.gray)
                            .frame(height: 1)
                        
                        // Original 屏幕在下
                        ScreenContainer(
                            screenID: .original,
                            content: AnyView(
                                ZStack {
                                    if let image = isOriginalPaused ? pausedOriginalImage : originalImage {
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: deviceOrientation.isLandscape ? screenHeight / 2 : screenWidth,
                                                   height: centerY)
                                            .scaleEffect(isOriginalPaused ? currentScale : currentScale)
                                            .offset(isOriginalPaused ? originalOffset : .zero)
                                            .rotationEffect(isOriginalPaused ? getRotationAngle(deviceOrientation) : .zero)
                                            .animation(.easeInOut(duration: 0.3), value: deviceOrientation)
                                            .clipped()
                                            .gesture(isOriginalPaused && currentScale > 1.0 ?
                                                DragGesture()
                                                    .onChanged { value in
                                                        handleDragGesture(
                                                            value: value,
                                                            screenWidth: screenWidth,
                                                            screenHeight: screenHeight,
                                                            centerY: centerY
                                                        )
                                                    }
                                                    .onEnded { _ in
                                                        handleDragEnd()
                                                    }
                                                : nil
                                            )
                                            .zIndex(1)
                                        
                                        // 添加边框容器
                                        if isOriginalPaused {
                                            EdgeBorderContainer(
                                                screenWidth: screenWidth,
                                                centerY: centerY,
                                                showTopBorder: showTopBorder,
                                                showBottomBorder: showBottomBorder,
                                                showLeftBorder: showLeftBorder,
                                                showRightBorder: showRightBorder
                                            )
                                        }
                                    }
                                    
                                    // 添加边框灯效果
                                    if borderLightManager.showOriginalHighlight {
                                        BorderLightView(
                                            screenWidth: screenWidth,
                                            centerY: centerY
                                        )
                                        .zIndex(2)
                                    }
                                }
                            )
                        )
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: isScreensSwapped)  // 添加交换动画
                
                // 触控区域
                ZStack {
                    // Original的触控区2和2a
                    VStack {
                        if !isOriginalPaused {
                            // 触控区2（未定格状态）
                            Color.clear
                                .contentShape(Rectangle())
                                .frame(height: (screenHeight - 20) / 2)
                                .simultaneousGesture(  // 单击手势保持低优先级
                                    TapGesture(count: 1)
                                        .onEnded {
                                            if isZone2Enabled {
                                                handleSingleTap(screenID: .original)
                                            }
                                        }
                                )
                                .highPriorityGesture(  // 双击手势设置为优先级
                                    TapGesture(count: 2)
                                        .onEnded {
                                            if isZone2Enabled {
                                                print("------------------------")
                                                print("触控区2被双击")
                                                print("区域：Original屏幕")
                                                print("位置：\(isScreensSwapped ? "下部" : "上部")")
                                                print("进入触控区2a")
                                                
                                                togglePauseState(for: .original)
                                                
                                                print("当前布局：\(layoutDescription)")
                                                print("------------------------")
                                            }
                                        }
                                )
                                .simultaneousGesture(  // 添加双指缩放手势
                                    MagnificationGesture()
                                        .onChanged { scale in
                                            if isZone2Enabled {
                                                handlePinchGesture(
                                                    scale: scale,
                                                    screenID: .original,
                                                    baseScale: originalScale,
                                                    currentScale: &currentScale
                                                )
                                            }
                                        }
                                        .onEnded { scale in
                                            if isZone2Enabled {
                                                handlePinchEnd(
                                                    screenID: .original,
                                                    currentScale: currentScale,
                                                    baseScale: &originalScale
                                                )
                                            }
                                        }
                                )
                                .simultaneousGesture(  // 添加长按手势
                                    LongPressGesture(minimumDuration: 0.8)
                                        .onEnded { _ in
                                            if isZone2Enabled {
                                                print("------------------------")
                                                print("触控区2被长按")
                                                print("区域：Original屏幕")
                                                print("位置：\(isScreensSwapped ? "下部" : "上部")")
                                                print("------------------------")
                                            }
                                        }
                                )
                        } else {
                            // 触控区2a（定格状态）
                            Color.clear
                                .contentShape(Rectangle())
                                .frame(height: (screenHeight - 20) / 2)
                                .gesture(
                                    TapGesture(count: 2)  // 双击退出
                                        .onEnded {
                                            if isZone2Enabled {
                                                print("------------------------")
                                                print("触控区2a被双击")
                                                print("区域：Original屏幕")
                                                print("位置：\(isScreensSwapped ? "下部" : "上部")")
                                                print("退出到触控区2")
                                                
                                                togglePauseState(for: .original)
                                                
                                                print("当前布局：\(layoutDescription)")
                                                print("------------------------")
                                            }
                                        }
                                )
                                .simultaneousGesture(  // 双指缩放
                                    MagnificationGesture()
                                        .onChanged { scale in
                                            if isZone2Enabled {
                                                let newScale = originalScale * scale
                                                currentScale = min(max(newScale, minScale), maxScale)
                                                print("------------------------")
                                                print("触控区2a双指手势：\(scale > 1.0 ? "拉开" : "靠近")")
                                                print("画面比例：\(Int(currentScale * 100))%")
                                                print("------------------------")
                                            }
                                        }
                                        .onEnded { scale in
                                            if isZone2Enabled {
                                                originalScale = currentScale
                                                print("------------------------")
                                                print("触控区2a双指手势结束")
                                                print("最终画面比例：\(Int(originalScale * 100))%")
                                                
                                                // 只在缩小操作且图片超出边界时行中心位置矫正
                                                if scale < 1.0 && isImageOutOfBounds(
                                                    scale: currentScale,
                                                    offset: originalOffset,
                                                    screenWidth: UIScreen.main.bounds.width,
                                                    screenHeight: UIScreen.main.bounds.height
                                                ) {
                                                    print("图片超出边界，执行缩小后的中心位置矫正")
                                                    centerImage(at: currentScale)
                                                } else {
                                                    print("图片在边界内，保持当前位置")
                                                }
                                                
                                                print("------------------------")
                                            }
                                        }
                                )
                                .simultaneousGesture(  // 修改拖动手势代码
                                    DragGesture()
                                        .onChanged { value in
                                            handleDragGesture(
                                                value: value,
                                                screenWidth: screenWidth,
                                                screenHeight: screenHeight,
                                                centerY: centerY
                                            )
                                        }
                                        .onEnded { _ in
                                            handleDragEnd()
                                        }
                                )
                                .simultaneousGesture(  // 添加长按手势
                                    LongPressGesture(minimumDuration: 0.8)
                                        .onEnded { _ in
                                            if isZone2Enabled {
                                                print("------------------------")
                                                print("触控区2a被长按")
                                                print("区域：Original屏幕（定格状态）")
                                                print("位置：\(isScreensSwapped ? "下部" : "上部")")
                                                print("------------------------")
                                            }
                                        }
                                )
                        }
                        Spacer()
                    }
                    .frame(height: screenHeight / 2)
                    .position(x: screenWidth/2, y: isScreensSwapped ? screenHeight*3/4 : screenHeight/4)
                    
                    // Mirrored屏的触控区3和3a
                    VStack {
                        if !isMirroredPaused {
                            // 触控区3（未定格状态）
                            Color.clear
                                .contentShape(Rectangle())
                                .frame(height: (screenHeight - 20) / 2)
                                .simultaneousGesture(  // 单击手势保持低优先级
                                    TapGesture(count: 1)
                                        .onEnded {
                                            if isZone3Enabled {
                                                handleSingleTap(screenID: .mirrored)
                                            }
                                        }
                                )
                                .highPriorityGesture(  // 双击手势设置为高优先级
                                    TapGesture(count: 2)
                                        .onEnded {
                                            if isZone3Enabled {
                                                print("------------------------")
                                                print("触控区3被双击")
                                                print("区域：Mirrored屏幕")
                                                print("位置：\(isScreensSwapped ? "上部" : "下部")")
                                                print("进入触控区3a")
                                                
                                                togglePauseState(for: .mirrored)
                                                
                                                print("当前布局：\(layoutDescription)")
                                                print("------------------------")
                                            }
                                        }
                                )
                                .simultaneousGesture(  // 添加双指缩放手势
                                    MagnificationGesture()
                                        .onChanged { scale in
                                            if isZone3Enabled {
                                                handlePinchGesture(
                                                    scale: scale,
                                                    screenID: .mirrored,
                                                    baseScale: mirroredScale,
                                                    currentScale: &currentMirroredScale
                                                )
                                            }
                                        }
                                        .onEnded { scale in
                                            if isZone3Enabled {
                                                handlePinchEnd(
                                                    screenID: .mirrored,
                                                    currentScale: currentMirroredScale,
                                                    baseScale: &mirroredScale
                                                )
                                            }
                                        }
                                )
                                .simultaneousGesture(  // 添加长按手势
                                    LongPressGesture(minimumDuration: 0.8)
                                        .onEnded { _ in
                                            if isZone3Enabled {
                                                print("------------------------")
                                                print("触控区3被长按")
                                                print("区域：Mirrored屏幕")
                                                print("位置：\(isScreensSwapped ? "上部" : "下部")")
                                                print("------------------------")
                                            }
                                        }
                                )
                        } else {
                            // 触控区3a（定格状态）
                            Color.clear
                                .contentShape(Rectangle())
                                .frame(height: (screenHeight - 20) / 2)
                                .gesture(
                                    TapGesture(count: 2)  // 双击退出
                                        .onEnded {
                                            if isZone3Enabled {
                                                print("------------------------")
                                                print("触控区3a被双击")
                                                print("区域：Mirrored屏幕")
                                                print("位置：\(isScreensSwapped ? "下部" : "上部")")
                                                print("退出到触控区3")
                                                
                                                togglePauseState(for: .mirrored)
                                                
                                                print("当前布局：\(layoutDescription)")
                                                print("------------------------")
                                            }
                                        }
                                )
                                .simultaneousGesture(  // 双指缩放
                                    MagnificationGesture()
                                        .onChanged { scale in
                                            if isZone3Enabled {
                                                let newScale = mirroredScale * scale
                                                currentMirroredScale = min(max(newScale, minScale), maxScale)
                                                print("------------------------")
                                                print("触控区3a双指手势：\(scale > 1.0 ? "拉开" : "靠近")")
                                                print("画面比例：\(Int(currentMirroredScale * 100))%")
                                                print("------------------------")
                                            }
                                        }
                                        .onEnded { scale in
                                            if isZone3Enabled {
                                                mirroredScale = currentMirroredScale
                                                print("------------------------")
                                                print("触控区3a双指手势结束")
                                                print("最终画面比例：\(Int(mirroredScale * 100))%")
                                                
                                                // 添加缩小操作的边界检查和中心矫正
                                                if scale < 1.0 && isImageOutOfBounds(
                                                    scale: currentMirroredScale,
                                                    offset: mirroredOffset,
                                                    screenWidth: UIScreen.main.bounds.width,
                                                    screenHeight: UIScreen.main.bounds.height
                                                ) {
                                                    print("图片超出边界，执行缩小后的中心位置矫正")
                                                    centerMirroredImage(at: currentMirroredScale)
                                                } else {
                                                    print("图片在边界内，保持当前位置")
                                                }
                                                
                                                print("------------------------")
                                            }
                                        }
                                )
                                .simultaneousGesture(  // 添加拖动手势
                                    DragGesture()
                                        .onChanged { value in
                                            handleMirroredDragGesture(
                                                value: value,
                                                screenWidth: screenWidth,
                                                screenHeight: screenHeight,
                                                centerY: centerY
                                            )
                                        }
                                        .onEnded { _ in
                                            handleMirroredDragEnd()
                                        }
                                )
                                .simultaneousGesture(  // 添加长按手势
                                    LongPressGesture(minimumDuration: 0.8)
                                        .onEnded { _ in
                                            if isZone3Enabled {
                                                print("------------------------")
                                                print("触控区3a被长按")
                                                print("区域：Mirrored屏幕（定格状态）")
                                                print("位置：\(isScreensSwapped ? "上部" : "下部")")
                                                print("------------------------")
                                            }
                                        }
                                )
                        }
                        Spacer()
                    }
                    .frame(height: screenHeight / 2)
                    .position(x: screenWidth/2, y: isScreensSwapped ? screenHeight/4 : screenHeight*3/4)
                    
                    // 触控1（透明形）
                    ZStack {
                        Color.clear
                            .contentShape(Rectangle())
                            .frame(width: screenWidth, height: 20)
                        
                        // 按钮容器
                        if showContainer {
                            ButtonContainer(width: containerWidth) {
                                handleSwapButtonTap()
                            }
                            .animation(.linear(duration: 0.5), value: containerWidth)
                        }
                    }
                    .position(x: screenWidth/2, y: screenHeight/2)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { gesture in
                                if isZone1Enabled {
                                    print("------------------------")
                                    print("触控区1被点击")
                                    print("区域：中央透明矩形")
                                    print("点击位置：(x=\(Int(gesture.location.x)), y=\(Int(gesture.location.y)))pt")
                                    print("可点击状态：已启用")
                                    print("------------------------")
                                    
                                    handleContainerVisibility(showContainer: true)
                                } else {
                                    print("------------------------")
                                    print("触控区1禁��")
                                    print("------------------------")
                                }
                            }
                    )
                }
            }
            .onAppear {
                // 确保开启设备方向监听
                UIDevice.current.beginGeneratingDeviceOrientationNotifications()
                setupVideoProcessing()
                startOrientationObserving()
                print("------------------------")
                print("视图初始化")
                print("触控区2永远对应Original幕（双击可定格/恢复画面）")
                print("触控区3：永远对应Mirrored屏幕（双击可定格/恢复画面）")
                print("初始布局：\(layoutDescription)")
                print("------------------------")
            }
            .onDisappear {
                UIDevice.current.endGeneratingDeviceOrientationNotifications()
                NotificationCenter.default.removeObserver(self)
                hideContainerTimer?.invalidate()
                borderLightManager.turnOffAllLights()
            }
        }
        .ignoresSafeArea(.all)
    }
    
    private func setupVideoProcessing() {
        let processor = VideoProcessor()
        
        // 设置原始画面处理器
        processor.normalImageHandler = { image in
            DispatchQueue.main.async {
                self.originalImage = image
            }
        }
        
        // 设置镜像画面处理器
        processor.flippedImageHandler = { image in
            DispatchQueue.main.async {
                self.mirroredImage = image
            }
        }
        
        cameraManager.videoOutputDelegate = processor
        cameraManager.checkPermission()
    }
    
    // 添加布局变化监
    private func onLayoutChanged() {
        print("------------------------")
        print("布局生变化")
        print("当前布局：\(layoutDescription)")
        print("------------------------")
    }
    
    private func togglePauseState(for screenID: ScreenID) {
        switch screenID {
        case .original:
            if isOriginalPaused {
                // 退出定格状态
                isOriginalPaused = false
                pausedOriginalImage = nil
                // 保持当前缩放比例，不重置为1.0
                originalOffset = .zero
                print("Original画面已恢复")
            } else {
                // 进入定格状态
                isOriginalPaused = true
                
                // 根据设备方向调整定格画面
                if let image = originalImage {
                    switch deviceOrientation {
                    case .landscapeLeft:
                        pausedOriginalImage = image.rotate(degrees: -90)
                    case .landscapeRight:
                        pausedOriginalImage = image.rotate(degrees: 90)
                    case .portraitUpsideDown:
                        pausedOriginalImage = image.rotate(degrees: 180)
                    default:
                        pausedOriginalImage = image
                    }
                }
                
                // 保持当前缩放比例
                originalOffset = .zero
                print("Original画面已定格")
            }
            
        case .mirrored:
            if isMirroredPaused {
                // 退出定格状态
                isMirroredPaused = false
                pausedMirroredImage = nil
                // 保持当前缩放比例，不重置为1.0
                mirroredOffset = .zero
                print("Mirrored画面已恢复")
            } else {
                // 进入定格状态
                isMirroredPaused = true
                
                // 根据设备方向调整定格画面
                if let image = mirroredImage {
                    switch deviceOrientation {
                    case .landscapeLeft:
                        pausedMirroredImage = image.rotate(degrees: -90)
                    case .landscapeRight:
                        pausedMirroredImage = image.rotate(degrees: 90)
                    case .portraitUpsideDown:
                        pausedMirroredImage = image.rotate(degrees: 180)
                    default:
                        pausedMirroredImage = image
                    }
                }
                
                // 保持当前缩放比例
                mirroredOffset = .zero
                print("Mirrored画面已定格")
            }
        }
    }
}

// 添加 VideoProcessor 类
class VideoProcessor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    var normalImageHandler: ((UIImage) -> Void)?
    var flippedImageHandler: ((UIImage) -> Void)?
    let context = CIContext()
    private var lastLogTime: Date = Date()
    private let logInterval: TimeInterval = 1.0  // 最多出一次日志
    private var lastOrientation: UIDeviceOrientation = .unknown
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // 修正频方向
        connection.videoOrientation = .portrait
        connection.isVideoMirrored = true
        
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        
        // 生成正常画面
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            let normalImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
            DispatchQueue.main.async {
                self.normalImageHandler?(normalImage)
            }
        }
        
        // 生成镜像画面（备方向处理）
        var mirroredImage = ciImage.transformed(by: CGAffineTransform(scaleX: -1, y: 1))
        
        // 根据设备方向旋转镜像画面
        let deviceOrientation = UIDevice.current.orientation
        if deviceOrientation == .landscapeLeft || deviceOrientation == .landscapeRight {
            let rotationTransform = CGAffineTransform(translationX: ciImage.extent.width, y: ciImage.extent.height)
                .rotated(by: .pi)
            mirroredImage = mirroredImage.transformed(by: rotationTransform)
            
            // 只在向改变时输出次日志
            if deviceOrientation != lastOrientation {
                print("镜像画面根设备方向(\(deviceOrientation == .landscapeLeft ? "向左" : "向右"))整")
                lastOrientation = deviceOrientation
            }
        }
        
        if let cgImage = context.createCGImage(mirroredImage, from: mirroredImage.extent) {
            let flippedUIImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
            DispatchQueue.main.async {
                self.flippedImageHandler?(flippedUIImage)
            }
        }
    }
}

// 添 UIImage 扩展来处理图片旋转
extension UIImage {
    func rotate(degrees: CGFloat) -> UIImage {
        let radians = degrees * .pi / 180.0
        let rotatedSize = CGSize(
            width: size.width * abs(cos(radians)) + size.height * abs(sin(radians)),
            height: size.height * abs(cos(radians)) + size.width * abs(sin(radians))
        )
        
        UIGraphicsBeginImageContext(rotatedSize)
        let context = UIGraphicsGetCurrentContext()!
        
        context.translateBy(x: rotatedSize.width/2, y: rotatedSize.height/2)
        context.rotate(by: radians)
        draw(in: CGRect(
            x: -size.width/2,
            y: -size.height/2,
            width: size.width,
            height: size.height
        ))
        
        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return rotatedImage
    }
}

#Preview {
    TwoOfMeScreens()
} 

