import SwiftUI

// MARK: - View Extension
extension View {
    @ViewBuilder
    func apply(colorModifier shouldApply: Bool) -> some View {
        if shouldApply {
            self.foregroundColor(BorderLightStyleManager.shared.splitScreenIconColor)
                .colorMultiply(BorderLightStyleManager.shared.splitScreenIconColor)
        } else {
            self
        }
    }
}

struct TouchZoneOne: View {
    // MARK: - Properties
    @Binding var showContainer: Bool
    @Binding var containerWidth: CGFloat
    @Binding var touchZonePosition: TouchZonePosition
    @Binding var dragOffset: CGFloat
    @Binding var isZone1Enabled: Bool
    @State private var isScreenSwapped: Bool = false
    @State private var hideContainerTimer: Timer? = nil
    @ObservedObject private var styleManager = BorderLightStyleManager.shared
    let originalImage: UIImage?
    let mirroredImage: UIImage?
    let isOriginalPaused: Bool
    let isMirroredPaused: Bool
    let pausedOriginalImage: UIImage?
    let pausedMirroredImage: UIImage?
    @State private var zone1LastTapTime: Date = Date()
    @State private var zone1TapCount: Int = 0
    @State private var lastOutputTime: Date = Date()
    @State private var isDraggingTouchZone: Bool = false
    
    let dragDampingFactor: CGFloat
    let animationDuration: TimeInterval
    let screenWidth: CGFloat
    let screenHeight: CGFloat
    let dragVerticalOffset: CGFloat
    let deviceOrientation: UIDeviceOrientation
    let screenshotManager: ScreenshotManager
    let handleSwapButtonTap: () -> Void
    
    // MARK: - Init
    init(
        showContainer: Binding<Bool>,
        containerWidth: Binding<CGFloat>,
        touchZonePosition: Binding<TouchZonePosition>,
        dragOffset: Binding<CGFloat>,
        isZone1Enabled: Binding<Bool>,
        originalImage: UIImage?,
        mirroredImage: UIImage?,
        isOriginalPaused: Bool,
        isMirroredPaused: Bool,
        pausedOriginalImage: UIImage?,
        pausedMirroredImage: UIImage?,
        dragDampingFactor: CGFloat,
        animationDuration: TimeInterval,
        screenWidth: CGFloat,
        screenHeight: CGFloat,
        dragVerticalOffset: CGFloat,
        deviceOrientation: UIDeviceOrientation,
        screenshotManager: ScreenshotManager,
        handleSwapButtonTap: @escaping () -> Void
    ) {
        self._showContainer = showContainer
        self._containerWidth = containerWidth
        self._touchZonePosition = touchZonePosition
        self._dragOffset = dragOffset
        self._isZone1Enabled = isZone1Enabled
        self.originalImage = originalImage
        self.mirroredImage = mirroredImage
        self.isOriginalPaused = isOriginalPaused
        self.isMirroredPaused = isMirroredPaused
        self.pausedOriginalImage = pausedOriginalImage
        self.pausedMirroredImage = pausedMirroredImage
        self.dragDampingFactor = dragDampingFactor
        self.animationDuration = animationDuration
        self.screenWidth = screenWidth
        self.screenHeight = screenHeight
        self.dragVerticalOffset = dragVerticalOffset
        self.deviceOrientation = deviceOrientation
        self.screenshotManager = screenshotManager
        self.handleSwapButtonTap = handleSwapButtonTap
    }
    
    // MARK: - Body
    var body: some View {
        ZStack {
            Image(getIconName(deviceOrientation))
                .resizable()
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
                .rotationEffect(getRotationAngle(deviceOrientation))
                .animation(.easeInOut(duration: 0.3), value: deviceOrientation)
                .apply(colorModifier: styleManager.splitScreenIconColor == .black || styleManager.splitScreenIconColor == .white)
            
            // 按钮容器
            if showContainer {
                ButtonContainer(width: containerWidth) {
                    handleSwapButtonTapInternal()
                }
                .rotationEffect(getRotationAngle(deviceOrientation))
                .animation(.linear(duration: 0.5), value: containerWidth)
            }
        }
        .position(x: screenWidth/2 + touchZonePosition.xOffset + (dragOffset * dragDampingFactor), y: screenHeight/2)
        .gesture(
            DragGesture(minimumDistance: 5.0)
                .onChanged { value in
                    if isZone1Enabled {
                        isDraggingTouchZone = true
                        
                        // 应用阻尼效果
                        let rawOffset = value.translation.width
                        dragOffset = rawOffset
                        
                        // 每隔100ms打印一次状态，减少日志输出频率
                        let now = Date()
                        if now.timeIntervalSince(lastOutputTime) >= 0.1 {
                            print("------------------------")
                            print("触控区1正在拖动")
                            print("原始偏移：\\(Int(rawOffset))pt")
                            print("阻尼后偏移：\\(Int(rawOffset * dragDampingFactor))pt")
                            print("------------------------")
                            lastOutputTime = now
                        }
                    }
                }
                .onEnded { value in
                    if isZone1Enabled {
                        isDraggingTouchZone = false
                        let totalOffset = touchZonePosition.xOffset + (value.translation.width * dragDampingFactor)
                        
                        // 根据最终位置决定停靠位置
                        withAnimation(
                            .interpolatingSpring(
                                duration: animationDuration,
                                bounce: 0.2,
                                initialVelocity: 0.5
                            )
                        ) {
                            if totalOffset < -50 {
                                touchZonePosition = .left
                            } else if totalOffset > 50 {
                                touchZonePosition = .right
                            } else {
                                touchZonePosition = .center
                            }
                            dragOffset = 0
                        }
                        
                        // 打印最终位置
                        print("------------------------")
                        print("触控区1拖动结束")
                        print("最终位置：\\(touchZonePosition)")
                        print("------------------------")
                    }
                }
        )
        .onTapGesture {
            if isZone1Enabled {
                let now = Date()
                let timeSinceLastTap = now.timeIntervalSince(zone1LastTapTime)
                
                if timeSinceLastTap > 0.3 {  // 如果距离上次点击超过300ms，认为是新的单击
                    zone1TapCount = 1
                    // 延迟处理单击，给双击留出判断时间
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if self.zone1TapCount == 1 {  // 如果在延迟期间没有发生第二次点击
                            print("------------------------")
                            print("触控区1被点击")
                            print("区域：中央透明矩形")
                            print("可点击状态：已启用")
                            print("------------------------")
                            
                            handleContainerVisibility(showContainer: true)
                        }
                    }
                } else {  // 300ms内的第二次点击
                    zone1TapCount += 1
                    if zone1TapCount == 2 {  // 双击确认
                        print("------------------------")
                        print("触控区1被双击")
                        print("区域：中央透明矩形")
                        print("------------------------")
                        
                        // 更新截图管理器的图像引用
                        screenshotManager.setImages(
                            original: isOriginalPaused ? pausedOriginalImage : originalImage,
                            mirrored: isMirroredPaused ? pausedMirroredImage : mirroredImage
                        )
                        
                        // 执行双屏截图
                        screenshotManager.captureDoubleScreens()
                    }
                }
                zone1LastTapTime = now
            } else {
                print("------------------------")
                print("触控区1禁用")
                print("------------------------")
            }
        }
    }
    
    // MARK: - Helper Methods
    private func handleContainerVisibility(showContainer: Bool) {
        if showContainer {
            // 取消之前的定时器（如果存在）
            hideContainerTimer?.invalidate()
            
            self.showContainer = true
            withAnimation(.linear(duration: 0.5)) {
                containerWidth = screenWidth
            }
            
            // 创建新的定时器，2秒后隐藏容器
            hideContainerTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
                withAnimation(.linear(duration: 0.5)) {
                    self.containerWidth = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.showContainer = false
                }
            }
        }
    }
    
    private func getIconName(_ orientation: UIDeviceOrientation) -> String {
        // 根据分屏蝴蝶颜色设置选择图标
        if styleManager.splitScreenIconColor == .black || styleManager.splitScreenIconColor == .white {
            return "icon-bf-white"  // 使用白色轮廓的图标
        }
        
        // 选择彩色时使用默认的彩色图标逻辑
        switch orientation {
        case .landscapeLeft:
            return isScreenSwapped ? "icon-bf-color-3" : "icon-bf-color-4"
        case .landscapeRight:
            return isScreenSwapped ? "icon-bf-color-4" : "icon-bf-color-3"
        case .portraitUpsideDown:
            return isScreenSwapped ? "icon-bf-color-1" : "icon-bf-color-2"
        default: // 正常竖屏
            return isScreenSwapped ? "icon-bf-color-2" : "icon-bf-color-1"
        }
    }
    
    private func getIconColor() -> Color {
        // 根据设置返回对应的颜色
        return styleManager.splitScreenIconColor
    }
    
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
    
    private func handleSwapButtonTapInternal() {
        isScreenSwapped.toggle()
        handleSwapButtonTap()
        
        // 点击交换按钮后立即隐藏容器
        withAnimation(.linear(duration: 0.5)) {
            containerWidth = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showContainer = false
        }
        
        // 取消定时器
        hideContainerTimer?.invalidate()
        hideContainerTimer = nil
    }
} 