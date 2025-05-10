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
    @Published var isLivePhoto = false
    @Published var livePhotoVideoURL: URL?
    @Published var tempImageURL: URL?
    @Published var tempVideoURL: URL?
    @Published var livePhotoIdentifier = ""
    @Published var currentScale: CGFloat = 1.0
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
    
    // 添加缓存属性
    private var cachedSimulatedImageURL: URL?
    private var cachedSimulatedVideoURL: URL?
    private var isGeneratingSimulation = false
    
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
    
    private init() {}
    
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
        
        let rotationAngle: CGFloat
        let shouldRotate: Bool
        var newSize = image.size
        
        switch orientation {
        case .landscapeLeft:
            rotationAngle = -.pi/2
            shouldRotate = true
            newSize = CGSize(width: image.size.height, height: image.size.width)
        case .landscapeRight:
            rotationAngle = .pi/2
            shouldRotate = true
            newSize = CGSize(width: image.size.height, height: image.size.width)
        case .portraitUpsideDown:
            rotationAngle = .pi
            shouldRotate = true
        default:
            return image
        }
        
        if !shouldRotate {
            return image
        }
        
        return autoreleasepool { () -> UIImage in
            UIGraphicsBeginImageContextWithOptions(newSize, false, image.scale)
            let context = UIGraphicsGetCurrentContext()!
            
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
        let actualOrientation = orientationManager.currentOrientation
        
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
    func showLivePhotoPreview(image: UIImage, videoURL: URL, imageURL: URL, identifier: String, orientation: UIDeviceOrientation = .portrait, cameraManager: CameraManager, scale: CGFloat = 1.0) {
        print("------------------------")
        print("[Live Photo预览] 开始初始化")
        print("设备方向：\(orientation.rawValue)")
        print("缩放比例：\(scale)")
        
        // 保存原始视频URL
        self.originalVideoURL = videoURL
        
        // 处理图片旋转（包括横屏和倒置竖屏）
        let processedImage = (orientation.isLandscape || orientation == .portraitUpsideDown) ? 
            rotateImageIfNeeded(image) : image
        
        // 保存原始处理后的图片
        self.originalLiveImage = processedImage
        
        // 添加模拟mix-live的逻辑
        if isCheckmarkEnabled && (isPinnedDrawingActive || isMakeupViewActive) {
            simulatedLivePhotoMode = true
            
            // 获取标准尺寸（竖屏3024x4032）
            let standardSize = CGSize(width: 3024, height: 4032)
            
            // 根据方向调整尺寸
            let targetSize: CGSize
            if orientation.isLandscape {
                targetSize = CGSize(width: standardSize.height, height: standardSize.width)
                print("[模拟Live] 横屏模式，使用尺寸：\(targetSize.width) x \(targetSize.height)")
            } else {
                targetSize = standardSize
                print("[模拟Live] 竖屏模式，使用尺寸：\(targetSize.width) x \(targetSize.height)")
            }
            
            // 创建模拟的mix-live图片(黄色)
            let renderer = UIGraphicsImageRenderer(size: targetSize)
            let simulatedImage = renderer.image { ctx in
                UIColor.yellow.setFill()
                ctx.fill(CGRect(origin: .zero, size: targetSize))
            }
            
            // 根据方向处理模拟图片
            let finalSimulatedImage = (orientation.isLandscape || orientation == .portraitUpsideDown) ? 
                rotateImageIfNeeded(simulatedImage) : simulatedImage
            
            self.capturedImage = finalSimulatedImage
            
            // 创建模拟视频（白色）
            createSimulatedVideo(size: targetSize) { url in
                self.simulatedVideoURL = url
                self.livePhotoVideoURL = url
            }
            
            print("[模拟Live] 创建mix-live预览")
            print("- 静态图片: 黄色 (\(targetSize.width) x \(targetSize.height))")
            print("- 视频: 白色 (\(targetSize.width) x \(targetSize.height))")
            print("- 设备方向: \(orientation.rawValue)")
            print("- 保存原始图片和视频引用")
        } else {
            simulatedLivePhotoMode = false
            self.capturedImage = processedImage
            self.livePhotoVideoURL = videoURL
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
            self.captureOrientation = orientation
            self.currentScale = scale
            self.currentIndicatorScale = scale
            
            print("[Live Photo预览] 状态更新：")
            print("- isLivePhoto：\(self.isLivePhoto)")
            print("- livePhotoVideoURL：\(String(describing: self.livePhotoVideoURL))")
            print("- isPlayingLivePhoto：\(self.isPlayingLivePhoto)")
            
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
    
    // 隐藏预览
    func hidePreview(cameraManager: CameraManager) {
        withAnimation {
            self.isPreviewVisible = false
            self.isPlayingLivePhoto = false
            self.showScaleIndicator = false
            // 重置拖动状态
            self.dragOffset = .zero
            self.lastDragOffset = .zero
            self.isCheckmarkEnabled = false  // 重置勾选状态
            self.previewMixImage = nil  // 清除预览图片缓存
            // 注意：不再在这里清理绘画相关状态
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
        
        // 重置状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.capturedImage = nil
            self.livePhotoVideoURL = nil
            self.tempImageURL = nil
            self.tempVideoURL = nil
            self.livePhotoIdentifier = ""
            self.currentScale = 1.0
            self.isCapturing = false
            
            print("[清理缓存] 已清理所有临时文件和状态")
        }
    }
    
    // 修改保存方法
    public func saveToPhotos(completion: ((Bool) -> Void)? = nil) {
        if isLivePhoto {
            if simulatedLivePhotoMode {
                print("[模拟Live] 保存mix-live图片")
                // 这里先使用模拟数据,后续实现实际处理
                saveLivePhotoToPhotoLibrary { success in
                    completion?(success)
                }
            } else {
                // 原有的Live Photo保存逻辑
                saveLivePhotoToPhotoLibrary { success in
                    completion?(success)
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
                        scale: currentScale
                    )
                }
            } else {
                imageToSave = capturedImage!
            }
            
            // 根据设备方向旋转图片
            print("[保存图片] 当前设备方向：\(captureOrientation.rawValue)")
            imageToSave = rotateImageForSaving(imageToSave, orientation: captureOrientation)
            
            saveImageToPhotoLibrary(imageToSave) { success in
                completion?(success)
            }
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
    private func saveLivePhotoToPhotoLibrary(completion: @escaping (Bool) -> Void) {
        print("开始保存Live Photo到相册")
        print("模拟模式：\(simulatedLivePhotoMode)")
        print("设备方向：\(captureOrientation.rawValue)")
        
        if simulatedLivePhotoMode {
            // 使用缓存的资源
            guard let imageURL = cachedSimulatedImageURL,
                  let videoURL = cachedSimulatedVideoURL else {
                print("错误：没有缓存的模拟资源")
                completion(false)
                return
            }
            
            print("[模拟Live] 使用缓存资源")
            print("- 图片路径：\(imageURL.path)")
            print("- 视频路径：\(videoURL.path)")
            
            // 生成Live Photo
            LivePhoto.generate(from: imageURL, videoURL: videoURL) { progress in
                print("Live Photo生成进度: \(progress)")
            } completion: { livePhoto, resources in
                if let resources = resources {
                    // 保存到相册
                    LivePhoto.saveToLibrary(resources) { success in
                        if success {
                            print("模拟Live Photo已成功保存到相册")
                            DispatchQueue.main.async {
                                self.showSaveSuccess = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    self.showSaveSuccess = false
                                }
                            }
                            completion(true)
                        } else {
                            print("保存模拟Live Photo失败")
                            completion(false)
                        }
                    }
                } else {
                    print("错误：Live Photo资源生成失败")
                    completion(false)
                }
            }
        } else {
            // 原始Live Photo保存逻辑
            guard let imageURL = tempImageURL,
                  let videoURL = livePhotoVideoURL else {
                print("错误：缺少必要的Live Photo资源")
                print("- 图片URL：\(String(describing: tempImageURL))")
                print("- 视频URL：\(String(describing: livePhotoVideoURL))")
                completion(false)
                return
            }
            
            // 检查文件是否存在
            let fileManager = FileManager.default
            let imageExists = fileManager.fileExists(atPath: imageURL.path)
            let videoExists = fileManager.fileExists(atPath: videoURL.path)
            
            print("[Live Photo保存] 资源检查：")
            print("- 图片文件存在：\(imageExists)")
            print("- 视频文件存在：\(videoExists)")
            
            guard imageExists && videoExists else {
                print("错误：Live Photo资源文件不存在")
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
    
    // 更新绘画图片的方法
    public func updatePinnedDrawingImage(_ image: UIImage?) {
        pinnedDrawingImage = image
        // 清除预览图片缓存
        previewMixImage = nil
    }
    
    // 获取预览图片的方法
    public func getPreviewImage(baseImage: UIImage) -> UIImage {
        if isCheckmarkEnabled && (pinnedDrawingImage != nil || isMakeupViewActive) {
            if previewMixImage == nil {
                previewMixImage = ImageProcessor.shared.createPreviewImage(
                    baseImage: baseImage,
                    drawingImage: pinnedDrawingImage,
                    makeupImage: isMakeupViewActive ? makeupImage : nil,
                    scale: currentScale
                )
            }
            return previewMixImage!
        }
        return baseImage
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
    
    // 修改createSimulatedVideo方法中的异步部分
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
                        }
                    }
                    frameNumber += 1
                }
            }
            
            videoInput.markAsFinished()
            videoWriter.finishWriting {
                DispatchQueue.main.async {
                    completion(outputURL)
                }
            }
        }
    }
    
    // 修改勾选状态变化的处理
    public func handleCheckmarkToggle() {
        if isLivePhoto {
            if isCheckmarkEnabled {
                // 避免重复生成
                if isGeneratingSimulation {
                    print("[勾选处理] 正在生成模拟资源，请等待...")
                    return
                }
                
                // 如果已经有缓存的资源，直接使用
                if let imageURL = cachedSimulatedImageURL,
                   let videoURL = cachedSimulatedVideoURL,
                   FileManager.default.fileExists(atPath: imageURL.path),
                   FileManager.default.fileExists(atPath: videoURL.path) {
                    print("[勾选处理] 使用已缓存的模拟资源")
                    print("- 图片路径：\(imageURL.path)")
                    print("- 视频路径：\(videoURL.path)")
                    
                    // 直接使用缓存的资源更新UI
                    if let simulatedImage = UIImage(contentsOfFile: imageURL.path) {
                        let finalSimulatedImage = (self.captureOrientation.isLandscape || self.captureOrientation == .portraitUpsideDown) ? 
                            self.rotateImageIfNeeded(simulatedImage) : simulatedImage
                        
                        self.capturedImage = finalSimulatedImage
                        self.simulatedVideoURL = videoURL
                        self.livePhotoVideoURL = videoURL
                        self.simulatedLivePhotoMode = true
                        
                        // 发送模拟完成通知
                        NotificationCenter.default.post(name: Notification.Name("SimulationComplete"), object: nil)
                    }
                    return
                }
                
                // 切换到模拟模式
                if originalLiveImage != nil {
                    isGeneratingSimulation = true
                    
                    // 获取标准尺寸（竖屏3024x4032）
                    let standardSize = CGSize(width: 3024, height: 4032)
                    
                    // 根据方向调整尺寸
                    let targetSize: CGSize
                    if captureOrientation.isLandscape {
                        targetSize = CGSize(width: standardSize.height, height: standardSize.width)
                        print("[模拟Live] 横屏模式，使用尺寸：\(targetSize.width) x \(targetSize.height)")
                    } else {
                        targetSize = standardSize
                        print("[模拟Live] 竖屏模式，使用尺寸：\(targetSize.width) x \(targetSize.height)")
                    }
                    
                    // 创建模拟图片并保存到文件
                    let renderer = UIGraphicsImageRenderer(size: targetSize, format: {
                        let format = UIGraphicsImageRendererFormat()
                        format.scale = 1.0  // 强制使用1.0的缩放比例
                        format.opaque = true  // 设置为不透明
                        return format
                    }())
                    
                    let simulatedImage = renderer.image { ctx in
                        // 使用Core Graphics绘制以确保正确的尺寸
                        let context = ctx.cgContext
                        
                        // 创建渐变
                        let colors = [
                            UIColor.yellow.cgColor,
                            UIColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0).cgColor
                        ]
                        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                                colors: colors as CFArray,
                                                locations: [0, 1])!
                        
                        context.drawLinearGradient(gradient,
                                                 start: CGPoint(x: 0, y: 0),
                                                 end: CGPoint(x: targetSize.width, y: targetSize.height),
                                                 options: [])
                    }
                    
                    print("[模拟Live] 生成的图片尺寸：\(simulatedImage.size.width) x \(simulatedImage.size.height)")
                    
                    // 保存模拟图片
                    let imageIdentifier = UUID().uuidString
                    let imageURL = persistentDirectory.appendingPathComponent("\(imageIdentifier).heic")
                    
                    // 使用CGImageDestination直接写入HEIC文件
                    if let destination = CGImageDestinationCreateWithURL(imageURL as CFURL,
                                                                       UTType.heic.identifier as CFString,
                                                                       1, nil) {
                        let options: [CFString: Any] = [
                            kCGImageDestinationLossyCompressionQuality: 1.0,
                            kCGImageDestinationOptimizeColorForSharing: true
                        ]
                        
                        CGImageDestinationSetProperties(destination, options as CFDictionary)
                        CGImageDestinationAddImage(destination, simulatedImage.cgImage!, options as CFDictionary)
                        
                        if CGImageDestinationFinalize(destination) {
                            print("[模拟Live] 图片已保存到：\(imageURL.path)")
                            
                            // 验证保存后的图片尺寸
                            if let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
                               let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any],
                               let width = properties[kCGImagePropertyPixelWidth as String] as? Int,
                               let height = properties[kCGImagePropertyPixelHeight as String] as? Int {
                                print("[模拟Live] 验证保存后的图片尺寸：\(width) x \(height)")
                            }
                            
                            self.cachedSimulatedImageURL = imageURL
                            print("[模拟Live] 图片已缓存：\(imageURL.path)")
                            
                            // 创建模拟视频
                            createSimulatedVideo(size: targetSize) { [weak self] url in
                                guard let self = self else { return }
                                DispatchQueue.main.async {
                                    if let url = url {
                                        print("[模拟Live] 视频已缓存：\(url.path)")
                                        self.cachedSimulatedVideoURL = url
                                        self.simulatedVideoURL = url
                                        self.livePhotoVideoURL = url
                                        
                                        // 根据方向处理模拟图片
                                        let finalSimulatedImage = (self.captureOrientation.isLandscape || self.captureOrientation == .portraitUpsideDown) ? 
                                            self.rotateImageIfNeeded(simulatedImage) : simulatedImage
                                        
                                        // 更新UI
                                        self.capturedImage = finalSimulatedImage
                                        self.simulatedLivePhotoMode = true
                                        self.isGeneratingSimulation = false
                                        
                                        print("[勾选处理] 模拟资源生成完成")
                                        print("- 图片尺寸：\(targetSize.width) x \(targetSize.height)")
                                        print("- 视频尺寸：\(targetSize.width) x \(targetSize.height)")
                                        
                                        // 发送模拟完成通知
                                        NotificationCenter.default.post(name: Notification.Name("SimulationComplete"), object: nil)
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                // 恢复原始图片和视频
                if let originalImage = originalLiveImage {
                    print("[勾选处理] 恢复普通Live模式")
                    capturedImage = originalImage
                    simulatedLivePhotoMode = false
                    if let originalVideo = originalVideoURL {
                        livePhotoVideoURL = originalVideo
                    }
                }
            }
        } else {
            // 非Live Photo模式的处理
            if isCheckmarkEnabled {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: Notification.Name("SimulationComplete"), object: nil)
                }
            }
        }
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
        
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: compressionQuality,
            kCGImageDestinationOptimizeColorForSharing: true,
            kCGImagePropertyOrientation: self.imageOrientation.rawValue
        ]
        
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
        
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
