import UIKit
import SwiftUI

class ImageProcessor {
    static let shared = ImageProcessor()
    
    // 添加水印缓存
    private var watermarkCache: [String: UIImage] = [:]
    private let cacheQueue = DispatchQueue(label: "com.mirror.watermarkCache")
    
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
    
    // 临时方法：创建一个全屏黄色矩形图片用于测试
    func createTestMixImage(baseImage: UIImage) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: baseImage.size)
        let mixImage = renderer.image { ctx in
            // 绘制一个全屏的黄色矩形
            ctx.cgContext.setFillColor(UIColor.yellow.withAlphaComponent(0.8).cgColor)
            ctx.cgContext.fill(CGRect(origin: .zero, size: baseImage.size))
        }
        return mixImage
    }
    
    // 修改添加水印处理方法
    func addWatermark(to image: UIImage, orientation: UIDeviceOrientation) -> UIImage {
        // 检查水印开关状态
        let isWatermarkEnabled = UserSettingsManager.shared.loadWatermarkEnabled()
        if !isWatermarkEnabled {
            // 如果水印关闭但真实模式开启，仍然需要添加网格
            if RealModeController.shared.isRealModeEnabled,
               let gridImage = RealModeController.shared.getReferenceGridImage() {
                return autoreleasepool { () -> UIImage in
                    let format = UIGraphicsImageRendererFormat()
                    format.scale = 1.0
                    format.opaque = true
                    
                    let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
                    return renderer.image { ctx in
                        // 绘制原始图片
                        image.draw(in: CGRect(origin: .zero, size: image.size))
                        // 绘制网格
                        gridImage.draw(in: CGRect(origin: .zero, size: image.size))
                    }
                }
            }
            return image
        }
        
        // 获取水印图片
        guard let watermark = getCachedWatermark(for: orientation) else {
            return image
        }
        
        return autoreleasepool { () -> UIImage in
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1.0
            format.opaque = true
            
            let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
            return renderer.image { ctx in
                // 绘制原始图片
                image.draw(in: CGRect(origin: .zero, size: image.size))
                // 绘制水印
                watermark.draw(in: CGRect(origin: .zero, size: image.size))
                // 如果真实模式开启，绘制网格
                if RealModeController.shared.isRealModeEnabled,
                   let gridImage = RealModeController.shared.getReferenceGridImage() {
                    gridImage.draw(in: CGRect(origin: .zero, size: image.size))
                }
            }
        }
    }
    
    // 添加 UIImage 扩展方法用于旋转图片
    private func rotateImage(_ image: UIImage, by degrees: CGFloat) -> UIImage? {
        let radians = degrees * .pi / 180
        let rotatedSize = CGRect(origin: .zero, size: image.size)
            .applying(CGAffineTransform(rotationAngle: CGFloat(radians)))
            .integral.size
        
        UIGraphicsBeginImageContextWithOptions(rotatedSize, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        // 移动原点到中心
        context.translateBy(x: rotatedSize.width/2, y: rotatedSize.height/2)
        // 旋转
        context.rotate(by: radians)
        // 绘制图片
        image.draw(in: CGRect(
            x: -image.size.width/2,
            y: -image.size.height/2,
            width: image.size.width,
            height: image.size.height
        ))
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    // 修改图像合成方法
    func createMixImage(
        baseImage: UIImage,
        drawingImage: UIImage?,
        makeupImage: UIImage? = nil,
        scale: CGFloat = 1.0,
        isForVideo: Bool = false,
        orientation: UIDeviceOrientation = .portrait,
        watermark: UIImage? = nil,
        gridImage: UIImage? = nil
    ) -> UIImage {
        // 如果没有绘画图片和化妆图片，且没有传入水印，则使用默认水印
        if drawingImage == nil && makeupImage == nil && watermark == nil && gridImage == nil {
            return addWatermark(to: baseImage, orientation: orientation)
        }
        
        // 使用基础图片的原始尺寸
        let size = baseImage.size
        
        print("------------------------")
        print("[图片合成] 开始")
        print("基础图片尺寸：\(size.width) x \(size.height)")
        if let drawingImage = drawingImage {
            print("绘画图片尺寸：\(drawingImage.size.width) x \(drawingImage.size.height)")
        }
        if let makeupImage = makeupImage {
            print("化妆图片尺寸：\(makeupImage.size.width) x \(makeupImage.size.height)")
        }
        print("缩放比例：\(scale)")
        print("是否用于视频：\(isForVideo)")
        print("------------------------")
        
        return autoreleasepool { () -> UIImage in
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1.0
            format.opaque = false
            
            let renderer = UIGraphicsImageRenderer(size: size, format: format)
            let mixImage = renderer.image { ctx in
                // 绘制基础图片
                baseImage.draw(in: CGRect(origin: .zero, size: size))
                
                // 如果有绘画图片，绘制绘画图片
                if let drawingImage = drawingImage {
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
                    
                    print("[图片合成] 绘制绘画图片")
                    print("绘制区域：\(drawingRect)")
                    // 绘制绘画图片，保持原始比例
                    drawingImage.draw(in: drawingRect)
                }
                
                // 如果有化妆图片，绘制化妆图片
                if let makeupImage = makeupImage {
                    var makeupRect: CGRect
                    
                    if isForVideo {
                        // 视频模式：使用与绘画图片相同的逻辑
                        let makeupSize = makeupImage.size
                        let aspectRatio = makeupSize.width / makeupSize.height
                        
                        // 根据缩放比例调整化妆图片的尺寸
                        let scaledWidth = size.width / scale
                        let scaledHeight = size.height / scale
                        
                        if aspectRatio > scaledWidth / scaledHeight {
                            // 化妆图片更宽，以宽度为基准
                            let height = scaledWidth / aspectRatio
                            makeupRect = CGRect(
                                x: (size.width - scaledWidth) / 2,
                                y: (size.height - height) / 2,
                                width: scaledWidth,
                                height: height
                            )
                        } else {
                            // 化妆图片更高，以高度为基准
                            let width = scaledHeight * aspectRatio
                            makeupRect = CGRect(
                                x: (size.width - width) / 2,
                                y: (size.height - scaledHeight) / 2,
                                width: width,
                                height: scaledHeight
                            )
                        }
                    } else {
                        // 静态图片模式：使用预览图片的逻辑
                        let makeupSize = makeupImage.size
                        let makeupAspect = makeupSize.width / makeupSize.height
                        
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
                    }
                    
                    print("[图片合成] 绘制化妆图片")
                    print("基础图片尺寸：\(size.width) x \(size.height)")
                    print("化妆图片原始尺寸：\(makeupImage.size.width) x \(makeupImage.size.height)")
                    print("绘制区域：\(makeupRect)")
                    print("缩放比例：\(scale)")
                    print("处理模式：\(isForVideo ? "视频模式" : "静态图片模式")")
                    
                    // 绘制化妆图片
                    makeupImage.draw(in: makeupRect)
                }
                
                // 添加水印
                let isWatermarkEnabled = UserSettingsManager.shared.loadWatermarkEnabled()
                if isWatermarkEnabled {
                    if let watermark = watermark {
                        // 使用传入的已变换水印
                        watermark.draw(in: CGRect(origin: .zero, size: size))
                    } else if let defaultWatermark = getCachedWatermark(for: orientation) {
                        // 使用默认水印
                        defaultWatermark.draw(in: CGRect(origin: .zero, size: size))
                    }
                }
                
                // 如果传入了网格图片，添加网格
                if let gridImage = gridImage {
                    gridImage.draw(in: CGRect(origin: .zero, size: size))
                } else if RealModeController.shared.isRealModeEnabled,
                          let defaultGridImage = RealModeController.shared.getReferenceGridImage() {
                    // 如果没有传入网格图片但真实模式开启，使用默认网格
                    defaultGridImage.draw(in: CGRect(origin: .zero, size: size))
                }
            }
            
            print("[图片合成] 完成")
            print("最终图片尺寸：\(mixImage.size.width) x \(mixImage.size.height)")
            print("------------------------")
            
            return mixImage
        }
    }
    
    // 图像尺寸压缩方法
    func compressImageIfNeeded(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        
        // 如果图片尺寸在限制范围内，直接返回
        if size.width <= maxDimension && size.height <= maxDimension {
            return image
        }
        
        // 计算压缩比例
        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        // 使用autoreleasepool来管理临时对象的内存
        return autoreleasepool { () -> UIImage in
            let format = UIGraphicsImageRendererFormat()
            format.scale = UIScreen.main.scale
            format.opaque = false
            
            let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
            let compressedImage = renderer.image { ctx in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
            
            return compressedImage
        }
    }
    
    // 预览图片处理方法
    func createPreviewImage(baseImage: UIImage, drawingImage: UIImage?, makeupImage: UIImage? = nil, scale: CGFloat = 1.0) -> UIImage {
        // 如果没有绘画图片和化妆图片，直接返回原图
        guard drawingImage != nil || makeupImage != nil else {
            return baseImage
        }
        
        // 使用原始图片尺寸，不再缩小预览尺寸
        let size = baseImage.size
        
        // 使用autoreleasepool来管理临时对象的内存
        return autoreleasepool { () -> UIImage in
            let format = UIGraphicsImageRendererFormat()
            format.scale = UIScreen.main.scale // 使用屏幕的scale以保持清晰度
            format.opaque = false
            
            let renderer = UIGraphicsImageRenderer(size: size, format: format)
            let previewImage = renderer.image { ctx in
                // 确保绘制区域被裁剪
                ctx.cgContext.setBlendMode(.normal)
                
                // 绘制基础图片
                baseImage.draw(in: CGRect(origin: .zero, size: size))
                
                // 如果有绘画图片，绘制绘画图片
                if let drawingImage = drawingImage {
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
                    
                    // 绘制绘画图片，保持原始比例
                    drawingImage.draw(in: drawingRect)
                }
                
                // 如果有化妆图片，绘制化妆图片
                if let makeupImage = makeupImage {
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
                        // 根据基础图片的缩放比例计算化妆图片的大小
                        let scaledBaseHeight = size.height / scale
                        
                        // 计算化妆图片的绘制尺寸，保持与基础图片相同的缩放比例
                        let makeupDrawWidth = makeupSize.width * (scaledBaseHeight / makeupSize.height)
                        let makeupDrawHeight = scaledBaseHeight
                        
                        // 居中绘制
                        let x = (size.width - makeupDrawWidth) / 2
                        let y = (size.height - makeupDrawHeight) / 2
                        
                        drawRect = CGRect(x: x, y: y, width: makeupDrawWidth, height: makeupDrawHeight)
                    }
                    
                    // 绘制化妆图片
                    makeupImage.draw(in: drawRect)
                    
                    print("------------------------")
                    print("[预览图片] 绘制化妆图片")
                    print("基础图片尺寸：\(size.width) x \(size.height)")
                    print("化妆图片原始尺寸：\(makeupSize.width) x \(makeupSize.height)")
                    print("绘制区域：\(drawRect)")
                    print("缩放比例：\(scale)")
                    print("缩放模式：\(scale == 1.0 ? "全屏100%" : (scale < 1.0 ? "全景模式" : "全屏放大模式"))")
                    print("------------------------")
                }
            }
            
            return previewImage
        }
    }
    
    func createSimulatedMixLivePhoto(baseImage: UIImage, drawingImage: UIImage?, makeupImage: UIImage?) -> (UIImage, URL?) {
        // 创建模拟的静态图片(黄色)
        let simulatedImage = UIGraphicsImageRenderer(size: baseImage.size).image { ctx in
            UIColor.yellow.setFill()
            ctx.fill(CGRect(origin: .zero, size: baseImage.size))
        }
        
        // 这里返回模拟数据,后续实现实际视频处理
        return (simulatedImage, nil)
    }
} 