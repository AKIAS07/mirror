import SwiftUI
import UIKit
import Photos


// 添加截图动画视图
struct ScreenshotAnimationView: View {
    @Binding var isVisible: Bool
    @ObservedObject var screenshotManager = ScreenshotManager.shared
    let touchZonePosition: TouchZonePosition  // 添加触控区位置参数
    
    // 添加全屏动画状态
    @State private var showFullScreenAnimation = false
    @State private var fullScreenScale: CGFloat = 1.0
    @State private var fullScreenOpacity: Double = 0.0
    @State private var showText = false
    
    var body: some View {
        ZStack {
            // 全屏动画
            if showFullScreenAnimation, let previewImage = screenshotManager.previewImage {
                Rectangle()
                    .fill(Color.black.opacity(0.5))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(fullScreenOpacity)
                
                // 截图预览
                Image(uiImage: previewImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: UIScreen.main.bounds.width * 0.8, height: UIScreen.main.bounds.height * 0.8)
                    .cornerRadius(20)
                    .scaleEffect(fullScreenScale)
                    .opacity(fullScreenOpacity)
                
                // 保存提示文本
                Text("已保存到相册")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
                    .opacity(showText ? 1 : 0)
                    .offset(y: UIScreen.main.bounds.height * 0.3)
                    .animation(.easeInOut(duration: 0.3), value: showText)
            }
        }
        .onChange(of: isVisible) { newValue in
            if newValue {
                // 延迟执行全屏动画，给图片处理留出更多时间
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    // 使用较慢的动画速度，减少帧率压力
                    withAnimation(.easeInOut(duration: 0.4)) {
                        showFullScreenAnimation = true
                        fullScreenOpacity = 0.8  // 降低透明度，减少渲染压力
                    }
                    
                    // 执行缩小动画
                    withAnimation(.easeInOut(duration: 0.6)) {
                        fullScreenScale = 0.3
                    }
                    
                    // 缩小动画结束后显示文本
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        showText = true
                        
                        // 停留1秒后再开始淡出动画
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            // 执行淡出动画
                            withAnimation(.easeInOut(duration: 0.4)) {
                                fullScreenOpacity = 0
                                showText = false
                            }
                            
                            // 重置状态
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                showFullScreenAnimation = false
                                fullScreenScale = 1.0
                                isVisible = false
                            }
                        }
                    }
                }
            } else {
                // 重置所有状态
                showText = false
                showFullScreenAnimation = false
                fullScreenScale = 1.0
                fullScreenOpacity = 0
            }
        }
    }
}

class ScreenshotManager: ObservableObject {
    static let shared = ScreenshotManager()
    
    // 添加动画状态
    @Published var isFlashing = false
    // 添加截图预览
    @Published var previewImage: UIImage?
    
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
                    // 获取当前设备方向
                    let isLandscape = UIDevice.current.orientation.isLandscape
                    print("[截图] 当前设备方向：\(isLandscape ? "横屏" : "竖屏")")
                    
                    // 获取并裁剪两个屏幕的图像
                    guard let originalImage = self.originalImage,
                          let mirroredImage = self.mirroredImage else {
                        print("------------------------")
                        print("[截图] 错误：无法获取摄像头画面")
                        print("------------------------")
                        return
                    }
                    
                    // 根据实际方向裁剪两个屏幕的图像
                    let croppedOriginal = self.cropImageToScreenSize(originalImage, for: .original, isLandscape: isLandscape)
                    let croppedMirrored = self.cropImageToScreenSize(mirroredImage, for: .mirrored, isLandscape: isLandscape)
                    
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
                                
                                // 设置预览图片
                                self.previewImage = finalScreenshot
                                
                                // 延长延迟时间，减少动画和图片处理的重叠
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                    self.isFlashing = true
                                    // 延长动画持续时间
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                        self.isFlashing = false
                                        self.previewImage = nil  // 清理预览图片
                                    }
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
    private func cropImageToScreenSize(_ image: UIImage, for screenID: ScreenID, isLandscape: Bool = false) -> UIImage {
        // 使用ImageCropUtility进行裁剪，使用默认的零偏移量
        return ImageCropUtility.shared.cropImageToScreenSize(
            image,
            for: screenID,
            isLandscape: isLandscape
        )
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
        let _ = UIGraphicsGetCurrentContext()!
        
        // 根据设备方向进行不同的处理
        switch orientation {
        case .landscapeLeft:
            //向左横屏
            top.draw(in: CGRect(x: 0, y: 0, width: finalSize.width/2, height: finalSize.height))
            bottom.draw(in: CGRect(x: finalSize.width/2, y: 0, width: finalSize.width/2, height: finalSize.height))
            
        case .landscapeRight:
            // 向右横屏
            top.draw(in: CGRect(x: 0, y: 0, width: finalSize.width/2, height: finalSize.height))
            bottom.draw(in: CGRect(x: finalSize.width/2, y: 0, width: finalSize.width/2, height: finalSize.height))
            
        case .portraitUpsideDown:
            // 倒置竖屏
            top.draw(in: CGRect(x: 0, y: 0, width: finalSize.width, height: finalSize.height/2))
            bottom.draw(in: CGRect(x: 0, y: finalSize.height/2, width: finalSize.width, height: finalSize.height/2))
            
        default:
            // 正常竖屏
            top.draw(in: CGRect(x: 0, y: 0, width: finalSize.width, height: finalSize.height/2))
            bottom.draw(in: CGRect(x: 0, y: finalSize.height/2, width: finalSize.width, height: finalSize.height/2))
        }
        
        let combinedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return combinedImage ?? UIImage()
    }
} 