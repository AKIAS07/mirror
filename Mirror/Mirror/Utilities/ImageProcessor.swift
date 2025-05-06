import UIKit
import SwiftUI

class ImageProcessor {
    static let shared = ImageProcessor()
    
    private init() {}
    
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
    
    // 优化的图像合成方法
    func createMixImage(baseImage: UIImage, drawingImage: UIImage?) -> UIImage {
        // 如果没有绘画图片，直接返回原图
        guard let drawingImage = drawingImage else {
            return baseImage
        }
        
        // 使用基础图片的原始尺寸
        let size = baseImage.size
        
        // 使用autoreleasepool来管理临时对象的内存
        return autoreleasepool { () -> UIImage in
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1.0 // 使用1.0的scale以避免尺寸过大
            format.opaque = false
            
            let renderer = UIGraphicsImageRenderer(size: size, format: format)
            let mixImage = renderer.image { ctx in
                // 确保绘制区域被裁剪
                ctx.cgContext.setBlendMode(.normal)
                
                // 绘制基础图片
                baseImage.draw(in: CGRect(origin: .zero, size: size))
                
                // 计算绘画图片的绘制区域，保持原始比例
                let drawingSize = drawingImage.size
                let aspectRatio = drawingSize.width / drawingSize.height
                
                var drawingRect: CGRect
                if aspectRatio > size.width / size.height {
                    // 绘画图片更宽，以宽度为基准
                    let height = size.width / aspectRatio
                    drawingRect = CGRect(
                        x: 0,
                        y: (size.height - height) / 2,
                        width: size.width,
                        height: height
                    )
                } else {
                    // 绘画图片更高，以高度为基准
                    let width = size.height * aspectRatio
                    drawingRect = CGRect(
                        x: (size.width - width) / 2,
                        y: 0,
                        width: width,
                        height: size.height
                    )
                }
                
                // 绘制绘画图片，保持原始比例
                drawingImage.draw(in: drawingRect)
            }
            
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
    func createPreviewImage(baseImage: UIImage, drawingImage: UIImage?) -> UIImage {
        // 如果没有绘画图片，直接返回原图
        guard let drawingImage = drawingImage else {
            return baseImage
        }
        
        // 计算预览尺寸（使用较小的尺寸以提高性能）
        let previewMaxDimension: CGFloat = 1024 // 降低预览图片尺寸以提高性能
        let size = baseImage.size
        var renderSize = size
        
        // 如果图片尺寸超过限制，按比例缩小
        if size.width > previewMaxDimension || size.height > previewMaxDimension {
            let ratio = min(previewMaxDimension / size.width, previewMaxDimension / size.height)
            renderSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        }
        
        // 使用autoreleasepool来管理临时对象的内存
        return autoreleasepool { () -> UIImage in
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1.0 // 降低预览图片的scale以提高性能
            format.opaque = false
            
            let renderer = UIGraphicsImageRenderer(size: renderSize, format: format)
            let previewImage = renderer.image { ctx in
                // 确保绘制区域被裁剪
                ctx.cgContext.setBlendMode(.normal)
                
                // 绘制基础图片
                baseImage.draw(in: CGRect(origin: .zero, size: renderSize))
                
                // 计算绘画图片的绘制区域，保持原始比例
                let drawingSize = drawingImage.size
                let aspectRatio = drawingSize.width / drawingSize.height
                
                var drawingRect: CGRect
                if aspectRatio > renderSize.width / renderSize.height {
                    // 绘画图片更宽，以宽度为基准
                    let height = renderSize.width / aspectRatio
                    drawingRect = CGRect(
                        x: 0,
                        y: (renderSize.height - height) / 2,
                        width: renderSize.width,
                        height: height
                    )
                } else {
                    // 绘画图片更高，以高度为基准
                    let width = renderSize.height * aspectRatio
                    drawingRect = CGRect(
                        x: (renderSize.width - width) / 2,
                        y: 0,
                        width: width,
                        height: renderSize.height
                    )
                }
                
                // 绘制绘画图片，保持原始比例
                drawingImage.draw(in: drawingRect)
            }
            
            return previewImage
        }
    }
} 