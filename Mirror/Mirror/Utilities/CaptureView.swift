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
    @Published public var livePhotoImageData: Data?  // 添加存储Live Photo图像数据
    @Published public var livePhotoVideoURL: URL?    // 添加存储Live Photo视频URL
    @Published public var isPlayingLivePhoto: Bool = false  // 添加播放Live Photo状态
    
    private var isProcessingAlert = false
    
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
    
    // 修改保存方法，添加Live Photo保存逻辑
    public func saveToPhotos() {
        if isLivePhoto && livePhotoImageData != nil && livePhotoVideoURL != nil {
            saveLivePhotoToPhotoLibrary()
        } else if let image = capturedImage {
            let processedImage = cropImage(image, scale: currentScale)
            saveImageToPhotoLibrary(processedImage) { [weak self] success in
                if success {
                    withAnimation {
                        self?.showSaveSuccess = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            self?.showSaveSuccess = false
                        }
                    }
                }
            }
        }
    }
    
    // 添加Live Photo保存方法
    private func saveLivePhotoToPhotoLibrary() {
        guard let imageData = livePhotoImageData, let videoURL = livePhotoVideoURL else {
            print("[Live Photo保存] 缺少必要数据")
            return
        }
        
        // 检查权限状态
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        switch status {
        case .authorized, .limited:
            // 创建临时图片文件
            let tempImageURL = FileManager.default.temporaryDirectory.appendingPathComponent("LivePhoto_\(UUID().uuidString).jpg")
            
            do {
                // 写入照片数据
                try imageData.write(to: tempImageURL)
                
                // 保存到相册
                PHPhotoLibrary.shared().performChanges({
                    let creationRequest = PHAssetCreationRequest.forAsset()
                    let options = PHAssetResourceCreationOptions()
                    options.shouldMoveFile = true
                    
                    // 添加照片和视频资源
                    creationRequest.addResource(with: .photo, fileURL: tempImageURL, options: options)
                    creationRequest.addResource(with: .pairedVideo, fileURL: videoURL, options: options)
                    
                }) { [weak self] success, error in
                    // 清理临时文件
                    try? FileManager.default.removeItem(at: tempImageURL)
                    
                    DispatchQueue.main.async {
                        if success {
                            print("[Live Photo保存] 保存成功")
                            withAnimation {
                                self?.showSaveSuccess = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation {
                                    self?.showSaveSuccess = false
                                }
                            }
                        } else {
                            print("[Live Photo保存] 保存失败：\(error?.localizedDescription ?? "未知错误")")
                        }
                    }
                }
            } catch {
                print("[Live Photo保存] 写入临时文件失败：\(error.localizedDescription)")
            }
            
        case .notDetermined:
            // 未确定状态，请求权限
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] newStatus in
                if newStatus == .authorized || newStatus == .limited {
                    DispatchQueue.main.async {
                        self?.saveLivePhotoToPhotoLibrary()
                    }
                }
            }
            
        case .denied, .restricted:
            // 已拒绝，显示去设置的弹窗
            PermissionManager.shared.alertState = .permission(isFirstRequest: false)
            
        @unknown default:
            print("[Live Photo保存] 未知错误")
        }
    }
    
    // 添加私有保存方法
    private func saveImageToPhotoLibrary(_ image: UIImage, completion: @escaping (Bool) -> Void) {
        // 检查权限状态
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        switch status {
        case .authorized, .limited:
            // 已有权限，直接保存
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        print("[相册保存] 保存成功")
                        completion(true)
                    } else {
                        print("[相册保存] 保存失败：\(error?.localizedDescription ?? "未知错误")")
                        completion(false)
                    }
                }
            }
            
        case .notDetermined:
            // 未确定状态，请求权限
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] newStatus in
                if newStatus == .authorized || newStatus == .limited {
                    DispatchQueue.main.async {
                        self?.saveImageToPhotoLibrary(image, completion: completion)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(false)
                    }
                }
            }
            
        case .denied, .restricted:
            // 已拒绝，显示去设置的弹窗
            PermissionManager.shared.alertState = .permission(isFirstRequest: false)
            completion(false)
            
        @unknown default:
            completion(false)
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

// 截图操作视图
public struct CaptureActionsView: View {
    @ObservedObject var captureState: CaptureState
    @ObservedObject private var orientationManager = DeviceOrientationManager.shared
    @ObservedObject private var styleManager = BorderLightStyleManager.shared
    let onDismiss: () -> Void
    
    // 添加长按手势状态
    @GestureState private var isLongPressed = false
    
    public var body: some View {
        if captureState.showButtons {
            GeometryReader { geometry in
                let screenBounds = UIScreen.main.bounds
                
                ZStack {
                    // 修改全屏背景层的实现
                    if captureState.showButtons {
                        Color.black.opacity(0.0001)
                            .frame(width: screenBounds.width, height: screenBounds.height)
                            .position(x: screenBounds.width/2, y: screenBounds.height/2)
                            .contentShape(Rectangle())
                            .allowsHitTesting(true)
                            .onTapGesture {
                                withAnimation {
                                    captureState.reset {
                                        onDismiss()
                                    }
                                }
                            }
                    }

                    // 图片层 - 在播放Live Photo时隐藏
                    if let image = captureState.capturedImage {
                        if !(captureState.isLivePhoto && captureState.isPlayingLivePhoto) {
                            ZStack {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: screenBounds.width, height: screenBounds.height)
                                    .scaleEffect(captureState.currentScale)
                                    .position(x: screenBounds.width/2, y: screenBounds.height/2)
                                    .allowsHitTesting(false)
                            }
                        }
                    }
                    
                    // 添加Live Photo播放视图 - 单独的层
                    if captureState.isLivePhoto && captureState.livePhotoVideoURL != nil && captureState.isPlayingLivePhoto {
                        ZStack {
                            // 添加黑色背景确保视频可见
                            Color.black
                                .frame(width: screenBounds.width, height: screenBounds.height)
                                .position(x: screenBounds.width/2, y: screenBounds.height/2)
                            
                            LivePhotoPlayerView(
                                videoURL: captureState.livePhotoVideoURL!,
                                isPlaying: $captureState.isPlayingLivePhoto  // 传递绑定
                            )
                            .frame(width: screenBounds.width, height: screenBounds.height)
                            .scaleEffect(captureState.currentScale)
                            .position(x: screenBounds.width/2, y: screenBounds.height/2)
                            .allowsHitTesting(false)
                            .onAppear {
                                print("[Live Photo播放] 视图显示")
                            }
                        }
                        .zIndex(20) // 确保视频在最上层
                    }
                    
                    // 半透明背景层（用于点击隐藏按钮和长按播放Live Photo）
                    Color.black.opacity(0.01)
                        .frame(width: screenBounds.width, height: screenBounds.height)
                        .position(x: screenBounds.width/2, y: screenBounds.height/2)
                        .contentShape(Rectangle()) // 确保整个区域可点击
                        .onTapGesture(count: BorderLightStyleManager.shared.captureGestureCount) {
                            // 触发震动反馈
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.prepare()
                            generator.impactOccurred()
                            
                            withAnimation {
                                captureState.reset {
                                    onDismiss()
                                }
                            }
                        }
                        // 使用DragGesture替代LongPressGesture，可能更可靠
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in
                                    // 手势开始/变化时
                                    print("[拖动手势] 检测到")
                                    if captureState.isLivePhoto && captureState.livePhotoVideoURL != nil && !captureState.isPlayingLivePhoto {
                                        // 触发震动反馈
                                        let generator = UIImpactFeedbackGenerator(style: .medium)
                                        generator.impactOccurred()
                                        
                                        print("[拖动手势] 开始播放Live Photo")
                                        withAnimation {
                                            captureState.isPlayingLivePhoto = true
                                        }
                                    } else {
                                        print("[拖动手势] 不满足播放条件或已在播放")
                                        print("isLivePhoto: \(captureState.isLivePhoto)")
                                        print("livePhotoVideoURL: \(String(describing: captureState.livePhotoVideoURL))")
                                        print("isPlayingLivePhoto: \(captureState.isPlayingLivePhoto)")
                                    }
                                }
                                .onEnded { _ in
                                    // 手势结束时
                                    print("[拖动手势] 结束")
                                    if captureState.isPlayingLivePhoto {
                                        print("[拖动手势] 停止播放Live Photo")
                                        withAnimation {
                                            captureState.isPlayingLivePhoto = false
                                        }
                                    }
                                }
                        )
                    
                    // Live Photo提示标识
                    if captureState.isLivePhoto && !captureState.isPlayingLivePhoto {
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
                            .rotationEffect(.degrees(getRotationAngle()))
                        }
                        .position(x: screenBounds.width/2, y: screenBounds.height - 160)
                        .zIndex(10)
                        .onAppear {
                            print("[Live Photo提示] 显示")
                        }
                    }
                    
                    // 底部操作按钮
                    if captureState.showButtons {
                        VStack(spacing: 0) {
                            Spacer()
                            
                            // 底部操作按钮
                            ZStack {
                                HStack(spacing: CaptureButtonStyle.buttonSpacing) {
                                    Spacer()
                                    
                                    // 使用新的下载按钮
                                    CaptureActionButton.downloadButton(
                                        captureState: captureState,
                                        color: styleManager.iconColor,
                                        rotationAngle: getRotationAngle()
                                    )
                                    
                                    // 分享按钮
                                    CaptureActionButton(
                                        systemName: "arrowshape.turn.up.right.fill",
                                        action: captureState.shareImage,
                                        color: styleManager.iconColor
                                    )
                                    .rotationEffect(.degrees(getRotationAngle()))
                                    .animation(.easeInOut(duration: 0.3), value: getRotationAngle())
                                    
                                    Spacer()
                                }
                            }
                            .frame(height: 120)
                        }
                        .frame(width: screenBounds.width, height: screenBounds.height)
                    }
                    
                    // 添加保存成功提示
                    if captureState.showSaveSuccess {
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
                            .rotationEffect(.degrees(getRotationAngle()))
                            .position(x: screenBounds.width/2, y: screenBounds.height/2)
                    }
                    
                    // 将关闭按钮移到最上层
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: {
                                print("关闭按钮被点击")
                                // 触发震动反馈
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.prepare()
                                generator.impactOccurred()
                                
                                withAnimation {
                                    captureState.reset {
                                        onDismiss()
                                    }
                                }
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(width: 36, height: 36)
                                    .background(Color.black.opacity(0.35))
                                    .clipShape(Circle())
                            }
                            .padding(.top, 80)  // 增加顶部间距
                            Spacer()
                        }
                        Spacer()
                    }
                    .zIndex(100)  // 确保按钮在最上层
                }
            }
            .ignoresSafeArea()
            .zIndex(9)
            .onAppear {
                print("------------------------")
                print("[CaptureActionsView] 视图加载")
                print("CaptureState.isLivePhoto：\(captureState.isLivePhoto)")
                print("CaptureState.capturedImage：\(String(describing: captureState.capturedImage != nil))")
                print("CaptureState.capturedLivePhotoURL：\(String(describing: captureState.capturedLivePhotoURL))")
                print("CaptureState.livePhotoVideoURL：\(String(describing: captureState.livePhotoVideoURL))")
                print("CaptureState.showButtons：\(captureState.showButtons)")
                print("------------------------")
            }
        }
    }
    
    // 添加辅助方法
    private func getRotationAngle() -> Double {
        switch orientationManager.currentOrientation {
        case .landscapeLeft: return 90
        case .landscapeRight: return -90
        case .portraitUpsideDown: return 180
        default: return 0
        }
    }   
}

// 修改LivePhotoPlayerView实现，使用VideoPlayer
struct LivePhotoPlayerView: UIViewControllerRepresentable {
    let videoURL: URL
    @Binding var isPlaying: Bool  // 添加绑定属性
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        print("[LivePhotoPlayerView] makeUIViewController 被调用")
        print("[LivePhotoPlayerView] 视频URL: \(videoURL.absoluteString)")
        
        // 检查文件是否存在
        if FileManager.default.fileExists(atPath: videoURL.path) {
            print("[LivePhotoPlayerView] 视频文件存在")
        } else {
            print("[LivePhotoPlayerView] 错误：视频文件不存在")
        }
        
        let player = AVPlayer(url: videoURL)
        let playerViewController = AVPlayerViewController()
        playerViewController.player = player
        playerViewController.showsPlaybackControls = false
        playerViewController.videoGravity = .resizeAspectFill
        
        // 添加播放结束通知
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            print("[LivePhotoPlayerView] 视频播放完毕，重置到第一帧")
            player.seek(to: .zero)
            player.pause()
            
            // 通知外部停止播放
            DispatchQueue.main.async {
                self.isPlaying = false
            }
        }
        
        // 自动播放
        print("[LivePhotoPlayerView] 开始播放视频")
        player.play()
        
        return playerViewController
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        print("[LivePhotoPlayerView] updateUIViewController 被调用")
        
        if let player = uiViewController.player {
            print("[LivePhotoPlayerView] 播放状态: \(player.timeControlStatus.rawValue)")
            
            if player.timeControlStatus != .playing && isPlaying {
                print("[LivePhotoPlayerView] 重新开始播放")
                player.seek(to: .zero)
                player.play()
            }
        }
    }
    
    static func dismantleUIViewController(_ uiViewController: AVPlayerViewController, coordinator: ()) {
        print("[LivePhotoPlayerView] dismantleUIViewController 被调用")
        NotificationCenter.default.removeObserver(uiViewController)
        uiViewController.player?.pause()
        uiViewController.player = nil
    }
}   