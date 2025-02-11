import SwiftUI
import UIKit
import Photos


// 修改截图动画视图
struct ScreenshotAnimationView: View {
    @Binding var isVisible: Bool
    @ObservedObject var screenshotManager = ScreenshotManager.shared
    @ObservedObject var orientationManager = DeviceOrientationManager.shared
    let touchZonePosition: TouchZonePosition
    
    @State private var showFullScreenAnimation = false
    @State private var fullScreenScale: CGFloat = 1.0
    @State private var fullScreenOpacity: Double = 0.0
    @State private var showText = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 全屏动画
                if showFullScreenAnimation, let previewImage = screenshotManager.previewImage {
                    // 背景遮罩
                    Rectangle()
                        .fill(Color.black.opacity(0.5))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .opacity(fullScreenOpacity)
                    
                    // 截图预览容器
                    ZStack {
                        // 截图预览
                        Image(uiImage: previewImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: getPreviewSize(geometry).width,
                                   height: getPreviewSize(geometry).height)
                            .cornerRadius(20)
                            .scaleEffect(fullScreenScale)
                            .opacity(fullScreenOpacity)
                            .rotationEffect(getRotationAngle(orientationManager.currentOrientation))
                        
                        // 保存提示文本
                        if showText {
                            Text("已保存到相册")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(8)
                                .rotationEffect(getRotationAngle(orientationManager.currentOrientation))
                                .offset(getTextOffset(geometry))
                        }
                    }
                    .position(getContainerPosition(geometry))
                }
            }
            .onChange(of: isVisible) { newValue in
                if newValue {
                    // 延迟执行全屏动画
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            showFullScreenAnimation = true
                            fullScreenOpacity = 0.8
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
                }
            }
        }
    }
    
    // 获取旋转角度
    private func getRotationAngle(_ orientation: UIDeviceOrientation) -> Angle {
        switch orientation {
        case .landscapeLeft:
            return .degrees(90)
        case .landscapeRight:
            return .degrees(-90)
        case .portraitUpsideDown:
            return .degrees(180)
        default:
            return .degrees(0)
        }
    }
    
    // 获取预览图片尺寸
    private func getPreviewSize(_ geometry: GeometryProxy) -> CGSize {
        let isLandscape = orientationManager.currentOrientation.isLandscape
        let maxWidth = isLandscape ? geometry.size.height * 0.8 : geometry.size.width * 0.8
        let maxHeight = isLandscape ? geometry.size.width * 0.8 : geometry.size.height * 0.8
        return CGSize(width: maxWidth, height: maxHeight)
    }
    
    // 获取容器位置
    private func getContainerPosition(_ geometry: GeometryProxy) -> CGPoint {
        let isLandscape = orientationManager.currentOrientation.isLandscape
        return CGPoint(
            x: isLandscape ? geometry.size.width / 2 : geometry.size.width / 2,
            y: isLandscape ? geometry.size.height / 2 : geometry.size.height / 2
        )
    }
    
    // 获取文本偏移
    private func getTextOffset(_ geometry: GeometryProxy) -> CGSize {
        let isLandscape = orientationManager.currentOrientation.isLandscape
        return CGSize(
            width: 0,
            height: isLandscape ? geometry.size.width * 0.3 : geometry.size.height * 0.3
        )
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