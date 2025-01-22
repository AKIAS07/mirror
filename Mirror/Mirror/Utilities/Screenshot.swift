import SwiftUI
import UIKit
import Photos


// 添加截图动画视图
struct ScreenshotAnimationView: View {
    @Binding var isVisible: Bool
    let screenWidth = UIScreen.main.bounds.width
    let screenHeight = UIScreen.main.bounds.height
    let touchZonePosition: TouchZonePosition  // 添加触控区位置参数
    
    // 定义触控区1的尺寸和位置
    private let touchZoneWidth: CGFloat = 50
    private let touchZoneHeight: CGFloat = 20
    private let cornerLength: CGFloat = 15  // L形标记的长度
    private let lineWidth: CGFloat = 10      // 线条宽度
    private let padding: CGFloat = 20        // 与触控区的间距
    
    var body: some View {
        // 触控区1位于屏幕中心，根据位置偏移
        let centerX = screenWidth/2 + touchZonePosition.xOffset
        let centerY = screenHeight/2
        
        // 计算四个角的位置
        let left = centerX - touchZoneWidth/2 - padding
        let right = centerX + touchZoneWidth/2 + padding
        let top = centerY - touchZoneHeight/2 - padding
        let bottom = centerY + touchZoneHeight/2 + padding
        
        ZStack {
            // 左上角
            Path { path in
                path.move(to: CGPoint(x: left, y: top + cornerLength))
                path.addLine(to: CGPoint(x: left, y: top))
                path.addLine(to: CGPoint(x: left + cornerLength, y: top))
            }
            .stroke(Color.yellow, lineWidth: lineWidth)
            
            // 右上角
            Path { path in
                path.move(to: CGPoint(x: right - cornerLength, y: top))
                path.addLine(to: CGPoint(x: right, y: top))
                path.addLine(to: CGPoint(x: right, y: top + cornerLength))
            }
            .stroke(Color.yellow, lineWidth: lineWidth)
            
            // 左下角
            Path { path in
                path.move(to: CGPoint(x: left, y: bottom - cornerLength))
                path.addLine(to: CGPoint(x: left, y: bottom))
                path.addLine(to: CGPoint(x: left + cornerLength, y: bottom))
            }
            .stroke(Color.yellow, lineWidth: lineWidth)
            
            // 右下角
            Path { path in
                path.move(to: CGPoint(x: right - cornerLength, y: bottom))
                path.addLine(to: CGPoint(x: right, y: bottom))
                path.addLine(to: CGPoint(x: right, y: bottom - cornerLength))
            }
            .stroke(Color.yellow, lineWidth: lineWidth)
        }
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isVisible)
    }
}

class ScreenshotManager: ObservableObject {
    static let shared = ScreenshotManager()
    
    // 添加动画状态
    @Published var isFlashing = false
    
    // 添加原始图像引用
    private var originalImage: UIImage?
    private var mirroredImage: UIImage?
    
    // 添加设置图像的方法
    func setImages(original: UIImage?, mirrored: UIImage?) {
        self.originalImage = original
        self.mirroredImage = mirrored
    }
    
    func captureDoubleScreens() {
        print("------------------------")
        print("[截图] 开始双屏截图")
        print("------------------------")
        
        // 检查相册权限
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                // 确保在主线程执行UI操作
                DispatchQueue.main.async {
                    // 获取并裁剪两个屏幕的图像
                    guard let originalImage = self.originalImage,
                          let mirroredImage = self.mirroredImage else {
                        print("------------------------")
                        print("[截图] 错误：无法获取摄像头画面")
                        print("------------------------")
                        return
                    }
                    
                    // 裁剪两个屏幕的图像
                    let croppedOriginal = self.cropImageToScreenSize(originalImage, for: .original)
                    let croppedMirrored = self.cropImageToScreenSize(mirroredImage, for: .mirrored)
                    
                    // 创建最终的双屏截图
                    let finalScreenshot = self.combineImages(top: croppedOriginal, bottom: croppedMirrored)
                    
                    // 保存到相册
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetChangeRequest.creationRequestForAsset(from: finalScreenshot)
                    }) { success, error in
                        DispatchQueue.main.async {
                            if success {
                                print("------------------------")
                                print("[截图] 双屏截图已保存到相册")
                                print("------------------------")
                                
                                // 显示截图成功动画
                                self.isFlashing = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    self.isFlashing = false
                                }
                            } else {
                                print("------------------------")
                                print("[截图] 保存失败：\(error?.localizedDescription ?? "未知错误")")
                                print("------------------------")
                            }
                        }
                    }
                }
            } else {
                print("------------------------")
                print("[截图] 错误：没有相册访问权限")
                print("------------------------")
            }
        }
    }
    
    // 裁剪图片到屏幕大小
    private func cropImageToScreenSize(_ image: UIImage, for screenID: ScreenID) -> UIImage {
        let screenBounds = UIScreen.main.bounds
        let screenWidth = screenBounds.width
        let screenHeight = screenBounds.height
        
        // 计算显示区域的尺寸（屏幕的一半高度）
        let viewportWidth = screenWidth
        let viewportHeight = screenHeight / 2
        
        // 计算图片缩放后的实际尺寸
        let scale = image.size.width / screenWidth  // 图片相对于屏幕的缩放比例
        let scaledImageWidth = image.size.width
        let scaledImageHeight = image.size.height
        
        // 计算基础偏移（图片中心到显示区域中心的距离）
        let baseOffsetY = (scaledImageHeight - viewportHeight * scale) / 2
        
        // 计算可见区域在原始图片中的位置
        let visibleX = (scaledImageWidth - viewportWidth * scale) / 2
        let visibleY = baseOffsetY
        
        let visibleWidth = viewportWidth * scale
        let visibleHeight = viewportHeight * scale
        
        // 确保裁剪区域不超出图片范围
        let safeCropX = max(0, min(visibleX, image.size.width - visibleWidth))
        let safeCropY = max(0, min(visibleY, image.size.height - visibleHeight))
        let safeCropWidth = min(visibleWidth, image.size.width - safeCropX)
        let safeCropHeight = min(visibleHeight, image.size.height - safeCropY)
        
        // 创建裁剪区域
        let cropRect = CGRect(x: safeCropX, y: safeCropY, width: safeCropWidth, height: safeCropHeight)
        
        // 从原图中裁剪指定区域
        if let cgImage = image.cgImage?.cropping(to: cropRect) {
            return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
        }
        
        return image
    }
    
    // 合并两个图片
    private func combineImages(top: UIImage, bottom: UIImage) -> UIImage {
        let screenBounds = UIScreen.main.bounds
        let orientation = UIDevice.current.orientation
        
        // 根据设备方向决定最终图片的尺寸和拼接方式
        let finalSize: CGSize
        let isLandscape = orientation.isLandscape
        
        if isLandscape {
            // 横屏时，最终图片的宽度是屏幕高度，高度是屏幕宽度
            finalSize = CGSize(width: screenBounds.height, height: screenBounds.width)
        } else {
            // 竖屏时，最终图片的宽度是屏幕宽度，高度是屏幕高度
            finalSize = CGSize(width: screenBounds.width, height: screenBounds.height)
        }
        
        UIGraphicsBeginImageContextWithOptions(finalSize, false, 0.0)
        let context = UIGraphicsGetCurrentContext()!
        
        // 根据设备方向进行不同的处理
        switch orientation {
        case .landscapeLeft:
            // 向左横屏：垂直拼接后逆时针旋转90度
            context.translateBy(x: 0, y: finalSize.height)
            context.rotate(by: -CGFloat.pi / 2)
            // 在旋转后的坐标系中绘制
            let drawHeight = finalSize.height
            let drawWidth = finalSize.width
            top.draw(in: CGRect(x: 0, y: 0, width: drawHeight, height: drawWidth/2))
            bottom.draw(in: CGRect(x: 0, y: drawWidth/2, width: drawHeight, height: drawWidth/2))
            
        case .landscapeRight:
            // 向右横屏：垂直拼接后顺时针旋转90度
            context.translateBy(x: finalSize.width, y: 0)
            context.rotate(by: CGFloat.pi / 2)
            // 在旋转后的坐标系中绘制
            let drawHeight = finalSize.height
            let drawWidth = finalSize.width
            top.draw(in: CGRect(x: 0, y: 0, width: drawHeight, height: drawWidth/2))
            bottom.draw(in: CGRect(x: 0, y: drawWidth/2, width: drawHeight, height: drawWidth/2))
            
        case .portraitUpsideDown:
            // 倒置竖屏：垂直拼接后旋转180度
            context.translateBy(x: finalSize.width, y: finalSize.height)
            context.rotate(by: CGFloat.pi)
            top.draw(in: CGRect(x: 0, y: 0, width: finalSize.width, height: finalSize.height/2))
            bottom.draw(in: CGRect(x: 0, y: finalSize.height/2, width: finalSize.width, height: finalSize.height/2))
            
        default:
            // 正常竖屏：直接垂直拼接
            top.draw(in: CGRect(x: 0, y: 0, width: finalSize.width, height: finalSize.height/2))
            bottom.draw(in: CGRect(x: 0, y: finalSize.height/2, width: finalSize.width, height: finalSize.height/2))
        }
        
        let combinedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return combinedImage ?? UIImage()
    }
} 