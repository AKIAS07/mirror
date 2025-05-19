import UIKit
import AVFoundation

class LiveProcessor {
    static let shared = LiveProcessor()
    
    private init() {}
    
    // 处理 Live Photo 的图片部分
    func processLivePhotoImage(baseImage: UIImage, drawingImage: UIImage?, makeupImage: UIImage?, scale: CGFloat = 1.0) -> UIImage {
        print("[图片处理] 开始处理 Live Photo 图片")
        print("基础图片尺寸：\(baseImage.size)")
        print("缩放比例：\(scale)")
        
        // 如果没有绘画图片和化妆图片，直接返回原图
        guard drawingImage != nil || makeupImage != nil else {
            print("[图片处理] 无叠加图层，返回原图")
            return baseImage
        }
        
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
                    // 绘制绘画图片，保持原始比例
                    drawingImage.draw(in: drawingRect)
                }
                
                // 如果有化妆图片，绘制化妆图片
                if let makeupImage = makeupImage {
                    print("[图片处理] 绘制化妆图层")
                    // 计算化妆图片的绘制区域，考虑缩放比例
                    let makeupSize = makeupImage.size
                    let makeupAspect = makeupSize.width / makeupSize.height
                    
                    var drawRect: CGRect
                    if scale == 1.0 {
                        // 全屏模式（100%）- 保持原始宽高比
                        let makeupDrawHeight = size.height
                        let makeupDrawWidth = makeupDrawHeight * makeupAspect
                        
                        // 居中绘制
                        let x = (size.width - makeupDrawWidth) / 2
                        let y = 0.0
                        
                        drawRect = CGRect(x: x, y: y, width: makeupDrawWidth, height: makeupDrawHeight)
                    } else {
                        // 其他模式（60%和100%以上）- 根据缩放比例调整大小
                        let scaledBaseHeight = size.height / scale
                        let makeupDrawWidth = makeupSize.width * (scaledBaseHeight / makeupSize.height)
                        let makeupDrawHeight = scaledBaseHeight
                        
                        // 居中绘制
                        let x = (size.width - makeupDrawWidth) / 2
                        let y = (size.height - makeupDrawHeight) / 2
                        
                        drawRect = CGRect(x: x, y: y, width: makeupDrawWidth, height: makeupDrawHeight)
                    }
                    
                    print("[图片处理] 化妆图层绘制区域：\(drawRect)")
                    // 绘制化妆图片
                    makeupImage.draw(in: drawRect)
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
        progressHandler: ((Double) -> Void)? = nil
    ) async -> URL? {
        print("[视频处理] 开始处理视频")
        print("输入视频URL：\(videoURL.path)")
        print("设备方向：\(orientation.rawValue)")
        
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
        writerInput.transform = preferredTransform  // 使用原始视频的变换信息
        
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
        var processedFrames: Double = 0
        
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
                        
                        // 处理帧图像
                        let processedImage = ImageProcessor.shared.createMixImage(
                            baseImage: frameImage,
                            drawingImage: drawingImage,
                            makeupImage: makeupImage,
                            scale: scale
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
                        }
                        
                        // 更新进度
                        processedFrames += 1
                        if let handler = progressHandler {
                            DispatchQueue.main.async {
                                handler(processedFrames / totalFrames)
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
