import SwiftUI
import UIKit

// 图片裁剪工具类
class ImageCropUtility {
    static let shared = ImageCropUtility()
    
    private init() {}
    
    // 通用的裁剪方法，支持横竖屏
    func cropImageToScreenSize(
        _ image: UIImage,
        for screenID: ScreenID,
        offset: CGSize = .zero,
        isLandscape: Bool = false,
        pausedOrientation: UIDeviceOrientation? = nil
    ) -> UIImage {
        // 使用定格时的方向来决定裁剪方式
        let shouldUseLandscape = pausedOrientation?.isLandscape ?? isLandscape
        
        if shouldUseLandscape {
            return cropImageToScreenSizeLandscape(image, for: screenID, offset: offset)
        } else {
            return cropImageToScreenSizePortrait(image, for: screenID, offset: offset)
        }
    }
    
    // 竖屏裁剪方法
    private func cropImageToScreenSizePortrait(_ image: UIImage, for screenID: ScreenID, offset: CGSize) -> UIImage {
        let screenBounds = UIScreen.main.bounds
        let screenWidth = screenBounds.width
        let screenHeight = screenBounds.height
        
        // 计算显示区域的尺寸（屏幕的一半高度）
        let viewportWidth = screenWidth
        let viewportHeight = screenHeight / 2
        
        // 计算图片缩放后的实际尺寸
        let scale = max(viewportWidth / image.size.width, viewportHeight / image.size.height)
        let scaledImageWidth = image.size.width * scale
        let scaledImageHeight = image.size.height * scale
        
        // 计算基础偏移（图片中心到显示区域中心的距离）
        let baseOffsetX = (scaledImageWidth - viewportWidth) / 2
        let baseOffsetY = (scaledImageHeight - viewportHeight) / 2
        
        // 计算可见区域在原始图片中的位置，不再考虑用户的拖动偏移
        let visibleX = baseOffsetX
        let visibleY = baseOffsetY 
        
        // 确保裁剪区域不超出图片范围
        let safeCropX = max(0, min(visibleX / scale, image.size.width - viewportWidth / scale))
        let safeCropY = max(0, min(visibleY / scale, image.size.height - viewportHeight / scale))
        let safeCropWidth = min(viewportWidth / scale, image.size.width - safeCropX)
        let safeCropHeight = min(viewportHeight / scale, image.size.height - safeCropY)
        
        // 创建裁剪区域
        let cropRect = CGRect(x: safeCropX,
                            y: safeCropY,
                            width: safeCropWidth,
                            height: safeCropHeight)
        
        // 从原图中裁剪指定区域
        if let cgImage = image.cgImage?.cropping(to: cropRect) {
            return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
        }
        
        return image
    }
    
    // 横屏裁剪方法
    private func cropImageToScreenSizeLandscape(_ image: UIImage, for screenID: ScreenID, offset: CGSize) -> UIImage {
        print("------------------------")
        print("[横屏裁剪] 开始")
        print("原始图片尺寸: \(image.size.width) x \(image.size.height)")
        print("屏幕ID: \(screenID)")
        
        let screenBounds = UIScreen.main.bounds
        // 使用竖屏时的尺寸，因为摄像头捕获的画面尺寸是固定的
        let screenWidth = screenBounds.width   // 竖屏时的宽度
        let screenHeight = screenBounds.height // 竖屏时的高度
        
        print("屏幕尺寸: \(screenWidth) x \(screenHeight)")
        print("设备方向: \(UIDevice.current.orientation.rawValue)")
        
        // 计算横屏显示区域的尺寸
        let viewportWidth = screenHeight / 2  // 横屏时宽度为竖屏高度的一半
        let viewportHeight = screenWidth      // 横屏时高度为竖屏宽度
        
        print("视口尺寸: \(viewportWidth) x \(viewportHeight)")
        
        // 计算图片缩放后的实际尺寸
        let scale = max(viewportWidth / image.size.width, viewportHeight / image.size.height)
        let scaledImageWidth = image.size.width * scale
        let scaledImageHeight = image.size.height * scale
        
        print("缩放比例: \(scale)")
        print("缩放后图片尺寸: \(scaledImageWidth) x \(scaledImageHeight)")
        
        // 计算基础偏移（图片中心到显示区域中心的距离）
        let baseOffsetX = (scaledImageWidth - viewportWidth) / 2
        let baseOffsetY = (scaledImageHeight - viewportHeight) / 2
        
        print("基础偏移量: X=\(baseOffsetX), Y=\(baseOffsetY)")
        
        // 计算可见区域在原始图片中的位置
        let visibleX = baseOffsetX
        let visibleY = baseOffsetY + (screenID == .mirrored ? viewportHeight : 0)
        
        print("可见区域起点: X=\(visibleX), Y=\(visibleY)")
        
        // 将缩放后的坐标转换回原始图片坐标
        let originalX = visibleX / scale
        let originalY = visibleY / scale
        let originalWidth = viewportWidth / scale
        let originalHeight = viewportHeight / scale
        
        print("裁剪起始点: X=\(originalX), Y=\(originalY)")
        print("裁剪尺寸: Width=\(originalWidth), Height=\(originalHeight)")
        
        // 确保裁剪区域不超出图片范围
        let safeCropX = max(0, min(originalX, image.size.width - originalWidth))
        let safeCropY = max(0, min(originalY, image.size.height - originalHeight))
        let safeCropWidth = min(originalWidth, image.size.width - safeCropX)
        let safeCropHeight = min(originalHeight, image.size.height - safeCropY)
        
        // 创建裁剪区域
        let cropRect = CGRect(x: safeCropX,
                            y: safeCropY,
                            width: safeCropWidth,
                            height: safeCropHeight)
        
        print("最终裁剪区域: \(cropRect)")
        
        // 从原图中裁剪指定区域
        if let cgImage = image.cgImage?.cropping(to: cropRect) {
            let croppedImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
            
            // 再次裁剪，去掉底部2像素
            let finalHeight = croppedImage.size.height - 2
            let finalRect = CGRect(x: 0,
                                 y: 0,
                                 width: croppedImage.size.width,
                                 height: finalHeight)
            
            if let finalCGImage = croppedImage.cgImage?.cropping(to: finalRect) {
                let finalImage = UIImage(cgImage: finalCGImage, scale: image.scale, orientation: image.imageOrientation)
                print("最终图片尺寸: \(finalImage.size.width) x \(finalImage.size.height)")
                print("[横屏裁剪] 完成")
                print("------------------------")
                return finalImage
            }
            
            return croppedImage
        }
        
        print("[横屏裁剪] 失败")
        print("------------------------")
        return image
    }
} 