import SwiftUI
import UIKit
import Photos
import AVKit

// 截图操作按钮样式
public struct CaptureButtonStyle {
    public static let buttonSize: CGFloat = 60
    public static let buttonSpacing: CGFloat = 40
    public static let buttonBackgroundOpacity: Double = 0.5
}

// 截图操作状态
public class CaptureState: ObservableObject {
    @Published public var capturedImage: UIImage?
    @Published public var capturedLivePhotoURL: URL?
    @Published public var showButtons: Bool = false
    @Published public var currentScale: CGFloat = 1.0
    @Published public var showSaveSuccess: Bool = false
    @Published public var isCapturing: Bool = false
    @Published public var isLivePhoto: Bool = false
    @Published public var livePhotoImageData: Data?
    @Published public var livePhotoVideoURL: URL?
    @Published public var isPlayingLivePhoto: Bool = false
    @Published public var livePhotoIdentifier: String = ""
    @Published public var tempImageURL: URL?
    @Published public var tempVideoURL: URL?
    @Published public var captureOrientation: UIDeviceOrientation = .portrait
    @Published var showScaleIndicator = false
    @Published var currentIndicatorScale: CGFloat = 1.0
    @Published public var isCheckmarkEnabled: Bool = false
    
    private var isProcessingAlert = false
    private let fileManager = FileManager.default
    private var persistentDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    // 根据缩放比例裁剪图片
    func cropImage(_ image: UIImage, scale: CGFloat) -> UIImage {
        let screenBounds = UIScreen.main.bounds
        let screenSize = screenBounds.size
        
        // 计算图片在屏幕上的实际显示尺寸
        let imageAspect = image.size.width / image.size.height
        let screenAspect = screenSize.width / screenSize.height
        
        var drawWidth: CGFloat
        var drawHeight: CGFloat
        
        if imageAspect > screenAspect {
            // 图片较宽，以高度为基准
            drawHeight = screenSize.height
            drawWidth = drawHeight * imageAspect
        } else {
            // 图片较高，以宽度为基准
            drawWidth = screenSize.width
            drawHeight = drawWidth / imageAspect
        }
        
        // 应用缩放
        let scale = max(1.0, scale)
        drawWidth *= scale
        drawHeight *= scale
        
        // 计算居中位置
        let x = (drawWidth - screenSize.width) / 2
        let y = (drawHeight - screenSize.height) / 2
        
        // 创建绘图上下文
        UIGraphicsBeginImageContextWithOptions(screenSize, false, image.scale)
        
        // 绘制放大后的图片，保持宽高比
        let drawRect = CGRect(x: -x, y: -y, width: drawWidth, height: drawHeight)
        image.draw(in: drawRect)
        
        // 获取裁剪后的图片
        let croppedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return croppedImage ?? image
    }
    
    // 添加持久化存储方法
    private func persistFile(from sourceURL: URL, withPrefix prefix: String) -> URL? {
        let fileName = sourceURL.lastPathComponent
        let destinationURL = persistentDirectory.appendingPathComponent("\(prefix)_\(fileName)")
        
        print("[文件持久化] 开始")
        print("源文件：\(sourceURL.path)")
        print("目标文件：\(destinationURL.path)")
        
        do {
            // 如果目标文件已存在，先删除
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
                print("[文件持久化] 删除已存在的目标文件")
            }
            
            // 复制文件
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            print("[文件持久化] 文件复制成功")
            
            return destinationURL
        } catch {
            print("[文件持久化] 错误：\(error.localizedDescription)")
            return nil
        }
    }
    
    // 修改保存方法
    public func saveToPhotos() {
        print("------------------------")
        print("[保存到相册] 开始")
        print("是否为Live Photo：\(isLivePhoto)")
        
        // 直接使用 CaptureManager 的保存方法
        CaptureManager.shared.saveToPhotos { success in
            if success {
                print("[保存到相册] 保存成功")
                withAnimation {
                    self.showSaveSuccess = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        self.showSaveSuccess = false
                    }
                }
            } else {
                print("[保存到相册] 保存失败")
            }
        }
    }
    
    // 修改重置方法
    public func reset(onComplete: (() -> Void)? = nil) {
        capturedImage = nil
        capturedLivePhotoURL = nil
        showButtons = false
        isProcessingAlert = false
        isLivePhoto = false
        livePhotoImageData = nil
        livePhotoVideoURL = nil
        isPlayingLivePhoto = false  // 重置播放状态
        onComplete?()
    }
    
    // 修改分享方法
    public func shareImage() {
        if isLivePhoto {
            shareLivePhoto()
        } else {
            shareStaticImage()
        }
    }
    
    private func shareStaticImage() {
        guard let image = capturedImage else { return }
        let processedImage = cropImage(image, scale: currentScale)
        
        let activityViewController = UIActivityViewController(
            activityItems: [processedImage],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            rootViewController.present(activityViewController, animated: true) {
                print("分享界面已显示")
            }
        }
    }
    
    private func shareLivePhoto() {
        guard let livePhotoURL = capturedLivePhotoURL else { return }
        
        let activityViewController = UIActivityViewController(
            activityItems: [livePhotoURL],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            rootViewController.present(activityViewController, animated: true) {
                print("Live Photo 分享界面已显示")
            }
        }
    }
}

// 截图操作按钮
public struct CaptureActionButton: View {
    let systemName: String
    let action: () -> Void
    let feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle
    let color: Color
    
    public init(systemName: String, 
         action: @escaping () -> Void, 
         feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle = .medium,
         color: Color) {
        self.systemName = systemName
        self.action = action
        self.feedbackStyle = feedbackStyle
        self.color = color
    }
    
    public var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: feedbackStyle)
            generator.prepare()
            generator.impactOccurred()
            action()
        }) {
            Image(systemName: systemName)
                .font(.system(size: 24))
                .foregroundColor(color)
                .frame(width: 50, height: 50)
                .background(Color.black.opacity(0.35))
                .clipShape(Circle())
        }
    }
    
    // 添加一个新的初始化方法,专门用于处理下载按钮
    public static func downloadButton(
        captureState: CaptureState,
        color: Color,
        rotationAngle: Double
    ) -> some View {
        CaptureActionButton(
            systemName: "square.and.arrow.down.fill",
            action: {
                // 触发震动反馈
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.prepare()
                generator.impactOccurred()
                
                captureState.saveToPhotos()
            },
            feedbackStyle: .medium,
            color: color
        )
        .rotationEffect(.degrees(rotationAngle))
        .animation(.easeInOut(duration: 0.3), value: rotationAngle)
    }
}

// 修改进度条视图
struct SimulationProgressView: View {
    let progress: Double
    let screenBounds: CGRect
    
    var body: some View {
        ZStack {
            // 全屏半透明白色遮罩
            Color.white.opacity(0.5)
                .frame(width: screenBounds.width, height: screenBounds.height)
                .edgesIgnoringSafeArea(.all)
            
            // 进度指示器
            VStack(spacing: 12) {
                ProgressView(value: progress)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(20)
            .background(Color.black.opacity(0.6))
            .cornerRadius(12)
        }
    }
}

// 截图操作视图
public struct CaptureActionsView: View {
    @ObservedObject var captureManager: CaptureManager
    @ObservedObject private var orientationManager = DeviceOrientationManager.shared
    @ObservedObject private var styleManager = BorderLightStyleManager.shared
    let cameraManager: CameraManager
    let onDismiss: () -> Void
    
    // 使用普通的 State 来跟踪长按状态
    @State private var isLongPressed = false
    @State private var isScalingFrom60Percent = false  // 添加新状态跟踪是否从60%开始缩放
    
    // 添加缩放相关状态
    @State private var showScaleIndicator = false
    @State private var currentIndicatorScale: CGFloat = 1.0
    @State private var baseScale: CGFloat = 1.0
    @State private var shouldIgnoreScale: Bool = false
    
    // 添加加载状态
    @State private var isProcessingSimulation = false
    
    public var body: some View {
        if captureManager.isPreviewVisible {
            GeometryReader { geometry in
                let screenBounds = UIScreen.main.bounds
                
                ZStack {
                    // 背景层
                    Color.black
                        .frame(width: screenBounds.width, height: screenBounds.height)
                        .position(x: screenBounds.width/2, y: screenBounds.height/2)
                        .allowsHitTesting(false)

                    // 主要内容层
                    ZStack {
                        // 图片层 - 在播放Live Photo时隐藏
                        if let image = captureManager.capturedImage {
                            if !(captureManager.isLivePhoto && captureManager.isPlayingLivePhoto) {
                                let _ = captureManager.captureOrientation.isLandscape
                                let displayWidth = screenBounds.width
                                let displayHeight = screenBounds.height
                                
                                Group {
                                    // 根据Live模式和勾选状态显示不同的图片
                                    if captureManager.isLivePhoto {
                                        // Live Photo模式
                                        if captureManager.isCheckmarkEnabled {
                                            // 勾选状态 - 显示模拟的黄色图片
                                            Image(uiImage: image)  // 此时image已经是黄色的模拟图片
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: displayWidth, height: displayHeight)
                                                .scaleEffect(captureManager.currentScale)
                                                .offset(captureManager.dragOffset)
                                                .clipped()
                                        } else {
                                            // 未勾选状态 - 显示原始Live Photo静态图片
                                            Image(uiImage: image)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: displayWidth, height: displayHeight)
                                                .scaleEffect(captureManager.currentScale)
                                                .offset(captureManager.dragOffset)
                                                .clipped()
                                        }
                                    } else {
                                        // 普通照片模式 - 使用现有的预览图片处理逻辑
                                        let displayImage = Image(uiImage: captureManager.getPreviewImage(baseImage: image))
                                        displayImage
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: displayWidth, height: displayHeight)
                                            .scaleEffect(captureManager.currentScale)
                                            .offset(captureManager.dragOffset)
                                            .clipped()
                                    }
                                }
                            }
                        }
                        
                        // Live Photo播放视图
                        if captureManager.isLivePhoto && captureManager.livePhotoVideoURL != nil && captureManager.isPlayingLivePhoto {
                            ZStack {
                                let isLandscape = captureManager.captureOrientation.isLandscape
                                let displayWidth = isLandscape ? screenBounds.height : screenBounds.width
                                let displayHeight = isLandscape ? screenBounds.width : screenBounds.height
                                
                                // 使用LivePhotoPlayerView播放视频，无论是否为模拟模式
                                LivePhotoPlayerView(
                                    videoURL: captureManager.livePhotoVideoURL!,
                                    isPlaying: $captureManager.isPlayingLivePhoto,
                                    orientation: captureManager.captureOrientation
                                )
                                .frame(width: isLandscape ? displayWidth:displayWidth+250, height: isLandscape ? displayHeight+250:displayHeight)
                                .scaleEffect(captureManager.currentScale)
                                .offset(captureManager.dragOffset)
                                .rotationEffect(getRotationAngle(for: captureManager.captureOrientation))
                            }
                            .position(x: screenBounds.width/2, y: screenBounds.height/2)
                            .allowsHitTesting(false)
                            .zIndex(1)
                        }
                        
                        // 触控层 - 处理缩放、拖动和点击
                        Color.clear
                            .contentShape(Rectangle())
                            .frame(width: screenBounds.width, height: screenBounds.height)
                            .gesture(
                                SimultaneousGesture(
                                    SimultaneousGesture(
                                        // 缩放手势
                                        MagnificationGesture()
                                            .onChanged { value in
                                                // 如果应该忽略缩放，直接返回
                                                if shouldIgnoreScale {
                                                    return
                                                }
                                                
                                                let minScale: CGFloat = 0.6 // 最小缩放比例 (60%)
                                                let maxScale: CGFloat = 10.0 // 最大缩放比例
                                                let newScale = baseScale * value
                                                
                                                // 更新缩放提示
                                                captureManager.currentIndicatorScale = captureManager.currentScale
                                                captureManager.showScaleIndicator = true
                                                
                                                // 特殊处理100%和60%之间的缩放
                                                if abs(captureManager.currentScale - 1.0) < 0.01 && value < 1.0 {
                                                    // 从100%缩小时，直接跳到60%
                                                    captureManager.currentScale = minScale
                                                    baseScale = minScale
                                                    captureManager.currentIndicatorScale = minScale
                                                    
                                                    // 重置偏移量
                                                    withAnimation(.easeOut(duration: 0.2)) {
                                                        captureManager.dragOffset = .zero
                                                        captureManager.lastDragOffset = .zero
                                                    }
                                                    return
                                                } else if abs(captureManager.currentScale - minScale) < 0.01 && value > 1.0 {
                                                    // 从60%放大时，直接跳到100%并结束当前手势
                                                    captureManager.currentScale = 1.0
                                                    baseScale = 1.0
                                                    captureManager.currentIndicatorScale = 1.0
                                                    shouldIgnoreScale = true
                                                    
                                                    // 重置偏移量
                                                    withAnimation(.easeOut(duration: 0.2)) {
                                                        captureManager.dragOffset = .zero
                                                        captureManager.lastDragOffset = .zero
                                                    }
                                                    return
                                                } else if captureManager.currentScale >= 1.0 {
                                                    // 在100%以上时允许自由缩放
                                                    let oldScale = captureManager.currentScale
                                                    captureManager.currentScale = min(max(newScale, 1.0), maxScale)
                                                    
                                                    // 根据缩放比例调整偏移量
                                                    if captureManager.currentScale > 1.0 {
                                                        // 计算缩放前后的比例
                                                        let scaleFactor = captureManager.currentScale / oldScale
                                                        
                                                        // 按比例调整偏移量
                                                        let newOffset = CGSize(
                                                            width: captureManager.dragOffset.width * scaleFactor,
                                                            height: captureManager.dragOffset.height * scaleFactor
                                                        )
                                                        
                                                        // 计算新的最大偏移范围
                                                        let maxOffset = calculateMaxOffset(
                                                            scale: captureManager.currentScale,
                                                            screenSize: screenBounds.size,
                                                            imageSize: captureManager.capturedImage?.size ?? screenBounds.size
                                                        )
                                                        
                                                        // 限制新的偏移量在有效范围内
                                                        captureManager.dragOffset = CGSize(
                                                            width: max(-maxOffset.width, min(maxOffset.width, newOffset.width)),
                                                            height: max(-maxOffset.height, min(maxOffset.height, newOffset.height))
                                                        )
                                                        captureManager.lastDragOffset = captureManager.dragOffset
                                                    }
                                                }
                                                
                                                captureManager.currentIndicatorScale = captureManager.currentScale
                                            }
                                            .onEnded { _ in
                                                // 添加震动反馈
                                                let generator = UIImpactFeedbackGenerator(style: .light)
                                                generator.impactOccurred()
                                                
                                                // 重置缩放状态
                                                shouldIgnoreScale = false
                                                baseScale = captureManager.currentScale
                                                
                                                // 如果缩放比例接近1，重置位置
                                                if abs(captureManager.currentScale - 1.0) < 0.1 {
                                                    withAnimation(.easeOut(duration: 0.2)) {
                                                        captureManager.currentScale = 1.0
                                                        captureManager.dragOffset = .zero
                                                        captureManager.lastDragOffset = .zero
                                                    }
                                                }
                                                
                                                // 延迟隐藏缩放指示器
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                    withAnimation {
                                                        captureManager.showScaleIndicator = false
                                                    }
                                                }
                                            },
                                        // 拖动手势
                                        DragGesture()
                                            .onChanged { value in
                                                // 只有在缩放比例大于1时才允许拖动
                                                if captureManager.currentScale > 1.0 {
                                                    // 计算可拖动的最大范围
                                                    let maxOffset = calculateMaxOffset(
                                                        scale: captureManager.currentScale,
                                                        screenSize: screenBounds.size,
                                                        imageSize: captureManager.capturedImage?.size ?? screenBounds.size
                                                    )
                                                    
                                                    // 计算新的偏移量
                                                    var newOffset = CGSize(
                                                        width: captureManager.lastDragOffset.width + value.translation.width,
                                                        height: captureManager.lastDragOffset.height + value.translation.height
                                                    )
                                                    
                                                    // 添加边缘阻尼效果
                                                    let dampingFactor: CGFloat = 0.2
                                                    if abs(newOffset.width) > maxOffset.width {
                                                        let overscroll = abs(newOffset.width) - maxOffset.width
                                                        let damping = 1.0 - min(overscroll / maxOffset.width, dampingFactor)
                                                        newOffset.width *= damping
                                                    }
                                                    if abs(newOffset.height) > maxOffset.height {
                                                        let overscroll = abs(newOffset.height) - maxOffset.height
                                                        let damping = 1.0 - min(overscroll / maxOffset.height, dampingFactor)
                                                        newOffset.height *= damping
                                                    }
                                                    
                                                    // 限制拖动范围
                                                    newOffset.width = max(-maxOffset.width, min(maxOffset.width, newOffset.width))
                                                    newOffset.height = max(-maxOffset.height, min(maxOffset.height, newOffset.height))
                                                    
                                                    // 直接更新偏移量，不使用动画
                                                    captureManager.dragOffset = newOffset
                                                }
                                            }
                                            .onEnded { value in
                                                if captureManager.currentScale > 1.0 {
                                                    // 计算最终位置时添加边界检查
                                                    let maxOffset = calculateMaxOffset(
                                                        scale: captureManager.currentScale,
                                                        screenSize: screenBounds.size,
                                                        imageSize: captureManager.capturedImage?.size ?? screenBounds.size
                                                    )
                                                    
                                                    var finalOffset = captureManager.dragOffset
                                                    finalOffset.width = max(-maxOffset.width, min(maxOffset.width, finalOffset.width))
                                                    finalOffset.height = max(-maxOffset.height, min(maxOffset.height, finalOffset.height))
                                                    
                                                    withAnimation(.easeOut(duration: 0.2)) {
                                                        captureManager.dragOffset = finalOffset
                                                    }
                                                    captureManager.lastDragOffset = finalOffset
                                                }
                                            }
                                    ),
                                    TapGesture(count: BorderLightStyleManager.shared.captureGestureCount)
                                        .onEnded {
                                            withAnimation {
                                                captureManager.hidePreview(cameraManager: cameraManager)
                                                onDismiss()
                                            }
                                        }
                                )
                            )
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onEnded { _ in
                                        if isLongPressed {
                                            print("[长按手势] 结束")
                                            isLongPressed = false
                                            if captureManager.isPlayingLivePhoto {
                                                print("[长按手势] 停止播放Live Photo")
                                                withAnimation {
                                                    captureManager.isPlayingLivePhoto = false
                                                }
                                            }
                                        }
                                    }
                                    .onChanged { _ in
                                        // 如果手指移动时已经不是长按状态，则停止播放
                                        if !isLongPressed && captureManager.isPlayingLivePhoto {
                                            print("[长按手势] 手指移动，停止播放Live Photo")
                                            withAnimation {
                                                captureManager.isPlayingLivePhoto = false
                                            }
                                        }
                                    }
                            )
                            .highPriorityGesture(
                                LongPressGesture(minimumDuration: 0.5)
                                    .onEnded { _ in
                                        print("[长按手势] 开始")
                                        print("[长按手势] Live Photo状态：\(captureManager.isLivePhoto)")
                                        print("[长按手势] 视频URL：\(String(describing: captureManager.livePhotoVideoURL))")
                                        print("[长按手势] 当前播放状态：\(captureManager.isPlayingLivePhoto)")
                                        
                                        if captureManager.isLivePhoto && captureManager.livePhotoVideoURL != nil && !captureManager.isPlayingLivePhoto {
                                            isLongPressed = true
                                            // 触发震动反馈
                                            let generator = UIImpactFeedbackGenerator(style: .medium)
                                            generator.impactOccurred()
                                            
                                            print("[长按手势] 开始播放Live Photo")
                                            withAnimation {
                                                captureManager.isPlayingLivePhoto = true
                                            }
                                        }
                                    }
                            )
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 0)
                                    .onEnded { _ in
                                        // 在拖动结束时也检查是否需要停止播放
                                        if captureManager.isPlayingLivePhoto {
                                            print("[拖动手势] 结束，停止播放Live Photo")
                                            withAnimation {
                                                captureManager.isPlayingLivePhoto = false
                                            }
                                            isLongPressed = false
                                        }
                                    }
                            )
                            .onTapGesture { } // 添加空的点击手势以确保视图可以接收触摸事件
                            .allowsHitTesting(true)
                            .zIndex(2)
                    }
                    .frame(width: screenBounds.width, height: screenBounds.height)
                    .position(x: screenBounds.width/2, y: screenBounds.height/2)
                    
                    // Live Photo提示标识
                    if captureManager.isLivePhoto && !captureManager.isPlayingLivePhoto {
                        VStack {
                            HStack {
                                Image(systemName: "livephoto")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)
                                
                                Text("长按播放")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(15)
                        }
                        .position(x: screenBounds.width/2, y: screenBounds.height - 160)
                        .zIndex(10)
                    }
                    
                    // 保存成功提示
                    if captureManager.showSaveSuccess {
                        Text("已保存到相册")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                            .position(x: screenBounds.width/2, y: screenBounds.height/2)
                            .zIndex(11)
                    }
                    
                    // 底部操作按钮
                    VStack(spacing: 0) {
                        Spacer()
                        
                        // 底部操作按钮
                        ZStack {
                            HStack {
                                Spacer()
                                
                                // 使用新的下载按钮，居中显示
                                CaptureActionButton(
                                    systemName: "square.and.arrow.down.fill",
                                    action: {
                                        // 触发震动反馈
                                        let generator = UIImpactFeedbackGenerator(style: .medium)
                                        generator.prepare()
                                        generator.impactOccurred()
                                        
                                        captureManager.saveToPhotos()
                                    },
                                    feedbackStyle: .medium,
                                    color: styleManager.iconColor
                                )
                                
                                Spacer()
                            }
                        }
                        .rotationEffect(getRotationAngle(for: orientationManager.currentOrientation))
                        .animation(.easeInOut(duration: 0.3), value: orientationManager.currentOrientation)
                        .frame(height: 120)
                    }
                    .frame(width: screenBounds.width, height: screenBounds.height)
                    
                    // 将关闭按钮移到最上层
                    VStack {
                        HStack {
                            Spacer()
                            // 添加勾选按钮
                            if captureManager.shouldShowCheckmark {
                                ZStack {
                                    Button(action: {
                                        // 触发震动反馈
                                        let generator = UIImpactFeedbackGenerator(style: .light)
                                        generator.prepare()
                                        generator.impactOccurred()
                                        
                                        withAnimation {
                                            if captureManager.isCheckmarkEnabled {
                                                // 直接取消勾选
                                                captureManager.isCheckmarkEnabled.toggle()
                                                captureManager.handleCheckmarkToggle()
                                            } else {
                                                // 开始处理模拟数据
                                                isProcessingSimulation = true
                                                captureManager.isCheckmarkEnabled.toggle()
                                                captureManager.handleCheckmarkToggle()
                                            }
                                        }
                                    }) {
                                        Image(systemName: captureManager.isCheckmarkEnabled ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 20, weight: .medium))
                                            .foregroundColor(.white)
                                            .frame(width: 36, height: 36)
                                            .background(Color.black.opacity(0.35))
                                            .clipShape(Circle())
                                    }
                                    .rotationEffect(getRotationAngle(for: orientationManager.currentOrientation))
                                    .animation(.easeInOut(duration: 0.3), value: orientationManager.currentOrientation)
                                    .padding(.top, 80)
                                    
                                    // 添加加载指示器
                                    if isProcessingSimulation {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(1.2)
                                            .frame(width: 36, height: 36)
                                            .background(Color.black.opacity(0.35))
                                            .clipShape(Circle())
                                            .rotationEffect(getRotationAngle(for: orientationManager.currentOrientation))
                                            .animation(.easeInOut(duration: 0.3), value: orientationManager.currentOrientation)
                                            .padding(.top, 80)
                                    }
                                }
                                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SimulationComplete"))) { _ in
                                    withAnimation {
                                        isProcessingSimulation = false
                                    }
                                }
                            }
                            
                            Button(action: {
                                print("关闭按钮被点击")
                                // 触发震动反馈
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.prepare()
                                generator.impactOccurred()
                                
                                withAnimation {
                                    // 只重置勾选状态和预览图片缓存
                                    captureManager.isCheckmarkEnabled = false
                                    captureManager.previewMixImage = nil
                                    
                                    captureManager.hidePreview(cameraManager: cameraManager)
                                    onDismiss()
                                }
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(width: 36, height: 36)
                                    .background(Color.black.opacity(0.35))
                                    .clipShape(Circle())
                            }
                            .rotationEffect(getRotationAngle(for: orientationManager.currentOrientation))
                            .animation(.easeInOut(duration: 0.3), value: orientationManager.currentOrientation)
                            .padding(.top, 80)
                            Spacer()
                        }
                        Spacer()
                    }
                    .zIndex(99)
                    
                    // 添加缩放指示器
                    if captureManager.showScaleIndicator {
                        ScaleIndicatorView(
                            scale: captureManager.currentIndicatorScale,
                            deviceOrientation: orientationManager.currentOrientation,
                            isMinScale: abs(captureManager.currentIndicatorScale - 0.6) < 0.01
                        )
                        .position(x: screenBounds.width/2, y: screenBounds.height/2)
                        .zIndex(98)
                    }
                    
                    // 将进度条和遮罩层移到最顶层
                    if isProcessingSimulation && captureManager.simulationProgress > 0 && captureManager.simulationProgress <= 1.0 {
                        Color.white.opacity(0.5)
                            .frame(width: screenBounds.width, height: screenBounds.height)
                            .edgesIgnoringSafeArea(.all)
                            .zIndex(200)
                        
                        SimulationProgressView(
                            progress: captureManager.simulationProgress,
                            screenBounds: screenBounds
                        )
                        .position(x: screenBounds.width/2, y: screenBounds.height/2)
                        .zIndex(201)
                    }
                }
                .ignoresSafeArea()
            }
        }
    }
    
    // 修改 shouldRotate180Degrees 计算属性
    private var shouldRotate180Degrees: Bool {
        // 始终返回false，不进行180度旋转
        return false
    }
}

// 添加获取旋转角度的辅助方法
private func getRotationAngle(for orientation: UIDeviceOrientation) -> Angle {
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

// 修改LivePhotoPlayerView实现，使用AVPlayerLayer的transform来控制视频方向
struct LivePhotoPlayerView: UIViewControllerRepresentable {
    let videoURL: URL
    @Binding var isPlaying: Bool
    let orientation: UIDeviceOrientation
    
    // 添加播放器引用
    private let player = AVPlayer()
    
    class Coordinator: NSObject {
        var parent: LivePhotoPlayerView
        var playerTimeObserver: Any?
        var playerItemObserver: NSKeyValueObservation?
        
        init(_ parent: LivePhotoPlayerView) {
            self.parent = parent
        }
        
        deinit {
            if let observer = playerTimeObserver {
                parent.player.removeTimeObserver(observer)
            }
            playerItemObserver?.invalidate()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        print("[LivePhotoPlayerView] makeUIViewController 被调用")
        print("[LivePhotoPlayerView] 视频URL: \(videoURL.absoluteString)")
        print("[LivePhotoPlayerView] 设备方向: \(orientation)")
        
        // 检查文件是否存在
        if FileManager.default.fileExists(atPath: videoURL.path) {
            print("[LivePhotoPlayerView] 视频文件存在")
        } else {
            print("[LivePhotoPlayerView] 错误：视频文件不存在")
            return AVPlayerViewController()
        }
        
        let playerViewController = AVPlayerViewController()
        playerViewController.player = player
        playerViewController.showsPlaybackControls = false
        playerViewController.videoGravity = .resizeAspectFill
        
        // 设置视频源
        let playerItem = AVPlayerItem(url: videoURL)
        player.replaceCurrentItem(with: playerItem)
        
        // 监听播放器状态
        context.coordinator.playerItemObserver = playerItem.observe(\.status, options: [.new]) { item, _ in
            print("[LivePhotoPlayerView] 播放器状态更新: \(item.status.rawValue)")
            if item.status == .readyToPlay {
                print("[LivePhotoPlayerView] 播放器准备就绪")
                if self.isPlaying {
                    print("[LivePhotoPlayerView] 开始播放")
                    self.player.play()
                }
            }
        }
        
        // 设置视频方向
        if let playerLayer = playerViewController.view.layer as? AVPlayerLayer {
            let transform: CGAffineTransform
            
            switch orientation {
            case .landscapeLeft:
                transform = CGAffineTransform(rotationAngle: .pi / 2)
            case .landscapeRight:
                transform = CGAffineTransform(rotationAngle: -.pi / 2)
            case .portraitUpsideDown:
                transform = CGAffineTransform(rotationAngle: .pi)
            default:
                transform = .identity
            }
            
            // 应用变换到播放器层
            playerLayer.setAffineTransform(transform)
        }
        
        // 添加播放结束通知
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            print("[LivePhotoPlayerView] 视频播放完毕，重置到第一帧")
            self.player.seek(to: .zero)
            self.player.pause()
            
            // 通知外部停止播放
            DispatchQueue.main.async {
                self.isPlaying = false
            }
        }
        
        return playerViewController
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        print("[LivePhotoPlayerView] updateUIViewController 被调用")
        print("[LivePhotoPlayerView] 播放状态: \(player.timeControlStatus.rawValue)")
        
        if isPlaying {
            if player.timeControlStatus != .playing {
                if player.currentItem?.status == .readyToPlay {
                    print("[LivePhotoPlayerView] 开始/恢复播放")
                    player.seek(to: .zero)
                    player.play()
                } else {
                    print("[LivePhotoPlayerView] 等待播放器就绪")
                }
            }
        } else {
            if player.timeControlStatus == .playing {
                print("[LivePhotoPlayerView] 暂停播放")
                player.pause()
            }
        }
    }
    
    static func dismantleUIViewController(_ uiViewController: AVPlayerViewController, coordinator: Coordinator) {
        print("[LivePhotoPlayerView] dismantleUIViewController 被调用")
        coordinator.playerItemObserver?.invalidate()
        if let player = uiViewController.player {
            player.pause()
            NotificationCenter.default.removeObserver(player)
        }
        uiViewController.player = nil
    }
}

// 添加计算最大拖动范围的辅助函数
private func calculateMaxOffset(scale: CGFloat, screenSize: CGSize, imageSize: CGSize) -> CGSize {
    // 计算图片在屏幕上的实际显示尺寸
    let imageAspect = imageSize.width / imageSize.height
    let screenAspect = screenSize.width / screenSize.height
    
    var displayWidth: CGFloat
    var displayHeight: CGFloat
    
    if imageAspect > screenAspect {
        // 图片较宽，以高度为基准
        displayHeight = screenSize.height
        displayWidth = displayHeight * imageAspect
    } else {
        // 图片较高，以宽度为基准
        displayWidth = screenSize.width
        displayHeight = displayWidth / imageAspect
    }
    
    // 应用缩放
    displayWidth *= scale
    displayHeight *= scale
    
    // 计算可拖动的最大范围
    let maxOffsetX = max(0, (displayWidth - screenSize.width) / 2)
    let maxOffsetY = max(0, (displayHeight - screenSize.height) / 2)
    
    return CGSize(width: maxOffsetX, height: maxOffsetY)
}
