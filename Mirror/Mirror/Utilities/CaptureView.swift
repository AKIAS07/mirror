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
        
        if isLivePhoto {
            guard let imageURL = tempImageURL,
                  let videoURL = tempVideoURL else {
                print("[Live Photo保存] 错误：缺少必要文件")
                print("图片URL：\(String(describing: tempImageURL))")
                print("视频URL：\(String(describing: tempVideoURL))")
                return
            }
            
            // 检查原始文件是否存在
            let imageExists = fileManager.fileExists(atPath: imageURL.path)
            let videoExists = fileManager.fileExists(atPath: videoURL.path)
            
            print("[Live Photo保存] 原始文件检查：")
            print("图片文件存在：\(imageExists)")
            print("视频文件存在：\(videoExists)")
            
            guard imageExists && videoExists else {
                print("[Live Photo保存] 错误：原始文件不完整")
                return
            }
            
            // 创建持久化文件路径
            let documentsPath = persistentDirectory.path
            print("[Live Photo保存] 文档目录路径：\(documentsPath)")
            
            let persistentImageURL = persistentDirectory.appendingPathComponent("\(livePhotoIdentifier).heic")
            let persistentVideoURL = persistentDirectory.appendingPathComponent("\(livePhotoIdentifier).mov")
            
            print("[Live Photo保存] 持久化文件路径：")
            print("持久化图片路径：\(persistentImageURL.path)")
            print("持久化视频路径：\(persistentVideoURL.path)")
            
            do {
                // 如果文件已存在，先删除
                if fileManager.fileExists(atPath: persistentImageURL.path) {
                    try fileManager.removeItem(at: persistentImageURL)
                }
                if fileManager.fileExists(atPath: persistentVideoURL.path) {
                    try fileManager.removeItem(at: persistentVideoURL)
                }
                
                // 复制文件到持久化目录
                try fileManager.copyItem(at: imageURL, to: persistentImageURL)
                try fileManager.copyItem(at: videoURL, to: persistentVideoURL)
                
                print("[Live Photo保存] 文件复制完成")
                
                // 验证持久化文件
                let persistentImageExists = fileManager.fileExists(atPath: persistentImageURL.path)
                let persistentVideoExists = fileManager.fileExists(atPath: persistentVideoURL.path)
                
                print("[Live Photo保存] 持久化文件验证：")
                print("持久化图片存在：\(persistentImageExists)")
                print("持久化视频存在：\(persistentVideoExists)")
                
                guard persistentImageExists && persistentVideoExists else {
                    print("[Live Photo保存] 错误：持久化文件创建失败")
                    return
                }
                
                // 更新引用到持久化文件
                tempImageURL = persistentImageURL
                tempVideoURL = persistentVideoURL
                
                // 检查权限并保存
                let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
                print("[Live Photo保存] 相册权限状态：\(status.rawValue)")
                
                switch status {
                case .authorized, .limited:
                    PHPhotoLibrary.shared().performChanges({
                        let creationRequest = PHAssetCreationRequest.forAsset()
                        let options = PHAssetResourceCreationOptions()
                        options.shouldMoveFile = false
                        
                        print("[Live Photo保存] 添加资源到相册")
                        print("添加图片：\(persistentImageURL.path)")
                        creationRequest.addResource(with: .photo, fileURL: persistentImageURL, options: options)
                        
                        print("添加视频：\(persistentVideoURL.path)")
                        creationRequest.addResource(with: .pairedVideo, fileURL: persistentVideoURL, options: options)
                        
                    }) { [weak self] success, error in
                        DispatchQueue.main.async {
                            if success {
                                print("[Live Photo保存] 保存成功")
                                
                                // 最终验证持久化文件
                                let finalImageExists = self?.fileManager.fileExists(atPath: persistentImageURL.path) ?? false
                                let finalVideoExists = self?.fileManager.fileExists(atPath: persistentVideoURL.path) ?? false
                                print("[Live Photo保存] 最终文件验证：")
                                print("持久化图片存在：\(finalImageExists)")
                                print("持久化视频存在：\(finalVideoExists)")
                                
                                withAnimation {
                                    self?.showSaveSuccess = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation {
                                        self?.showSaveSuccess = false
                                    }
                                }
                            } else {
                                print("[Live Photo保存] 保存失败")
                                if let error = error as NSError? {
                                    print("错误域：\(error.domain)")
                                    print("错误码：\(error.code)")
                                    print("错误描述：\(error.localizedDescription)")
                                    print("用户信息：\(error.userInfo)")
                                }
                            }
                        }
                    }
                    
                case .notDetermined:
                    PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] newStatus in
                        if newStatus == .authorized || newStatus == .limited {
                            DispatchQueue.main.async {
                                self?.saveToPhotos()
                            }
                        }
                    }
                    
                case .denied, .restricted:
                    print("[Live Photo保存] 无权限访问相册")
                    PermissionManager.shared.alertState = .permission(isFirstRequest: false)
                    
                @unknown default:
                    print("[Live Photo保存] 未知权限状态")
                }
                
            } catch {
                print("[Live Photo保存] 文件复制错误：\(error.localizedDescription)")
            }
            
        } else {
            // 处理普通照片保存...
            if let image = capturedImage {
                let processedImage = cropImage(image, scale: currentScale)
                saveImageToPhotoLibrary(processedImage) { [weak self] success in
                    if success {
                        print("[相册保存] 普通照片保存成功")
                        withAnimation {
                            self?.showSaveSuccess = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                self?.showSaveSuccess = false
                            }
                        }
                    } else {
                        print("[相册保存] 普通照片保存失败")
                    }
                }
            }
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
    @ObservedObject private var captureManager = CaptureManager.shared
    let cameraManager: CameraManager
    let onDismiss: () -> Void
    
    // 添加长按手势状态
    @GestureState private var isLongPressed = false
    
    // 添加初始化方法
    init(captureState: CaptureState, 
         cameraManager: CameraManager,
         onDismiss: @escaping () -> Void) {
        self.captureState = captureState
        self.cameraManager = cameraManager
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        if captureManager.isPreviewVisible {
            GeometryReader { geometry in
                let screenBounds = UIScreen.main.bounds
                
                ZStack {
                    // 背景层
                    Color.black.opacity(0.0001)
                        .frame(width: screenBounds.width, height: screenBounds.height)
                        .position(x: screenBounds.width/2, y: screenBounds.height/2)
                        .allowsHitTesting(false)

                    // 主要内容层
                    ZStack {
                        // 图片层 - 在播放Live Photo时隐藏
                        if let image = captureManager.capturedImage {
                            if !(captureManager.isLivePhoto && captureManager.isPlayingLivePhoto) {
                                let isLandscape = captureManager.captureOrientation.isLandscape
                                let displayWidth = isLandscape ? screenBounds.height : screenBounds.width
                                let displayHeight = isLandscape ? screenBounds.width : screenBounds.height
                                
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: displayWidth+100, height: displayHeight)
                                    .scaleEffect(captureManager.currentScale)
                                    .rotationEffect(getRotationAngle(for: captureManager.captureOrientation))
                            }
                        }
                        
                        // Live Photo播放视图
                        if captureManager.isLivePhoto && captureManager.livePhotoVideoURL != nil && captureManager.isPlayingLivePhoto {
                            ZStack {
                                let isLandscape = captureManager.captureOrientation.isLandscape
                                let displayWidth = isLandscape ? screenBounds.height : screenBounds.width
                                let displayHeight = isLandscape ? screenBounds.width : screenBounds.height
                                
                                Color.clear
                                    //.frame(width: displayWidth, height: displayHeight)
                                
                                LivePhotoPlayerView(
                                    videoURL: captureManager.livePhotoVideoURL!,
                                    isPlaying: $captureManager.isPlayingLivePhoto,
                                    orientation: captureManager.captureOrientation
                                )
                                .frame(width: displayWidth+300, height: displayHeight)
                                .scaleEffect(captureManager.currentScale)
                                .rotationEffect(getRotationAngle(for: captureManager.captureOrientation))
                            }
                            .position(x: screenBounds.width/2, y: screenBounds.height/2)
                            .allowsHitTesting(false)
                        }
                        
                        // 触控层 - 处理缩放、点击和长按
                        Color.clear
                            .contentShape(Rectangle())
                            .frame(width: screenBounds.width, height: screenBounds.height)
                            .gesture(
                                SimultaneousGesture(
                                    SimultaneousGesture(
                                        MagnificationGesture()
                                            .onChanged { value in
                                                print("[缩放手势] 正在缩放 - 当前值: \(value)")
                                                let newScale = value * captureManager.currentScale
                                                print("[缩放手势] 计算新比例: \(newScale)")
                                                captureManager.currentScale = min(max(newScale, 0.6), 10.0)
                                                print("[缩放手势] 最终比例: \(captureManager.currentScale)")
                                            }
                                            .onEnded { value in
                                                print("[缩放手势] 缩放结束 - 最终值: \(value)")
                                                let generator = UIImpactFeedbackGenerator(style: .light)
                                                generator.impactOccurred()
                                            },
                                        DragGesture(minimumDistance: 0)
                                            .onChanged { _ in
                                                if captureManager.isLivePhoto && captureManager.livePhotoVideoURL != nil && !captureManager.isPlayingLivePhoto {
                                                    // 触发震动反馈
                                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                                    generator.impactOccurred()
                                                    
                                                    print("[拖动手势] 开始播放Live Photo")
                                                    withAnimation {
                                                        captureManager.isPlayingLivePhoto = true
                                                    }
                                                }
                                            }
                                            .onEnded { _ in
                                                if captureManager.isPlayingLivePhoto {
                                                    print("[拖动手势] 停止播放Live Photo")
                                                    withAnimation {
                                                        captureManager.isPlayingLivePhoto = false
                                                    }
                                                }
                                            }
                                    ),
                                    TapGesture(count: BorderLightStyleManager.shared.captureGestureCount)
                                        .onEnded {
                                            print("[触控层] 点击事件被触发")
                                            withAnimation {
                                                captureManager.hidePreview(cameraManager: cameraManager)
                                                onDismiss()
                                            }
                                        }
                                )
                            )
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
                        .frame(height: 120)
                    }
                    .frame(width: screenBounds.width, height: screenBounds.height)
                    
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
                            .padding(.top, 80)
                            Spacer()
                        }
                        Spacer()
                    }
                    .zIndex(100)
                }
                .ignoresSafeArea()
                .zIndex(9)
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

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        print("[LivePhotoPlayerView] makeUIViewController 被调用")
        print("[LivePhotoPlayerView] 视频URL: \(videoURL.absoluteString)")
        print("[LivePhotoPlayerView] 设备方向: \(orientation)")
        
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