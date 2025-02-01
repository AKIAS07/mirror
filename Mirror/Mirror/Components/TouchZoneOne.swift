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
    @Binding var isOriginalPaused: Bool
    @Binding var isMirroredPaused: Bool
    @Binding var pausedOriginalImage: UIImage?
    @Binding var pausedMirroredImage: UIImage?
    @State private var isScreenSwapped: Bool = false
    @State private var hideContainerTimer: Timer? = nil
    @ObservedObject private var styleManager = BorderLightStyleManager.shared
    let borderLightManager: BorderLightManager  // 修改为通过参数注入
    @State private var zone1LastTapTime: Date = Date()
    @State private var zone1TapCount: Int = 0
    @State private var lastOutputTime: Date = Date()
    @State private var isDraggingTouchZone: Bool = false
    @ObservedObject private var orientationManager = DeviceOrientationManager.shared  // 添加orientationManager
    
    let dragDampingFactor: CGFloat
    let animationDuration: TimeInterval
    let screenWidth: CGFloat
    let screenHeight: CGFloat
    let dragVerticalOffset: CGFloat
    let deviceOrientation: UIDeviceOrientation
    let screenshotManager: ScreenshotManager
    let handleSwapButtonTap: () -> Void
    let originalImage: UIImage?  // 移动到这里
    let mirroredImage: UIImage?  // 移动到这里
    
    // MARK: - Init
    init(
        showContainer: Binding<Bool>,
        containerWidth: Binding<CGFloat>,
        touchZonePosition: Binding<TouchZonePosition>,
        dragOffset: Binding<CGFloat>,
        isZone1Enabled: Binding<Bool>,
        isOriginalPaused: Binding<Bool>,
        isMirroredPaused: Binding<Bool>,
        pausedOriginalImage: Binding<UIImage?>,
        pausedMirroredImage: Binding<UIImage?>,
        originalImage: UIImage?,
        mirroredImage: UIImage?,
        dragDampingFactor: CGFloat,
        animationDuration: TimeInterval,
        screenWidth: CGFloat,
        screenHeight: CGFloat,
        dragVerticalOffset: CGFloat,
        deviceOrientation: UIDeviceOrientation,
        screenshotManager: ScreenshotManager,
        handleSwapButtonTap: @escaping () -> Void,
        borderLightManager: BorderLightManager
    ) {
        self._showContainer = showContainer
        self._containerWidth = containerWidth
        self._touchZonePosition = touchZonePosition
        self._dragOffset = dragOffset
        self._isZone1Enabled = isZone1Enabled
        self._isOriginalPaused = isOriginalPaused
        self._isMirroredPaused = isMirroredPaused
        self._pausedOriginalImage = pausedOriginalImage
        self._pausedMirroredImage = pausedMirroredImage
        self.dragDampingFactor = dragDampingFactor
        self.animationDuration = animationDuration
        self.screenWidth = screenWidth
        self.screenHeight = screenHeight
        self.dragVerticalOffset = dragVerticalOffset
        self.deviceOrientation = deviceOrientation
        self.screenshotManager = screenshotManager
        self.handleSwapButtonTap = handleSwapButtonTap
        self.borderLightManager = borderLightManager
        self.originalImage = originalImage  // 移到最后
        self.mirroredImage = mirroredImage  // 移到最后
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
                            print("原始偏移：\(Int(rawOffset))pt")
                            print("阻尼后偏移：\(Int(rawOffset * dragDampingFactor))pt")
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
                        print("最终位置：\(touchZonePosition)")
                        print("------------------------")
                    }
                }
        )
        .onLongPressGesture(minimumDuration: 0.5) {
            if isZone1Enabled {
                print("------------------------")
                print("触控区1被长按")
                print("区域：中央透明矩形")
                print("可点击状态：已启用")
                print("------------------------")
                
                handleContainerVisibility(showContainer: true)
            }
        }
        .onTapGesture {
            if isZone1Enabled {
                let now = Date()
                let timeSinceLastTap = now.timeIntervalSince(zone1LastTapTime)
                
                if timeSinceLastTap > 0.3 {  // 如果距离上次点击超过300ms，认为是新的单击
                    zone1TapCount = 1
                    
                    // 延迟处理单击，给双击留出判断时间
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if self.zone1TapCount == 1 {  // 如果在延迟期间没有发生第二次点击
                            if !self.styleManager.isDefaultGesture {  // 交换模式下的单击拍照
                                print("------------------------")
                                print("触控区1单击")
                                print("------------------------")
                                
                                // 如果两个屏幕都未定格，则执行定格和截图
                                if !self.isOriginalPaused && !self.isMirroredPaused {
                                    print("------------------------")
                                    print("开始定格两个屏幕")
                                    print("------------------------")
                                    
                                    // 先设置定格状态
                                    self.isOriginalPaused = true
                                    self.isMirroredPaused = true
                                    
                                    // 然后设置定格图像
                                    if let originalImg = self.originalImage {
                                        switch self.orientationManager.currentOrientation {
                                        case .landscapeLeft:
                                            self.pausedOriginalImage = originalImg.rotate(degrees: -90)
                                        case .landscapeRight:
                                            self.pausedOriginalImage = originalImg.rotate(degrees: 90)
                                        case .portraitUpsideDown:
                                            self.pausedOriginalImage = originalImg.rotate(degrees: 180)
                                        default:
                                            self.pausedOriginalImage = originalImg
                                        }
                                        print("Original画面已定格")
                                    }
                                    
                                    if let mirroredImg = self.mirroredImage {
                                        switch self.orientationManager.currentOrientation {
                                        case .landscapeLeft:
                                            self.pausedMirroredImage = mirroredImg.rotate(degrees: -90)
                                        case .landscapeRight:
                                            self.pausedMirroredImage = mirroredImg.rotate(degrees: 90)
                                        case .portraitUpsideDown:
                                            self.pausedMirroredImage = mirroredImg.rotate(degrees: 180)
                                        default:
                                            self.pausedMirroredImage = mirroredImg
                                        }
                                        print("Mirrored画面已定格")
                                    }
                                    
                                    print("------------------------")
                                    print("开始执行截图")
                                    print("Original定格状态: \(self.isOriginalPaused)")
                                    print("Mirrored定格状态: \(self.isMirroredPaused)")
                                    print("------------------------")
                                    
                                    // 更新截图管理器的图像引用并执行截图
                                    self.screenshotManager.setImages(
                                        original: self.pausedOriginalImage ?? self.originalImage,
                                        mirrored: self.pausedMirroredImage ?? self.mirroredImage
                                    )
                                    self.screenshotManager.captureDoubleScreens()
                                    
                                } else if self.isOriginalPaused && self.isMirroredPaused {
                                    // 如果两个屏幕都已定格，则退出定格状态
                                    print("------------------------")
                                    print("退出定格状态")
                                    print("------------------------")
                                    
                                    self.isOriginalPaused = false
                                    self.isMirroredPaused = false
                                    self.pausedOriginalImage = nil
                                    self.pausedMirroredImage = nil
                                    
                                    print("两个屏幕已退出定格")
                                    
                                } else {
                                    // 处理一个定格一个未定格的情况
                                    print("------------------------")
                                    print("一个屏幕已定格，定格另一个屏幕")
                                    print("------------------------")
                                    
                                    // 处理Original屏幕
                                    if !self.isOriginalPaused {
                                        self.isOriginalPaused = true
                                        if let originalImg = self.originalImage {
                                            switch self.orientationManager.currentOrientation {
                                            case .landscapeLeft:
                                                self.pausedOriginalImage = originalImg.rotate(degrees: -90)
                                            case .landscapeRight:
                                                self.pausedOriginalImage = originalImg.rotate(degrees: 90)
                                            case .portraitUpsideDown:
                                                self.pausedOriginalImage = originalImg.rotate(degrees: 180)
                                            default:
                                                self.pausedOriginalImage = originalImg
                                            }
                                            print("Original画面已定格")
                                        }
                                    }
                                    
                                    // 处理Mirrored屏幕
                                    if !self.isMirroredPaused {
                                        self.isMirroredPaused = true
                                        if let mirroredImg = self.mirroredImage {
                                            switch self.orientationManager.currentOrientation {
                                            case .landscapeLeft:
                                                self.pausedMirroredImage = mirroredImg.rotate(degrees: -90)
                                            case .landscapeRight:
                                                self.pausedMirroredImage = mirroredImg.rotate(degrees: 90)
                                            case .portraitUpsideDown:
                                                self.pausedMirroredImage = mirroredImg.rotate(degrees: 180)
                                            default:
                                                self.pausedMirroredImage = mirroredImg
                                            }
                                            print("Mirrored画面已定格")
                                        }
                                    }
                                    
                                    print("------------------------")
                                    print("开始执行截图")
                                    print("Original定格状态: \(self.isOriginalPaused)")
                                    print("Mirrored定格状态: \(self.isMirroredPaused)")
                                    print("------------------------")
                                    
                                    // 更新截图管理器的图像引用并执行截图
                                    self.screenshotManager.setImages(
                                        original: self.pausedOriginalImage ?? self.originalImage,
                                        mirrored: self.pausedMirroredImage ?? self.mirroredImage
                                    )
                                    self.screenshotManager.captureDoubleScreens()
                                }
                            } else {
                                // 默认模式：单击控制边框灯
                                print("------------------------")
                                print("触控区1被点击")
                                print("区域：中央透明矩形")
                                print("可点击状态：已启用")
                                print("------------------------")
                                
                                if self.borderLightManager.showOriginalHighlight || self.borderLightManager.showMirroredHighlight {
                                    self.borderLightManager.turnOffAllLights()
                                    print("所有边框灯已关闭")
                                } else {
                                    self.borderLightManager.turnOnAllLights()
                                    print("所有边框灯已开启")
                                }
                            }
                        }
                    }
                } else {  // 300ms内的第二次点击
                    zone1TapCount += 1
                    if zone1TapCount == 2 {  // 双击确认
                        print("------------------------")
                        print("触控区1被双击")
                        print("区域：中央透明矩形")
                        print("------------------------")
                        
                        // 根据手势设置决定双击功能
                        if self.styleManager.isDefaultGesture {
                            // 默认模式：双击拍照
                            print("------------------------")
                            print("触控区1双击拍照（默认模式）")
                            print("------------------------")
                            
                            // 如果两个屏幕都未定格，则先定格再截图
                            if !isOriginalPaused && !isMirroredPaused {
                                print("------------------------")
                                print("开始定格两个屏幕")
                                print("------------------------")
                                
                                // 先设置定格状态
                                isOriginalPaused = true
                                isMirroredPaused = true
                                
                                // 然后设置定格图像
                                if let originalImg = originalImage {
                                    switch orientationManager.currentOrientation {
                                    case .landscapeLeft:
                                        pausedOriginalImage = originalImg.rotate(degrees: -90)
                                    case .landscapeRight:
                                        pausedOriginalImage = originalImg.rotate(degrees: 90)
                                    case .portraitUpsideDown:
                                        pausedOriginalImage = originalImg.rotate(degrees: 180)
                                    default:
                                        pausedOriginalImage = originalImg
                                    }
                                    print("Original画面已定格")
                                }
                                
                                if let mirroredImg = mirroredImage {
                                    switch orientationManager.currentOrientation {
                                    case .landscapeLeft:
                                        pausedMirroredImage = mirroredImg.rotate(degrees: -90)
                                    case .landscapeRight:
                                        pausedMirroredImage = mirroredImg.rotate(degrees: 90)
                                    case .portraitUpsideDown:
                                        pausedMirroredImage = mirroredImg.rotate(degrees: 180)
                                    default:
                                        pausedMirroredImage = mirroredImg
                                    }
                                    print("Mirrored画面已定格")
                                }
                                
                                print("------------------------")
                                print("开始执行截图")
                                print("Original定格状态: \(isOriginalPaused)")
                                print("Mirrored定格状态: \(isMirroredPaused)")
                                print("------------------------")
                                
                                // 更新截图管理器的图像引用
                                self.screenshotManager.setImages(
                                    original: self.pausedOriginalImage ?? self.originalImage,
                                    mirrored: self.pausedMirroredImage ?? self.mirroredImage
                                )
                                
                                // 执行双屏截图
                                self.screenshotManager.captureDoubleScreens()
                                
                            } else if isOriginalPaused && isMirroredPaused {
                                // 如果两个屏幕都已定格，则退出定格状态
                                print("------------------------")
                                print("退出定格状态")
                                print("------------------------")
                                
                                isOriginalPaused = false
                                isMirroredPaused = false
                                pausedOriginalImage = nil
                                pausedMirroredImage = nil
                                
                                print("两个屏幕已退出定格")
                                
                            } else {
                                // 处理一个定格一个未定格的情况
                                print("------------------------")
                                print("一个屏幕已定格，定格另一个屏幕")
                                print("------------------------")
                                
                                // 处理Original屏幕
                                if !isOriginalPaused {
                                    isOriginalPaused = true
                                    if let originalImg = originalImage {
                                        switch orientationManager.currentOrientation {
                                        case .landscapeLeft:
                                            pausedOriginalImage = originalImg.rotate(degrees: -90)
                                        case .landscapeRight:
                                            pausedOriginalImage = originalImg.rotate(degrees: 90)
                                        case .portraitUpsideDown:
                                            pausedOriginalImage = originalImg.rotate(degrees: 180)
                                        default:
                                            pausedOriginalImage = originalImg
                                        }
                                        print("Original画面已定格")
                                    }
                                }
                                
                                // 处理Mirrored屏幕
                                if !isMirroredPaused {
                                    isMirroredPaused = true
                                    if let mirroredImg = mirroredImage {
                                        switch orientationManager.currentOrientation {
                                        case .landscapeLeft:
                                            pausedMirroredImage = mirroredImg.rotate(degrees: -90)
                                        case .landscapeRight:
                                            pausedMirroredImage = mirroredImg.rotate(degrees: 90)
                                        case .portraitUpsideDown:
                                            pausedMirroredImage = mirroredImg.rotate(degrees: 180)
                                        default:
                                            pausedMirroredImage = mirroredImg
                                        }
                                        print("Mirrored画面已定格")
                                    }
                                }
                                
                                print("------------------------")
                                print("开始执行截图")
                                print("Original定格状态: \(isOriginalPaused)")
                                print("Mirrored定格状态: \(isMirroredPaused)")
                                print("------------------------")
                                
                                // 更新截图管理器的图像引用并执行截图
                                self.screenshotManager.setImages(
                                    original: self.pausedOriginalImage ?? self.originalImage,
                                    mirrored: self.pausedMirroredImage ?? self.mirroredImage
                                )
                                self.screenshotManager.captureDoubleScreens()
                            }
                        } else {
                            // 交换模式：双击控制边框灯
                            if self.borderLightManager.showOriginalHighlight || self.borderLightManager.showMirroredHighlight {
                                self.borderLightManager.turnOffAllLights()
                                print("所有边框灯已关闭")
                            } else {
                                self.borderLightManager.turnOnAllLights()
                                print("所有边框灯已开启")
                            }
                        }
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