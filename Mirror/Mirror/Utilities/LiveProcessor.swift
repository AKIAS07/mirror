import UIKit
import AVFoundation

class LiveProcessor {
    static let shared = LiveProcessor()
    
    // 添加水印缓存
    private var watermarkCache: [String: UIImage] = [:]
    private let cacheQueue = DispatchQueue(label: "com.mirror.liveWatermarkCache")
    
    private init() {
        // 预加载水印图片
        preloadWatermarks()
    }
    
    // 预加载水印图片
    private func preloadWatermarks() {
        if let watermarkA = UIImage(named: "mixlogoA") {
            cacheQueue.sync {
                watermarkCache["A_0"] = watermarkA
                watermarkCache["A_180"] = watermarkA.rotated(by: 180)
            }
        }
        
        if let watermarkB = UIImage(named: "mixlogoB") {
            cacheQueue.sync {
                watermarkCache["B_0"] = watermarkB
                watermarkCache["B_90"] = watermarkB.rotated(by: 90)
                watermarkCache["B_-90"] = watermarkB.rotated(by: -90)
            }
        }
    }
    
    // 获取缓存的水印图片
    private func getCachedWatermark(for orientation: UIDeviceOrientation) -> UIImage? {
        return cacheQueue.sync {
            switch orientation {
            case .portrait:
                return watermarkCache["A_0"]
            case .portraitUpsideDown:
                return watermarkCache["A_180"]
            case .landscapeLeft:
                return watermarkCache["B_90"]
            case .landscapeRight:
                return watermarkCache["B_-90"]
            default:
                return watermarkCache["A_0"]
            }
        }
    }
    
    // 处理图像变换的方法
    private func processImageTransformation(
        image: UIImage?,
        isMirrored: Bool,
        isFront: Bool,
        isBack: Bool,
        orientation: UIDeviceOrientation
    ) -> UIImage? {
        guard let image = image else { return nil }
        
        print("[图像变换] 开始处理")
        print("镜像状态：\(isMirrored)")
        print("前置摄像头：\(isFront)")
        print("后置摄像头：\(isBack)")
        print("设备方向：\(orientation.rawValue)")
        
        var resultImage = image
        
        if !isMirrored {
            // 情况一：非镜像模式
            if isBack && !isFront {
                // 1. 后置摄像头，任何方向都进行方法B（逆时针90度）
                print("[图像变换] 后置非镜像：应用方法B（逆时针90度）")
                if let rotated = rotateCounterClockwise90(resultImage) {
                    resultImage = rotated
                }
            } else if !isBack && isFront {
                if orientation == .portrait || orientation == .portraitUpsideDown {
                    // 2. 前置摄像头，竖屏或倒置竖屏时进行方法B
                    print("[图像变换] 前置非镜像竖屏：应用方法B（逆时针90度）")
                    if let rotated = rotateCounterClockwise90(resultImage) {
                        resultImage = rotated
                    }
                } else if orientation == .landscapeLeft || orientation == .landscapeRight {
                    // 3. 前置摄像头，横屏时进行方法A
                    print("[图像变换] 前置非镜像横屏：应用方法A（顺时针90度）")
                    if let rotated = rotateClockwise90(resultImage) {
                        resultImage = rotated
                    }
                }
            }
        } else {
            // 情况二：镜像模式
            if isBack && !isFront {
                if orientation == .portrait || orientation == .portraitUpsideDown {
                    // 1. 后置摄像头，竖屏或倒置竖屏时先B后D
                    print("[图像变换] 后置镜像竖屏：应用方法B（逆时针90度）后方法D（垂直翻转）")
                    if let rotated = rotateCounterClockwise90(resultImage),
                       let flipped = flipVertical180(rotated) {
                        resultImage = flipped
                    }
                } else if orientation == .landscapeLeft || orientation == .landscapeRight {
                    // 2. 后置摄像头，横屏时先B后C
                    print("[图像变换] 后置镜像横屏：应用方法B（逆时针90度）后方法C（水平翻转）")
                    if let rotated = rotateCounterClockwise90(resultImage),
                       let flipped = flipHorizontal180(rotated) {
                        resultImage = flipped
                    }
                }
            } else if !isBack && isFront {
                if orientation == .portrait || orientation == .portraitUpsideDown {
                    // 3. 前置摄像头，竖屏或倒置竖屏时先B后D
                    print("[图像变换] 前置镜像竖屏：应用方法B（逆时针90度）后方法D（垂直翻转）")
                    if let rotated = rotateCounterClockwise90(resultImage),
                       let flipped = flipVertical180(rotated) {
                        resultImage = flipped
                    }
                } else if orientation == .landscapeLeft || orientation == .landscapeRight {
                    // 4. 前置摄像头，横屏时先A后C
                    print("[图像变换] 前置镜像横屏：应用方法A（顺时针90度）后方法C（水平翻转）")
                    if let rotated = rotateClockwise90(resultImage),
                       let flipped = flipHorizontal180(rotated) {
                        resultImage = flipped
                    }
                }
            }
        }
        
        print("[图像变换] 处理完成")
        return resultImage
    }
    
    // 处理 Live Photo 的图片部分
    func processLivePhotoImage(baseImage: UIImage, drawingImage: UIImage?, makeupImage: UIImage?, scale: CGFloat = 1.0, orientation: UIDeviceOrientation = .portrait) -> UIImage {
        print("[图片处理] 开始处理 Live Photo 图片")
        print("基础图片尺寸：\(baseImage.size)")
        print("缩放比例：\(scale)")
        print("设备方向：\(orientation)")
        
        // 检查水印开关状态
        let isWatermarkEnabled = UserSettingsManager.shared.loadWatermarkEnabled()
        
        // 使用原始图片尺寸
        let size = baseImage.size
        
        // 使用autoreleasepool来管理临时对象的内存
        return autoreleasepool { () -> UIImage in
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1.0 // 使用1.0的scale以避免尺寸过大
            format.opaque = true // 设置为不透明
            format.preferredRange = .standard // 使用标准色彩范围
            
            let renderer = UIGraphicsImageRenderer(size: size, format: format)
            let mixImage = renderer.image { ctx in
                // 先绘制白色背景确保图片不透明
                UIColor.white.setFill()
                ctx.fill(CGRect(origin: .zero, size: size))
                
                // 绘制基础图片
                baseImage.draw(in: CGRect(origin: .zero, size: size))
                
                // 如果有绘画图片，绘制绘画图片
                if let drawingImage = drawingImage {
                    print("[图片处理] 绘制绘画图层")
                    // 计算绘画图片的绘制区域，保持原始比例并考虑缩放
                    let drawingSize = drawingImage.size
                    let aspectRatio = drawingSize.width / drawingSize.height
                    
                    // 根据缩放比例调整绘画图片的尺寸
                    let scaledWidth = size.width / scale
                    let scaledHeight = size.height / scale
                    
                    var drawingRect: CGRect
                    if aspectRatio > scaledWidth / scaledHeight {
                        // 绘画图片更宽，以宽度为基准
                        let height = scaledWidth / aspectRatio
                        drawingRect = CGRect(
                            x: (size.width - scaledWidth) / 2,
                            y: (size.height - height) / 2,
                            width: scaledWidth,
                            height: height
                        )
                    } else {
                        // 绘画图片更高，以高度为基准
                        let width = scaledHeight * aspectRatio
                        drawingRect = CGRect(
                            x: (size.width - width) / 2,
                            y: (size.height - scaledHeight) / 2,
                            width: width,
                            height: scaledHeight
                        )
                    }
                    
                    print("[图片处理] 绘画图层绘制区域：\(drawingRect)")
                    // 绘制绘画图片
                    drawingImage.draw(in: drawingRect)
                }
                
                // 如果有化妆图片，绘制化妆图片
                if let makeupImage = makeupImage {
                    print("[图片处理] 绘制化妆图层")
                    // 计算化妆图片的绘制区域，考虑缩放比例
                    let makeupSize = makeupImage.size
                    let makeupAspect = makeupSize.width / makeupSize.height
                    
                    var makeupRect: CGRect
                    if scale == 1.0 {
                        // 全屏模式（100%）- 保持原始宽高比
                        let makeupDrawHeight = size.height
                        let makeupDrawWidth = makeupDrawHeight * makeupAspect
                        
                        // 居中绘制
                        let x = (size.width - makeupDrawWidth) / 2
                        let y = 0.0
                        
                        makeupRect = CGRect(x: x, y: y, width: makeupDrawWidth, height: makeupDrawHeight)
                    } else {
                        // 其他模式（60%和100%以上）- 根据缩放比例调整大小
                        let scaledBaseHeight = size.height / scale
                        
                        // 计算化妆图片的绘制尺寸，保持与基础图片相同的缩放比例
                        let makeupDrawWidth = makeupSize.width * (scaledBaseHeight / makeupSize.height)
                        let makeupDrawHeight = scaledBaseHeight
                        
                        // 居中绘制
                        let x = (size.width - makeupDrawWidth) / 2
                        let y = (size.height - makeupDrawHeight) / 2
                        
                        makeupRect = CGRect(x: x, y: y, width: makeupDrawWidth, height: makeupDrawHeight)
                    }
                    
                    print("[图片处理] 化妆图层绘制区域：\(makeupRect)")
                    // 绘制化妆图片
                    makeupImage.draw(in: makeupRect)
                }
                
                // 添加水印（使用缓存的水印）
                if isWatermarkEnabled {
                    if let watermark = getCachedWatermark(for: orientation) {
                        watermark.draw(in: CGRect(origin: .zero, size: size))
                    }
                }
            }
            
            print("[图片处理] 图片处理完成")
            print("最终图片尺寸：\(mixImage.size)")
            return mixImage
        }
    }
    
    // 处理 Live Photo 的视频部分
    func processLivePhotoVideo(
        videoURL: URL,
        drawingImage: UIImage?,
        makeupImage: UIImage?,
        scale: CGFloat = 1.0,
        orientation: UIDeviceOrientation = .portrait,
        isMirrored: Bool = false,
        isFront: Bool = true,
        isBack: Bool = false,
        progressHandler: ((Double) -> Void)? = nil
    ) async -> URL? {
        print("[视频处理] 开始处理视频")
        print("输入视频URL：\(videoURL.path)")
        print("设备方向：\(orientation.rawValue)")
        print("镜像状态：\(isMirrored)")
        print("前置摄像头：\(isFront)")
        print("后置摄像头：\(isBack)")
        
        // 检查水印开关状态
        let isWatermarkEnabled = UserSettingsManager.shared.loadWatermarkEnabled()
        
        // 处理绘画图层和化妆图层的变换
        let transformedDrawingImage = processImageTransformation(
            image: drawingImage,
            isMirrored: isMirrored,
            isFront: isFront,
            isBack: isBack,
            orientation: orientation
        )
        
        let transformedMakeupImage = processImageTransformation(
            image: makeupImage,
            isMirrored: isMirrored,
            isFront: isFront,
            isBack: isBack,
            orientation: orientation
        )
        
        // 处理水印图片的变换
        let transformedWatermark = isWatermarkEnabled ? processImageTransformation(
            image: getCachedWatermark(for: orientation),
            isMirrored: isMirrored,
            isFront: isFront,
            isBack: isBack,
            orientation: orientation
        ) : nil
        
        let asset = AVAsset(url: videoURL)
        
        // 创建输出URL
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mov")
        print("输出视频URL：\(outputURL.path)")
        
        // 获取视频尺寸和变换信息
        guard let track = try? await asset.loadTracks(withMediaType: .video).first else {
            print("[视频处理] 无法获取视频轨道")
            return nil
        }
        
        let size: CGSize
        let preferredTransform: CGAffineTransform
        do {
            size = try await track.load(.naturalSize)
            preferredTransform = try await track.load(.preferredTransform)
            print("[视频处理] 原始视频信息：")
            print("- 尺寸：\(size)")
            print("- 变换矩阵：\(preferredTransform)")
        } catch {
            print("[视频处理] 无法获取视频信息：\(error.localizedDescription)")
            return nil
        }
        
        // 设置写入器
        guard let writer = try? AVAssetWriter(outputURL: outputURL, fileType: .mov) else {
            print("[视频处理] 创建视频写入器失败")
            return nil
        }
        
        // 设置视频输出参数，保持原始变换信息
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: size.width,
            AVVideoHeightKey: size.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 2_000_000,
                AVVideoMaxKeyFrameIntervalKey: 30,
                AVVideoExpectedSourceFrameRateKey: 30,
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
            ]
        ]
        
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        writerInput.expectsMediaDataInRealTime = false
        writerInput.transform = preferredTransform
        
        // 设置像素缓冲适配器
        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: size.width,
            kCVPixelBufferHeightKey as String: size.height,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: attributes
        )
        
        writer.add(writerInput)
        
        // 创建读取器
        guard let reader = try? AVAssetReader(asset: asset) else {
            print("[视频处理] 创建视频读取器失败")
            return nil
        }
        
        let readerOutput = AVAssetReaderTrackOutput(
            track: track,
            outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB]
        )
        
        reader.add(readerOutput)
        
        // 开始写入
        writer.startWriting()
        reader.startReading()
        writer.startSession(atSourceTime: .zero)
        
        // 获取总帧数（用于进度计算）
        let duration = try? await track.load(.timeRange).duration
        let totalFrames = Double(CMTimeGetSeconds(duration ?? .zero) * Float64(track.nominalFrameRate))
        
        // 使用 actor 来管理帧计数
        actor FrameCounter {
            private var count: Double = 0
            
            func increment() {
                count += 1
            }
            
            func getProgress(total: Double) -> Double {
                return count / total
            }
        }
        
        let frameCounter = FrameCounter()
        
        return await withCheckedContinuation { continuation in
            // 创建串行队列处理视频帧
            let processingQueue = DispatchQueue(label: "com.mirror.videoProcessing")
            
            processingQueue.async {
                while reader.status == .reading && writer.status == .writing {
                    autoreleasepool {
                        // 读取视频帧
                        guard let sampleBuffer = readerOutput.copyNextSampleBuffer(),
                              let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                            if reader.status == .reading {
                                reader.cancelReading()
                            }
                            
                            // 完成写入
                            writerInput.markAsFinished()
                            writer.finishWriting {
                                print("[视频处理] 视频处理完成")
                                print("输出视频大小：\((try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? UInt64) ?? 0) bytes")
                                
                                // 检查处理结果
                                if writer.status == .completed {
                                    print("[视频处理] 视频写入成功")
                                    continuation.resume(returning: outputURL)
                                } else {
                                    print("[视频处理] 视频写入失败：\(writer.error?.localizedDescription ?? "未知错误")")
                                    try? FileManager.default.removeItem(at: outputURL)
                                    continuation.resume(returning: nil)
                                }
                            }
                            return
                        }
                        
                        // 转换为 UIImage
                        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
                        let context = CIContext()
                        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
                            return
                        }
                        
                        let frameImage = UIImage(cgImage: cgImage)
                        
                        // 处理帧图像 - 根据水印开关状态决定是否添加水印
                        let processedImage = ImageProcessor.shared.createMixImage(
                            baseImage: frameImage,
                            drawingImage: transformedDrawingImage,
                            makeupImage: transformedMakeupImage,
                            scale: scale,
                            isForVideo: true,
                            orientation: orientation,
                            watermark: isWatermarkEnabled ? transformedWatermark : nil
                        )
                        
                        // 创建新的像素缓冲区
                        var newPixelBuffer: CVPixelBuffer?
                        CVPixelBufferCreate(
                            kCFAllocatorDefault,
                            Int(size.width),
                            Int(size.height),
                            kCVPixelFormatType_32ARGB,
                            attributes as CFDictionary,
                            &newPixelBuffer
                        )
                        
                        if let pixelBuffer = newPixelBuffer {
                            // 将处理后的图像写入像素缓冲区
                            CVPixelBufferLockBaseAddress(pixelBuffer, [])
                            let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer)
                            let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
                            
                            let context = CGContext(
                                data: pixelData,
                                width: Int(size.width),
                                height: Int(size.height),
                                bitsPerComponent: 8,
                                bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                                space: rgbColorSpace,
                                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                            )
                            
                            if let cgImage = processedImage.cgImage {
                                context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
                            }
                            
                            CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
                            
                            // 获取原始帧的时间戳
                            let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                            
                            // 等待写入器准备就绪
                            while !writerInput.isReadyForMoreMediaData {
                                Thread.sleep(forTimeInterval: 0.01)
                            }
                            
                            // 写入处理后的帧
                            adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                            
                            // 更新进度
                            Task {
                                await frameCounter.increment()
                                if let handler = progressHandler {
                                    let progress = await frameCounter.getProgress(total: totalFrames)
                                    DispatchQueue.main.async {
                                        handler(progress)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func angleForOrientation(_ orientation: UIDeviceOrientation) -> CGFloat {
        switch orientation {
        case .portrait:
            return 0
        case .landscapeLeft:
            return 90
        case .landscapeRight:
            return -90
        case .portraitUpsideDown:
            return 180
        default:
            return 0
        }
    }
    
    // 顺时针旋转90度
    func rotateClockwise90(_ image: UIImage?) -> UIImage? {
        guard let image = image else { return nil }
        return image.rotated(by: 90)
    }
    
    // 逆时针旋转90度
    func rotateCounterClockwise90(_ image: UIImage?) -> UIImage? {
        guard let image = image else { return nil }
        return image.rotated(by: -90)
    }
    
    // 水平翻转
    func flipHorizontal180(_ image: UIImage?) -> UIImage? {
        guard let image = image else { return nil }
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        // 水平翻转变换
        context.translateBy(x: image.size.width, y: 0)
        context.scaleBy(x: -1, y: 1)
        
        // 绘制图像
        image.draw(in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    // 垂直翻转
    func flipVertical180(_ image: UIImage?) -> UIImage? {
        guard let image = image else { return nil }
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        // 垂直翻转变换
        context.translateBy(x: 0, y: image.size.height)
        context.scaleBy(x: 1, y: -1)
        
        // 绘制图像
        image.draw(in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

// 添加 UIImage 扩展
extension UIImage {
    func rotated(by degrees: CGFloat) -> UIImage? {
        let radians = degrees * .pi / 180
        let rotatedSize = CGRect(origin: .zero, size: size)
            .applying(CGAffineTransform(rotationAngle: CGFloat(radians)))
            .integral.size
        
        UIGraphicsBeginImageContext(rotatedSize)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        context.translateBy(x: rotatedSize.width/2, y: rotatedSize.height/2)
        context.rotate(by: radians)
        draw(in: CGRect(x: -size.width/2, y: -size.height/2, width: size.width, height: size.height))
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
} 
