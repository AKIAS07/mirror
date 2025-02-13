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
        pausedOrientation: UIDeviceOrientation? = nil,
        scale: CGFloat = 1.0
    ) -> UIImage {
        // 使用定格时的方向来决定裁剪方式
        let shouldUseLandscape = pausedOrientation?.isLandscape ?? isLandscape
        
        if shouldUseLandscape {
            return cropImageToScreenSizeLandscape(image, for: screenID, offset: offset, scale: scale)
        } else {
            return cropImageToScreenSizePortrait(image, for: screenID, offset: offset, scale: scale)
        }
    }
    
    // 竖屏裁剪方法
    private func cropImageToScreenSizePortrait(_ image: UIImage, for screenID: ScreenID, offset: CGSize, scale: CGFloat) -> UIImage {
        print("------------------------")
        print("[竖屏裁剪] 详细调试")
        print("1. 输入参数:")
        print("- 原始图片尺寸: \(image.size.width) x \(image.size.height)")
        print("- 传入缩放比例: \(Int(scale * 100))%")
        
        let screenBounds = UIScreen.main.bounds
        let screenWidth = screenBounds.width
        let screenHeight = screenBounds.height
        
        // 计算显示区域的尺寸（屏幕的一半高度）
        let viewportWidth = screenWidth
        let viewportHeight = screenHeight / 2
        
        print("2. 视口信息:")
        print("- 屏幕尺寸: \(screenWidth) x \(screenHeight)")
        print("- 视口尺寸: \(viewportWidth) x \(viewportHeight)")
        
        // 计算基础缩放比例（使图片适应视口）
        let baseScale = max(viewportWidth / image.size.width, viewportHeight / image.size.height)
        let finalScale = baseScale * scale
        
        print("3. 缩放计算:")
        print("- 基础缩放比例: \(Int(baseScale * 100))%")
        print("- 用户缩放比例: \(Int(scale * 100))%")
        print("- 最终缩放比例: \(Int(finalScale * 100))%")
        
        // 计算缩放后的图片尺寸
        let scaledWidth = image.size.width * finalScale
        let scaledHeight = image.size.height * finalScale
        
        print("4. 缩放后尺寸:")
        print("- 缩放后图片尺寸: \(scaledWidth) x \(scaledHeight)")
        
        // 计算裁剪区域
        let cropWidth = viewportWidth / baseScale  // 使用基础缩放计算裁剪区域
        let cropHeight = viewportHeight / baseScale
        
        print("5. 裁剪区域计算:")
        print("- 理想裁剪尺寸: \(cropWidth) x \(cropHeight)")
        
        // 确保裁剪区域不超出图片范围并居中
        let safeCropX = max(0, (image.size.width - cropWidth) / 2)
        let safeCropY = max(0, (image.size.height - cropHeight) / 2)
        
        let cropRect = CGRect(
            x: safeCropX,
            y: safeCropY,
            width: min(cropWidth, image.size.width - safeCropX),
            height: min(cropHeight, image.size.height - safeCropY)
        )
        
        print("6. 最终裁剪信息:")
        print("- 裁剪起点: (\(safeCropX), \(safeCropY))")
        print("- 裁剪尺寸: \(cropRect.width) x \(cropRect.height)")
        
        // 从原图中裁剪指定区域
        if let cgImage = image.cgImage?.cropping(to: cropRect) {
            let croppedImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
            print("7. 裁剪结果:")
            print("- 最终图片尺寸: \(croppedImage.size.width) x \(croppedImage.size.height)")
            print("[竖屏裁剪] 完成")
            print("------------------------")
            return croppedImage
        }
        
        print("[竖屏裁剪] 失败")
        print("------------------------")
        return image
    }
    
    // 横屏裁剪方法
    private func cropImageToScreenSizeLandscape(_ image: UIImage, for screenID: ScreenID, offset: CGSize, scale: CGFloat) -> UIImage {
        print("------------------------")
        print("[横屏裁剪] 详细调试")
        print("1. 输入参数:")
        print("- 原始图片尺寸: \(image.size.width) x \(image.size.height)")
        print("- 传入缩放比例: \(Int(scale * 100))%")
        print("- 屏幕ID: \(screenID)")
        
        let screenBounds = UIScreen.main.bounds
        let screenWidth = screenBounds.width   // 竖屏时的宽度
        let screenHeight = screenBounds.height // 竖屏时的高度
        
        // 计算横屏显示区域的尺寸
        let viewportWidth = screenHeight / 2  // 横屏时宽度为竖屏高度的一半
        let viewportHeight = screenWidth      // 横屏时高度为竖屏宽度
        
        print("2. 视口信息:")
        print("- 屏幕尺寸: \(screenWidth) x \(screenHeight)")
        print("- 视口尺寸: \(viewportWidth) x \(viewportHeight)")
        
        // 计算基础缩放比例（使图片适应视口）
        let baseScale = max(viewportWidth / image.size.width, viewportHeight / image.size.height)
        let finalScale = baseScale * scale
        
        print("3. 缩放计算:")
        print("- 基础缩放比例: \(Int(baseScale * 100))%")
        print("- 用户缩放比例: \(Int(scale * 100))%")
        print("- 最终缩放比例: \(Int(finalScale * 100))%")
        
        // 计算缩放后的图片尺寸
        let scaledWidth = image.size.width * finalScale
        let scaledHeight = image.size.height * finalScale
        
        print("4. 缩放后尺寸:")
        print("- 缩放后图片尺寸: \(scaledWidth) x \(scaledHeight)")
        
        // 计算裁剪区域
        let cropWidth = viewportWidth / baseScale  // 使用基础缩放计算裁剪区域
        let cropHeight = viewportHeight / baseScale
        
        print("5. 裁剪区域计算:")
        print("- 理想裁剪尺寸: \(cropWidth) x \(cropHeight)")
        
        // 确保裁剪区域不超出图片范围
        let safeCropX = max(0, (image.size.width - cropWidth) / 2)
        var safeCropY = max(0, (image.size.height - cropHeight) / 2)
        

        
        let cropRect = CGRect(
            x: safeCropX,
            y: safeCropY,
            width: min(cropWidth, image.size.width - safeCropX),
            height: min(cropHeight, image.size.height - safeCropY)
        )
        
        print("6. 最终裁剪信息:")
        print("- 裁剪起点: (\(safeCropX), \(safeCropY))")
        print("- 裁剪尺寸: \(cropRect.width) x \(cropRect.height)")
        
        // 从原图中裁剪指定区域
        if let cgImage = image.cgImage?.cropping(to: cropRect) {
            let croppedImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
            
            // 再次裁剪，去掉底部2像素（保持原有的微调逻辑）
            let finalHeight = croppedImage.size.height - 2
            let finalRect = CGRect(
                x: 0,
                y: 0,
                width: croppedImage.size.width,
                height: finalHeight
            )
            
            if let finalCGImage = croppedImage.cgImage?.cropping(to: finalRect) {
                let finalImage = UIImage(cgImage: finalCGImage, scale: image.scale, orientation: image.imageOrientation)
                print("7. 裁剪结果:")
                print("- 最终图片尺寸: \(finalImage.size.width) x \(finalImage.size.height)")
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
    
    // 添加定格图片裁剪方法
    func cropPausedImage(
        _ image: UIImage,
        for screenID: ScreenID,
        targetOrientation: UIDeviceOrientation,
        pausedOrientation: UIDeviceOrientation,
        offset: CGSize = .zero,
        scale: CGFloat = 1.0
    ) -> UIImage {
        print("------------------------")
        print("[定格图片裁剪] 详细调试")
        print("1. 输入参数:")
        print("- 原始图片尺寸: \(image.size.width) x \(image.size.height)")
        print("- 目标方向: \(targetOrientation.rawValue)")
        print("- 定格方向: \(pausedOrientation.rawValue)")
        print("- 传入缩放比例: \(Int(scale * 100))%")
        print("- 屏幕ID: \(screenID)")
        
        // 如果目标方向和定格方向相同，直接使用现有的裁剪方法
        if targetOrientation == pausedOrientation {
            print("2. 方向相同，使用标准裁剪方法")
            return cropImageToScreenSize(
                image,
                for: screenID,
                offset: offset,
                isLandscape: targetOrientation.isLandscape,
                pausedOrientation: pausedOrientation,
                scale: scale
            )
        }
        
        print("2. 方向不同，使用特殊裁剪逻辑")
        
        // 处理方向不同的情况
        let screenBounds = UIScreen.main.bounds
        let screenWidth = screenBounds.width
        let screenHeight = screenBounds.height
        
        print("3. 屏幕信息:")
        print("- 屏幕尺寸: \(screenWidth) x \(screenHeight)")
        
        // 根据目标方向计算裁剪区域
        let viewportWidth: CGFloat
        let viewportHeight: CGFloat
        
        if targetOrientation.isLandscape {
            viewportWidth = screenHeight / 2
            viewportHeight = screenWidth
            print("4. 目标是横屏:")
        } else {
            viewportWidth = screenWidth
            viewportHeight = screenHeight / 2
            print("4. 目标是竖屏:")
        }
        print("- 视口尺寸: \(viewportWidth) x \(viewportHeight)")
        
        // 计算实际需要的基础缩放比例
        let baseScale = max(viewportWidth / image.size.width, viewportHeight / image.size.height)
        print("5. 缩放计算:")
        print("- 基础缩放比例: \(Int(baseScale * 100))%")
        print("- 用户缩放比例: \(Int(scale * 100))%")
        
        // 使用组合缩放比例
        let finalScale = baseScale * scale
        print("- 最终缩放比例: \(Int(finalScale * 100))%")
        
        // 计算裁剪区域
        let cropWidth = viewportWidth / scale  // 只使用用户缩放
        let cropHeight = viewportHeight / scale
        
        print("6. 裁剪区域计算:")
        print("- 理想裁剪尺寸: \(cropWidth) x \(cropHeight)")
        
        // 确保裁剪区域不超出图片范围
        let safeCropX = max(0, (image.size.width - cropWidth) / 2)
        let safeCropY = max(0, (image.size.height - cropHeight) / 2)
        
        let cropRect = CGRect(
            x: safeCropX,
            y: safeCropY,
            width: min(cropWidth, image.size.width - safeCropX),
            height: min(cropHeight, image.size.height - safeCropY)
        )
        
        print("7. 最终裁剪信息:")
        print("- 裁剪区域: \(cropRect)")
        print("- 裁剪起点: (\(safeCropX), \(safeCropY))")
        print("- 裁剪尺寸: \(cropRect.width) x \(cropRect.height)")
        
        // 执行裁剪
        if let cgImage = image.cgImage?.cropping(to: cropRect) {
            let croppedImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
            print("8. 裁剪结果:")
            print("- 最终图片尺寸: \(croppedImage.size.width) x \(croppedImage.size.height)")
            print("[定格图片裁剪] 完成")
            print("------------------------")
            return croppedImage
        }
        
        print("[定格图片裁剪] 失败")
        print("------------------------")
        return image
    }
} 