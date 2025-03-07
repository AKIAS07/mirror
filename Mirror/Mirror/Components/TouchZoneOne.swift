import SwiftUI

// MARK: - View Extension
extension View {
    @ViewBuilder
    func apply(colorModifier shouldApply: Bool) -> some View {
        if shouldApply && !BorderLightStyleManager.shared.splitScreenIconImage.hasPrefix("color") {
            self.colorMultiply(BorderLightStyleManager.shared.splitScreenIconColor)
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
    let borderLightManager: BorderLightManager
    let imageUploader: ImageUploader
    @State private var zone1LastTapTime: Date = Date()
    @State private var zone1TapCount: Int = 0
    @State private var lastOutputTime: Date = Date()
    @State private var isDraggingTouchZone: Bool = false
    @ObservedObject private var orientationManager = DeviceOrientationManager.shared
    
    let dragDampingFactor: CGFloat
    let animationDuration: TimeInterval
    let screenWidth: CGFloat
    let screenHeight: CGFloat
    let dragVerticalOffset: CGFloat
    let deviceOrientation: UIDeviceOrientation
    let screenshotManager: ScreenshotManager
    let handleSwapButtonTap: () -> Void
    let originalImage: UIImage?
    let mirroredImage: UIImage?
    
    @State private var showMiddleIconAnimation: Bool = false
    @State private var middleAnimationPosition: CGPoint = CGPoint(x: 0, y: 0)
    @State private var showTapAnimation: Bool = false
    @State private var showBorderLightTapAnimation: Bool = false
    @State private var showContainerWorkItem: DispatchWorkItem? = nil
    @State private var hasTriggeredLongPressHaptic: Bool = false
    
    let currentCameraScale: CGFloat  // 添加 Original 屏幕的摄像头缩放比例
    let currentMirroredCameraScale: CGFloat  // 添加 Mirrored 屏幕的摄像头缩放比例
    
    // 添加震动反馈生成器
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyFeedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let lightFeedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    
    // 添加摄像头基准缩放比例属性
    @State private var originalCameraScale: CGFloat = 1.0  // Original 屏幕的基准摄像头缩放比例
    @State private var mirroredCameraScale: CGFloat = 1.0  // Mirrored 屏幕的基准摄像头缩放比例
    
    let bothScreensRestarting: Bool
    let anyScreenRestarting: Bool  // 添加新属性
    let onDisabledAction: () -> Void
    let onPhotoDisabledAction: () -> Void  // 添加新的回调属性
    
    let dragScale: CGFloat  // 添加新属性
    
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
        borderLightManager: BorderLightManager,
        imageUploader: ImageUploader,
        currentCameraScale: CGFloat,  // Original 屏幕的当前摄像头缩放比例
        currentMirroredCameraScale: CGFloat,  // Mirrored 屏幕的当前摄像头缩放比例
        bothScreensRestarting: Bool,
        anyScreenRestarting: Bool,  // 添加新参数
        onDisabledAction: @escaping () -> Void,
        onPhotoDisabledAction: @escaping () -> Void,  // 添加新参数
        dragScale: CGFloat  // 添加新参数
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
        self.imageUploader = imageUploader
        self.originalImage = originalImage
        self.mirroredImage = mirroredImage
        self.currentCameraScale = currentCameraScale
        self.currentMirroredCameraScale = currentMirroredCameraScale
        self.bothScreensRestarting = bothScreensRestarting
        self.anyScreenRestarting = anyScreenRestarting
        self.onDisabledAction = onDisabledAction
        self.onPhotoDisabledAction = onPhotoDisabledAction
        self.dragScale = dragScale
        
        // 初始化时设置基准缩放比例为当前缩放比例
        self._originalCameraScale = State(initialValue: currentCameraScale)
        self._mirroredCameraScale = State(initialValue: currentMirroredCameraScale)
    }
    
    // MARK: - Body
    var body: some View {
        ZStack {
            // 主图标和动画容器
            ZStack {
                
                // 边框灯点击动画（动画a）
                if showBorderLightTapAnimation {
                    Image("icon-bf-white")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 75, height: 75)
                        .opacity(0.2)
                        .transition(.opacity)
                        .rotationEffect(getRotationAngle(orientationManager.currentOrientation))
                        .position(x: screenWidth/2 + touchZonePosition.xOffset + (dragOffset * dragDampingFactor), y: screenHeight/2)
                }
                
                // 拍照点击动画（动画b）
                if showTapAnimation {
                    // 蝴蝶图标动画
                    Image("icon-bf-white")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 150, height: 150)
                        .opacity(0.2)
                        .transition(.opacity)
                        .rotationEffect(getRotationAngle(orientationManager.currentOrientation))
                        .position(x: screenWidth/2 + touchZonePosition.xOffset + (dragOffset * dragDampingFactor), y: screenHeight/2)
                    
                    // 四角动画（仅在非全定格状态下显示）
                    if (isOriginalPaused && isMirroredPaused) {
                        SquareCornerAnimationView()
                            .opacity(0.8)
                            .scaleEffect(0.98)
                    }
                }


                // 主图标（放在最上层）
                Image(getIconName(deviceOrientation))
                    .resizable()
                    .frame(width: 40, height: 40)
                    .scaleEffect(dragScale)
                    .opacity(1.0 - (dragScale - 1.0) * 0.1)
                    .contentShape(Rectangle())
                    .rotationEffect(getRotationAngle(deviceOrientation))
                    .animation(.easeInOut(duration: 0.3), value: deviceOrientation)
                    .animation(.easeInOut(duration: 0.2), value: dragScale)
                    .apply(colorModifier: styleManager.splitScreenIconColor != .purple)
                    .position(x: screenWidth/2 + touchZonePosition.xOffset + (dragOffset * dragDampingFactor), y: screenHeight/2)
            }
            
            
            // 按钮容器
            if showContainer {
                ButtonContainer(width: containerWidth) {
                    handleSwapButtonTapInternal()
                }
                .animation(.linear(duration: 0.5), value: containerWidth)
                .position(x: screenWidth/2 + touchZonePosition.xOffset + (dragOffset * dragDampingFactor), y: screenHeight/2)
            }
        }
        .gesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    // 检查 Pro 权限
                    ProManager.shared.checkTouchZone1Access {
                        if bothScreensRestarting {
                            onDisabledAction()
                            return
                        }
                        // 触发长按震动反馈
                        heavyFeedbackGenerator.impactOccurred()
                        print("------------------------")
                        print("触控区1长按时间达到")
                        print("触发震动反馈")
                        print("------------------------")
                        
                        // 在这里直接开始显示中央透明矩形的延迟任务
                        if !isDraggingTouchZone {
                            // 取消之前的延迟任务（如果存在）
                            showContainerWorkItem?.cancel()
                            
                            // 创建新的延迟任务
                            let workItem = DispatchWorkItem {
                                handleContainerVisibility(showContainer: true)
                            }
                            showContainerWorkItem = workItem
                            
                            // 延迟0.3秒执行
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
                        }
                    }
                }
        )
        .simultaneousGesture(  // 使用 simultaneousGesture 添加拖动手势
            LongPressGesture(minimumDuration: 0.5)
                .sequenced(before: DragGesture(minimumDistance: 0))
                .onChanged { value in
                    // 检查 Pro 权限
                    ProManager.shared.checkTouchZone1Access {
                        switch value {
                        case .first(_):
                            break
                        case .second(true, let drag):
                            if let drag = drag {
                                let translation = drag.translation
                                let distance = sqrt(pow(translation.width, 2) + pow(translation.height, 2))
                                
                                if distance > 5 {  // 只处理移动超过阈值的情况
                                    // 重置长按震动状态
                                    hasTriggeredLongPressHaptic = false
                                    
                                    // 取消延迟显示任务
                                    showContainerWorkItem?.cancel()
                                    showContainerWorkItem = nil
                                    
                                    // 如果已经显示了交换按钮，立即隐藏
                                    if showContainer {
                                        showContainer = false
                                        containerWidth = 0
                                    }
                                    
                                    isDraggingTouchZone = true
                                    
                                    // 应用阻尼效果
                                    let rawOffset = translation.width
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
                        case .second(false, _):
                            hasTriggeredLongPressHaptic = false
                            break
                        }
                    }
                }
                .onEnded { _ in
                    // 检查 Pro 权限
                    ProManager.shared.checkTouchZone1Access {
                        // 重置长按震动状态
                        hasTriggeredLongPressHaptic = false
                        
                        if isZone1Enabled && isDraggingTouchZone {
                            isDraggingTouchZone = false
                            let totalOffset = touchZonePosition.xOffset + (dragOffset * dragDampingFactor)
                            
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
                            
                            // 触发震动反馈
                            feedbackGenerator.impactOccurred()
                            
                            // 打印最终位置
                            print("------------------------")
                            print("触控区1拖动结束")
                            print("最终位置：\(touchZonePosition)")
                            print("------------------------")
                        }
                    }
                }
        )
        .onTapGesture {
            // 检查 Pro 权限
            ProManager.shared.checkTouchZone1Access {
                if bothScreensRestarting {
                    onDisabledAction()
                    return
                }
                
                if isZone1Enabled {
                    let now = Date()
                    let timeSinceLastTap = now.timeIntervalSince(zone1LastTapTime)
                    
                    if timeSinceLastTap > 0.3 {  // 单击逻辑
                        zone1TapCount = 1
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            if self.zone1TapCount == 1 {
                                if anyScreenRestarting {  // 检查是否有任何屏幕在重启
                                    self.onPhotoDisabledAction()
                                    return
                                }
                                
                                // 触发单击震动反馈
                                self.feedbackGenerator.impactOccurred()
                                
                                if self.styleManager.isDefaultGesture {  // 默认模式：单击控制边框灯
                                    print("------------------------")
                                    print("触控区1单击控制边框灯（默认模式）")
                                    print("------------------------")
                                    
                                    // 显示边框灯动画
                                    showBorderLightAnimation()
                                    
                                    if self.borderLightManager.showOriginalHighlight || self.borderLightManager.showMirroredHighlight {
                                        self.borderLightManager.turnOffAllLights()
                                        print("所有边框灯已关闭")
                                    } else {
                                        self.borderLightManager.turnOnAllLights()
                                        print("所有边框灯已开启")
                                    }
                                } else {  // 交换模式：单击拍照
                                    print("------------------------")
                                    print("触控区1单击拍照（交换模式）")
                                    print("------------------------")
                                    
                                    // 显示拍照动画
                                    showPhotoAnimation()

                                    // 如果两个屏幕都未定格，则先定格再截图
                                    if !isOriginalPaused && !isMirroredPaused {
                                        handleScreenshot()
                                    } else if self.isOriginalPaused && self.isMirroredPaused {
                                        // 如果两个屏幕都已定格，则退出定格状态
                                        print("------------------------")
                                        print("退出定格状态")
                                        print("------------------------")
                                        
                                        // 先关闭所有手电筒
                                        imageUploader.closeAllFlashlights()
                                        
                                        // 然后退出定格状态
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
                                        if !isOriginalPaused {
                                            handleOriginalScreenPause()
                                        }
                                        
                                        // 处理Mirrored屏幕
                                        if !isMirroredPaused {
                                            handleMirroredScreenPause()
                                        }
                                        
                                        print("------------------------")
                                        print("开始执行截图")
                                        print("Original定格状态: \(isOriginalPaused)")
                                        print("Mirrored定格状态: \(isMirroredPaused)")
                                        print("------------------------")
                                        
                                        // 更新截图管理器的图像引用并执行截图
                                        self.screenshotManager.setImages(
                                            original: self.pausedOriginalImage ?? self.originalImage,
                                            mirrored: self.pausedMirroredImage ?? self.mirroredImage,
                                            originalCameraScale: self.currentCameraScale,
                                            mirroredCameraScale: self.currentMirroredCameraScale
                                        )
                                        self.screenshotManager.takeScreenshot()
                                    }
                                }
                            }
                        }
                    } else {  // 双击逻辑
                        zone1TapCount += 1
                        if zone1TapCount == 2 {
                            if anyScreenRestarting {  // 检查是否有任何屏幕在重启
                                self.onPhotoDisabledAction()
                                return
                            }
                            
                            // 触发双击震动反馈
                            lightFeedbackGenerator.impactOccurred(intensity: 0.8)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                self.lightFeedbackGenerator.impactOccurred(intensity: 1.0)
                            }
                            
                            print("------------------------")
                            print("触控区1被双击")
                            print("区域：中央透明矩形")
                            print("------------------------")
                            
                            // 根据手势设置决定双击功能
                            if self.styleManager.isDefaultGesture {  // 默认模式：双击拍照
                                print("------------------------")
                                print("触控区1双击拍照（默认模式）")
                                print("------------------------")
                                
                                // 显示拍照动画
                                showPhotoAnimation()

                                // 如果两个屏幕都未定格，则先定格再截图
                                if !isOriginalPaused && !isMirroredPaused {
                                    handleScreenshot()
                                } else if self.isOriginalPaused && self.isMirroredPaused {
                                    // 如果两个屏幕都已定格，则退出定格状态
                                    print("------------------------")
                                    print("退出定格状态")
                                    print("------------------------")
                                    
                                    // 先关闭所有手电筒
                                    imageUploader.closeAllFlashlights()
                                    
                                    // 然后退出定格状态
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
                                    if !isOriginalPaused {
                                        handleOriginalScreenPause()
                                    }
                                    
                                    // 处理Mirrored屏幕
                                    if !isMirroredPaused {
                                        handleMirroredScreenPause()
                                    }
                                    
                                    print("------------------------")
                                    print("开始执行截图")
                                    print("Original定格状态: \(isOriginalPaused)")
                                    print("Mirrored定格状态: \(isMirroredPaused)")
                                    print("------------------------")
                                    
                                    // 更新截图管理器的图像引用并执行截图
                                    self.screenshotManager.setImages(
                                        original: self.pausedOriginalImage ?? self.originalImage,
                                        mirrored: self.pausedMirroredImage ?? self.mirroredImage,
                                        originalCameraScale: self.currentCameraScale,
                                        mirroredCameraScale: self.currentMirroredCameraScale
                                    )
                                    self.screenshotManager.takeScreenshot()
                                }
                            } else {  // 交换模式：双击控制边框灯
                                // 显示边框灯动画
                                showBorderLightAnimation()
                                
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
                }
            }
        }
        .onAppear {
            // 预准备震动反馈生成器
            feedbackGenerator.prepare()
            heavyFeedbackGenerator.prepare()
            lightFeedbackGenerator.prepare()
            
            // 添加按钮颜色更新通知监听
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("UpdateButtonColors"),
                object: nil,
                queue: .main
            ) { _ in
                // 强制视图刷新
                withAnimation {
                    showContainer.toggle()
                    showContainer.toggle()
                }
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
        // 如果是 color1-6 图片，直接返回对应图片
        if styleManager.splitScreenIconImage.hasPrefix("color") {
            return styleManager.splitScreenIconImage
        }
        
        // 否则使用原来的逻辑
        if styleManager.splitScreenIconColor == .purple {
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
        
        return "icon-bf-white"  // 非紫色时使用白色轮廓的图标
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
        
        // 处理手电筒状态交换
        imageUploader.handleScreenSwap()
        
        // 更新截图管理器的屏幕交换状态
        screenshotManager.updateScreenSwapState(isScreenSwapped)
        
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
    
    // 添加动画触发辅助方法
    private func showPhotoAnimation() {
        withAnimation {
            showTapAnimation = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            withAnimation {
                showTapAnimation = false
            }
        }
    }
    
    private func showBorderLightAnimation() {
        withAnimation {
            showBorderLightTapAnimation = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            withAnimation {
                showBorderLightTapAnimation = false
            }
        }
    }
    
    // 添加一个辅助方法来处理图片旋转
    private func handleImageRotation(originalImg: UIImage, mirroredImg: UIImage) -> (UIImage, UIImage) {
        let currentOrientation = self.orientationManager.currentOrientation
        var rotatedOriginalImg = originalImg
        var rotatedMirroredImg = mirroredImg
        
        // 根据当前方向旋转图片
        switch currentOrientation {
        case .landscapeLeft:
            rotatedOriginalImg = originalImg.rotate(degrees: -90)
            rotatedMirroredImg = mirroredImg.rotate(degrees: -90)
        case .landscapeRight:
            rotatedOriginalImg = originalImg.rotate(degrees: 90)
            rotatedMirroredImg = mirroredImg.rotate(degrees: 90)
        case .portraitUpsideDown:
            rotatedOriginalImg = originalImg.rotate(degrees: 180)
            rotatedMirroredImg = mirroredImg.rotate(degrees: 180)
        default:
            // 正常竖屏不需要旋转
            break
        }
        
        print("[双屏定格] 方向处理:")
        print("当前设备方向: \(currentOrientation.rawValue)")
        print("已完成图片旋转")
        
        return (rotatedOriginalImg, rotatedMirroredImg)
    }
    
    // 修改截图调用部分
    private func handleDoubleTap() {
        print("------------------------")
        print("双击触发截图")
        print("------------------------")
        
        // 使用新的方法名
        ScreenshotManager.shared.takeScreenshot()
    }
    
    // 在 TouchZoneOne struct 中添加新的方法
    private func handleScreenshot() {
        print("------------------------")
        print("[双屏截图] 开始处理")
        print("------------------------")
        
        // 如果两个屏幕都未定格，则先定格再截图
        if !isOriginalPaused && !isMirroredPaused {
            handleBothScreensUnpaused()
        } else if isOriginalPaused && isMirroredPaused {
            // 如果两个屏幕都已定格，则退出定格状态
            handleBothScreensPaused()
        } else {
            // 处理一个定格一个未定格的情况
            handlePartiallyPausedScreens()
        }
    }

    // 处理两个屏幕都未定格的情况
    private func handleBothScreensUnpaused() {
        print("------------------------")
        print("[双屏定格] 开始")
        print("Original摄像头缩放: \(Int(self.currentCameraScale * 100))%")
        print("Mirrored摄像头缩放: \(Int(self.currentMirroredCameraScale * 100))%")
        print("------------------------")
        
        // 先设置定格状态
        self.isOriginalPaused = true
        self.isMirroredPaused = true
        
        // 然后设置定格图像
        if let originalImg = self.originalImage, let mirroredImg = self.mirroredImage {
            print("[双屏定格] 图片信息:")
            print("Original图片尺寸: \(Int(originalImg.size.width))x\(Int(originalImg.size.height))")
            print("Mirrored图片尺寸: \(Int(mirroredImg.size.width))x\(Int(mirroredImg.size.height))")
            
            // 处理图片旋转
            let (rotatedOriginalImg, rotatedMirroredImg) = handleImageRotation(
                originalImg: originalImg,
                mirroredImg: mirroredImg
            )
            
            // 先设置 Original 屏幕的定格图片，禁用闪光动画
            imageUploader.setPausedImage(
                rotatedOriginalImg,
                for: .original,
                scale: self.currentCameraScale,
                cameraScale: self.currentCameraScale,
                isDualScreenMode: true,  // 标记为双屏模式
                otherScreenImage: rotatedMirroredImg,
                disableFlash: true  // 添加参数禁用闪光
            )
            
            // 等待一个很短的时间确保 Original 屏幕的设置完成
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // 然后设置 Mirrored 屏幕的定格图片，禁用闪光动画
                self.imageUploader.setPausedImage(
                    rotatedMirroredImg,
                    for: .mirrored,
                    scale: self.currentMirroredCameraScale,
                    cameraScale: self.currentMirroredCameraScale,
                    isDualScreenMode: true,  // 标记为双屏模式
                    otherScreenImage: rotatedOriginalImg,
                    disableFlash: true  // 添加参数禁用闪光
                )
                
                self.verifyAndTakeScreenshot(originalImg: rotatedOriginalImg, mirroredImg: rotatedMirroredImg)
            }
        } else {
            print("[错误] 无法获取原始图片:")
            print("Original图片: \(self.originalImage != nil ? "存在" : "为空")")
            print("Mirrored图片: \(self.mirroredImage != nil ? "存在" : "为空")")
        }
        
        showPauseAnimation()
    }

    // 处理两个屏幕都已定格的情况
    private func handleBothScreensPaused() {
        print("------------------------")
        print("退出定格状态")
        print("------------------------")
        
        // 先关闭所有手电筒
        imageUploader.closeAllFlashlights()
        
        // 然后退出定格状态
        self.isOriginalPaused = false
        self.isMirroredPaused = false
        self.pausedOriginalImage = nil
        self.pausedMirroredImage = nil
        
        print("两个屏幕已退出定格")
    }

    // 处理一个定格一个未定格的情况
    private func handlePartiallyPausedScreens() {
        print("------------------------")
        print("一个屏幕已定格，定格另一个屏幕")
        print("------------------------")
        
        // 处理Original屏幕
        if !isOriginalPaused {
            handleOriginalScreenPause()
        }
        
        // 处理Mirrored屏幕
        if !isMirroredPaused {
            handleMirroredScreenPause()
        }
        
        print("------------------------")
        print("开始执行截图")
        print("Original定格状态: \(isOriginalPaused)")
        print("Mirrored定格状态: \(isMirroredPaused)")
        print("------------------------")
        
        // 更新截图管理器的图像引用并执行截图
        self.screenshotManager.setImages(
            original: self.pausedOriginalImage ?? self.originalImage,
            mirrored: self.pausedMirroredImage ?? self.mirroredImage,
            originalCameraScale: self.currentCameraScale,
            mirroredCameraScale: self.currentMirroredCameraScale
        )
        self.screenshotManager.takeScreenshot()
    }

    // 处理 Original 屏幕的定格
    private func handleOriginalScreenPause() {
        isOriginalPaused = true
        if let originalImg = originalImage {
            switch self.orientationManager.currentOrientation {
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
            imageUploader.setPausedImage(
                self.pausedOriginalImage,
                for: .original,
                scale: self.currentCameraScale,
                cameraScale: self.currentCameraScale,
                isDualScreenMode: true,
                otherScreenImage: self.pausedMirroredImage
            )
        }
    }

    // 处理 Mirrored 屏幕的定格
    private func handleMirroredScreenPause() {
        isMirroredPaused = true
        if let mirroredImg = mirroredImage {
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
            imageUploader.setPausedImage(
                self.pausedMirroredImage,
                for: .mirrored,
                scale: self.currentMirroredCameraScale,
                cameraScale: self.currentMirroredCameraScale,
                isDualScreenMode: true,
                otherScreenImage: self.pausedOriginalImage
            )
        }
    }

    // 验证定格结果并执行截图
    private func verifyAndTakeScreenshot(originalImg: UIImage, mirroredImg: UIImage) {
        if let pausedOriginal = self.pausedOriginalImage {
            print("[双屏定格] Original定格成功")
            print("定格后尺寸: \(Int(pausedOriginal.size.width))x\(Int(pausedOriginal.size.height))")
        } else {
            print("[错误] Original定格失败: pausedOriginalImage 为空")
        }
        
        if let pausedMirrored = self.pausedMirroredImage {
            print("[双屏定格] Mirrored定格成功")
            print("定格后尺寸: \(Int(pausedMirrored.size.width))x\(Int(pausedMirrored.size.height))")
        } else {
            print("[错误] Mirrored定格失败: pausedMirroredImage 为空")
        }
        
        // 更新截图管理器的图像引用并执行截图
        self.screenshotManager.setImages(
            original: originalImg,
            mirrored: mirroredImg,
            originalCameraScale: self.currentCameraScale,
            mirroredCameraScale: self.currentMirroredCameraScale
        )
        self.screenshotManager.takeScreenshot()
    }

    // 显示定格动画
    private func showPauseAnimation() {
        withAnimation {
            showMiddleIconAnimation = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            withAnimation {
                showMiddleIconAnimation = false
            }
        }
    }
} 