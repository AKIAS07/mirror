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
                .frame(width: width, height: 120)
                .opacity(0.0)
            
            // 交换图标按钮（扩大点击区域）
            Image(systemName: "arrow.up.and.down.square.fill")
                .font(.system(size: 120, weight: .bold))  // 加大图标
                .foregroundColor(.white)
                .background(
                    Image(systemName: "square.fill")
                        .font(.system(size: 120, weight: .bold))
                        .foregroundColor(.black)
                )
                .frame(width: 120, height: 120)  // 扩大框架
                .contentShape(Rectangle())  // 扩大点击区域
                .onTapGesture {
                    print("------------------------")
                    print("交换按钮被点击")
                    print("点击区域：120x120pt")
                    print("------------------------")
                    onSwapTapped()
                }
        }
    }
}

// 添加触控区位置枚举
enum TouchZonePosition: Int {
    case left = 1   // 左边位置
    case center = 0 // 中间位置（初始）
    case right = 2  // 右边位置
    
    var xOffset: CGFloat {
        switch self {
        case .left: return -100
        case .center: return 0
        case .right: return 100
        }
    }
}

// 将复杂的手势处理逻辑拆分成单独的视图组件
private struct ScreenGestureView: View {
    let screenID: ScreenID
    let isZone2Enabled: Bool
    let isZone3Enabled: Bool
    let isDefaultGesture: Bool
    let isScreensSwapped: Bool
    let layoutDescription: String
    let isOriginalPaused: Bool
    let isMirroredPaused: Bool
    @Binding var originalScale: CGFloat
    @Binding var mirroredScale: CGFloat
    @Binding var currentScale: CGFloat
    @Binding var currentMirroredScale: CGFloat
    let minScale: CGFloat
    let maxScale: CGFloat
    @Binding var currentIndicatorScale: CGFloat
    @Binding var activeScalingScreen: ScreenID?
    @Binding var showScaleIndicator: Bool
    let originalOffset: CGSize
    let mirroredOffset: CGSize
    let imageUploader: ImageUploader
    let togglePauseState: (ScreenID) -> Void
    let handleSingleTap: (ScreenID) -> Void
    let isImageOutOfBounds: (CGFloat, CGSize, CGFloat, CGFloat) -> Bool
    let centerImage: (CGFloat) -> Void
    let centerMirroredImage: (CGFloat) -> Void
    let handleDragGesture: (DragGesture.Value, CGFloat, CGFloat, CGFloat, CGSize) -> Void
    let handleMirroredDragGesture: (DragGesture.Value, CGFloat, CGFloat, CGFloat, CGSize) -> Void
    let handleDragEnd: () -> Void
    let handleMirroredDragEnd: () -> Void

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(TwoOfMeGestureManager.createTapGestures(
                for: screenID,
                isZone2Enabled: isZone2Enabled,
                isZone3Enabled: isZone3Enabled,
                isDefaultGesture: isDefaultGesture,
                isScreensSwapped: isScreensSwapped,
                layoutDescription: layoutDescription,
                currentImageScale: $currentScale,
                originalImageScale: $originalScale,
                currentMirroredImageScale: $currentMirroredScale,
                mirroredImageScale: $mirroredScale,
                togglePauseState: togglePauseState,
                handleSingleTap: handleSingleTap,
                imageUploader: imageUploader
            ))
            .gesture(TwoOfMeGestureManager.createCombinedGestures(
                for: screenID,
                isZone2Enabled: isZone2Enabled,
                isZone3Enabled: isZone3Enabled,
                isOriginalPaused: isOriginalPaused,
                isMirroredPaused: isMirroredPaused,
                originalScale: $originalScale,
                mirroredScale: $mirroredScale,
                currentScale: $currentScale,
                currentMirroredScale: $currentMirroredScale,
                minScale: minScale,
                maxScale: maxScale,
                currentIndicatorScale: $currentIndicatorScale,
                activeScalingScreen: $activeScalingScreen,
                showScaleIndicator: $showScaleIndicator,
                originalOffset: originalOffset,
                mirroredOffset: mirroredOffset,
                imageUploader: imageUploader,
                isImageOutOfBounds: isImageOutOfBounds,
                centerImage: centerImage,
                centerMirroredImage: centerMirroredImage,
                handleDragGesture: handleDragGesture,
                handleMirroredDragGesture: handleMirroredDragGesture,
                handleDragEnd: handleDragEnd,
                handleMirroredDragEnd: handleMirroredDragEnd
            ))
            .allowsHitTesting(!imageUploader.isFlashlightActive(for: screenID))
    }
}

// 添加新的屏幕内容视图组件
private struct ScreenContentView: View {
    let screenID: ScreenID
    let image: UIImage?
    let isPaused: Bool
    let pausedImage: UIImage?
    let scale: CGFloat
    let offset: CGSize
    let orientation: UIDeviceOrientation
    let imageUploader: ImageUploader
    let borderLightManager: BorderLightManager
    let showFlash: Bool
    let screenWidth: CGFloat
    let screenHeight: CGFloat
    let centerY: CGFloat
    let isScreensSwapped: Bool  // 添加这个参数
    
    var body: some View {
        ZStack {
            if let displayImage = isPaused ? pausedImage : image {
                ZStack {
                    Image(uiImage: displayImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: orientation.isLandscape ? screenHeight / 2 : screenWidth,
                               height: centerY)
                        .scaleEffect(scale)
                        .offset(isPaused ? offset : .zero)
                        .rotationEffect(isPaused ? DeviceOrientationManager.shared.getRotationAngle(orientation) : .zero)
                        .animation(.easeInOut(duration: 0.3), value: orientation)
                        .clipped()
                        .zIndex(1)
                    
                    // 添加关闭按钮
                    if imageUploader.isFlashlightActive(for: screenID) {
                        CloseButtonView(
                            screenID: screenID,
                            imageUploader: imageUploader,
                            screenWidth: screenWidth,
                            centerY: centerY
                        )
                    }
                }
                .zIndex(1)
            }
            
            // 添加边框灯效果
            BorderLightView(
                screenWidth: screenWidth,
                centerY: centerY,
                showOriginalHighlight: screenID == .original ? borderLightManager.showOriginalHighlight : false,
                showMirroredHighlight: screenID == .mirrored ? borderLightManager.showMirroredHighlight : false,
                screenPosition: screenID == .original ? .original : .mirrored,
                isScreensSwapped: isScreensSwapped
            )
            .zIndex(2)
            
            // 添加覆盖层视图
            if (screenID == .original && imageUploader.showOriginalOverlay) || 
               (screenID == .mirrored && imageUploader.showMirroredOverlay) {
                OverlayView(
                    screenID: screenID,
                    deviceOrientation: orientation,
                    screenWidth: screenWidth,
                    centerY: centerY,
                    screenHeight: screenHeight,
                    imageUploader: imageUploader
                )
            }
            
            // 闪光动画
            if showFlash {
                FlashAnimationView(frame: CGRect(
                    x: 0,
                    y: 0,
                    width: screenWidth,
                    height: screenHeight/2
                ))
                .zIndex(4)
            }
        }
    }
}

// 添加关闭按钮视图组件
private struct CloseButtonView: View {
    let screenID: ScreenID
    let imageUploader: ImageUploader
    let screenWidth: CGFloat
    let centerY: CGFloat
    
    var body: some View {
        ZStack {
            Color.clear
                .frame(width: 80, height: 80)
                .contentShape(Circle())
            
            Button(action: {
                print("------------------------")
                print("[关闭按钮] 被点击")
                print("区域：\(screenID.debugName)屏幕")
                print("------------------------")
                
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.prepare()
                generator.impactOccurred()
                
                imageUploader.closeFlashlight(for: screenID)
            }) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.gray.opacity(0.3))
                    //.background(Color.black.opacity(0.3))
                    .clipShape(Circle())
                    .contentShape(Circle())
            }
            Image(systemName: "minus")
            .font(.system(size: 40))
            .foregroundColor(.white.opacity(0.3))
            //.background(Color.black.opacity(0.3))
            .clipShape(Circle())
            .contentShape(Circle())
        }
        .position(x: screenWidth/2, y: centerY/2)
        .zIndex(999)
    }
}

// 添加触控区域视图组件
private struct TouchZoneView: View {
    let screenID: ScreenID
    let isPaused: Bool
    let isZone2Enabled: Bool
    let isZone3Enabled: Bool
    let isDefaultGesture: Bool
    let isScreensSwapped: Bool
    let layoutDescription: String
    let screenHeight: CGFloat
    @Binding var originalScale: CGFloat
    @Binding var mirroredScale: CGFloat
    @Binding var currentScale: CGFloat
    @Binding var currentMirroredScale: CGFloat
    let minScale: CGFloat
    let maxScale: CGFloat
    @Binding var currentIndicatorScale: CGFloat
    @Binding var activeScalingScreen: ScreenID?
    @Binding var showScaleIndicator: Bool
    let originalOffset: CGSize
    let mirroredOffset: CGSize
    let imageUploader: ImageUploader
    let togglePauseState: (ScreenID) -> Void
    let handleSingleTap: (ScreenID) -> Void
    let isImageOutOfBounds: (CGFloat, CGSize, CGFloat, CGFloat) -> Bool
    let centerImage: (CGFloat) -> Void
    let centerMirroredImage: (CGFloat) -> Void
    let handleDragGesture: (DragGesture.Value, CGFloat, CGFloat, CGFloat, CGSize) -> Void
    let handleMirroredDragGesture: (DragGesture.Value, CGFloat, CGFloat, CGFloat, CGSize) -> Void
    let handleDragEnd: () -> Void
    let handleMirroredDragEnd: () -> Void

    var body: some View {
        ScreenGestureView(
            screenID: screenID,
            isZone2Enabled: isZone2Enabled,
            isZone3Enabled: isZone3Enabled,
            isDefaultGesture: isDefaultGesture,
            isScreensSwapped: isScreensSwapped,
            layoutDescription: layoutDescription,
            isOriginalPaused: isPaused,
            isMirroredPaused: isPaused,
            originalScale: $originalScale,
            mirroredScale: $mirroredScale,
            currentScale: $currentScale,
            currentMirroredScale: $currentMirroredScale,
            minScale: minScale,
            maxScale: maxScale,
            currentIndicatorScale: $currentIndicatorScale,
            activeScalingScreen: $activeScalingScreen,
            showScaleIndicator: $showScaleIndicator,
            originalOffset: originalOffset,
            mirroredOffset: mirroredOffset,
            imageUploader: imageUploader,
            togglePauseState: togglePauseState,
            handleSingleTap: handleSingleTap,
            isImageOutOfBounds: isImageOutOfBounds,
            centerImage: centerImage,
            centerMirroredImage: centerMirroredImage,
            handleDragGesture: handleDragGesture,
            handleMirroredDragGesture: handleMirroredDragGesture,
            handleDragEnd: handleDragEnd,
            handleMirroredDragEnd: handleMirroredDragEnd
        )
        .frame(height: (screenHeight - 20) / 2)
    }
}

struct TwoOfMeScreens: View {
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var imageUploader = ImageUploader()
    @StateObject private var permissionManager = PermissionManager.shared
    
    @State private var originalImage: UIImage?
    @State private var mirroredImage: UIImage?
    @State private var containerWidth: CGFloat = 0
    @State private var showContainer = false
    @State private var isScreensSwapped = false
    @State private var isOriginalPaused = false  // Original画面定格状态
    @State private var isMirroredPaused = false  // Mirrored画面定格状态
    @State private var pausedOriginalImage: UIImage?
    @State private var pausedMirroredImage: UIImage?
    @State private var dragVerticalOffset: CGFloat = 0  // 添加垂直拖动偏移量
    @State private var pageOffset: CGFloat = 0  // 添加页面偏移状态
    
    // 添加手势设置状态变量
    @State private var isDefaultGesture: Bool = BorderLightStyleManager.shared.isDefaultGesture
    
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
    
    // Original 实时画面的缩放状态
    @State private var originalCameraScale: CGFloat = 1.0
    @State private var currentCameraScale: CGFloat = 1.0

    // Original 定格画面的缩放状态
    @State private var originalImageScale: CGFloat = 1.0
    @State private var currentImageScale: CGFloat = 1.0

    // Mirrored 实时画面的缩放状态
    @State private var mirroredCameraScale: CGFloat = 1.0
    @State private var currentMirroredCameraScale: CGFloat = 1.0

    // Mirrored 定格画面的缩放状态
    @State private var mirroredImageScale: CGFloat = 1.0
    @State private var currentMirroredImageScale: CGFloat = 1.0
    
    @State private var lastScale: CGFloat = 1.0  // 添加记录上次缩放值的状态
    @State private var lastOutputTime: Date = Date()  // 添加上次输出时间记录
    private let outputInterval: TimeInterval = 0.2  // 设置输出时间间隔（秒）
    
    // 添加缩放限制常量
    private let minScale: CGFloat = 1.0     // 最小100%
    private let maxScale: CGFloat = 10.0    // 最大1000%
    
    // 修改定格时的缩放限制
    private let minPausedScale: CGFloat = 1.0  // 最小100%（相对于定格时的大小）
    private let maxPausedScale: CGFloat = 10.0 // 最大1000%（相对于定格时的大小）
    
    @State private var showScaleLimitMessage = false  // 添加限制提示状态
    @State private var scaleLimitMessage = ""  // 添加限制提示信息
    
    // 添加拖动相关的状态和常量
    @State private var originalOffset: CGSize = .zero
    @State private var mirroredOffset: CGSize = .zero
    
    // 添加阻尼相关常量
    private let dragDampingFactor: CGFloat = 0.6  // 拖动阻尼系数（0.0-1.0，越小阻力越大）
    private let animationDuration: TimeInterval = 0.5  // 动画持续时间
    private let springDamping: CGFloat = 0.5  // 弹簧阻尼（0.0-1.0，越小弹性越大）
    private let springResponse: CGFloat = 0.8  // 弹簧响应速度
    
    @State private var showScaleIndicator = false
    @State private var currentIndicatorScale: CGFloat = 1.0
    
    // 添加状态变量来跟踪当前缩放的屏幕
    @State private var activeScalingScreen: ScreenID?
    
    // 添加状态变量跟踪是否是首次显示
    @State private var isFirstAppear: Bool = true
    @State private var isRestoringFromBackground: Bool = false  // 添加状态跟踪变量
    
    // 添加动画相关的状态变量
    @State private var showMiddleIconAnimation = false
    @State private var middleAnimationPosition: CGPoint = .zero
    
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
                scaleLimitMessage = "已放大至最小尺寸"
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
            activeScalingScreen = screenID
            showScaleIndicator = true
            
            // 打印日志
            let currentPercentage = Int(currentScale * 100)
            print("------------------------")
            print("触控区\(screenID == .original ? "2" : "3")双指缩放")
            print("当前比例：\(currentPercentage)%")
            print("------------------------")
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
        
        // 延迟隐藏缩放提示
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showScaleIndicator = false
            activeScalingScreen = nil
        }
        
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
    @StateObject private var orientationManager = DeviceOrientationManager.shared
    
    // 修改获取旋转角度的方法
    private func getRotationAngle(_ orientation: UIDeviceOrientation) -> Angle {
        return orientationManager.getRotationAngle(orientation)
    }
    
    // 修改方向描述辅助方法
    private func getOrientationDescription(_ orientation: UIDeviceOrientation) -> String {
        return orientationManager.getOrientationDescription(orientation)
    }
    
    // 添加拖动会话控制相关的状态变量
    @State private var isDragging: Bool = false        // 是否正在拖动
    @State private var dragSessionStarted: Bool = false // 当前拖动会话是否已开始
    @State private var initialDragLocation: CGPoint = .zero  // 录置
    
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
    
    // 添加记录初始触摸位置和初始偏移的状态
    @State private var initialTouchLocation: CGPoint = .zero
    @State private var initialOffset: CGSize = .zero
    
    // 添加一个状态变量跟踪是否已经开始拖动
    @State private var dragStarted: Bool = false
    
    // 添加边框显示状态
    @State private var showTopBorder: Bool = false
    @State private var showBottomBorder: Bool = false
    @State private var showLeftBorder: Bool = false
    @State private var showRightBorder: Bool = false
    
    // 添加边缘检测方法
    @StateObject private var originalEdgeDetector = EdgeDetector()
    @StateObject private var mirroredEdgeDetector = EdgeDetector()
    
    // 修改拖拽处理方法中的边缘检测部分
    private func handleDragGesture(
        _ value: DragGesture.Value,
        _ screenWidth: CGFloat,
        _ screenHeight: CGFloat,
        _ centerY: CGFloat,
        _ dampedTranslation: CGSize  // 新增参数
    ) {
        if isZone2Enabled && currentCameraScale > 1.0 {
            // 在拖动开始时记录初始状态和打印日志
            if !dragStarted {
                dragStarted = true
                
                // 记录初始态
                initialTouchLocation = value.startLocation
                initialOffset = originalOffset
                
                print("------------------------")
                print("Original画面拖动开始")
                print("手指位置：x=\(Int(value.startLocation.x))pt, y=\(Int(value.startLocation.y))pt")
                print("画面比例：\(Int(currentCameraScale * 100))%")
                print("设备方向：\(getOrientationDescription(orientationManager.currentOrientation))")
                print("------------------------")
            }
            
            // 计算和应用新的偏移值
            let newOffset = CGSize(
                width: initialOffset.width + dampedTranslation.width,
                height: initialOffset.height + dampedTranslation.height
            )
            
            let maxOffset = calculateMaxOffset(
                for: currentCameraScale,
                screenWidth: screenWidth,
                screenHeight: screenHeight
            )
            
            originalOffset = CGSize(
                width: max(min(newOffset.width, maxOffset.width), -maxOffset.width),
                height: max(min(newOffset.height, maxOffset.height), -maxOffset.height)
            )
            
            // 更新 ImageUploader 的偏移量
            imageUploader.setOffset(originalOffset, maxOffset: maxOffset)
            
            // 使用封装的边缘检测方法
            let edges = originalEdgeDetector.detectEdges(
                offset: originalOffset,
                maxOffset: maxOffset,
                orientation: orientationManager.currentOrientation
            )
            originalEdgeDetector.updateBorders(edges: edges)
            
            // 打印调试信息
            print("------------------------")
            print("边缘检测状态")
            print("设备方向：\(getOrientationDescription(orientationManager.currentOrientation))")
            if edges.left { print("  左边缘重合") }
            if edges.right { print("  右边缘重合") }
            if edges.top { print("  下边缘重合") }
            if edges.bottom { print("  上边缘重合") }
            print("------------------------")
            
            // 在更新偏移量后，计算并打印可见区域
            if let image = originalImage {
                calculateVisibleArea(
                    imageSize: image.size,
                    screenWidth: screenWidth,
                    screenHeight: screenHeight,
                    scale: currentCameraScale,
                    offset: originalOffset
                )
            }
        }
    }
    
    // 添加拖拽结束处理方法
    private func handleDragEnd() {
        // 重置拖动状态
        dragStarted = false
        
        print("------------------------")
        print("Original画面拖动结束")
        print("最终偏：x=\(Int(originalOffset.width))pt, y=\(Int(originalOffset.height))pt")
        print("画面比例：\(Int(currentCameraScale * 100))%")
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

    // 修改 Mirrored 屏幕的拖拽处理方法
    private func handleMirroredDragGesture(
        _ value: DragGesture.Value,
        _ screenWidth: CGFloat,
        _ screenHeight: CGFloat,
        _ centerY: CGFloat,
        _ dampedTranslation: CGSize  // 新增参数
    ) {
        if isZone3Enabled && currentMirroredCameraScale > 1.0 {
            // 在拖动开始时记录初始状态和打印日志
            if !mirroredDragStarted {
                mirroredDragStarted = true
                
                // 记录初始状态
                mirroredInitialTouchLocation = value.startLocation
                mirroredInitialOffset = mirroredOffset
                
                print("------------------------")
                print("Mirrored画面拖动开始")
                print("手指位置：x=\(Int(value.startLocation.x))pt, y=\(Int(value.startLocation.y))pt")
                print("画面比例：\(Int(currentMirroredCameraScale * 100))%")
                print("设备方向：\(getOrientationDescription(orientationManager.currentOrientation))")
                print("------------------------")
            }
            
            // 计算和应用新的偏移值
            let newOffset = CGSize(
                width: mirroredInitialOffset.width + dampedTranslation.width,
                height: mirroredInitialOffset.height + dampedTranslation.height
            )
            
            let maxOffset = calculateMaxOffset(
                for: currentMirroredCameraScale,
                screenWidth: screenWidth,
                screenHeight: screenHeight
            )
            
            mirroredOffset = CGSize(
                width: max(min(newOffset.width, maxOffset.width), -maxOffset.width),
                height: max(min(newOffset.height, maxOffset.height), -maxOffset.height)
            )
            
            // 更新 ImageUploader 的偏移量
            imageUploader.setOffset(mirroredOffset, maxOffset: maxOffset)
            
            // 使用边缘检测方法
            let edges = mirroredEdgeDetector.detectEdges(
                offset: mirroredOffset,
                maxOffset: maxOffset,
                orientation: orientationManager.currentOrientation
            )
            mirroredEdgeDetector.updateBorders(edges: edges)
            
            // 打印调试信息
            print("------------------------")
            print("Mirrored边缘检测状态")
            print("设备方向：\(getOrientationDescription(orientationManager.currentOrientation))")
            if edges.left { print("  左边缘重合") }
            if edges.right { print("  右边缘重合") }
            if edges.top { print("  下边框重合") }
            if edges.bottom { print("  上边缘重合") }
            print("------------------------")
            
            // 在更新偏移量后，计算并打印可见区域
            if let image = mirroredImage {
                calculateVisibleArea(
                    imageSize: image.size,
                    screenWidth: screenWidth,
                    screenHeight: screenHeight,
                    scale: currentMirroredCameraScale,
                    offset: mirroredOffset
                )
            }
        }
    }

    // 添加 Mirrored 拖拽结束处理方法
    private func handleMirroredDragEnd() {
        // 重置拖动状态
        mirroredDragStarted = false
        
        print("------------------------")
        print("Mirrored画面拖动结束")
        print("最终偏移：x=\(Int(mirroredOffset.width))pt, y=\(Int(mirroredOffset.height))pt")
        print("画面比例：\(Int(currentMirroredCameraScale * 100))%")
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
            
            // 创建新计时器，3秒后动隐藏
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
        withAnimation(.easeInOut(duration: 0.3)) {
            isScreensSwapped.toggle()
            
            // 更新截图管理器的屏幕交换状态
            screenshotManager.updateScreenSwapState(isScreensSwapped)
            
            // 通知 ImageUploader 处理分屏交换
            imageUploader.handleScreenSwap()
            
            print("------------------------")
            print("[分屏交换] 布局已更新")
            print("当前布局：\(isScreensSwapped ? "Mirrored在上，Original在下" : "Original在上，Mirrored在下")")
            print("------------------------")
        }
    }
    
    // 添加边框灯管理器
    @StateObject private var borderLightManager = BorderLightManager()
    
    // 修改处理幕点击的方法
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
    
    private func handleSelectedImage(_ image: UIImage?) {
        guard let image = image else { return }
        
        switch imageUploader.selectedScreenID {
        case .original:
            // 自动进入定格状态
            if !isOriginalPaused {
                isOriginalPaused = true
                print("------------------------")
                print("Original画面已自动定格")
                print("当前缩放比例: \(Int(originalImageScale * 100))%")
                print("------------------------")
            }
            
            // 根据设备方向调整定格画面，并传入缩放比例
            switch orientationManager.currentOrientation {
            case .landscapeLeft:
                pausedOriginalImage = image.rotate(degrees: 0)
            case .landscapeRight:
                pausedOriginalImage = image.rotate(degrees: 0)
            case .portraitUpsideDown:
                pausedOriginalImage = image.rotate(degrees: 0)
            default:
                pausedOriginalImage = image
            }
            
            // 更新 ImageUploader 时传入缩放比例
            imageUploader.setPausedImage(pausedOriginalImage, for: .original, scale: currentImageScale)
            
        case .mirrored:
            // 自动进入定格状态
            if !isMirroredPaused {
                isMirroredPaused = true
                print("------------------------")
                print("Mirrored画面已自动定格")
                print("当前缩放比例: \(Int(mirroredImageScale * 100))%")
                print("------------------------")
            }
            
            // 根据设备方向调整定格画面，并传入缩放比例
            switch orientationManager.currentOrientation {
            case .landscapeLeft:
                pausedMirroredImage = image.rotate(degrees: 0)
            case .landscapeRight:
                pausedMirroredImage = image.rotate(degrees: 0)
            case .portraitUpsideDown:
                pausedMirroredImage = image.rotate(degrees: 0)
            default:
                pausedMirroredImage = image
            }
            
            // 更新 ImageUploader 时传入缩放比例
            imageUploader.setPausedImage(pausedMirroredImage, for: .mirrored, scale: currentMirroredImageScale)
            
        case .none:
            break
        }
    }
    
    // 添加触控区位置状态
    @State private var touchZonePosition: TouchZonePosition = .center
    @State private var dragOffset: CGFloat = 0
    @State private var isDraggingTouchZone: Bool = false
    
    // 添加计算可见区域的方法
    private func calculateVisibleArea(
        imageSize: CGSize,
        screenWidth: CGFloat,
        screenHeight: CGFloat,
        scale: CGFloat,
        offset: CGSize
    ) {
        print("------------------------")
        print("[可见区域] 初始参数")
        print("屏幕尺寸：\(Int(screenWidth))x\(Int(screenHeight))")
        print("图片尺寸：\(Int(imageSize.width))x\(Int(imageSize.height))")
        print("缩放比例：\(scale)")
        print("当前偏移：\(offset)")
        print("------------------------")
        
        // 计算显示区域的尺寸（屏幕的一半高度）
        let viewportWidth = screenWidth
        let viewportHeight = screenHeight / 2
        
        print("------------------------")
        print("[可见区域] 显示区域")
        print("宽度：\(Int(viewportWidth))")
        print("高度：\(Int(viewportHeight))")
        print("------------------------")
        
        // 计算图片缩放后的实际尺寸
        let scaledImageWidth = imageSize.width * scale
        let scaledImageHeight = imageSize.height * scale
        
        print("------------------------")
        print("[可见区域] 缩放后尺寸")
        print("宽度：\(Int(scaledImageWidth))")
        print("高度：\(Int(scaledImageHeight))")
        print("------------------------")
        
        // 计算图片中心点相对于显示区域的偏移
        let centerOffsetX = offset.width
        let centerOffsetY = offset.height
        
        // 计算可见区域在原始图片中的位置
        let visibleX = (scaledImageWidth - viewportWidth) / 2 - centerOffsetX
        let visibleY = (scaledImageHeight - viewportHeight) / 2 - centerOffsetY
        let visibleWidth = viewportWidth
        let visibleHeight = viewportHeight
        
        print("------------------------")
        print("[可见区域] 缩放空间中的位置")
        print("中心偏移：(\(Int(centerOffsetX)), \(Int(centerOffsetY)))")
        print("可见区域：")
        print("  起点：(\(Int(visibleX)), \(Int(visibleY)))")
        print("  尺寸：\(Int(visibleWidth))x\(Int(visibleHeight))")
        print("------------------------")
        
        // 转换为原始图片的坐标系
        let originalVisibleX = visibleX / scale
        let originalVisibleY = visibleY / scale
        let originalVisibleWidth = visibleWidth / scale
        let originalVisibleHeight = visibleHeight / scale
        
        print("------------------------")
        print("[可见区域] 原始图片中的位置")
        print("起点：(\(Int(originalVisibleX)), \(Int(originalVisibleY)))")
        print("尺寸：\(Int(originalVisibleWidth))x\(Int(originalVisibleHeight))")
        print("终点：(\(Int(originalVisibleX + originalVisibleWidth)), \(Int(originalVisibleY + originalVisibleHeight)))")
        print("------------------------")
    }
    
    // 添加触控区1点击状态跟踪
    @State private var zone1LastTapTime: Date = Date()
    @State private var zone1TapCount: Int = 0
    
    // 添加截图管理器
    @StateObject private var screenshotManager = ScreenshotManager.shared
    
    @ObservedObject private var styleManager = BorderLightStyleManager.shared
    @State private var isScreenSwapped: Bool = false
    
    @State private var showOriginalFlash = false  // 添加原始画面闪光状态
    @State private var showMirroredFlash = false  // 添加镜像画面闪光状态
    @State private var touchZonePoint: CGPoint = .zero  // 修改变量名
    
    @State private var showOriginalRestartHint = false  // Original屏幕重启提示
    @State private var showMirroredRestartHint = false  // Mirrored屏幕重启提示
    
    // 添加状态变量来控制提示的显示
    @State private var showRestartHint = false  // 控制提示的显示
    @State private var restartHintWorkItem: DispatchWorkItem?  // 用于延迟隐藏提示
    
    // 添加新的状态变量
    @State private var showPhotoDisabledHint = false
    @State private var photoDisabledHintWorkItem: DispatchWorkItem?
    
    @State private var dragScale: CGFloat = 1.0  // 添加拖拽缩放状态
    
    @State private var isEdgeDismissOverlayActive = false  // 添加遮罩状态
    
    init() {
        // 不再需要设置边框灯管理器引用
    }
    
    var body: some View {
        GeometryReader { geometry in
            let screenBounds = UIScreen.main.bounds
            let screenHeight = screenBounds.height
            let screenWidth = screenBounds.width
            
            ZStack {
                // 背景 (zIndex = 0)
                Color.black.edgesIgnoringSafeArea(.all)
                    .zIndex(0)
                
                // 所有内容包装在一个偏移容器中 (zIndex = 1)
                ZStack {
                    // 上下分屏布局
                    VStack(spacing: 0) {
                        // 根据交换状态决定显示个屏幕
                        if !isScreensSwapped {
                            // Original 屏幕在上
                            ScreenContainer(
                                screenID: .original,
                                content: AnyView(
                                    ScreenContentView(
                                        screenID: .original,  // 或 .mirrored
                                        image: originalImage,  // 或 mirroredImage
                                        isPaused: isOriginalPaused,  // 或 isMirroredPaused
                                        pausedImage: pausedOriginalImage,  // 或 pausedMirroredImage
                                        scale: isOriginalPaused ? currentCameraScale : currentCameraScale,  // 根据需要调整
                                        offset: originalOffset,  // 或 mirroredOffset
                                        orientation: orientationManager.currentOrientation,
                                        imageUploader: imageUploader,
                                        borderLightManager: borderLightManager,
                                        showFlash: showOriginalFlash,  // 或 showMirroredFlash
                                        screenWidth: geometry.size.width,
                                        screenHeight: geometry.size.height,
                                        centerY: geometry.size.height / 2,
                                        isScreensSwapped: isScreensSwapped  // 添加这个参数
                                    )
                                )
                            )

                            // Mirrored 屏幕在下
                            ScreenContainer(
                                screenID: .mirrored,
                                content: AnyView(
                                    ScreenContentView(
                                        screenID: .mirrored,  // 或 .original
                                        image: mirroredImage,  // 或 originalImage
                                        isPaused: isMirroredPaused,  // 或 isOriginalPaused
                                        pausedImage: pausedMirroredImage,  // 或 pausedOriginalImage
                                        scale: isMirroredPaused ? currentMirroredCameraScale : currentMirroredCameraScale,  // 根据需要调整
                                        offset: mirroredOffset,  // 或 originalOffset
                                        orientation: orientationManager.currentOrientation,
                                        imageUploader: imageUploader,
                                        borderLightManager: borderLightManager,
                                        showFlash: showMirroredFlash,  // 或 showOriginalFlash
                                        screenWidth: geometry.size.width,
                                        screenHeight: geometry.size.height,
                                        centerY: geometry.size.height / 2,
                                        isScreensSwapped: isScreensSwapped  // 添加这个参数
                                    )
                                )
                            )
                        } else {
                            // Mirrored 屏幕在上
                            ScreenContainer(
                                screenID: .mirrored,
                                content: AnyView(
                                    ScreenContentView(
                                        screenID: .mirrored,  // 或 .original
                                        image: mirroredImage,  // 或 originalImage
                                        isPaused: isMirroredPaused,  // 或 isOriginalPaused
                                        pausedImage: pausedMirroredImage,  // 或 pausedOriginalImage
                                        scale: isMirroredPaused ? currentMirroredCameraScale : currentMirroredCameraScale,  // 根据需要调整
                                        offset: mirroredOffset,  // 或 originalOffset
                                        orientation: orientationManager.currentOrientation,
                                        imageUploader: imageUploader,
                                        borderLightManager: borderLightManager,
                                        showFlash: showMirroredFlash,  // 或 showOriginalFlash
                                        screenWidth: geometry.size.width,
                                        screenHeight: geometry.size.height,
                                        centerY: geometry.size.height / 2,
                                        isScreensSwapped: isScreensSwapped  // 添加这个参数
                                    )
                                )
                            )

                            //Original屏幕在下
                            ScreenContainer(
                                screenID: .original,
                                content: AnyView(
                                    ScreenContentView(
                                        screenID: .original,  // 或 .mirrored
                                        image: originalImage,  // 或 mirroredImage
                                        isPaused: isOriginalPaused,  // 或 isMirroredPaused
                                        pausedImage: pausedOriginalImage,  // 或 pausedMirroredImage
                                        scale: isOriginalPaused ? currentCameraScale : currentCameraScale,  // 根据需要调整
                                        offset: originalOffset,  // 或 mirroredOffset
                                        orientation: orientationManager.currentOrientation,
                                        imageUploader: imageUploader,
                                        borderLightManager: borderLightManager,
                                        showFlash: showOriginalFlash,  // 或 showMirroredFlash
                                        screenWidth: geometry.size.width,
                                        screenHeight: geometry.size.height,
                                        centerY: geometry.size.height / 2,
                                        isScreensSwapped: isScreensSwapped  // 添加这个参数
                                    )
                                )
                            )
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: isScreensSwapped)  // 添加交换动画
                    
                    // 其他触控区域（区域2和3）
                    if !imageUploader.isOverlayVisible {
                        ZStack {
                            // Original的触控区2和2a
                            VStack {
                                TouchZoneView(
                                    screenID: .original,
                                    isPaused: isOriginalPaused,
                                    isZone2Enabled: isZone2Enabled,
                                    isZone3Enabled: isZone3Enabled,
                                    isDefaultGesture: isDefaultGesture,
                                    isScreensSwapped: isScreensSwapped,
                                    layoutDescription: layoutDescription,
                                    screenHeight: screenHeight,
                                    originalScale: $originalCameraScale,
                                    mirroredScale: $mirroredCameraScale,
                                    currentScale: $currentCameraScale,
                                    currentMirroredScale: $currentMirroredCameraScale,
                                    minScale: minScale,
                                    maxScale: maxScale,
                                    currentIndicatorScale: $currentIndicatorScale,
                                    activeScalingScreen: $activeScalingScreen,
                                    showScaleIndicator: $showScaleIndicator,
                                    originalOffset: originalOffset,
                                    mirroredOffset: mirroredOffset,
                                    imageUploader: imageUploader,
                                    togglePauseState: togglePauseState,
                                    handleSingleTap: handleSingleTap,
                                    isImageOutOfBounds: isImageOutOfBounds,
                                    centerImage: centerImage,
                                    centerMirroredImage: centerMirroredImage,
                                    handleDragGesture: handleDragGesture,
                                    handleMirroredDragGesture: handleMirroredDragGesture,
                                    handleDragEnd: handleDragEnd,
                                    handleMirroredDragEnd: handleMirroredDragEnd
                                )
                                Spacer()
                            }
                            .frame(height: screenHeight / 2)
                            .position(x: screenWidth/2, y: isScreensSwapped ? screenHeight*3/4 : screenHeight/4)
                            .zIndex(1)
                            
                            // Mirrored的触控区3和3a
                            VStack {
                                TouchZoneView(
                                    screenID: .mirrored,
                                    isPaused: isMirroredPaused,
                                    isZone2Enabled: isZone2Enabled,
                                    isZone3Enabled: isZone3Enabled,
                                    isDefaultGesture: isDefaultGesture,
                                    isScreensSwapped: isScreensSwapped,
                                    layoutDescription: layoutDescription,
                                    screenHeight: screenHeight,
                                    originalScale: $originalCameraScale,
                                    mirroredScale: $mirroredCameraScale,
                                    currentScale: $currentCameraScale,
                                    currentMirroredScale: $currentMirroredCameraScale,
                                    minScale: minScale,
                                    maxScale: maxScale,
                                    currentIndicatorScale: $currentIndicatorScale,
                                    activeScalingScreen: $activeScalingScreen,
                                    showScaleIndicator: $showScaleIndicator,
                                    originalOffset: originalOffset,
                                    mirroredOffset: mirroredOffset,
                                    imageUploader: imageUploader,
                                    togglePauseState: togglePauseState,
                                    handleSingleTap: handleSingleTap,
                                    isImageOutOfBounds: isImageOutOfBounds,
                                    centerImage: centerImage,
                                    centerMirroredImage: centerMirroredImage,
                                    handleDragGesture: handleDragGesture,
                                    handleMirroredDragGesture: handleMirroredDragGesture,
                                    handleDragEnd: handleDragEnd,
                                    handleMirroredDragEnd: handleMirroredDragEnd
                                )
                                Spacer()
                            }
                            .frame(height: screenHeight / 2)
                            .position(x: screenWidth/2, y: isScreensSwapped ? screenHeight/4 : screenHeight*3/4)
                            .zIndex(2)
                        }
                    }
                }
                .offset(x: pageOffset)
                .zIndex(1)
                
                // 重启提示视图 (zIndex = 2)
                ZStack {
                    if showOriginalRestartHint {
                        RestartCameraView(action: {
                            showOriginalRestartHint = false
                            // 只重启 Original 屏幕
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak cameraManager] in
                                guard let cameraManager = cameraManager else { return }
                                print("------------------------")
                                print("[Two of Me] Original屏幕重启")
                                print("------------------------")
                                if let processor = cameraManager.videoOutputDelegate as? VideoProcessor {
                                    processor.enableOriginalOutput = true
                                    cameraManager.restartCamera()  // 直接重启相机
                                }
                            }
                        })
                        .frame(height: UIScreen.main.bounds.height / 2)
                        .position(x: geometry.size.width/2, 
                                 y: isScreensSwapped ? geometry.size.height * 3/4 : geometry.size.height/4)
                    }
                    
                    if showMirroredRestartHint {
                        RestartCameraView(action: {
                            showMirroredRestartHint = false
                            // 只重启 Mirrored 屏幕
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak cameraManager] in
                                guard let cameraManager = cameraManager else { return }
                                print("------------------------")
                                print("[Two of Me] Mirrored屏幕重启")
                                print("------------------------")
                                if let processor = cameraManager.videoOutputDelegate as? VideoProcessor {
                                    processor.enableMirroredOutput = true
                                    cameraManager.restartCamera()  // 直接重启相机
                                }
                            }
                        })
                        .frame(height: UIScreen.main.bounds.height / 2)
                        .position(x: geometry.size.width/2, 
                                 y: isScreensSwapped ? geometry.size.height/4 : geometry.size.height * 3/4)
                    }
                }
                .offset(x: pageOffset)  // 添加页面偏移
                .zIndex(2)
                
                // 触控区1移到这里 (zIndex = 3)
                if !imageUploader.isOverlayVisible {
                    TouchZoneOne(
                        showContainer: $showContainer,
                        containerWidth: $containerWidth,
                        touchZonePosition: $touchZonePosition,
                        dragOffset: $dragOffset,
                        isZone1Enabled: $isZone1Enabled,
                        isOriginalPaused: $isOriginalPaused,
                        isMirroredPaused: $isMirroredPaused,
                        pausedOriginalImage: $pausedOriginalImage,
                        pausedMirroredImage: $pausedMirroredImage,
                        originalImage: originalImage,
                        mirroredImage: mirroredImage,
                        dragDampingFactor: dragDampingFactor,
                        animationDuration: animationDuration,
                        screenWidth: screenWidth,
                        screenHeight: screenHeight,
                        dragVerticalOffset: dragVerticalOffset,
                        deviceOrientation: orientationManager.currentOrientation,
                        screenshotManager: screenshotManager,
                        handleSwapButtonTap: handleSwapButtonTap,
                        borderLightManager: borderLightManager,
                        imageUploader: imageUploader,
                        currentCameraScale: originalCameraScale,
                        currentMirroredCameraScale: mirroredCameraScale,
                        bothScreensRestarting: showOriginalRestartHint && showMirroredRestartHint,
                        anyScreenRestarting: showOriginalRestartHint || showMirroredRestartHint,
                        onDisabledAction: {
                            // 显示"请先打开摄像头"提示
                            restartHintWorkItem?.cancel()
                            showRestartHint = true
                            
                            let workItem = DispatchWorkItem {
                                withAnimation {
                                    showRestartHint = false
                                }
                            }
                            restartHintWorkItem = workItem
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
                        },
                        onPhotoDisabledAction: {
                            // 显示"请先打开所有摄像头"提示
                            photoDisabledHintWorkItem?.cancel()
                            showPhotoDisabledHint = true
                            
                            let workItem = DispatchWorkItem {
                                withAnimation {
                                    showPhotoDisabledHint = false
                                }
                            }
                            photoDisabledHintWorkItem = workItem
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
                        },
                        dragScale: dragScale  // 传递缩放值
                    )
                    .overlay(
                        Group {
                            if showRestartHint && showOriginalRestartHint && showMirroredRestartHint {
                                Text("请先打开摄像头")
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.black.opacity(0.75))
                                    .cornerRadius(8)
                                    .opacity(0.8)
                                    .allowsHitTesting(false)
                                    .transition(.opacity)
                            } else if showPhotoDisabledHint && (showOriginalRestartHint || showMirroredRestartHint) {
                                Text("请先打开所有摄像头")
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.black.opacity(0.75))
                                    .cornerRadius(8)
                                    .opacity(0.8)
                                    .allowsHitTesting(false)
                                    .transition(.opacity)
                            }
                        }
                    )
                    .zIndex(11)
                }
                
                // 边缘退出手势触控区 - 移到最外层并降低优先级
                EdgeDismissGesture(
                    screenWidth: screenWidth,
                    screenHeight: screenHeight,
                    onDismiss: {
                        // 在退出前关闭所有功能
                        borderLightManager.turnOffAllLights()  // 关闭边框灯
                        cameraManager.stopSession()  // 停止相机会话
                        
                        print("------------------------")
                        print("分屏页面退出")
                        print("------------------------")
                        
                        // 发送通知以便主页面处理
                        NotificationCenter.default.post(
                            name: NSNotification.Name("DismissTwoOfMeView"),
                            object: nil
                        )
                    },
                    pageOffset: $pageOffset,  // 传递页面偏移绑定
                    dragScale: $dragScale,  // 传递缩放绑定
                    isOverlayActive: $isEdgeDismissOverlayActive,  // 传递遮罩状态
                    touchZonePosition: $touchZonePosition  // 传递触控区位置绑定
                )
                .simultaneousGesture(  // 改用 simultaneousGesture 替代 highPriorityGesture
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            // 只有在起始点在边缘20pt范围内时才处理手势
                            let edgeWidth: CGFloat = 20
                            let isLeftEdge = value.startLocation.x <= edgeWidth
                            let isRightEdge = value.startLocation.x >= screenWidth - edgeWidth
                            
                            if isLeftEdge || isRightEdge {
                                // 处理边缘退出手势
                                let horizontalDrag = isLeftEdge ? 
                                    value.location.x - value.startLocation.x :
                                    value.startLocation.x - value.location.x
                                
                                pageOffset = isLeftEdge ? max(0, horizontalDrag) : min(0, -horizontalDrag)
                            }
                        }
                        .onEnded { value in
                            // 如果拖动超过阈值则退出
                            if abs(pageOffset) > screenWidth * 0.3 {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    pageOffset = value.startLocation.x <= 20 ? screenWidth : -screenWidth
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    // 在退出前关闭所有功能
                                    borderLightManager.turnOffAllLights()  // 关闭边框灯
                                    cameraManager.stopSession()  // 停止相机会话
                                    
                                    print("------------------------")
                                    print("分屏页面退出")
                                    print("------------------------")
                                    
                                    // 发送通知以便主页面处理
                                    NotificationCenter.default.post(
                                        name: NSNotification.Name("DismissTwoOfMeView"),
                                        object: nil
                                    )
                                }
                            } else {
                                // 否则回弹
                                withAnimation(.easeOut(duration: 0.2)) {
                                    pageOffset = 0
                                }
                            }
                        }
                )
                .zIndex(4)
                
                // 截图动画 (zIndex = 5)
                ScreenshotAnimationView(
                    isVisible: $screenshotManager.isFlashing,
                    touchZonePosition: touchZonePosition
                )
                .zIndex(998)
                
                // 修改缩放提示动画 (zIndex = 6)
                if showScaleIndicator, let activeScreen = activeScalingScreen {
                    ScaleIndicatorView(
                        scale: currentIndicatorScale,
                        deviceOrientation: orientationManager.currentOrientation  // 传入设备方向
                    )
                    .position(
                        x: screenWidth/2,
                        y: activeScreen == .original 
                            ? (isScreensSwapped ? screenHeight * 3/4 : screenHeight/4)  // Original屏幕中心
                            : (isScreensSwapped ? screenHeight/4 : screenHeight * 3/4)  // Mirrored屏幕中心
                    )
                    .animation(.easeInOut(duration: 0.2), value: currentIndicatorScale)
                    .zIndex(6)
                }
                
                // 添加动画图标 (zIndex = 7)
                if showMiddleIconAnimation {
                    Image("icon-bf-white")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                        .colorMultiply(BorderLightStyleManager.shared.splitScreenIconColor)
                        .opacity(0.25)
                        .transition(.opacity)
                        .rotationEffect(getRotationAngle(orientationManager.currentOrientation))
                        .position(middleAnimationPosition)
                        .zIndex(7)
                }
                
                // 添加黄色遮罩视图 (zIndex = 8)
                YellowMaskView(
                    screenWidth: screenWidth,
                    screenHeight: screenHeight
                )
                .offset(x: pageOffset) // 跟随页面偏移
                .zIndex(8)
                
                // 添加全屏透明遮罩
                EdgeDismissOverlay(isActive: isEdgeDismissOverlayActive)
                    .zIndex(999)  // 确保遮罩在最上层
            }
            .onAppear {
                // 确保开启设备方向监听
                UIDevice.current.beginGeneratingDeviceOrientationNotifications()
                
                if isFirstAppear {
                    // 首次显示时初始化视频处理
                    isFirstAppear = false
                    setupVideoProcessing()
                    print("首次显示时初始化视频处理")
                }
                
                // 添加退出定格状态的通知监听
                NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("ExitPausedState"),
                    object: nil,
                    queue: .main
                ) { [self] notification in
                    if let userInfo = notification.userInfo,
                       let screenID = userInfo["screenID"] as? ScreenID {
                        print("------------------------")
                        print("[通知] 收到退出定格状态通知")
                        print("区域：\(screenID == .original ? "Original" : "Mirrored")屏幕")
                        print("------------------------")
                        
                        // 退出定格状态
                        switch screenID {
                        case .original:
                            if isOriginalPaused {
                                isOriginalPaused = false
                                pausedOriginalImage = nil
                                originalOffset = .zero
                                originalCameraScale = 1.0
                                currentCameraScale = 1.0
                                print("Original画面已恢复")
                            }
                        case .mirrored:
                            if isMirroredPaused {
                                isMirroredPaused = false
                                pausedMirroredImage = nil
                                mirroredOffset = .zero
                                mirroredCameraScale = 1.0
                                currentMirroredCameraScale = 1.0
                                print("Mirrored画面已恢复")
                            }
                        }
                    }
                }
                
                // 添加重置缩放比例的通知监听
                NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("ResetScreenScales"),
                    object: nil,
                    queue: .main
                ) { [self] notification in
                    print("------------------------")
                    print("[双屏重置] 重置两个屏幕的缩放比例和偏移量")
                    print("------------------------")
                    
                    // 重置 Original 屏幕的缩放比例
                    originalImageScale = 1.0
                    currentImageScale = 1.0
                    originalCameraScale = 1.0
                    currentCameraScale = 1.0
                    
                    // 重置 Original 屏幕的偏移量
                    originalOffset = .zero
                    
                    // 重置 Mirrored 屏幕的缩放比例  
                    mirroredImageScale = 1.0
                    currentMirroredImageScale = 1.0
                    mirroredCameraScale = 1.0
                    currentMirroredCameraScale = 1.0
                    
                    // 重置 Mirrored 屏幕的偏移量
                    mirroredOffset = .zero
                    
                    print("[重置完成]")
                    print("Original - 缩放: 100%, 偏移: (0, 0)")
                    print("Mirrored - 缩放: 100%, 偏移: (0, 0)")
                }
                
                print("------------------------")
                print("视图初始化")
                print("触控区2永远对应Original幕（双击可定格/恢复画面）")
                print("触控区3：永远对应Mirrored屏幕（双击可定格/恢复画面）")
                print("初始布局：\(layoutDescription)")
                print("------------------------")
                
                // 加载保存的配置
                let settings = UserSettingsManager.shared.loadTwoOfMeSettings()
                isScreensSwapped = settings.isScreensSwapped
                originalCameraScale = settings.originalCameraScale
                mirroredCameraScale = settings.mirroredCameraScale
                originalImageScale = settings.originalImageScale
                mirroredImageScale = settings.mirroredImageScale
                
                // 同步屏幕交换状态到截图管理器
                screenshotManager.updateScreenSwapState(isScreensSwapped)
            }
            .onDisappear {
                UIDevice.current.endGeneratingDeviceOrientationNotifications()
                NotificationCenter.default.removeObserver(self)
                hideContainerTimer?.invalidate()
                borderLightManager.turnOffAllLights()
                NotificationCenter.default.removeObserver(self, name: NSNotification.Name("ResetScreenScales"), object: nil)
                
                // 保存当前配置
                UserSettingsManager.shared.saveTwoOfMeSettings(
                    isScreensSwapped: isScreensSwapped,
                    originalCameraScale: originalCameraScale,
                    mirroredCameraScale: mirroredCameraScale,
                    originalImageScale: originalImageScale,
                    mirroredImageScale: mirroredImageScale
                )
                
                // 重置所有参数
                UserSettingsManager.shared.resetTwoOfMeSettings()
            }
            .onChange(of: imageUploader.selectedImage) { newImage in
                handleSelectedImage(newImage)
            }
            // 添加前后台切换监听
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                print("------------------------")
                print("[Two of Me] 即将进入后台")
                print("------------------------")
                cameraManager.stopSession()
                // 同时显示两个重启提示
                showOriginalRestartHint = true
                showMirroredRestartHint = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                print("------------------------")
                print("[Two of Me] 已回到前台")
                print("------------------------")
                // 等待用户分别点击重启提示
            }
            // 添加手势设置变化监听
            .onAppear {
                // 初始化手势设置
                isDefaultGesture = BorderLightStyleManager.shared.isDefaultGesture
            }
            .onChange(of: BorderLightStyleManager.shared.isDefaultGesture) { newValue in
                isDefaultGesture = newValue
                print("------------------------")
                print("手势设置已更新")
                print("当前模式：\(isDefaultGesture ? "默认" : "交换")")
                print("边框灯：\(isDefaultGesture ? "单击" : "双击")")
                print("拍照：\(isDefaultGesture ? "双击" : "单击")")
                print("------------------------")
            }
            .onChange(of: isOriginalPaused) { newValue in
                if newValue {
                    showOriginalFlash = true
                    // 动画结束后自动隐藏
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        showOriginalFlash = false
                    }
                }
            }
            .onChange(of: isMirroredPaused) { newValue in
                if newValue {
                    showMirroredFlash = true
                    // 动画结束后自动隐藏
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        showMirroredFlash = false
                    }
                }
            }
            // 监听屏幕交换状态变化
            .onChange(of: isScreensSwapped) { newValue in
                // 同步屏幕交换状态到截图管理器
                screenshotManager.updateScreenSwapState(newValue)
            }
        }
        .ignoresSafeArea(.all)
        
        // 添加 Alert 处理
        .alert(item: $permissionManager.alertState) { state in
            permissionManager.makeAlert()
        }
        
        // 添加全局权限管理视图
        PermissionManagerView()
            .zIndex(1000)
            .onChange(of: permissionManager.alertState) { newValue in
                if newValue != nil {
                    // 当 Alert 出现时，停止相机并显示重启提示
                    handleCameraStop()
                }
            }
    }
    
    private func setupVideoProcessing() {
        print("------------------------")
        print("[视频处理] 初始化开始")
        print("------------------------")
        
        let processor = VideoProcessor()
        
        // 初始化时启用两个输出
        processor.enableOriginalOutput = true
        processor.enableMirroredOutput = true
        
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
        
        // 延迟1秒后在后台线程检查和启动相机
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak cameraManager] in
            DispatchQueue.global(qos: .userInitiated).async {
                cameraManager?.checkPermission()
                // 确保相机重启
                cameraManager?.restartCamera()
            }
        }
        
        print("------------------------")
        print("[视频处理] 初始化完成")
        print("------------------------")
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
                imageUploader.setPausedImage(nil, for: .original)
                // 重置偏移量
                originalOffset = .zero
                // 同步缩放比例到实时画面
                originalCameraScale = originalImageScale
                currentCameraScale = currentImageScale
                
                print("------------------------")
                print("[定格退出] Original屏幕")
                print("实时画面比例: \(Int(currentCameraScale * 100))%")
                print("定格画面比例: \(Int(currentImageScale * 100))%")
                print("------------------------")
            } else {
                // 进入定格状态
                isOriginalPaused = true
                // 同步实时画面的缩放比例到定格画面
                originalImageScale = originalCameraScale
                currentImageScale = currentCameraScale
                
                print("------------------------")
                print("[定格进入] Original屏幕")
                print("实时画面比例: \(Int(currentCameraScale * 100))%")
                print("定格画面比例: \(Int(currentImageScale * 100))%")
                print("------------------------")

                if let image = originalImage {
                    // 根据设备方向旋转图片
                    let rotatedImage = rotateImageForCurrentOrientation(image)
                    pausedOriginalImage = rotatedImage
                    
                    // 传入摄像头基准缩放比例，确保裁剪后的图片大小与摄像头画面一致
                    imageUploader.setPausedImage(
                        rotatedImage,
                        for: .original,
                        scale: currentImageScale,
                        cameraScale: originalCameraScale  // 添加摄像头基准比例参数
                    )
                }
            }
            
        case .mirrored:
            if isMirroredPaused {
                // 退出定格状态
                isMirroredPaused = false
                pausedMirroredImage = nil
                imageUploader.setPausedImage(nil, for: .mirrored)
                // 重置偏移量
                mirroredOffset = .zero
                // 同步缩放比例到实时画面
                mirroredCameraScale = mirroredImageScale
                currentMirroredCameraScale = currentMirroredImageScale
                
                print("------------------------")
                print("[定格退出] Mirrored屏幕")
                print("实时画面比例: \(Int(currentMirroredCameraScale * 100))%")
                print("定格画面比例: \(Int(currentMirroredImageScale * 100))%")
                print("------------------------")
            } else {
                // 进入定格状态
                isMirroredPaused = true
                // 同步实时画面的缩放比例到定格画面
                mirroredImageScale = mirroredCameraScale
                currentMirroredImageScale = currentMirroredCameraScale
                
                print("------------------------")
                print("[定格进入] Mirrored屏幕")
                print("实时画面比例: \(Int(currentMirroredCameraScale * 100))%")
                print("定格画面比例: \(Int(currentMirroredImageScale * 100))%")
                print("------------------------")

                if let image = mirroredImage {
                    // 根据设备方向旋转图片
                    let rotatedImage = rotateImageForCurrentOrientation(image)
                    pausedMirroredImage = rotatedImage
                    
                    // 传入摄像头基准缩放比例，确保裁剪后的图片大小与摄像头画面一致
                    imageUploader.setPausedImage(
                        rotatedImage,
                        for: .mirrored,
                        scale: currentMirroredImageScale,
                        cameraScale: mirroredCameraScale  // 添加摄像头基准比例参数
                    )
                }
            }
        }
    }
    
    // 辅助方法：根据当前设备方向旋转图片
    private func rotateImageForCurrentOrientation(_ image: UIImage) -> UIImage {
        let orientation = DeviceOrientationManager.shared.validOrientation
        switch orientation {
        case .landscapeLeft:
            return image.rotate(degrees: -90)
        case .landscapeRight:
            return image.rotate(degrees: 90)
        case .portraitUpsideDown:
            return image.rotate(degrees: 180)
        default:
            return image
        }
    }
    
    private func getIconName(_ orientation: UIDeviceOrientation) -> String {
        // 根据分屏蝴蝶颜色设置选择图标
        if styleManager.splitScreenIconColor != .purple {
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
    
    // 添加相机停止处理方法
    private func handleCameraStop() {
        print("------------------------")
        print("[权限弹窗] 停止相机会话")
        print("------------------------")
        
        // 停止相机会话
        cameraManager.safelyStopSession()
        
        // 显示重启提示
        showOriginalRestartHint = true
        showMirroredRestartHint = true
    }
    
    // 修改重启相机方法
    private func restartCamera() {
        if !cameraManager.permissionGranted {
            print("[相机重启] 无相机权限，无法重启")
            return
        }
        
        print("------------------------")
        print("[相机重启] 开始")
        print("------------------------")
        
        // 在后台线程启动相机会话
        DispatchQueue.global(qos: .userInitiated).async {
            cameraManager.restartCamera()
            
            // 在主线程更新 UI 状态
            DispatchQueue.main.async {
                showOriginalRestartHint = false
                showMirroredRestartHint = false
                print("[相机重启] 完成")
            }
        }
    }
    
    // 修改 Original 屏幕视图
    private var originalScreenView: some View {
        ZStack {
            if showOriginalRestartHint {
                // 显示重启提示
                RestartHintView(
                    screenID: .original,
                    onTap: restartCamera
                )
            } else {
                // 显示正常的相机视图
                // ... 原有的相机视图代码 ...
            }
        }
    }
    
    // 修改 Mirrored 屏幕视图
    private var mirroredScreenView: some View {
        ZStack {
            if showMirroredRestartHint {
                // 显示重启提示
                RestartHintView(
                    screenID: .mirrored,
                    onTap: restartCamera
                )
            } else {
                // 显示正常的相机视图
                // ... 原有的相机视图代码 ...
            }
        }
    }
}

// 添加重启提示视图组件
struct RestartHintView: View {
    let screenID: ScreenID
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
                Text("点击重启相机")
                    .foregroundColor(.white)
                    .font(.system(size: 16))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

#Preview {
    TwoOfMeScreens()
} 

