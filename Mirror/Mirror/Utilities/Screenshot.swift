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
    @State private var showButtons = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
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
                        
                        // 确认和取消按钮
                        if showButtons {
                            HStack(spacing: 40) {
                                // 确认按钮
                                Button(action: {
                                    screenshotManager.saveScreenshot()
                                    withAnimation {
                                        showText = true
                                        showButtons = false
                                    }
                                    // 显示保存文本后淡出
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                        hidePreview()
                                    }
                                }) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 44))
                                        .foregroundColor(.white)
                                }
                                
                                // 取消按钮
                                Button(action: {
                                    hidePreview()
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 44))
                                        .foregroundColor(.black)
                                }
                            }
                            .offset(getButtonsOffset(geometry))
                            .rotationEffect(getRotationAngle(orientationManager.currentOrientation))
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
                            fullScreenOpacity = 1
                        }
                        
                        // 执行缩小动画
                        withAnimation(.easeInOut(duration: 0.6)) {
                            fullScreenScale = 0.7
                        }
                        
                        // 显示按钮
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            withAnimation {
                                showButtons = true
                            }
                        }
                    }
                }
            }
        }
    }
    
    // 隐藏预览的辅助函数
    private func hidePreview() {
        withAnimation(.easeInOut(duration: 0.4)) {
            fullScreenOpacity = 0
            showText = false
            showButtons = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            showFullScreenAnimation = false
            fullScreenScale = 1.0
            isVisible = false
        }
    }
    
    // 获取旋转角度
    private func getRotationAngle(_ orientation: UIDeviceOrientation) -> Angle {
        let angle: Double
        switch orientation {
        case .landscapeLeft:
            angle = 90
        case .landscapeRight:
            angle = -90
        case .portraitUpsideDown:
            angle = 180
        default:
            angle = 0
        }
        print("[Debug] 当前旋转角度: \(angle)度")
        return .degrees(angle)
    }
    
    // 获取预览图片尺寸
    private func getPreviewSize(_ geometry: GeometryProxy) -> CGSize {
        let orientation = orientationManager.currentOrientation
        
        // 获取实际可用屏幕尺寸（去除安全区域的影响）
        let safeScreenSize = CGSize(
            width: UIScreen.main.bounds.width,
            height: UIScreen.main.bounds.height
        )
        
        // 使用实际屏幕尺寸进行计算
        let effectiveSize = orientation.isLandscape
            ? CGSize(width: safeScreenSize.height, height: safeScreenSize.width)
            : safeScreenSize
        
        // 计算最大尺寸和缩放比例
        let maxDimension = min(effectiveSize.width, effectiveSize.height) * 0.8
        let aspectRatio = effectiveSize.height / effectiveSize.width
        
        let size: CGSize
        if orientation.isLandscape {
            size = CGSize(
                width: maxDimension,
                height: maxDimension * aspectRatio
            )
        } else {
            size = CGSize(
                width: maxDimension,
                height: maxDimension * aspectRatio
            )
        }
        
        // print("""
        //     [Debug] 预览尺寸计算:
        //     - 原始屏幕尺寸: \(screenSize)
        //     - 实际屏幕尺寸: \(safeScreenSize)
        //     - 有效尺寸: \(effectiveSize)
        //     - 最大维度: \(maxDimension)
        //     - 最终尺寸: \(size)
        //     - 是否横屏: \(orientation.isLandscape)
        //     - 旋转角度: \(getRotationAngle(orientation).degrees)
        //     - 宽高比: \(aspectRatio)
        //     """)
        
        return size
    }
    
    // 获取容器位置
    private func getContainerPosition(_ geometry: GeometryProxy) -> CGPoint {
        let orientation = orientationManager.currentOrientation
        
        // 使用实际屏幕尺寸
        let screenSize = UIScreen.main.bounds.size
        
        // 计算中心点（考虑安全区域）
        let position = CGPoint(
            x: screenSize.width / 2,
            y: screenSize.height / 2
        )
        
        print("""
            [Debug] 容器位置:
            - 位置: \(position)
            - 实际屏幕尺寸: \(screenSize)
            - 是否横屏: \(orientation.isLandscape)
            - 旋转角度: \(getRotationAngle(orientation).degrees)
            """)
        
        return position
    }
    
    // 获取文本偏移
    private func getTextOffset(_ geometry: GeometryProxy) -> CGSize {
        let offset = CGSize(width: 0, height: 0)
        print("[Debug] 文本偏移: \(offset)")
        return offset
    }
    
    // 获取按钮偏移的方法
    private func getButtonsOffset(_ geometry: GeometryProxy) -> CGSize {
        let orientation = orientationManager.currentOrientation
        let previewSize = getPreviewSize(geometry)
        let verticalOffset = previewSize.height * fullScreenScale / 2 + 50
        
        switch orientation {
        case .landscapeLeft:
            return CGSize(width: 0, height: verticalOffset)
        case .landscapeRight:
            return CGSize(width: 0, height: verticalOffset)
        case .portraitUpsideDown:
            return CGSize(width: 0, height: verticalOffset)
        default: // 正常竖屏
            return CGSize(width: 0, height: verticalOffset)
        }
    }
}

class ScreenshotManager: ObservableObject {
    static let shared = ScreenshotManager()
    private let imageUploader: ImageUploader
    
    @Published var isFlashing = false
    @Published var previewImage: UIImage?
    
    private var originalImage: UIImage?
    private var mirroredImage: UIImage?
    private var pendingScreenshot: UIImage?
    private var originalCameraScale: CGFloat = 1.0
    private var mirroredCameraScale: CGFloat = 1.0
    
    init(imageUploader: ImageUploader = ImageUploader()) {
        self.imageUploader = imageUploader
    }
    
    func setImages(
        original: UIImage?,
        mirrored: UIImage?,
        originalCameraScale: CGFloat = 1.0,
        mirroredCameraScale: CGFloat = 1.0
    ) {
        self.originalImage = original
        self.mirroredImage = mirrored
        self.originalCameraScale = originalCameraScale
        self.mirroredCameraScale = mirroredCameraScale
    }
    
    func captureDoubleScreens() {
        print("------------------------")
        print("[截图] 开始双屏截图")
        print("------------------------")
        
        // 检查相册权限
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            if status == .authorized {
                DispatchQueue.main.async(execute: DispatchWorkItem(block: {
                    // 使用当前有效方向来决定布局
                    let currentOrientation = DeviceOrientationManager.shared.validOrientation
                    let isLandscape = currentOrientation.isLandscape
                    
                    print("[截图] 当前设备方向：\(currentOrientation)")
                    print("[截图] 是否横屏：\(isLandscape)")
                    
                    // 获取当前的摄像头缩放比例
                    let originalScale = self.originalCameraScale
                    let mirroredScale = self.mirroredCameraScale
                    
                    print("[截图] Original摄像头缩放: \(Int(originalScale * 100))%")
                    print("[截图] Mirrored摄像头缩放: \(Int(mirroredScale * 100))%")
                    
                    // 使用已经存储的图片
                    guard let originalImage = self.originalImage,
                          let mirroredImage = self.mirroredImage else {
                        print("[截图] 错误：无法获取定格图片")
                        return
                    }
                    
                    print("[截图] 已获取定格图片")
                    print("Original尺寸：\(Int(originalImage.size.width))x\(Int(originalImage.size.height))")
                    print("Mirrored尺寸：\(Int(mirroredImage.size.width))x\(Int(mirroredImage.size.height))")
                    
                    // 裁剪图片时传入当前方向
                    let croppedOriginal = ImageCropUtility.shared.cropImageToScreenSize(
                        originalImage,
                        for: .original,
                        isLandscape: isLandscape,
                        pausedOrientation: currentOrientation,
                        scale: 1.0,
                        cameraScale: originalScale
                    )
                    
                    let croppedMirrored = ImageCropUtility.shared.cropImageToScreenSize(
                        mirroredImage,
                        for: .mirrored,
                        isLandscape: isLandscape,
                        pausedOrientation: currentOrientation,
                        scale: 1.0,
                        cameraScale: mirroredScale
                    )
                    
                    // 创建最终的截图
                    let finalScreenshot = self.createCombinedImage(
                        top: croppedOriginal,
                        bottom: croppedMirrored,
                        isLandscape: isLandscape
                    )
                    
                    // 验证最终截图
                    if finalScreenshot.size.width == 0 || finalScreenshot.size.height == 0 {
                        print("[截图] 错误：生成的截图尺寸无效")
                        return
                    }
                    
                    // 保存预览图片和待保存的截图
                    self.previewImage = finalScreenshot
                    self.pendingScreenshot = finalScreenshot
                    
                    print("[截图] 最终截图尺寸：\(Int(finalScreenshot.size.width))x\(Int(finalScreenshot.size.height))")
                    
                    // 触发闪光动画
                    self.isFlashing = true
                    Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                        self.isFlashing = false
                    }
                }))
            } else {
                print("[截图] 错误：没有相册访问权限")
            }
        }
    }
    
    // 修改 createCombinedImage 方法
    private func createCombinedImage(top: UIImage, bottom: UIImage, isLandscape: Bool) -> UIImage {
        print("------------------------")
        print("[截图合并] 开始")
        print("Top图片尺寸: \(Int(top.size.width))x\(Int(top.size.height))")
        print("Bottom图片尺寸: \(Int(bottom.size.width))x\(Int(bottom.size.height))")
        print("是否横屏: \(isLandscape)")
        
        let screenBounds = UIScreen.main.bounds
        
        // 根据最后的有效方向决定最终图片的尺寸
        let finalSize = isLandscape 
            ? CGSize(width: screenBounds.height, height: screenBounds.width)
            : CGSize(width: screenBounds.width, height: screenBounds.height)
        
        print("最终尺寸: \(Int(finalSize.width))x\(Int(finalSize.height))")
        
        UIGraphicsBeginImageContextWithOptions(finalSize, true, 0.0)  // 修改这里，设置 opaque 为 true
        
        // 填充背景色
        UIColor.black.setFill()
        UIRectFill(CGRect(origin: .zero, size: finalSize))
        
        if isLandscape {
            // 横屏：左右布局
            top.draw(in: CGRect(x: 0, y: 0, width: finalSize.width/2, height: finalSize.height))
            bottom.draw(in: CGRect(x: finalSize.width/2, y: 0, width: finalSize.width/2, height: finalSize.height))
        } else {
            // 竖屏：上下布局
            top.draw(in: CGRect(x: 0, y: 0, width: finalSize.width, height: finalSize.height/2))
            bottom.draw(in: CGRect(x: 0, y: finalSize.height/2, width: finalSize.width, height: finalSize.height/2))
        }
        
        let combinedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        print("[截图合并] 完成")
        print("合并后尺寸: \(Int(combinedImage?.size.width ?? 0))x\(Int(combinedImage?.size.height ?? 0))")
        print("------------------------")
        
        return combinedImage ?? UIImage()
    }
    
    // 保存截图到相册
    func saveScreenshot() {
        guard let screenshot = pendingScreenshot else { return }
        
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: screenshot)
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("[截图] 双屏截图已保存到相册")
                } else {
                    print("[截图] 保存失败：\(error?.localizedDescription ?? "未知错误")")
                }
                self.pendingScreenshot = nil
            }
        }
    }
    
    // 修改裁剪图片到屏幕大小的方法
    private func cropImageToScreenSize(
        _ image: UIImage,
        for screenID: ScreenID,
        isLandscape: Bool = false,
        cameraScale: CGFloat = 1.0
    ) -> UIImage {
        print("------------------------")
        print("[截图] 裁剪图片")
        print("屏幕：\(screenID == .original ? "Original" : "Mirrored")")
        print("摄像头缩放比例：\(Int(cameraScale * 100))%")
        print("------------------------")
        
        // 使用ImageCropUtility进行裁剪，传入摄像头缩放比例
        return ImageCropUtility.shared.cropImageToScreenSize(
            image,
            for: screenID,
            isLandscape: isLandscape,
            scale: 1.0,  // 这里使用1.0因为我们已经在setPausedImage时应用了缩放
            cameraScale: cameraScale
        )
    }
} 