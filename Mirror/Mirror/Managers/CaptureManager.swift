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
    
    private let restartManager = ContentRestartManager.shared
    private let orientationManager = DeviceOrientationManager.shared
    private let fileManager = FileManager.default
    
    private var persistentDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private init() {}
    
    // 显示预览
    func showPreview(image: UIImage, scale: CGFloat = 1.0, orientation: UIDeviceOrientation = .portrait, cameraManager: CameraManager) {
        self.capturedImage = image
        self.currentScale = scale
        self.isLivePhoto = false
        self.captureOrientation = orientation
        
        // 锁定设备方向，防止旋转
        orientationManager.lockOrientation()
        
        // 先显示预览
        withAnimation {
            self.isPreviewVisible = true
        }

        // 延迟0.5秒后关闭摄像头
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            cameraManager.safelyStopSession()
            self.restartManager.isCameraActive = false
        }
    }
    
    // 显示 Live Photo 预览
    func showLivePhotoPreview(image: UIImage, videoURL: URL, imageURL: URL, identifier: String, orientation: UIDeviceOrientation = .portrait, cameraManager: CameraManager) {
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
            }
            if fileManager.fileExists(atPath: persistentVideoURL.path) {
                try fileManager.removeItem(at: persistentVideoURL)
            }
            
            // 复制文件
            try fileManager.copyItem(at: imageURL, to: persistentImageURL)
            try fileManager.copyItem(at: videoURL, to: persistentVideoURL)
            
            print("[Live Photo预览] 文件持久化成功")
            
            self.capturedImage = image
            self.livePhotoVideoURL = persistentVideoURL
            self.tempImageURL = persistentImageURL
            self.tempVideoURL = persistentVideoURL
            self.livePhotoIdentifier = identifier
            self.isLivePhoto = true
            self.captureOrientation = orientation
            
            // 锁定设备方向，防止旋转
            orientationManager.lockOrientation()
            
            // 显示预览
            withAnimation {
                self.isPreviewVisible = true
            }
            
            // 延迟关闭摄像头
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                cameraManager.safelyStopSession()
                self.restartManager.isCameraActive = false
            }
            
        } catch {
            print("[Live Photo预览] 文件持久化失败：\(error.localizedDescription)")
        }
    }
    
    // 隐藏预览
    func hidePreview(cameraManager: CameraManager) {
        withAnimation {
            self.isPreviewVisible = false
            self.isPlayingLivePhoto = false
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
    
    // 保存图片到相册
    func saveToPhotos(completion: ((Bool) -> Void)? = nil) {
        if isLivePhoto {
            saveLivePhotoToPhotoLibrary { success in
                completion?(success)
            }
        } else if let image = capturedImage {
            saveImageToPhotoLibrary(image) { success in
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
} 