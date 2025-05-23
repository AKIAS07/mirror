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
                        
                        // 确认、分享和取消按钮
                        if showButtons {
                            HStack(spacing:30) {
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
                                    Image(systemName: "square.and.arrow.down.fill")
                                        .font(.system(size: 30))
                                        .foregroundColor(.white)
                                }
                                
                                // 分享按钮
                                Button(action: {
                                    screenshotManager.shareScreenshot()
                                }) {
                                    Image(systemName: "arrowshape.turn.up.right.fill")
                                        .font(.system(size: 30))
                                        .foregroundColor(.white)
                                }
                                
                                // 取消按钮
                                Button(action: {
                                    hidePreview()
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 30))
                                        .foregroundColor(.white)
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
    @Published var showPreview = false  // 添加新的状态控制预览显示
    
    private var originalImage: UIImage?
    private var mirroredImage: UIImage?
    private var pendingScreenshot: UIImage?
    private var originalCameraScale: CGFloat = 1.0
    private var mirroredCameraScale: CGFloat = 1.0
    private var isScreenSwapped: Bool = false  // 添加屏幕交换状态追踪
    
    init(imageUploader: ImageUploader = ImageUploader()) {
        self.imageUploader = imageUploader
    }
    
    // 添加更新屏幕交换状态的方法
    func updateScreenSwapState(_ isSwapped: Bool) {
        print("------------------------")
        print("[截图] 更新屏幕交换状态")
        print("之前状态：\(self.isScreenSwapped ? "已交换" : "未交换")")
        print("新状态：\(isSwapped ? "已交换" : "未交换")")
        print("------------------------")
        self.isScreenSwapped = isSwapped
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
    
    func takeScreenshot() {
        print("[截图] 开始处理")
        
        // 直接执行截图，不触发闪光动画
        DispatchQueue.main.async {
            self.performScreenshot()
            // 添加这一行，显示预览
            self.showPreview = true
        }
    }
    
    private func performScreenshot() {
        // 使用当前有效方向来决定布局
        let currentOrientation = DeviceOrientationManager.shared.validOrientation
        let isLandscape = currentOrientation.isLandscape
        
        print("[截图] 当前设备方向：\(currentOrientation)")
        print("[截图] 是否横屏：\(isLandscape)")
        
        // 获取当前的摄像头缩放比例
        let originalScale = self.originalImage != nil ? self.originalCameraScale : 1.0
        let mirroredScale = self.mirroredImage != nil ? self.mirroredCameraScale : 1.0
        
        print("[截图] Original摄像头缩放: \(Int(originalScale * 100))%")
        print("[截图] Mirrored摄像头缩放: \(Int(mirroredScale * 100))%")
        
        // 获取两个屏幕的图片，优先使用定格的图片
        let finalOriginalImage = self.imageUploader.getCurrentFrame(for: .original) ?? self.originalImage
        let finalMirroredImage = self.imageUploader.getCurrentFrame(for: .mirrored) ?? self.mirroredImage
        
        // 使用获取到的图片
        guard let originalImage = finalOriginalImage,
              let mirroredImage = finalMirroredImage else {
            print("[截图] 错误：无法获取图片")
            return
        }
        
        print("[截图] 已获取图片")
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
    }
    
    // 修改 createCombinedImage 方法
    private func createCombinedImage(top: UIImage, bottom: UIImage, isLandscape: Bool) -> UIImage {
        print("------------------------")
        print("[截图合并] 开始")
        print("当前布局：\(isScreenSwapped ? "Mirrored在上，Original在下" : "Original在上，Mirrored在下")")
        print("Top图片尺寸: \(Int(top.size.width))x\(Int(top.size.height))")
        print("Bottom图片尺寸: \(Int(bottom.size.width))x\(Int(bottom.size.height))")
        print("是否横屏: \(isLandscape)")
        
        let screenBounds = UIScreen.main.bounds
        let currentOrientation = DeviceOrientationManager.shared.currentOrientation
        
        // 根据最后的有效方向决定最终图片的尺寸
        let finalSize = isLandscape 
            ? CGSize(width: screenBounds.height, height: screenBounds.width)
            : CGSize(width: screenBounds.width, height: screenBounds.height)
        
        print("最终尺寸: \(Int(finalSize.width))x\(Int(finalSize.height))")
        print("当前设备方向: \(currentOrientation)")
        
        // 定义图片布局结构
        struct ImageLayout {
            let first: UIImage
            let second: UIImage
            let firstFrame: CGRect
            let secondFrame: CGRect
        }
        
        // 获取布局配置
        func getLayout() -> ImageLayout {
            // 根据当前的分屏布局状态决定图片顺序
            let (firstImage, secondImage) = isScreenSwapped ? (bottom, top) : (top, bottom)
            
            switch currentOrientation {
            case .portrait:
                // 正常竖屏
                let firstFrame = CGRect(x: 0, y: 0, 
                                      width: finalSize.width, height: finalSize.height/2)
                let secondFrame = CGRect(x: 0, y: finalSize.height/2, 
                                       width: finalSize.width, height: finalSize.height/2)
                return ImageLayout(first: firstImage, second: secondImage,
                                 firstFrame: firstFrame, secondFrame: secondFrame)
                
            case .portraitUpsideDown:
                // 倒置竖屏 - 交换上下位置
                let firstFrame = CGRect(x: 0, y: finalSize.height/2, 
                                      width: finalSize.width, height: finalSize.height/2)
                let secondFrame = CGRect(x: 0, y: 0, 
                                       width: finalSize.width, height: finalSize.height/2)
                return ImageLayout(first: firstImage, second: secondImage,
                                 firstFrame: firstFrame, secondFrame: secondFrame)
                
            case .landscapeLeft:
                // 向左横屏
                let firstFrame = CGRect(x: 0, y: 0, 
                                      width: finalSize.width/2, height: finalSize.height)
                let secondFrame = CGRect(x: finalSize.width/2, y: 0, 
                                       width: finalSize.width/2, height: finalSize.height)
                return ImageLayout(first: firstImage, second: secondImage,
                                 firstFrame: firstFrame, secondFrame: secondFrame)
                
            case .landscapeRight:
                // 向右横屏 - 交换左右位置
                let firstFrame = CGRect(x: finalSize.width/2, y: 0, 
                                      width: finalSize.width/2, height: finalSize.height)
                let secondFrame = CGRect(x: 0, y: 0, 
                                       width: finalSize.width/2, height: finalSize.height)
                return ImageLayout(first: firstImage, second: secondImage,
                                 firstFrame: firstFrame, secondFrame: secondFrame)
                
            default:
                // 默认使用正常竖屏布局
                let firstFrame = CGRect(x: 0, y: 0, 
                                      width: finalSize.width, height: finalSize.height/2)
                let secondFrame = CGRect(x: 0, y: finalSize.height/2, 
                                       width: finalSize.width, height: finalSize.height/2)
                return ImageLayout(first: firstImage, second: secondImage,
                                 firstFrame: firstFrame, secondFrame: secondFrame)
            }
        }
        
        // 创建图片上下文并绘制
        UIGraphicsBeginImageContextWithOptions(finalSize, true, 0.0)
        
        // 填充背景色
        UIColor.black.setFill()
        UIRectFill(CGRect(origin: .zero, size: finalSize))
        
        // 获取并应用布局
        let layout = getLayout()
        layout.first.draw(in: layout.firstFrame)
        layout.second.draw(in: layout.secondFrame)
        
        // 在中心添加触控区1的图标
        if let iconImage = getIconImage(for: DeviceOrientationManager.shared.currentOrientation) {
            // 计算图标大小 (40x40 pt)
            let iconSize = CGSize(width: 40, height: 40)
            
            // 计算图标位置（居中）
            let iconX = (finalSize.width - iconSize.width) / 2
            let iconY = (finalSize.height - iconSize.height) / 2
            let iconRect = CGRect(origin: CGPoint(x: iconX, y: iconY), size: iconSize)
            
            // 获取图标颜色
            let iconColor = BorderLightStyleManager.shared.splitScreenIconColor
            
            if iconColor == .purple || BorderLightStyleManager.shared.splitScreenIconImage.hasPrefix("color") {
                // 直接绘制原始图标（彩色图标）
                iconImage.draw(in: iconRect)
            } else {
                // 为其他颜色创建着色的图标
                if let cgImage = iconImage.cgImage {
                    let tintedImage = UIImage(cgImage: cgImage, scale: iconImage.scale, orientation: iconImage.imageOrientation)
                        .withTintColor(UIColor(iconColor), renderingMode: .alwaysTemplate)
                    tintedImage.draw(in: iconRect)
                }
            }
        }
        
        let combinedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        print("[截图合并] 完成")
        print("合并后尺寸: \(Int(combinedImage?.size.width ?? 0))x\(Int(combinedImage?.size.height ?? 0))")
        print("------------------------")
        
        return combinedImage ?? UIImage()
    }
    
    // 添加获取图标图片的辅助方法
    private func getIconImage(for orientation: UIDeviceOrientation) -> UIImage? {
        let styleManager = BorderLightStyleManager.shared
        
        // 确定图标名称
        let iconName: String
        if styleManager.splitScreenIconImage.hasPrefix("color") {
            // 如果是自定义颜色图标，直接使用
            iconName = styleManager.splitScreenIconImage
        } else if styleManager.splitScreenIconColor == .purple {
            // 使用彩色图标逻辑
            switch orientation {
            case .landscapeLeft:
                iconName = isScreenSwapped ? "icon-bf-color-3" : "icon-bf-color-4"
            case .landscapeRight:
                iconName = isScreenSwapped ? "icon-bf-color-4" : "icon-bf-color-3"
            case .portraitUpsideDown:
                iconName = isScreenSwapped ? "icon-bf-color-1" : "icon-bf-color-2"
            default: // 正常竖屏
                iconName = isScreenSwapped ? "icon-bf-color-2" : "icon-bf-color-1"
            }
        } else {
            // 使用白色轮廓图标
            iconName = "icon-bf-white"
        }
        
        // 获取图片
        let image = UIImage(named: iconName)
        
        // 如果是紫色模式，直接返回原始彩色图标
        if styleManager.splitScreenIconColor == .purple {
            return image
        }
        
        // 对于其他颜色，需要应用颜色
        if let cgImage = image?.cgImage {
            return UIImage(cgImage: cgImage, scale: image?.scale ?? 1.0, orientation: image?.imageOrientation ?? .up)
        }
        
        return image
    }
    
    // 修改 saveScreenshot 方法
    func saveScreenshot() {
        guard let screenshot = pendingScreenshot else { return }
        
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        switch status {
        case .authorized, .limited:
            // 已有权限，直接保存
            performSaveScreenshot(screenshot) { [weak self] success in
                if success {
                    // 显示自定义成功提示文字
                    withAnimation {
                        self?.showPreview = false  // 隐藏预览
                    }
                }
            }
            
        case .notDetermined:
            // 未确定状态，先显示自定义权限弹窗
            PermissionManager.shared.handlePhotoLibraryAccess(for: screenshot) { [weak self] success in
                if success {
                    // 用户在系统弹窗中允许后，保存图片
                    self?.performSaveScreenshot(screenshot) { success in
                        if success {
                            // 显示自定义成功提示文字
                            withAnimation {
                                self?.showPreview = false  // 隐藏预览
                            }
                        }
                    }
                }
            }
            
        case .denied, .restricted:
            // 已拒绝，显示去设置的弹窗
            PermissionManager.shared.alertState = .permission(isFirstRequest: false)
            
        @unknown default:
            break
        }
    }
    
    // 修改 performSaveScreenshot 方法，添加完成回调
    private func performSaveScreenshot(_ screenshot: UIImage, completion: @escaping (Bool) -> Void = { _ in }) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: screenshot)
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("[截图] 双屏截图已保存到相册")
                    completion(true)
                } else {
                    print("[截图] 保存失败：\(error?.localizedDescription ?? "未知错误")")
                    completion(false)
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
    
    // 分享截图
    func shareScreenshot() {
        guard let screenshot = pendingScreenshot else { return }
        
        // 先隐藏预览
        withAnimation {
            showPreview = false
        }
        
        // 延迟一小段时间后再显示分享界面
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let activityViewController = UIActivityViewController(
                activityItems: [screenshot],
                applicationActivities: nil
            )
            
            // 在 iPad 上需要设置弹出位置
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                
                if let popoverController = activityViewController.popoverPresentationController {
                    popoverController.sourceView = window
                    popoverController.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                    popoverController.permittedArrowDirections = []
                }
                
                // 获取最顶层的视图控制器
                if let rootViewController = window.rootViewController {
                    var topController = rootViewController
                    while let presentedViewController = topController.presentedViewController {
                        topController = presentedViewController
                    }
                    
                    // 如果当前有正在显示的视图控制器，先关闭它
                    if topController.presentedViewController != nil {
                        topController.dismiss(animated: true) {
                            topController.present(activityViewController, animated: true) {
                                print("[截图] 分享界面已显示")
                            }
                        }
                    } else {
                        topController.present(activityViewController, animated: true) {
                            print("[截图] 分享界面已显示")
                        }
                    }
                }
            }
        }
    }
} 