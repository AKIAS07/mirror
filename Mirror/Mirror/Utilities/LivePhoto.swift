import UIKit
import AVFoundation
import UniformTypeIdentifiers
import Photos

// 添加错误枚举
enum LivePhotoError: Error {
    case exportSessionCreationFailed
    case exportFailed
    case outputFileNotFound
    case exportCancelled
}

class LivePhoto {
    // MARK: PUBLIC
    typealias LivePhotoResources = (pairedImage: URL, pairedVideo: URL)
    
    /// Generates a PHLivePhoto from an image and video. Also returns the paired image and video.
    public class func generate(from imageURL: URL?, videoURL: URL, progress: @escaping (CGFloat) -> Void, completion: @escaping (PHLivePhoto?, LivePhotoResources?) -> Void) {
        queue.async {
            shared.generate(from: imageURL, videoURL: videoURL, progress: progress, completion: completion)
        }
    }
    
    /// Save a Live Photo to the Photo Library by passing the paired image and video.
    public class func saveToLibrary(_ resources: LivePhotoResources, completion: @escaping (Bool) -> Void) {
        // 确保在主队列执行
        DispatchQueue.main.async {
            PHPhotoLibrary.shared().performChanges({
                let creationRequest = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                options.shouldMoveFile = false
                
                print("[LivePhoto] 开始保存资源到相册")
                print("- 图片路径：\(resources.pairedImage.path)")
                print("- 视频路径：\(resources.pairedVideo.path)")
                
                // 验证文件存在性
                let fileManager = FileManager.default
                let imageExists = fileManager.fileExists(atPath: resources.pairedImage.path)
                let videoExists = fileManager.fileExists(atPath: resources.pairedVideo.path)
                
                print("[LivePhoto] 文件验证：")
                print("- 图片文件存在：\(imageExists)")
                print("- 视频文件存在：\(videoExists)")
                
                guard imageExists && videoExists else {
                    print("[LivePhoto] 错误：文件不完整")
                    completion(false)
                    return
                }
                
                // 获取图片尺寸
                if let imageSource = CGImageSourceCreateWithURL(resources.pairedImage as CFURL, nil),
                   let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any],
                   let width = properties[kCGImagePropertyPixelWidth as String] as? Int,
                   let height = properties[kCGImagePropertyPixelHeight as String] as? Int {
                    print("[LivePhoto] 图片尺寸：\(width) x \(height)")
                }
                
                // 获取视频尺寸
                let asset = AVAsset(url: resources.pairedVideo)
                let tracks = asset.tracks(withMediaType: .video)
                if let videoTrack = tracks.first {
                    let size = videoTrack.naturalSize
                    print("[LivePhoto] 视频尺寸：\(size.width) x \(size.height)")
                }
                
                creationRequest.addResource(with: .photo, fileURL: resources.pairedImage, options: options)
                creationRequest.addResource(with: .pairedVideo, fileURL: resources.pairedVideo, options: options)
                
            }) { success, error in
                if let error = error {
                    print("[LivePhoto] 保存失败：\(error.localizedDescription)")
                    if let nsError = error as NSError? {
                        print("- 错误域：\(nsError.domain)")
                        print("- 错误码：\(nsError.code)")
                        print("- 详细信息：\(nsError.userInfo)")
                    }
                } else {
                    print("[LivePhoto] 保存成功")
                }
                completion(success)
            }
        }
    }
    
    // MARK: PRIVATE
    private static let shared = LivePhoto()
    private static let queue = DispatchQueue(label: "com.mirror.LivePhotoQueue", qos: .userInitiated)
    
    private func generate(from imageURL: URL?, videoURL: URL, progress: @escaping (CGFloat) -> Void, completion: @escaping (PHLivePhoto?, LivePhotoResources?) -> Void) {
        print("[LivePhoto] 开始生成Live Photo")
        print("- 图片路径：\(imageURL?.path ?? "nil")")
        print("- 视频路径：\(videoURL.path)")
        
        let assetIdentifier = UUID().uuidString
        print("[LivePhoto] 生成资源标识符：\(assetIdentifier)")
        
        guard let imageURL = imageURL else {
            print("[LivePhoto] 错误：没有图片URL")
            DispatchQueue.main.async {
                completion(nil, nil)
            }
            return
        }
        
        // 检查源文件是否存在
        if !FileManager.default.fileExists(atPath: imageURL.path) {
            print("[LivePhoto] 错误：图片文件不存在")
            DispatchQueue.main.async {
                completion(nil, nil)
            }
            return
        }
        
        if !FileManager.default.fileExists(atPath: videoURL.path) {
            print("[LivePhoto] 错误：视频文件不存在")
            DispatchQueue.main.async {
                completion(nil, nil)
            }
            return
        }
        
        // 获取视频时长
        let asset = AVURLAsset(url: videoURL)
        let duration = asset.duration
        let durationInSeconds = CMTimeGetSeconds(duration)
        print("[LivePhoto] 原始视频时长：\(durationInSeconds)秒")
        
        // 获取视频尺寸
        let tracks = asset.tracks(withMediaType: .video)
        if let videoTrack = tracks.first {
            let size = videoTrack.naturalSize
            print("[LivePhoto] 原始视频尺寸：\(size.width) x \(size.height)")
        }
        
        // 获取图片尺寸
        if let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
           let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any],
           let width = properties[kCGImagePropertyPixelWidth as String] as? Int,
           let height = properties[kCGImagePropertyPixelHeight as String] as? Int {
            print("[LivePhoto] 原始图片尺寸：\(width) x \(height)")
        }
        
        // 计算图片显示时间（视频时长的一半）
        let photoTime = durationInSeconds / 2.0
        print("[LivePhoto] 设置图片显示时间：\(photoTime)秒")
        
        // 添加资源ID到图片
        print("[LivePhoto] 开始处理图片...")
        guard let processedImageURL = addAssetID(assetIdentifier, toImage: imageURL, photoTime: photoTime) else {
            print("[LivePhoto] 错误：处理图片失败")
            DispatchQueue.main.async {
                completion(nil, nil)
            }
            return
        }
        print("[LivePhoto] 图片处理完成：\(processedImageURL.path)")
        
        // 验证处理后的图片
        if let attributes = try? FileManager.default.attributesOfItem(atPath: processedImageURL.path) {
            let fileSize = attributes[.size] as? Int64 ?? 0
            print("[LivePhoto] 处理后图片大小：\(Double(fileSize) / 1024.0 / 1024.0) MB")
        }
        
        // 添加资源ID到视频
        print("[LivePhoto] 开始处理视频...")
        processVideo(assetIdentifier: assetIdentifier, videoURL: videoURL, progress: progress) { processedVideoURL in
            if let videoURL = processedVideoURL {
                print("[LivePhoto] 视频处理完成")
                print("- 处理后视频路径：\(videoURL.path)")
                
                // 验证处理后的视频
                if let attributes = try? FileManager.default.attributesOfItem(atPath: videoURL.path) {
                    let fileSize = attributes[.size] as? Int64 ?? 0
                    print("[LivePhoto] 处理后视频大小：\(Double(fileSize) / 1024.0 / 1024.0) MB")
                }
                
                print("[LivePhoto] 开始生成最终的Live Photo")
                
                // 在主队列中请求Live Photo
                DispatchQueue.main.async {
                    PHLivePhoto.request(withResourceFileURLs: [processedImageURL, videoURL],
                                      placeholderImage: nil,
                                      targetSize: PHImageManagerMaximumSize,
                                      contentMode: .aspectFit) { livePhoto, info in
                        print("[LivePhoto] Live Photo请求回调")
                        print("- 信息：\(String(describing: info))")
                        
                        if let isDegraded = info[PHLivePhotoInfoIsDegradedKey] as? Bool, isDegraded {
                            print("- 是否降级：\(isDegraded)")
                            return
                        }
                        
                        if let error = info[PHLivePhotoInfoErrorKey] as? Error {
                            print("[LivePhoto] 生成错误：\(error.localizedDescription)")
                            completion(nil, nil)
                            return
                        }
                        
                        if let isCancelled = info[PHLivePhotoInfoCancelledKey] as? Bool, isCancelled {
                            print("[LivePhoto] 生成被取消")
                            completion(nil, nil)
                            return
                        }
                        
                        print("[LivePhoto] Live Photo生成成功")
                        completion(livePhoto, (processedImageURL, videoURL))
                    }
                }
            } else {
                print("[LivePhoto] 错误：处理视频失败")
                DispatchQueue.main.async {
                    completion(nil, nil)
                }
            }
        }
    }
    
    private func addAssetID(_ assetIdentifier: String, toImage imageURL: URL, photoTime: Double) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let destinationURL = tempDir.appendingPathComponent("\(UUID().uuidString).heic")
        
        guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil) else {
            print("[LivePhoto] 错误：无法创建图片源")
            return nil
        }
        
        // 获取原始图片属性
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            print("[LivePhoto] 错误：无法获取图片属性")
            return nil
        }
        
        // 获取原始尺寸
        guard let width = properties[kCGImagePropertyPixelWidth as String] as? Int,
              let height = properties[kCGImagePropertyPixelHeight as String] as? Int else {
            print("[LivePhoto] 错误：无法获取图片尺寸")
            return nil
        }
        
        print("[LivePhoto] 处理图片尺寸：\(width) x \(height)")
        
        // 创建完整的属性字典
        var makerNote: [String: Any] = [:]
        makerNote["17"] = assetIdentifier
        makerNote["AssetIdentifier"] = assetIdentifier
        makerNote["PhotoTime"] = photoTime
        
        var newProperties = properties
        newProperties[kCGImagePropertyMakerAppleDictionary as String] = makerNote
        newProperties[kCGImagePropertyExifDictionary as String] = [
            kCGImagePropertyExifImageUniqueID as String: assetIdentifier
        ]
        
        // 添加其他必要的元数据
        let tiffDict: [String: Any] = [
            kCGImagePropertyTIFFMake as String: "Apple",
            kCGImagePropertyTIFFModel as String: "iPhone",
            kCGImagePropertyTIFFSoftware as String: "Mirror"
        ]
        newProperties[kCGImagePropertyTIFFDictionary as String] = tiffDict
        
        // 创建目标
        guard let destination = CGImageDestinationCreateWithURL(destinationURL as CFURL,
                                                              UTType.heic.identifier as CFString,
                                                              1, nil) else {
            print("[LivePhoto] 错误：无法创建目标")
            return nil
        }
        
        // 设置目标属性
        let destinationProperties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 1.0,
            kCGImageDestinationOptimizeColorForSharing: true,
            kCGImagePropertyOrientation: properties[kCGImagePropertyOrientation as String] ?? 1,
            kCGImagePropertyIPTCDictionary: [
                "DateCreated": ISO8601DateFormatter().string(from: Date())
            ]
        ]
        
        CGImageDestinationSetProperties(destination, destinationProperties as CFDictionary)
        
        // 直接从源复制图片，保持所有原始属性
        CGImageDestinationAddImageFromSource(destination, imageSource, 0, newProperties as CFDictionary)
        
        if CGImageDestinationFinalize(destination) {
            // 验证输出文件
            if let verifySource = CGImageSourceCreateWithURL(destinationURL as CFURL, nil),
               let verifyProperties = CGImageSourceCopyPropertiesAtIndex(verifySource, 0, nil) as? [String: Any],
               let verifyWidth = verifyProperties[kCGImagePropertyPixelWidth as String] as? Int,
               let verifyHeight = verifyProperties[kCGImagePropertyPixelHeight as String] as? Int {
                print("[LivePhoto] 输出图片尺寸验证：\(verifyWidth) x \(verifyHeight)")
                
                // 验证尺寸是否保持不变
                if verifyWidth == width && verifyHeight == height {
                    print("[LivePhoto] 图片尺寸保持不变")
                    
                    // 验证元数据
                    if let makerApple = verifyProperties[kCGImagePropertyMakerAppleDictionary as String] as? [String: Any] {
                        print("[LivePhoto] 验证元数据：")
                        print("- AssetIdentifier: \(makerApple["AssetIdentifier"] ?? "missing")")
                        print("- PhotoTime: \(makerApple["PhotoTime"] ?? "missing")")
                    }
                    
                    return destinationURL
                } else {
                    print("[LivePhoto] 错误：图片尺寸发生变化")
                    print("原始尺寸：\(width) x \(height)")
                    print("处理后尺寸：\(verifyWidth) x \(verifyHeight)")
                    try? FileManager.default.removeItem(at: destinationURL)
                    return nil
                }
            }
        }
        
        print("[LivePhoto] 错误：无法完成图片处理")
        return nil
    }
    
    private func processVideo(assetIdentifier: String, videoURL: URL, progress: @escaping (CGFloat) -> Void, completion: @escaping (URL?) -> Void) {
        let tempDir = FileManager.default.temporaryDirectory
        let destinationURL = tempDir.appendingPathComponent("\(UUID().uuidString).mov")
        
        print("[LivePhoto] 开始处理视频：\(videoURL.path)")
        print("[LivePhoto] 目标视频路径：\(destinationURL.path)")
        
        let asset = AVURLAsset(url: videoURL)
        
        // 获取视频轨道
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            print("[LivePhoto] 错误：无法获取视频轨道")
            completion(nil)
            return
        }
        
        let naturalSize = videoTrack.naturalSize
        print("[LivePhoto] 处理前视频尺寸：\(naturalSize.width) x \(naturalSize.height)")
        
        // 创建导出会话
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
            print("[LivePhoto] 错误：无法创建导出会话")
            completion(nil)
            return
        }
        
        // 设置元数据
        let keyContentIdentifier = "com.apple.quicktime.content.identifier"
        let keySpaceQuickTimeMetadata = "mdta"
        
        let idItem = AVMutableMetadataItem()
        idItem.key = keyContentIdentifier as NSString
        idItem.keySpace = AVMetadataKeySpace(rawValue: keySpaceQuickTimeMetadata)
        idItem.value = assetIdentifier as NSString
        idItem.dataType = "com.apple.metadata.datatype.UTF-8"
        
        exportSession.metadata = [idItem]
        exportSession.outputURL = destinationURL
        exportSession.outputFileType = .mov
        
        // 设置视频合成
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = naturalSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: asset.duration)
        
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        
        // 设置变换以保持原始尺寸
        let transform = CGAffineTransform.identity
        layerInstruction.setTransform(transform, at: .zero)
        
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]
        
        exportSession.videoComposition = videoComposition
        
        print("[LivePhoto] 导出会话配置完成")
        print("- 输出路径：\(destinationURL.path)")
        print("- 输出格式：\(exportSession.outputFileType?.rawValue ?? "unknown")")
        print("- 导出质量：\(exportSession.presetName)")
        
        // 开始导出
        print("[LivePhoto] 开始导出视频...")
        
        // 使用Task来处理异步操作
        Task {
            await withCheckedContinuation { continuation in
                exportSession.exportAsynchronously {
                    let status = exportSession.status
                    DispatchQueue.main.async {
                        switch status {
                        case .completed:
                            print("[LivePhoto] 视频导出成功")
                            
                            // 验证输出视频尺寸
                            let outputAsset = AVURLAsset(url: destinationURL)
                            if let outputTrack = outputAsset.tracks(withMediaType: .video).first {
                                let outputSize = outputTrack.naturalSize
                                print("[LivePhoto] 验证输出视频尺寸：\(outputSize.width) x \(outputSize.height)")
                            }
                            
                            completion(destinationURL)
                        case .failed:
                            //print("[LivePhoto] 导出失败：\(exportSession.error?.localizedDescription ?? "未知错误")")
                            completion(nil)
                        case .cancelled:
                            print("[LivePhoto] 导出被取消")
                            completion(nil)
                        default:
                            print("[LivePhoto] 导出状态异常：\(status.rawValue)")
                            completion(nil)
                        }
                        continuation.resume()
                    }
                }
            }
        }
    }
    
    private static func addAssetID(to videoURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        let asset = AVAsset(url: videoURL)
        
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetPassthrough
        ) else {
            completion(.failure(LivePhotoError.exportSessionCreationFailed))
            return
        }
        
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
        
        let idItem = AVMutableMetadataItem()
        idItem.key = "com.apple.quicktime.content.identifier" as NSString
        idItem.keySpace = AVMetadataKeySpace(rawValue: "mdta")
        idItem.value = "com.apple.quicktime.content.identifier" as NSString
        idItem.dataType = "com.apple.metadata.datatype.UTF-8"
        
        exportSession.metadata = [idItem]
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov
        
        Task {
            await withCheckedContinuation { continuation in
                exportSession.exportAsynchronously {
                    let status = exportSession.status
                    DispatchQueue.main.async {
                        switch status {
                        case .completed:
                            if FileManager.default.fileExists(atPath: outputURL.path) {
                                completion(.success(outputURL))
                            } else {
                                completion(.failure(LivePhotoError.outputFileNotFound))
                            }
                        case .failed:
                            completion(.failure(exportSession.error ?? LivePhotoError.exportFailed))
                        case .cancelled:
                            completion(.failure(LivePhotoError.exportCancelled))
                        default:
                            completion(.failure(LivePhotoError.exportFailed))
                        }
                        continuation.resume()
                    }
                }
            }
        }
    }
} 
