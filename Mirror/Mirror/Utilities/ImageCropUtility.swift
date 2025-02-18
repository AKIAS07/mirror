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
        scale: CGFloat = 1.0,
        cameraScale: CGFloat = 1.0  // 添加摄像头基准比例参数
    ) -> UIImage {
        // 使用定格时的方向来决定裁剪方式
        let shouldUseLandscape = pausedOrientation?.isLandscape ?? isLandscape
        
        if shouldUseLandscape {
            return cropImageToScreenSizeLandscape(image, for: screenID, offset: offset, scale: scale * cameraScale, cameraScale: cameraScale)  // 组合用户缩放和摄像头缩放
        } else {
            return cropImageToScreenSizePortrait(image, for: screenID, offset: offset, scale: scale * cameraScale, cameraScale: cameraScale)  // 组合用户缩放和摄像头缩放
        }
    }
    
    // 竖屏裁剪方法
    private func cropImageToScreenSizePortrait(
        _ image: UIImage,
        for screenID: ScreenID,
        offset: CGSize,
        scale: CGFloat,
        cameraScale: CGFloat  // 添加摄像头基准比例参数
    ) -> UIImage {
        print("------------------------")
        print("[竖屏裁剪] 详细调试")
        print("1. 输入参数:")
        print("- 原始图片尺寸: \(image.size.width) x \(image.size.height)")
        print("- 用户缩放比例: \(Int(scale * 100))%")
        print("- 摄像头基准比例: \(Int(cameraScale * 100))%")
        
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
        // 组合基础缩放、用户缩放和摄像头缩放
        let finalScale = baseScale * scale * cameraScale
        
        print("3. 缩放计算:")
        print("- 基础缩放比例: \(Int(baseScale * 100))%")
        print("- 用户缩放比例: \(Int(scale * 100))%")
        print("- 摄像头基准比例: \(Int(cameraScale * 100))%")
        print("- 最终缩放比例: \(Int(finalScale * 100))%")
        
        // 计算缩放后的图片尺寸
        let scaledWidth = image.size.width * finalScale
        let scaledHeight = image.size.height * finalScale
        
        print("4. 缩放后尺寸:")
        print("- 缩放后图片尺寸: \(scaledWidth) x \(scaledHeight)")
        
        // 计算裁剪区域，考虑摄像头缩放
        let cropWidth = viewportWidth / (baseScale * cameraScale)  // 使用基础缩放和摄像头缩放计算裁剪区域
        let cropHeight = viewportHeight / (baseScale * cameraScale)
        
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
    private func cropImageToScreenSizeLandscape(
        _ image: UIImage,
        for screenID: ScreenID,
        offset: CGSize,
        scale: CGFloat,
        cameraScale: CGFloat  // 添加摄像头基准比例参数
    ) -> UIImage {
        print("------------------------")
        print("[横屏裁剪] 详细调试")
        print("1. 输入参数:")
        print("- 原始图片尺寸: \(image.size.width) x \(image.size.height)")
        print("- 用户缩放比例: \(Int(scale * 100))%")
        print("- 摄像头基准比例: \(Int(cameraScale * 100))%")
        
        let screenBounds = UIScreen.main.bounds
        let screenWidth = screenBounds.width
        let screenHeight = screenBounds.height
        
        // 计算横屏显示区域的尺寸
        let viewportWidth = screenHeight / 2  // 横屏时宽度为竖屏高度的一半
        let viewportHeight = screenWidth      // 横屏时高度为竖屏宽度
        
        print("2. 视口信息:")
        print("- 屏幕尺寸: \(screenWidth) x \(screenHeight)")
        print("- 视口尺寸: \(viewportWidth) x \(viewportHeight)")
        
        // 计算基础缩放比例（使图片适应视口）
        let baseScale = max(viewportWidth / image.size.width, viewportHeight / image.size.height)
        // 组合基础缩放、用户缩放和摄像头缩放
        let finalScale = baseScale * scale * cameraScale
        
        print("3. 缩放计算:")
        print("- 基础缩放比例: \(Int(baseScale * 100))%")
        print("- 用户缩放比例: \(Int(scale * 100))%")
        print("- 摄像头基准比例: \(Int(cameraScale * 100))%")
        print("- 最终缩放比例: \(Int(finalScale * 100))%")
        
        // 计算缩放后的图片尺寸
        let scaledWidth = image.size.width * finalScale
        let scaledHeight = image.size.height * finalScale
        
        print("4. 缩放后尺寸:")
        print("- 缩放后图片尺寸: \(scaledWidth) x \(scaledHeight)")
        
        // 计算裁剪区域，考虑摄像头缩放
        let cropWidth = viewportWidth / (baseScale * cameraScale)  // 使用基础缩放和摄像头缩放计算裁剪区域
        let cropHeight = viewportHeight / (baseScale * cameraScale)
        
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
        offset: CGSize,
        scale: CGFloat,
        cameraScale: CGFloat  // 添加摄像头基准比例参数
    ) -> UIImage {
        print("------------------------")
        print("[定格图片裁剪] 详细调试")
        print("1. 输入参数:")
        print("- 原始图片尺寸: \(image.size.width) x \(image.size.height)")
        print("- 目标方向: \(targetOrientation.rawValue)")
        print("- 定格方向: \(pausedOrientation.rawValue)")
        print("- 传入缩放比例: \(Int(scale * 100))%")
        print("- 摄像头基准比例: \(Int(cameraScale * 100))%")
        print("- 屏幕ID: \(screenID)")
        
        // 根据方向选择合适的裁剪方法
        if targetOrientation.isPortrait {
            print("2. 使用竖屏裁剪方法")
            return cropImageToScreenSizePortrait(
                image,
                for: screenID,
                offset: offset,
                scale: scale * cameraScale,
                cameraScale: cameraScale
            )
        } else {
            print("2. 使用横屏裁剪方法")
            return cropImageToScreenSizeLandscape(
                image,
                for: screenID,
                offset: offset,
                scale: scale * cameraScale,
                cameraScale: cameraScale
            )
        }
    }
    
    static func cropImage(
        _ image: UIImage,
        scale: CGFloat,
        cameraScale: CGFloat,
        screenID: ScreenID,
        orientation: UIDeviceOrientation
    ) -> UIImage? {
        print("------------------------")
        print("[定格图片裁剪] 详细调试")
        print("1. 输入参数:")
        print("- 原始图片尺寸: \(image.size.width) x \(image.size.height)")
        print("- 目标方向: \(orientation.rawValue)")
        print("- 定格方向: \(image.imageOrientation.rawValue)")
        print("- 传入缩放比例: \(Int(scale * 100))%")
        print("- 屏幕ID: \(screenID)")
        
        // 如果方向相同，使用标准裁剪方法
        if orientation.isPortrait {
            print("2. 方向相同，使用标准裁剪方法")
            return shared.cropImageToScreenSizePortrait(
                image,
                for: screenID,
                offset: .zero,
                scale: scale * cameraScale,
                cameraScale: cameraScale
            )
        } else {
            return shared.cropImageToScreenSizeLandscape(
                image,
                for: screenID,
                offset: .zero,
                scale: scale * cameraScale,
                cameraScale: cameraScale
            )
        }
    }
} 