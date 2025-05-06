import SwiftUI
import UIKit
import Photos

class CaptureManager: ObservableObject {
    static let shared = CaptureManager()
    
    @Published var isPreviewVisible = false
    @Published var capturedImage: UIImage?
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
    
    // 添加计算属性来判断是否应该显示勾选按钮
    var shouldShowCheckmark: Bool {
        return !isLivePhoto && (isPinnedDrawingActive || isMakeupViewActive)
    }
    
    private let restartManager = ContentRestartManager.shared
    private let orientationManager = DeviceOrientationManager.shared
    private let fileManager = FileManager.default
    
    private var persistentDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private init() {}
    
    // 旋转横屏图片
    private func rotateImage(_ image: UIImage, orientation: UIDeviceOrientation) -> UIImage {
        print("[图片旋转] 开始旋转图片")
        print("原始尺寸：\(image.size.width) x \(image.size.height)")
        print("设备方向：\(orientation.rawValue)")
        
        let rotationAngle: CGFloat
        let isLandscape = image.size.width > image.size.height
        
        // 根据设备方向决定旋转角度
        switch orientation {
        case .landscapeLeft:
            rotationAngle = .pi / 2 // 顺时针90度
        case .landscapeRight:
            rotationAngle = -.pi / 2 // 逆时针90度
        case .portraitUpsideDown:
            rotationAngle = .pi // 180度
        default:
            return image
        }
        
        // 创建绘图上下文
        let size: CGSize
        if orientation == .portraitUpsideDown {
            // 倒置竖屏时保持原始尺寸
            size = image.size
        } else {
            // 横屏时交换宽高
            size = CGSize(width: image.size.height, height: image.size.width)
        }
        
        UIGraphicsBeginImageContextWithOptions(size, false, image.scale)
        let context = UIGraphicsGetCurrentContext()!
        
        // 移动原点到中心并旋转
        context.translateBy(x: size.width / 2, y: size.height / 2)
        context.rotate(by: rotationAngle)
        
        // 绘制图片
        let rect: CGRect
        if orientation == .portraitUpsideDown {
            // 倒置竖屏时使用原始尺寸
            rect = CGRect(x: -image.size.width / 2,
                         y: -image.size.height / 2,
                         width: image.size.width,
                         height: image.size.height)
        } else {
            // 横屏时使用交换后的尺寸
            rect = CGRect(x: -image.size.width / 2,
                         y: -image.size.height / 2,
                         width: image.size.width,
                         height: image.size.height)
        }
        
        image.draw(in: rect)
        
        // 获取旋转后的图片
        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        print("[图片旋转] 旋转完成")
        print("旋转后尺寸：\(rotatedImage?.size.width ?? 0) x \(rotatedImage?.size.height ?? 0)")
        
        return rotatedImage ?? image
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
        // 处理图片旋转（包括横屏和倒置竖屏）
        let processedImage = (orientation.isLandscape || orientation == .portraitUpsideDown) ? 
            rotateImage(image, orientation: orientation) : image
        
        // 清除之前的预览图片缓存
        previewMixImage = nil
        
        self.capturedImage = processedImage
        self.currentScale = scale
        self.currentIndicatorScale = scale
        self.isLivePhoto = false
        self.captureOrientation = orientation
        
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
    }
    
    // 显示 Live Photo 预览
    func showLivePhotoPreview(image: UIImage, videoURL: URL, imageURL: URL, identifier: String, orientation: UIDeviceOrientation = .portrait, cameraManager: CameraManager, scale: CGFloat = 1.0) {
        print("------------------------")
        print("[Live Photo预览] 开始初始化")
        print("设备方向：\(orientation.rawValue)")
        print("缩放比例：\(scale)")
        
        // 处理图片旋转（包括横屏和倒置竖屏）
        let processedImage = (orientation.isLandscape || orientation == .portraitUpsideDown) ? 
            rotateImage(image, orientation: orientation) : image
        
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
            
            self.capturedImage = processedImage
            self.livePhotoVideoURL = persistentVideoURL
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
            saveLivePhotoToPhotoLibrary { success in
                completion?(success)
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
    
    // 保存 Live Photo
    private func saveLivePhotoToPhotoLibrary(completion: @escaping (Bool) -> Void) {
        guard let imageURL = tempImageURL,
              let videoURL = tempVideoURL else {
            print("[Live Photo保存] 错误：缺少必要文件")
            completion(false)
            return
        }
        
        // 验证文件是否存在
        let imageExists = fileManager.fileExists(atPath: imageURL.path)
        let videoExists = fileManager.fileExists(atPath: videoURL.path)
        
        print("[Live Photo保存] 文件验证：")
        print("图片路径：\(imageURL.path)")
        print("视频路径：\(videoURL.path)")
        print("图片文件存在：\(imageExists)")
        print("视频文件存在：\(videoExists)")
        
        guard imageExists && videoExists else {
            print("[Live Photo保存] 错误：文件不存在")
            completion(false)
            return
        }
        
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        print("[Live Photo保存] 权限状态：\(status.rawValue)")
        
        switch status {
        case .authorized, .limited:
            PHPhotoLibrary.shared().performChanges({
                let creationRequest = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                options.shouldMoveFile = false  // 改为复制而不是移动
                
                print("[Live Photo保存] 添加资源到相册")
                print("添加图片：\(imageURL.path)")
                creationRequest.addResource(with: .photo, fileURL: imageURL, options: options)
                
                print("添加视频：\(videoURL.path)")
                creationRequest.addResource(with: .pairedVideo, fileURL: videoURL, options: options)
                
            }) { [weak self] success, error in
                DispatchQueue.main.async {
                    if success {
                        print("[Live Photo保存] 保存成功")
                        
                        // 验证文件是否仍然存在
                        let finalImageExists = self?.fileManager.fileExists(atPath: imageURL.path) ?? false
                        let finalVideoExists = self?.fileManager.fileExists(atPath: videoURL.path) ?? false
                        print("[Live Photo保存] 最终文件验证：")
                        print("图片文件存在：\(finalImageExists)")
                        print("视频文件存在：\(finalVideoExists)")
                        
                        self?.showSaveSuccess = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            self?.showSaveSuccess = false
                        }
                        completion(true)
                    } else {
                        print("[Live Photo保存] 保存失败")
                        if let error = error as NSError? {
                            print("错误域：\(error.domain)")
                            print("错误码：\(error.code)")
                            print("错误描述：\(error.localizedDescription)")
                            print("用户信息：\(error.userInfo)")
                        }
                        completion(false)
                    }
                }
            }
            
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] newStatus in
                if newStatus == .authorized || newStatus == .limited {
                    DispatchQueue.main.async {
                        self?.saveLivePhotoToPhotoLibrary(completion: completion)
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
} 