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
    @Published var hasApplied180Rotation = false
    
    private let restartManager = ContentRestartManager.shared
    
    private init() {}
    
    // 显示预览
    func showPreview(image: UIImage, scale: CGFloat = 1.0, cameraManager: CameraManager) {
        self.capturedImage = image
        self.currentScale = scale
        self.isLivePhoto = false
        
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
    func showLivePhotoPreview(image: UIImage, videoURL: URL, imageURL: URL, identifier: String, cameraManager: CameraManager) {
        self.capturedImage = image
        self.livePhotoVideoURL = videoURL
        self.tempImageURL = imageURL
        self.tempVideoURL = videoURL
        self.livePhotoIdentifier = identifier
        self.isLivePhoto = true
        
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
    
    // 隐藏预览
    func hidePreview(cameraManager: CameraManager) {
        withAnimation {
            self.isPreviewVisible = false
            self.isPlayingLivePhoto = false
            self.hasApplied180Rotation = false
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
        
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        switch status {
        case .authorized, .limited:
            PHPhotoLibrary.shared().performChanges({
                let creationRequest = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                options.shouldMoveFile = true
                
                creationRequest.addResource(with: .photo, fileURL: imageURL, options: options)
                creationRequest.addResource(with: .pairedVideo, fileURL: videoURL, options: options)
                
            }) { [weak self] success, error in
                DispatchQueue.main.async {
                    if success {
                        print("[Live Photo保存] 保存成功")
                        self?.showSaveSuccess = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            self?.showSaveSuccess = false
                        }
                        completion(true)
                    } else {
                        print("[Live Photo保存] 保存失败：\(error?.localizedDescription ?? "未知错误")")
                        completion(false)
                    }
                    
                    // 清理临时文件
                    try? FileManager.default.removeItem(at: imageURL)
                    try? FileManager.default.removeItem(at: videoURL)
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
} 