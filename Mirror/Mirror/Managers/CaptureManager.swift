import SwiftUI
import UIKit
import Photos
import AVFoundation
import VideoToolbox  // 添加VideoToolbox导入
import MobileCoreServices

class CaptureManager: ObservableObject {
    static let shared = CaptureManager()
    
    @Published var isPreviewVisible = false
    @Published var capturedImage: UIImage?
    @Published var originalLiveImage: UIImage? // 添加属性保存原始Live图片
    @Published var originalVideoURL: URL? // 添加属性保存原始视频URL
    @Published var simulatedVideoURL: URL? // 添加属性保存模拟视频URL
    @Published var processedVideoURL: URL? // 添加属性保存处理后的视频URL
    @Published var isLivePhoto = false
    @Published var livePhotoVideoURL: URL?
    @Published var tempImageURL: URL?
    @Published var tempVideoURL: URL?
    @Published var livePhotoIdentifier = ""
    @Published var currentScale: CGFloat = 1.0  // 保存当前的缩放比例，会随视图缩放变化
    @Published var constScale: CGFloat = 1.0    // 保存初始缩放比例，用于mix处理
    @Published var isCapturing = false
    @Published var showSaveSuccess = false
    @Published var isPlayingLivePhoto = false
    @Published var captureOrientation: UIDeviceOrientation = .portrait
    @Published var showScaleIndicator = false
    @Published var currentIndicatorScale: CGFloat = 1.0
    @Published var dragOffset: CGSize = .zero  // 拖动偏移量
    @Published var lastDragOffset: CGSize = .zero  // 上次拖动的偏移量
    @Published var isCheckmarkEnabled: Bool = false  // 添加勾选状态
    @Published var isPinnedDrawingActive: Bool = false  // 添加固定绘画视图状态
    @Published var pinnedDrawingImage: UIImage? = nil  // 添加固定绘画图片
    @Published var isMakeupViewActive: Bool = false  // 添加化妆视图状态
    @Published var previewMixImage: UIImage? = nil  // 添加预览混合图片缓存
    @Published var makeupImage: UIImage? = nil  // 添加化妆图片状态
    @Published var simulatedLivePhotoMode: Bool = false // 用于测试mix-live功能
    @Published var isSimulatedMode: Bool = false  // 添加模拟模式状态
    @Published var simulationProgress: Double = 0.0 // 添加模拟进度状态
    @Published var isSaving: Bool = false // 添加保存状态
    @Published var savingProgress: Double = 0.0 // 添加保存进度
    @Published var isVideoProcessing: Bool = false  // 添加新状态：视频是否正在处理
    @Published var isResourcePreparing: Bool = false  // 添加新状态：资源是否正在准备中
    @Published var isVideoLoading: Bool = false  // 添加新状态：视频是否正在加载中
    
    // 添加用于视图显示的资源路径
    @Published var viewImageURL: URL?
    @Published var viewMovURL: URL?
    
    // 添加水印相关属性
    private var watermarkImageA: UIImage? = UIImage(named: "mixlogoA")
    private var watermarkImageB: UIImage? = UIImage(named: "mixlogoB")
    
    // 添加缓存属性
    private var cachedSimulatedImageURL: URL?
    private var cachedSimulatedVideoURL: URL?
    private var isGeneratingSimulation = false
    private var cachedMixImageURL: URL?  // 缓存第一次生成的mix图片URL
    private var cachedMixVideoURL: URL?  // 缓存第一次生成的mix视频URL（用于Live Photo）
    private var hasCachedMixResources: Bool = false  // 标记是否有缓存的mix资源
    
    // 添加水印开关状态监听
    private var watermarkObserver: NSObjectProtocol?
    
    // 添加计算属性来判断是否应该显示勾选按钮
    var shouldShowCheckmark: Bool {
        return (isPinnedDrawingActive || isMakeupViewActive)
    }
    
    private let restartManager = ContentRestartManager.shared
    private let orientationManager = DeviceOrientationManager.shared
    private let fileManager = FileManager.default
    
    private var persistentDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private init() {
        // 添加水印设置变化的监听
        watermarkObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("WatermarkSettingChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // 清除预览缓存，强制重新生成预览图片
            self?.clearPreviewCache()
            // 如果当前有图片，重新生成预览
            if let baseImage = self?.capturedImage {
                self?.previewMixImage = self?.getPreviewImage(baseImage: baseImage)
            }
        }
    }
    
    deinit {
        // 移除通知监听
        if let observer = watermarkObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // 旋转横屏图片
    private func rotateImageIfNeeded(_ image: UIImage) -> UIImage {
        print("------------------------")
        print("[图片旋转] 开始")
        print("原始尺寸：\(image.size.width) x \(image.size.height)")
        print("设备方向：\(orientationManager.getOrientationDescription(captureOrientation))")
        print("原始图片方向：\(image.imageOrientation.rawValue)")
        
        // 如果图片已经是正确的方向，直接返回
        if image.imageOrientation == .up && captureOrientation == .portrait {
            print("[图片旋转] 图片已经是正确方向，无需旋转")
            return image
        }
        
        // 根据方向旋转图片
        let angle: CGFloat
        let shouldSwapDimensions: Bool
        
        switch captureOrientation {
        case .portrait:
            print("[图片旋转] 竖屏，无需旋转")
            return image
            
        case .landscapeLeft:
            angle = .pi / 2
            shouldSwapDimensions = true
            print("[图片旋转] 向左横屏，旋转90度")
            
        case .landscapeRight:
            angle = -.pi / 2
            shouldSwapDimensions = true
            print("[图片旋转] 向右横屏，旋转-90度")
            
        case .portraitUpsideDown:
            angle = .pi
            shouldSwapDimensions = false
            print("[图片旋转] 倒置竖屏，旋转180度")
            
        default:
            print("[图片旋转] 未知方向，不旋转")
            return image
        }
        
        return autoreleasepool { () -> UIImage in
            // 创建绘图上下文
            let size: CGSize
            if shouldSwapDimensions {
                size = CGSize(width: image.size.height, height: image.size.width)
                print("[图片旋转] 交换宽高：\(size.width) x \(size.height)")
            } else {
                size = image.size
                print("[图片旋转] 保持原始尺寸：\(size.width) x \(size.height)")
            }
            
            UIGraphicsBeginImageContextWithOptions(size, false, image.scale)
            let context = UIGraphicsGetCurrentContext()!
            
            // 移动原点到中心并旋转
            context.translateBy(x: size.width / 2, y: size.height / 2)
            context.rotate(by: angle)
            
            // 绘制图片
            let rect = CGRect(
                x: -image.size.width / 2,
                y: -image.size.height / 2,
                width: image.size.width,
                height: image.size.height
            )
            
            image.draw(in: rect)
            
            // 获取旋转后的图片
            let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            if let finalImage = rotatedImage {
                print("[图片旋转] 完成")
                print("最终尺寸：\(finalImage.size.width) x \(finalImage.size.height)")
                print("最终图片方向：\(finalImage.imageOrientation.rawValue)")
                print("------------------------")
                return finalImage
            } else {
                print("[图片旋转] 失败，返回原始图片")
                print("------------------------")
                return image
            }
        }
    }
    
    // 添加图片旋转函数
    private func rotateImageForSaving(_ image: UIImage, orientation: UIDeviceOrientation) -> UIImage {
        print("[图片旋转] 开始处理保存时的图片旋转")
        print("原始尺寸：\(image.size.width) x \(image.size.height)")
        print("设备方向：\(orientation.rawValue)")
        print("原始图片方向：\(image.imageOrientation.rawValue)")
        
        let rotationAngle: CGFloat
        let shouldRotate: Bool
        var newSize = image.size
        
        switch orientation {
        case .landscapeLeft:
            rotationAngle = -.pi/2
            shouldRotate = true
            newSize = CGSize(width: image.size.height, height: image.size.width)
            print("[图片旋转] 向左横屏，旋转-90度")
        case .landscapeRight:
            rotationAngle = .pi/2
            shouldRotate = true
            newSize = CGSize(width: image.size.height, height: image.size.width)
            print("[图片旋转] 向右横屏，旋转90度")
        case .portraitUpsideDown:
            rotationAngle = .pi
            shouldRotate = true
            print("[图片旋转] 倒置竖屏，旋转180度")
        default:
            print("[图片旋转] 正常竖屏，无需旋转")
            return image
        }
        
        if !shouldRotate {
            return image
        }
        
        return autoreleasepool { () -> UIImage in
            UIGraphicsBeginImageContextWithOptions(newSize, true, image.scale)
            let context = UIGraphicsGetCurrentContext()!
            
            // 先填充白色背景
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: newSize))
            
            // 根据方向调整绘制方式
            switch orientation {
            case .landscapeLeft, .landscapeRight:
                // 移动到新画布中心
                context.translateBy(x: newSize.width/2, y: newSize.height/2)
                // 旋转
                context.rotate(by: rotationAngle)
                // 绘制图片
                image.draw(in: CGRect(x: -image.size.width/2,
                                    y: -image.size.height/2,
                                    width: image.size.width,
                                    height: image.size.height))
            case .portraitUpsideDown:
                // 移动到新画布中心
                context.translateBy(x: newSize.width/2, y: newSize.height/2)
                // 旋转180度
                context.rotate(by: rotationAngle)
                // 绘制图片
                image.draw(in: CGRect(x: -image.size.width/2,
                                    y: -image.size.height/2,
                                    width: image.size.width,
                                    height: image.size.height))
            default:
                break
            }
            
            let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            print("[图片旋转] 旋转完成")
            print("旋转后尺寸：\(rotatedImage?.size.width ?? 0) x \(rotatedImage?.size.height ?? 0)")
            print("旋转后图片方向：\(rotatedImage?.imageOrientation.rawValue ?? 0)")
            
            return rotatedImage ?? image
        }
    }
    
    // 显示预览
    func showPreview(image: UIImage, scale: CGFloat = 1.0, orientation: UIDeviceOrientation = .portrait, cameraManager: CameraManager) {
        print("------------------------")
        print("[预览显示] 开始")
        print("传入方向：\(orientationManager.getOrientationDescription(orientation))")
        print("当前设备方向：\(orientationManager.getOrientationDescription(orientationManager.currentOrientation))")
        
        // 使用当前实际的设备方向，而不是传入的方向
        let actualOrientation = orientationManager.validOrientation
        
        // 先设置捕获方向，这样后续的旋转处理才能正确进行
        self.captureOrientation = actualOrientation
        
        print("[预览显示] 设置捕获方向：\(orientationManager.getOrientationDescription(actualOrientation))")
        
        // 处理图片旋转（包括横屏和倒置竖屏）
        let processedImage = (actualOrientation.isLandscape || actualOrientation == .portraitUpsideDown) ? 
            rotateImageIfNeeded(image) : image
        
        print("[预览显示] 图片处理")
        print("原始尺寸：\(image.size.width) x \(image.size.height)")
        print("处理后尺寸：\(processedImage.size.width) x \(processedImage.size.height)")
        
        // 清除之前的预览图片缓存
        previewMixImage = nil
        
        self.capturedImage = processedImage
        self.currentScale = scale
        self.constScale = scale  // 保存初始缩放比例
        self.currentIndicatorScale = scale
        self.isLivePhoto = false
        
        print("[预览显示] 最终方向：\(orientationManager.getOrientationDescription(actualOrientation))")
        
        // 锁定设备方向，防止旋转
        orientationManager.lockOrientation()
        
        // 先显示预览和缩放指示器
        withAnimation {
            self.isPreviewVisible = true
            self.showScaleIndicator = true
        }
        
        // 延迟隐藏缩放指示器
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                self.showScaleIndicator = false
            }
        }

        // 延迟0.5秒后关闭摄像头
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            cameraManager.safelyStopSession()
            self.restartManager.isCameraActive = false
        }
        
        print("[预览显示] 完成")
        print("------------------------")
    }
    
    // 显示 Live Photo 预览
    func showLivePhotoPreview(image: UIImage, videoURL: URL, imageURL: URL, identifier: String, orientation: UIDeviceOrientation = .portrait, cameraManager: CameraManager, scale: CGFloat = 1.0, isMirrored: Bool, isFront: Bool, isBack: Bool) {
        print("------------------------")
        print("[Live Photo预览] 开始初始化")
        print("设备方向：\(orientation.rawValue)")
        print("缩放比例：\(scale)")
        
        // 设置加载状态为true
        self.isVideoLoading = true
        
        // 保存原始视频URL
        self.originalVideoURL = videoURL
        self.livePhotoVideoURL = videoURL  // 设置 livePhotoVideoURL 为原始视频URL
        
        // 使用当前实际的设备方向，而不是传入的方向
        let actualOrientation = orientationManager.validOrientation
        self.captureOrientation = actualOrientation
        
        print("[Live Photo预览] 使用实际设备方向：\(orientationManager.getOrientationDescription(actualOrientation))")
        
        // 处理图片旋转（包括横屏和倒置竖屏）
        let processedImage = (actualOrientation.isLandscape || actualOrientation == .portraitUpsideDown) ? 
            rotateImageIfNeeded(image) : image
        
        // 保存原始处理后的图片
        self.originalLiveImage = processedImage
        
        // 添加模拟mix-live的逻辑
        if isCheckmarkEnabled && (isPinnedDrawingActive || isMakeupViewActive) {
            simulatedLivePhotoMode = true
            
            // 复制原始资源
            let (copiedImageURL, copiedVideoURL) = copyLivePhotoResources(
                imageURL: imageURL,
                videoURL: videoURL
            )
            
            guard let newImageURL = copiedImageURL,
                  let newVideoURL = copiedVideoURL else {
                print("[Live Photo预览] 资源复制失败")
                simulatedLivePhotoMode = false
                self.capturedImage = processedImage
                self.viewMovURL = videoURL
                return
            }
            
            // 缓存复制的资源
            self.cachedSimulatedImageURL = newImageURL
            self.cachedSimulatedVideoURL = newVideoURL
            
            // 更新UI
            self.capturedImage = processedImage
            self.viewMovURL = newVideoURL
            self.simulatedVideoURL = newVideoURL
            self.currentScale = scale
            self.constScale = scale  // 保存初始缩放比例
            self.currentIndicatorScale = scale
            
            print("[Live Photo预览] 使用复制的资源")
            print("- 使用原始图片")
            print("- 使用复制的视频：\(newVideoURL.path)")
        } else {
            simulatedLivePhotoMode = false
            // 使用 LiveProcessor 处理图片，根据水印开关状态添加水印
            let processedWithWatermark = LiveProcessor.shared.processLivePhotoImage(
                baseImage: processedImage,
                drawingImage: nil,
                makeupImage: nil,
                scale: scale,
                orientation: actualOrientation
            )
            self.capturedImage = processedWithWatermark
            self.viewMovURL = videoURL
            
            // 处理视频，根据水印开关状态添加变换后的水印
            Task {
                if let processedVideo = await LiveProcessor.shared.processLivePhotoVideo(
                    videoURL: videoURL,
                    drawingImage: nil,
                    makeupImage: nil,
                    scale: scale,
                    orientation: actualOrientation,
                    isMirrored: isMirrored,
                    isFront: isFront,
                    isBack: isBack,
                    progressHandler: { [weak self] progress in
                        self?.simulationProgress = progress
                    }
                ) {
                    await MainActor.run {
                        self.processedVideoURL = processedVideo
                        self.viewMovURL = processedVideo  // 更新播放源
                        self.livePhotoVideoURL = processedVideo  // 同时更新 livePhotoVideoURL
                        // 处理完成后，设置加载状态为false
                        self.isVideoLoading = false
                        print("[Live Photo预览] 视频处理完成，更新播放源：\(processedVideo.path)")
                    }
                } else {
                    await MainActor.run {
                        // 处理失败时也需要设置加载状态为false
                        self.isVideoLoading = false
                    }
                }
            }
        }
        
        // 首先将文件复制到持久化目录
        let persistentImageURL = persistentDirectory.appendingPathComponent("\(identifier).heic")
        let persistentVideoURL = persistentDirectory.appendingPathComponent("\(identifier).mov")
        
        print("[Live Photo预览] 开始持久化文件")
        print("原始图片路径：\(imageURL.path)")
        print("原始视频路径：\(videoURL.path)")
        print("持久化图片路径：\(persistentImageURL.path)")
        print("持久化视频路径：\(persistentVideoURL.path)")
        
        do {
            // 如果文件已存在，先删除
            if fileManager.fileExists(atPath: persistentImageURL.path) {
                try fileManager.removeItem(at: persistentImageURL)
                print("[Live Photo预览] 删除已存在的图片文件")
            }
            if fileManager.fileExists(atPath: persistentVideoURL.path) {
                try fileManager.removeItem(at: persistentVideoURL)
                print("[Live Photo预览] 删除已存在的视频文件")
            }
            
            // 复制文件
            try fileManager.copyItem(at: imageURL, to: persistentImageURL)
            try fileManager.copyItem(at: videoURL, to: persistentVideoURL)
            
            print("[Live Photo预览] 文件持久化成功")
            print("[Live Photo预览] 验证文件：")
            print("- 图片文件存在：\(fileManager.fileExists(atPath: persistentImageURL.path))")
            print("- 视频文件存在：\(fileManager.fileExists(atPath: persistentVideoURL.path))")
            
            self.tempImageURL = persistentImageURL
            self.tempVideoURL = persistentVideoURL
            self.livePhotoIdentifier = identifier
            self.isLivePhoto = true
            self.currentScale = scale
            self.currentIndicatorScale = scale
            
            print("[Live Photo预览] 状态更新：")
            print("- isLivePhoto：\(self.isLivePhoto)")
            print("- viewMovURL：\(String(describing: self.viewMovURL))")
            print("- isPlayingLivePhoto：\(self.isPlayingLivePhoto)")
            
            // 添加方向更新监听
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleOrientationChangeForLivePhoto),
                name: NSNotification.Name("DeviceOrientationDidChange"),
                object: nil
            )
            
            // 锁定设备方向，防止旋转
            orientationManager.lockOrientation()
            
            // 显示预览和缩放指示器
            withAnimation {
                self.isPreviewVisible = true
                self.showScaleIndicator = true
            }
            
            // 延迟隐藏缩放指示器
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    self.showScaleIndicator = false
                }
            }
            
            // 延迟关闭摄像头
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                cameraManager.safelyStopSession()
                self.restartManager.isCameraActive = false
            }
            
        } catch {
            print("[Live Photo预览] 文件持久化失败：\(error.localizedDescription)")
            print("错误详情：\(error)")
        }
        print("------------------------")
    }
    
    // 添加处理 Live Photo 方向变化的方法
    @objc private func handleOrientationChangeForLivePhoto(_ notification: Notification) {
        guard let newOrientation = notification.userInfo?["orientation"] as? UIDeviceOrientation,
              let originalImage = self.originalLiveImage else {
            return
        }
        
        print("[Live Photo方向更新] 开始")
        print("新方向：\(orientationManager.getOrientationDescription(newOrientation))")
        
        // 更新捕获方向
        self.captureOrientation = newOrientation
        
        // 重新处理图片旋转
        let processedImage = (newOrientation.isLandscape || newOrientation == .portraitUpsideDown) ? 
            rotateImageIfNeeded(originalImage) : originalImage
        
        // 更新显示的图片
        DispatchQueue.main.async {
            self.capturedImage = processedImage
        }
        
        print("[Live Photo方向更新] 完成")
    }
    
    // 隐藏预览
    func hidePreview(cameraManager: CameraManager) {
        // 移除方向更新监听
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("DeviceOrientationDidChange"), object: nil)
        
        withAnimation {
            self.isPreviewVisible = false
            self.isPlayingLivePhoto = false
            self.showScaleIndicator = false
            self.isVideoLoading = false  // 重置视频加载状态
            // 重置拖动状态
            self.dragOffset = .zero
            self.lastDragOffset = .zero
            self.isCheckmarkEnabled = false  // 重置勾选状态
            self.previewMixImage = nil  // 清除预览图片缓存
        }
        
        // 解锁设备方向
        orientationManager.unlockOrientation()
        
        // 清理临时文件
        if let imageURL = tempImageURL {
            try? FileManager.default.removeItem(at: imageURL)
        }
        if let videoURL = tempVideoURL {
            try? FileManager.default.removeItem(at: videoURL)
        }
        
        // 清理持久化目录中的其他临时文件
        let fileManager = FileManager.default
        let persistentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        do {
            let files = try fileManager.contentsOfDirectory(at: persistentDirectory, includingPropertiesForKeys: nil)
            for file in files {
                if file.pathExtension == "heic" || file.pathExtension == "mov" {
                    try? fileManager.removeItem(at: file)
                }
            }
        } catch {
            print("[清理缓存] 清理临时文件失败：\(error.localizedDescription)")
        }
        
        // 清理缓存的模拟资源
        if let imageURL = cachedSimulatedImageURL {
            try? FileManager.default.removeItem(at: imageURL)
        }
        if let videoURL = cachedSimulatedVideoURL {
            try? FileManager.default.removeItem(at: videoURL)
        }
        cachedSimulatedImageURL = nil
        cachedSimulatedVideoURL = nil
        isGeneratingSimulation = false
        
        // 清理mix资源缓存
        if let imageURL = cachedMixImageURL {
            try? FileManager.default.removeItem(at: imageURL)
        }
        if let videoURL = cachedMixVideoURL {
            try? FileManager.default.removeItem(at: videoURL)
        }
        cachedMixImageURL = nil
        cachedMixVideoURL = nil
        hasCachedMixResources = false
        
        // 重置状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.capturedImage = nil
            self.originalLiveImage = nil  // 清除原始 Live Photo 图片
            self.viewMovURL = nil
            self.viewImageURL = nil
            self.tempImageURL = nil
            self.tempVideoURL = nil
            self.livePhotoIdentifier = ""
            self.currentScale = 1.0
            self.isCapturing = false
            
            // 清理处理后的视频
            if let processedVideo = self.processedVideoURL {
                try? FileManager.default.removeItem(at: processedVideo)
            }
            self.processedVideoURL = nil
            
            print("[清理缓存] 已清理所有临时文件和状态")
        }
    }
    
    // 修改保存方法
    public func saveToPhotos(isMirrored: Bool = false, isFront: Bool = true, isBack: Bool = false, completion: ((Bool) -> Void)? = nil) {
        if isLivePhoto {
            if simulatedLivePhotoMode {
                print("[模拟Live] 保存mix-live图片")
                // 这里先使用模拟数据,后续实现实际处理
                saveLivePhotoToPhotoLibrary(isMirrored: isMirrored, isFront: isFront, isBack: isBack) { success in
                    completion?(success)
                }
            } else {
                // 开始保存流程
                isSaving = true
                savingProgress = 0.0
                
                // 检查资源是否准备好
                Task {
                    await checkAndSaveLivePhoto(isMirrored: isMirrored, isFront: isFront, isBack: isBack) { success in
                        DispatchQueue.main.async {
                            self.isSaving = false
                            self.savingProgress = 0.0
                            completion?(success)
                        }
                    }
                }
            }
        } else {
            // 使用预览图片（如果有）或重新生成
            var imageToSave: UIImage
            if isCheckmarkEnabled {
                if let previewMix = previewMixImage {
                    imageToSave = previewMix
                } else {
                    // 如果没有预览图片，则重新生成
                    imageToSave = ImageProcessor.shared.createMixImage(
                        baseImage: capturedImage!,
                        drawingImage: pinnedDrawingImage,
                        makeupImage: isMakeupViewActive ? makeupImage : nil,
                        scale: currentScale,
                        orientation: captureOrientation
                    )
                }
            } else {
                imageToSave = ImageProcessor.shared.addWatermark(to: capturedImage!, orientation: captureOrientation)
            }
            
            // 根据设备方向旋转图片
            print("[保存图片] 当前设备方向：\(captureOrientation.rawValue)")
            imageToSave = rotateImageForSaving(imageToSave, orientation: captureOrientation)
            
            saveImageToPhotoLibrary(imageToSave) { success in
                completion?(success)
            }
        }
    }
    
    // 添加资源检查和保存方法
    private func checkAndSaveLivePhoto(isMirrored: Bool, isFront: Bool, isBack: Bool, completion: @escaping (Bool) -> Void) async {
        print("------------------------")
        print("[Live Photo保存] 开始检查资源")
        
        // 最大等待时间（秒）
        let maxWaitTime: Double = 10.0
        // 检查间隔（秒）
        let checkInterval: Double = 0.1
        // 已等待时间
        var waitedTime: Double = 0.0
        
        // 循环检查资源是否准备好
        while waitedTime < maxWaitTime {
            // 更新进度
            let progress = min(0.9, waitedTime / maxWaitTime)
            await MainActor.run {
                self.savingProgress = progress
            }
            
            // 检查视频资源是否已处理完成
            if let processedVideoURL = self.processedVideoURL,
               FileManager.default.fileExists(atPath: processedVideoURL.path) {
                print("[Live Photo保存] 检测到处理完成的视频资源")
                print("视频路径：\(processedVideoURL.path)")
                
                // 设置进度为95%
                await MainActor.run {
                    self.savingProgress = 0.95
                }
                
                // 执行保存操作
                self.saveLivePhotoToPhotoLibrary(isMirrored: isMirrored, isFront: isFront, isBack: isBack) { success in
                    DispatchQueue.main.async {
                        // 完成后设置进度为100%
                        self.savingProgress = 1.0
                        completion(success)
                    }
                }
                return
            }
            
            // 等待一段时间后继续检查
            try? await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
            waitedTime += checkInterval
        }
        
        // 如果超时，使用当前可用的资源进行保存
        print("[Live Photo保存] 等待超时，使用当前可用资源")
        self.saveLivePhotoToPhotoLibrary(isMirrored: isMirrored, isFront: isFront, isBack: isBack) { success in
            completion(success)
        }
    }
    
    // 保存普通照片
    private func saveImageToPhotoLibrary(_ image: UIImage, completion: @escaping (Bool) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        switch status {
        case .authorized, .limited:
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        print("[相册保存] 保存成功")
                        self.showSaveSuccess = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            self.showSaveSuccess = false
                        }
                        completion(true)
                    } else {
                        print("[相册保存] 保存失败：\(error?.localizedDescription ?? "未知错误")")
                        completion(false)
                    }
                }
            }
            
        case .notDetermined:
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
            PermissionManager.shared.alertState = .permission(isFirstRequest: false)
            completion(false)
            
        @unknown default:
            completion(false)
        }
    }
    
    // 修改保存 Live Photo 的方法
    private func saveLivePhotoToPhotoLibrary(isMirrored: Bool = false, isFront: Bool = true, isBack: Bool = false, completion: @escaping (Bool) -> Void) {
        print("开始保存Live Photo到相册")
        print("模拟模式：\(simulatedLivePhotoMode)")
        print("设备方向：\(captureOrientation.rawValue)")
        print("镜像状态：\(isMirrored)")
        print("前置摄像头：\(isFront)")
        print("后置摄像头：\(isBack)")
        
        // 确定要使用的图片和视频URL
        let imageURLToUse: URL?
        var videoURLToUse: URL?
        
        if simulatedLivePhotoMode && isCheckmarkEnabled {
            // 使用预览中的图片
            if let previewImage = capturedImage {
                // 根据设备方向旋转预览图片
                print("[保存Live Photo] 处理预览图片旋转")
                print("当前设备方向：\(captureOrientation.rawValue)")
                let rotatedImage = rotateImageForSaving(previewImage, orientation: captureOrientation)
                
                // 将旋转后的预览图片保存为临时文件
                let tempDir = FileManager.default.temporaryDirectory
                let processedImageURL = tempDir.appendingPathComponent("\(UUID().uuidString)_processed.heic")
                
                if let imageData = rotatedImage.heicData() {
                    try? imageData.write(to: processedImageURL)
                    imageURLToUse = processedImageURL
                    print("[保存Live Photo] 已保存旋转后的预览图片到：\(processedImageURL.path)")
                } else {
                    imageURLToUse = tempImageURL
                    print("[保存Live Photo] 预览图片保存失败，使用原始图片")
                }
            } else {
                imageURLToUse = tempImageURL
            }
            videoURLToUse = simulatedVideoURL ?? livePhotoVideoURL
        } else {
            // 不勾选时的处理
            if let originalImage = originalLiveImage {
                // 使用 LiveProcessor 处理图片，只添加水印
                let processedImage = LiveProcessor.shared.processLivePhotoImage(
                    baseImage: originalImage,
                    drawingImage: nil,
                    makeupImage: nil,
                    scale: currentScale,
                    orientation: captureOrientation
                )
                
                // 根据设备方向旋转图片
                let rotatedImage = rotateImageForSaving(processedImage, orientation: captureOrientation)
                
                // 将处理后的图片保存为临时文件
                let tempDir = FileManager.default.temporaryDirectory
                let processedImageURL = tempDir.appendingPathComponent("\(UUID().uuidString)_processed.heic")
                
                if let imageData = rotatedImage.heicData() {
                    try? imageData.write(to: processedImageURL)
                    imageURLToUse = processedImageURL
                    print("[保存Live Photo] 已保存带水印的图片到：\(processedImageURL.path)")
                } else {
                    imageURLToUse = tempImageURL
                    print("[保存Live Photo] 图片处理失败，使用原始图片")
                }
                
                // 使用处理后的视频URL，如果没有则使用原始视频URL
                videoURLToUse = processedVideoURL ?? viewMovURL ?? livePhotoVideoURL
                print("[保存Live Photo] 使用视频：\(String(describing: videoURLToUse?.path))")
            } else {
                imageURLToUse = tempImageURL
                videoURLToUse = processedVideoURL ?? viewMovURL ?? livePhotoVideoURL
            }
        }
        
        // 如果视频处理失败或不需要处理，使用原始资源继续保存
        guard let imageURL = imageURLToUse,
              let videoURL = videoURLToUse else {
            print("错误：缺少必要的Live Photo资源")
            print("图片URL：\(String(describing: imageURLToUse))")
            print("视频URL：\(String(describing: videoURLToUse))")
            print("processedVideoURL：\(String(describing: processedVideoURL))")
            print("viewMovURL：\(String(describing: viewMovURL))")
            print("livePhotoVideoURL：\(String(describing: livePhotoVideoURL))")
            completion(false)
            return
        }
        
        // 生成Live Photo
        LivePhoto.generate(from: imageURL, videoURL: videoURL) { progress in
            print("Live Photo生成进度: \(progress)")
        } completion: { livePhoto, resources in
            if let resources = resources {
                // 保存到相册
                LivePhoto.saveToLibrary(resources) { success in
                    if success {
                        print("Live Photo已成功保存到相册")
                        DispatchQueue.main.async {
                            self.showSaveSuccess = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                self.showSaveSuccess = false
                            }
                        }
                        completion(true)
                    } else {
                        print("保存Live Photo失败")
                        completion(false)
                    }
                }
            } else {
                print("错误：Live Photo资源生成失败")
                completion(false)
            }
        }
    }
    
    // 重置所有状态
    func reset() {
        capturedImage = nil
        isPreviewVisible = false
        currentScale = 1.0
        isLivePhoto = false
        livePhotoVideoURL = nil
        isPlayingLivePhoto = false
        livePhotoIdentifier = ""
        tempImageURL = nil
        tempVideoURL = nil
    }
    
    // 获取预览图片的方法
    public func getPreviewImage(baseImage: UIImage) -> UIImage {
        // 如果已经有缓存的预览图片，直接返回
        if let cached = previewMixImage {
            return cached
        }
        
        // 生成新的预览图片
        let newPreviewImage: UIImage
        if isCheckmarkEnabled && (pinnedDrawingImage != nil || isMakeupViewActive) {
            newPreviewImage = ImageProcessor.shared.createMixImage(
                baseImage: baseImage,
                drawingImage: pinnedDrawingImage,
                makeupImage: isMakeupViewActive ? makeupImage : nil,
                scale: constScale,  // 使用固定的初始缩放比例
                orientation: captureOrientation
            )
        } else {
            newPreviewImage = ImageProcessor.shared.addWatermark(to: baseImage, orientation: captureOrientation)
        }
        
        // 缓存预览图片
        previewMixImage = newPreviewImage
        return newPreviewImage
    }
    
    // 清除预览图片缓存的方法
    public func clearPreviewCache() {
        previewMixImage = nil
    }
    
    // 更新绘画图片的方法
    public func updatePinnedDrawingImage(_ image: UIImage?) {
        pinnedDrawingImage = image
        clearPreviewCache()
        
        // 如果已经勾选了mix，立即更新预览图片
        if isCheckmarkEnabled, let baseImage = capturedImage {
            previewMixImage = ImageProcessor.shared.createMixImage(
                baseImage: baseImage,
                drawingImage: pinnedDrawingImage,
                makeupImage: isMakeupViewActive ? makeupImage : nil,
                scale: currentScale,
                orientation: captureOrientation
            )
        }
    }
    
    // 添加公开的图片处理方法
    public func processImageForOrientation(_ image: UIImage) -> UIImage {
        return (captureOrientation.isLandscape || captureOrientation == .portraitUpsideDown) ? 
            rotateImageIfNeeded(image) : image
    }
    
    // 修改createSimulatedImage方法
    private func createSimulatedImage(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            // 创建渐变背景
            let colors = [
                UIColor(red: 1.0, green: 0.9, blue: 0.0, alpha: 1.0),  // 亮黄色
                UIColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0),  // 黄色
                UIColor(red: 1.0, green: 0.7, blue: 0.0, alpha: 1.0),  // 深黄色
            ]
            
            let locations: [CGFloat] = [0.0, 0.5, 1.0]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                    colors: colors.map { $0.cgColor } as CFArray,
                                    locations: locations)!
            
            context.cgContext.drawLinearGradient(gradient,
                                               start: CGPoint(x: 0, y: 0),
                                               end: CGPoint(x: size.width, y: size.height),
                                               options: [])
            
            // 添加细微纹理
            let gridSize: CGFloat = 2.0
            for x in stride(from: 0, to: size.width, by: gridSize) {
                for y in stride(from: 0, to: size.height, by: gridSize) {
                    let color = UIColor(white: 1.0, alpha: CGFloat.random(in: 0.0...0.05))
                    color.setFill()
                    context.fill(CGRect(x: x, y: y, width: gridSize, height: gridSize))
                }
            }
            
            // 添加少量随机线条
            for _ in 0..<100 {
                let color = UIColor(white: 1.0, alpha: 0.1)
                color.setStroke()
                
                let path = UIBezierPath()
                let startPoint = CGPoint(x: CGFloat.random(in: 0...size.width),
                                       y: CGFloat.random(in: 0...size.height))
                let endPoint = CGPoint(x: CGFloat.random(in: 0...size.width),
                                     y: CGFloat.random(in: 0...size.height))
                
                path.move(to: startPoint)
                path.addLine(to: endPoint)
                path.lineWidth = 0.5
                path.stroke()
            }
        }
        return image
    }
    
    // 修改createSimulatedVideo方法
    private func createSimulatedVideo(size: CGSize, completion: @escaping (URL?) -> Void) {
        let tempDir = FileManager.default.temporaryDirectory
        let outputURL = tempDir.appendingPathComponent("\(UUID().uuidString).mov")
        
        let videoWriter = try? AVAssetWriter(outputURL: outputURL, fileType: .mov)
        guard let videoWriter = videoWriter else {
            completion(nil)
            return
        }
        
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: size.width,
            AVVideoHeightKey: size.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 2_000_000,
                AVVideoExpectedSourceFrameRateKey: 30,
                AVVideoMaxKeyFrameIntervalKey: 30,
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
            ]
        ]
        
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = true
        
        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: size.width,
            kCVPixelBufferHeightKey as String: size.height,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput,
                                                          sourcePixelBufferAttributes: attributes)
        
        videoWriter.add(videoInput)
        videoWriter.startWriting()
        videoWriter.startSession(atSourceTime: .zero)
        
        // 创建纯白色图片
        let renderer = UIGraphicsImageRenderer(size: size)
        let whiteImage = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        
        let frameCount = Int(2.965 * 30) // 约3秒，30fps
        var frameNumber = 0
        
        let queue = DispatchQueue(label: "com.mirror.videoWriting")
        queue.async {
            while frameNumber < frameCount {
                if videoInput.isReadyForMoreMediaData {
                    autoreleasepool {
                        let presentationTime = CMTime(value: Int64(frameNumber), timescale: 30)
                        
                        var pixelBuffer: CVPixelBuffer?
                        CVPixelBufferCreate(kCFAllocatorDefault,
                                          Int(size.width),
                                          Int(size.height),
                                          kCVPixelFormatType_32ARGB,
                                          attributes as CFDictionary,
                                          &pixelBuffer)
                        
                        if let pixelBuffer = pixelBuffer {
                            CVPixelBufferLockBaseAddress(pixelBuffer, [])
                            let context = CGContext(data: CVPixelBufferGetBaseAddress(pixelBuffer),
                                                 width: Int(size.width),
                                                 height: Int(size.height),
                                                 bitsPerComponent: 8,
                                                 bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                                                 space: CGColorSpaceCreateDeviceRGB(),
                                                 bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)
                            
                            // 绘制纯白色图片
                            context?.draw(whiteImage.cgImage!, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
                            CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
                            
                            adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                            
                            // 更新进度（最多更新到95%）
                            let progress = min(0.95, Double(frameNumber) / Double(frameCount))
                            DispatchQueue.main.async { [weak self] in
                                self?.simulationProgress = progress
                            }
                        }
                    }
                    frameNumber += 1
                }
            }
            
            videoInput.markAsFinished()
            videoWriter.finishWriting { [weak self] in
                DispatchQueue.main.async {
                    // 设置进度为98%，表示视频已生成，正在处理最后的步骤
                    self?.simulationProgress = 0.98
                    completion(outputURL)
                }
            }
        }
    }
    
    // 添加复制Live Photo资源的方法
    private func copyLivePhotoResources(imageURL: URL, videoURL: URL) -> (imageURL: URL?, videoURL: URL?) {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
        
        // 生成唯一标识符
        let identifier = UUID().uuidString
        
        // 创建目标URL
        let copiedImageURL = tempDir.appendingPathComponent("\(identifier)_copy.heic")
        let copiedVideoURL = tempDir.appendingPathComponent("\(identifier)_copy.mov")
        
        do {
            // 复制图片文件
            try fileManager.copyItem(at: imageURL, to: copiedImageURL)
            // 复制视频文件
            try fileManager.copyItem(at: videoURL, to: copiedVideoURL)
            
            print("[资源复制] 成功")
            print("- 原始图片：\(imageURL.path)")
            print("- 复制图片：\(copiedImageURL.path)")
            print("- 原始视频：\(videoURL.path)")
            print("- 复制视频：\(copiedVideoURL.path)")
            
            return (copiedImageURL, copiedVideoURL)
        } catch {
            print("[资源复制] 失败：\(error.localizedDescription)")
            return (nil, nil)
        }
    }

    // 修改勾选状态变化的处理
    public func handleCheckmarkToggle(isMirrored: Bool, isFront: Bool, isBack: Bool) {
        if isLivePhoto {
            if isCheckmarkEnabled {
                // 检查视频是否正在处理中
                if isVideoProcessing {
                    print("[勾选处理] 视频正在处理中，等待资源准备完成...")
                    isResourcePreparing = true
                    
                    // 开始监测视频处理状态
                    startMonitoringVideoProcessing(isMirrored: isMirrored, isFront: isFront, isBack: isBack)
                    return
                }
                
                // 避免重复生成
                if isGeneratingSimulation {
                    print("[勾选处理] 正在生成模拟资源，请等待...")
                    return
                }
                
                // 检查是否有缓存的mix资源
                if hasCachedMixResources,
                   let imageURL = cachedMixImageURL,
                   let videoURL = cachedMixVideoURL,
                   FileManager.default.fileExists(atPath: imageURL.path),
                   FileManager.default.fileExists(atPath: videoURL.path) {
                    print("[勾选处理] 使用已缓存的mix资源")
                    print("- 图片路径：\(imageURL.path)")
                    print("- 视频路径：\(videoURL.path)")
                    
                    // 直接使用缓存的资源更新UI
                    if let mixImage = UIImage(contentsOfFile: imageURL.path) {
                        // 在主线程更新UI
                        DispatchQueue.main.async {
                            self.capturedImage = mixImage
                            self.viewMovURL = videoURL
                            self.simulatedVideoURL = videoURL
                            self.simulatedLivePhotoMode = true
                            
                            // 发送完成通知
                            NotificationCenter.default.post(name: Notification.Name("SimulationComplete"), object: nil)
                        }
                    }
                    return
                }
                
                // 重置进度为0%
                simulationProgress = 0.0
                
                // 切换到模拟模式
                if let originalImage = originalLiveImage,
                   let _ = originalVideoURL, let tempVideo = tempVideoURL {
                    isGeneratingSimulation = true
                    
                    // 复制未勾选时的mov（tempVideoURL），图片仍用tempImageURL
                    let (copiedImageURL, copiedVideoURL) = copyLivePhotoResources(
                        imageURL: tempImageURL!,
                        videoURL: tempVideo
                    )
                    
                    guard let imageURL = copiedImageURL,
                          let videoURL = copiedVideoURL else {
                        print("[勾选处理] 资源复制失败")
                        isGeneratingSimulation = false
                        return
                    }
                    
                    // 缓存复制的资源
                    self.cachedSimulatedImageURL = imageURL
                    self.cachedSimulatedVideoURL = videoURL
                    
                    // 处理图片，同时添加水印、绘画和化妆效果
                    let processedImage = LiveProcessor.shared.processLivePhotoImage(
                        baseImage: originalImage,
                        drawingImage: isCheckmarkEnabled ? pinnedDrawingImage : nil,
                        makeupImage: isCheckmarkEnabled ? makeupImage : nil,
                        scale: constScale,
                        orientation: self.captureOrientation
                    )
                    
                    // 处理视频，确保同时叠加水印、绘画和化妆效果
                    Task {
                        if let processedVideoURL = await LiveProcessor.shared.processLivePhotoVideo(
                            videoURL: videoURL,
                            drawingImage: isCheckmarkEnabled ? pinnedDrawingImage : nil,
                            makeupImage: isCheckmarkEnabled ? makeupImage : nil,
                            scale: constScale,
                            orientation: self.captureOrientation,
                            isMirrored: isMirrored,
                            isFront: isFront,
                            isBack: isBack,
                            progressHandler: { [weak self] progress in
                                self?.simulationProgress = progress
                            }
                        ) {
                            // 保存处理后的资源到缓存
                            // 将处理后的图片保存为文件
                            let tempDir = FileManager.default.temporaryDirectory
                            let mixImageURL = tempDir.appendingPathComponent("\(UUID().uuidString)_mix.heic")
                            if let imageData = processedImage.heicData() {
                                try? imageData.write(to: mixImageURL)
                                self.cachedMixImageURL = mixImageURL
                                self.cachedMixVideoURL = processedVideoURL
                                self.hasCachedMixResources = true
                                print("[勾选处理] 已缓存mix资源")
                            }
                            
                            // 在主线程更新UI
                            await MainActor.run {
                                // 更新UI
                                self.capturedImage = processedImage
                                self.viewMovURL = processedVideoURL
                                self.simulatedVideoURL = processedVideoURL
                                self.simulatedLivePhotoMode = true
                                self.isGeneratingSimulation = false
                                
                                // 更新进度到100%
                                self.simulationProgress = 1.0
                                
                                // 发送完成通知
                                NotificationCenter.default.post(name: Notification.Name("SimulationComplete"), object: nil)
                                
                                print("[勾选处理] 模拟资源生成完成")
                                print("- 使用处理后的图片")
                                print("- 使用处理后的视频：\(processedVideoURL.path)")
                            }
                        }
                    }
                }
            } else {
                // 取消勾选时恢复到原始状态和资源
                if let originalImage = originalLiveImage {
                    print("[勾选处理] 恢复普通Live模式")
                    print("- 恢复原始图片")
                    
                    // 使用 LiveProcessor 处理原始图片，只添加水印
                    let processedImage = LiveProcessor.shared.processLivePhotoImage(
                        baseImage: originalImage,
                        drawingImage: nil,
                        makeupImage: nil,
                        scale: constScale,
                        orientation: captureOrientation
                    )
                    capturedImage = processedImage
                    
                    // 恢复到原始处理后的视频
                    if let processedVideo = processedVideoURL {
                        print("- 恢复到原始处理后的视频：\(processedVideo.path)")
                        viewMovURL = processedVideo
                    } else if let originalVideo = originalVideoURL {
                        print("- 恢复到原始视频：\(originalVideo.path)")
                        viewMovURL = originalVideo
                    }
                    
                    simulatedLivePhotoMode = false
                    
                    print("[勾选处理] 资源恢复完成")
                    print("- 当前视频URL：\(String(describing: viewMovURL?.path))")
                }
            }
        } else {
            // 非Live Photo模式的处理
            if isCheckmarkEnabled {
                // 检查是否有缓存的mix图片
                if hasCachedMixResources,
                   let imageURL = cachedMixImageURL,
                   FileManager.default.fileExists(atPath: imageURL.path) {
                    print("[勾选处理] 使用已缓存的mix图片")
                    if let mixImage = UIImage(contentsOfFile: imageURL.path) {
                        previewMixImage = mixImage
                        NotificationCenter.default.post(name: Notification.Name("SimulationComplete"), object: nil)
                        return
                    }
                }
                
                // 清除预览缓存，强制重新生成预览图片
                clearPreviewCache()
                
                // 如果有原始图片，重新生成预览图片
                if let baseImage = capturedImage {
                    let mixImage = ImageProcessor.shared.createMixImage(
                        baseImage: baseImage,
                        drawingImage: pinnedDrawingImage,
                        makeupImage: isMakeupViewActive ? makeupImage : nil,
                        scale: constScale,
                        orientation: captureOrientation
                    )
                    
                    // 保存处理后的图片到缓存
                    let tempDir = FileManager.default.temporaryDirectory
                    let mixImageURL = tempDir.appendingPathComponent("\(UUID().uuidString)_mix.heic")
                    if let imageData = mixImage.heicData() {
                        try? imageData.write(to: mixImageURL)
                        self.cachedMixImageURL = mixImageURL
                        self.hasCachedMixResources = true
                        print("[勾选处理] 已缓存mix图片")
                    }
                    
                    previewMixImage = mixImage
                }
                
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: Notification.Name("SimulationComplete"), object: nil)
                }
            } else {
                // 取消勾选时不清除缓存，只恢复原始状态
                clearPreviewCache()
                if let baseImage = capturedImage {
                    previewMixImage = ImageProcessor.shared.addWatermark(to: baseImage, orientation: captureOrientation)
                }
            }
        }
    }
    
    // 添加监测视频处理状态的方法
    private func startMonitoringVideoProcessing(isMirrored: Bool, isFront: Bool, isBack: Bool) {
        // 创建一个定时器来检查视频处理状态
        let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            // 检查视频是否处理完成
            if !self.isVideoProcessing {
                timer.invalidate()
                self.isResourcePreparing = false
                
                // 视频处理完成后，自动开始mix处理
                DispatchQueue.main.async {
                    self.handleCheckmarkToggle(isMirrored: isMirrored, isFront: isFront, isBack: isBack)
                }
            }
        }
        timer.fire()
    }
}

// 修改HEIC转换扩展
extension UIImage {
    func heicData(compressionQuality: CGFloat = 1.0) -> Data? {
        let data = NSMutableData()
        
        guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, AVFileType.heic as CFString, 1, nil) else {
            print("[HEIC转换] 创建目标失败")
            return nil
        }
        
        guard let cgImage = self.cgImage else {
            print("[HEIC转换] 获取CGImage失败")
            return nil
        }
        
        // 创建不透明的图片
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue)
        guard let context = CGContext(data: nil,
                                    width: cgImage.width,
                                    height: cgImage.height,
                                    bitsPerComponent: 8,
                                    bytesPerRow: 0,
                                    space: colorSpace,
                                    bitmapInfo: bitmapInfo.rawValue) else {
            print("[HEIC转换] 创建上下文失败")
            return nil
        }
        
        // 先填充白色背景
        context.setFillColor(CGColor(gray: 1.0, alpha: 1.0))
        context.fill(CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        
        // 绘制原始图片
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        
        // 获取处理后的图片
        guard let opaqueImage = context.makeImage() else {
            print("[HEIC转换] 创建不透明图片失败")
            return nil
        }
        
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: compressionQuality,
            kCGImageDestinationOptimizeColorForSharing: true,
            kCGImagePropertyOrientation: self.imageOrientation.rawValue
        ]
        
        CGImageDestinationAddImage(destination, opaqueImage, options as CFDictionary)
        
        guard CGImageDestinationFinalize(destination) else {
            print("[HEIC转换] 完成转换失败")
            return nil
        }
        
        print("[HEIC转换] 完成")
        print("- 输出数据大小：\(data.length) bytes")
        print("- 压缩质量：\(compressionQuality)")
        
        return data as Data
    }
} 
