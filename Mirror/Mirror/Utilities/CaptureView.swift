import SwiftUI
import UIKit
import Photos

// 截图操作按钮样式
public struct CaptureButtonStyle {
    public static let buttonSize: CGFloat = 60
    public static let buttonSpacing: CGFloat = 40
    public static let buttonBackgroundOpacity: Double = 0.5
}

// 截图操作状态
public class CaptureState: ObservableObject {
    @Published public var capturedImage: UIImage?
    @Published public var showButtons: Bool = false
    @Published public var currentScale: CGFloat = 1.0
    @Published public var showSaveSuccess: Bool = false
    @Published public var isCapturing: Bool = false  // 新增：是否正在捕捉过程中
    
    private var isProcessingAlert = false
    
    // 根据缩放比例裁剪图片
    func cropImage(_ image: UIImage, scale: CGFloat) -> UIImage {
        let screenBounds = UIScreen.main.bounds
        let screenSize = screenBounds.size
        
        // 计算图片在屏幕上的实际显示尺寸
        let imageAspect = image.size.width / image.size.height
        let screenAspect = screenSize.width / screenSize.height
        
        var drawWidth: CGFloat
        var drawHeight: CGFloat
        
        if imageAspect > screenAspect {
            // 图片较宽，以高度为基准
            drawHeight = screenSize.height
            drawWidth = drawHeight * imageAspect
        } else {
            // 图片较高，以宽度为基准
            drawWidth = screenSize.width
            drawHeight = drawWidth / imageAspect
        }
        
        // 应用缩放
        let scale = max(1.0, scale)
        drawWidth *= scale
        drawHeight *= scale
        
        // 计算居中位置
        let x = (drawWidth - screenSize.width) / 2
        let y = (drawHeight - screenSize.height) / 2
        
        // 创建绘图上下文
        UIGraphicsBeginImageContextWithOptions(screenSize, false, image.scale)
        
        // 绘制放大后的图片，保持宽高比
        let drawRect = CGRect(x: -x, y: -y, width: drawWidth, height: drawHeight)
        image.draw(in: drawRect)
        
        // 获取裁剪后的图片
        let croppedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return croppedImage ?? image
    }
    
    // 修改保存图片方法
    public func saveToPhotos() {
        guard let image = capturedImage else {
            print("[相册保存] 错误：没有可保存的图片")
            return
        }
        
        let processedImage = cropImage(image, scale: currentScale)
        print("[相册保存] 开始处理图片保存")
        
        // 检查权限状态
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        switch status {
        case .authorized, .limited:
            // 已有权限，直接保存
            saveImageToPhotoLibrary(processedImage) { [weak self] success in
                if success {
                    withAnimation {
                        self?.showSaveSuccess = true
                    }
                    // 使用配置的显示时间
                    DispatchQueue.main.asyncAfter(deadline: .now() + AppConfig.AnimationConfig.Toast.duration) {
                        withAnimation {
                            self?.showSaveSuccess = false
                        }
                    }
                }
            }
            
        case .notDetermined:
            // 未确定状态，显示自定义权限弹窗
            PermissionManager.shared.handlePhotoLibraryAccess(for: processedImage) { [weak self] success in
                if success {
                    self?.saveImageToPhotoLibrary(processedImage) { success in
                        if success {
                            withAnimation {
                                self?.showSaveSuccess = true
                            }
                            // 使用配置的显示时间
                            DispatchQueue.main.asyncAfter(deadline: .now() + AppConfig.AnimationConfig.Toast.duration) {
                                withAnimation {
                                    self?.showSaveSuccess = false
                                }
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
    
    // 添加私有保存方法
    private func saveImageToPhotoLibrary(_ image: UIImage, completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("[相册保存] 保存成功")
                    completion(true)
                } else {
                    print("[相册保存] 保存失败：\(error?.localizedDescription ?? "未知错误")")
                    completion(false)
                }
            }
        }
    }
    
    // 修改重置方法
    public func reset(onComplete: (() -> Void)? = nil) {
        capturedImage = nil
        showButtons = false
        isProcessingAlert = false
        onComplete?()
    }
    
    // 分享图片
    public func shareImage() {
        guard let image = capturedImage else { return }
        
        // 根据缩放比例处理图片
        let processedImage = cropImage(image, scale: currentScale)
        
        let activityViewController = UIActivityViewController(
            activityItems: [processedImage],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            rootViewController.present(activityViewController, animated: true) {
                print("分享界面已显示")
            }
        }
    }
}

// 截图操作按钮
public struct CaptureActionButton: View {
    let systemName: String
    let action: () -> Void
    let feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle
    let color: Color
    
    public init(systemName: String, 
         action: @escaping () -> Void, 
         feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle = .medium,
         color: Color) {
        self.systemName = systemName
        self.action = action
        self.feedbackStyle = feedbackStyle
        self.color = color
    }
    
    public var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: feedbackStyle)
            generator.prepare()
            generator.impactOccurred()
            action()
        }) {
            Image(systemName: systemName)
                .font(.system(size: 24))
                .foregroundColor(color)
                .frame(width: 50, height: 50)
                .background(Color.black.opacity(0.35))
                .clipShape(Circle())
        }
    }
    
    // 添加一个新的初始化方法,专门用于处理下载按钮
    public static func downloadButton(
        captureState: CaptureState,
        color: Color,
        rotationAngle: Double
    ) -> some View {
        CaptureActionButton(
            systemName: "square.and.arrow.down.fill",
            action: {
                // 触发震动反馈
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.prepare()
                generator.impactOccurred()
                
                captureState.saveToPhotos()
            },
            feedbackStyle: .medium,
            color: color
        )
        .rotationEffect(.degrees(rotationAngle))
        .animation(.easeInOut(duration: 0.3), value: rotationAngle)
    }
}

// 截图操作视图
public struct CaptureActionsView: View {
    @ObservedObject var captureState: CaptureState
    @ObservedObject private var orientationManager = DeviceOrientationManager.shared
    @ObservedObject private var styleManager = BorderLightStyleManager.shared
    let onDismiss: () -> Void
    
    public var body: some View {
        if captureState.showButtons {
            GeometryReader { geometry in
                let screenBounds = UIScreen.main.bounds
                
                ZStack {
                    // 修改全屏背景层的实现
                    if captureState.showButtons {
                        Color.black.opacity(0.0001)
                            .frame(width: screenBounds.width, height: screenBounds.height)
                            .position(x: screenBounds.width/2, y: screenBounds.height/2)
                            .contentShape(Rectangle())
                            .allowsHitTesting(true)
                            .onTapGesture {
                                withAnimation {
                                    captureState.reset {
                                        onDismiss()
                                    }
                                }
                            }
                    }

                    // 图片层
                    if let image = captureState.capturedImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: screenBounds.width, height: screenBounds.height)
                            .scaleEffect(captureState.currentScale)
                            .position(x: screenBounds.width/2, y: screenBounds.height/2)
                            .allowsHitTesting(false)
                    }
                    
                    // 半透明背景层（用于点击隐藏按钮）
                    Color.black.opacity(0.01)
                        .frame(width: screenBounds.width, height: screenBounds.height)
                        .position(x: screenBounds.width/2, y: screenBounds.height/2)
                        .onTapGesture(count: BorderLightStyleManager.shared.captureGestureCount) {
                            // 触发震动反馈
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.prepare()
                            generator.impactOccurred()
                            
                            withAnimation {
                                captureState.reset {
                                    onDismiss()
                                }
                            }
                        }
                    
                    // 底部操作按钮
                    if captureState.showButtons {
                        VStack(spacing: 0) {
                            Spacer()
                            
                            // 底部操作按钮
                            ZStack {
                                HStack(spacing: CaptureButtonStyle.buttonSpacing) {
                                    Spacer()
                                    
                                    // 使用新的下载按钮
                                    CaptureActionButton.downloadButton(
                                        captureState: captureState,
                                        color: styleManager.iconColor,
                                        rotationAngle: getRotationAngle()
                                    )
                                    
                                    // 分享按钮
                                    CaptureActionButton(
                                        systemName: "arrowshape.turn.up.right.fill",
                                        action: captureState.shareImage,
                                        color: styleManager.iconColor
                                    )
                                    .rotationEffect(.degrees(getRotationAngle()))
                                    .animation(.easeInOut(duration: 0.3), value: getRotationAngle())
                                    
                                    Spacer()
                                }
                            }
                            .frame(height: 120)
                        }
                        .frame(width: screenBounds.width, height: screenBounds.height)
                    }
                    
                    // 添加保存成功提示
                    if captureState.showSaveSuccess {
                        Text("已保存到相册")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                            .rotationEffect(.degrees(getRotationAngle()))
                            .position(x: screenBounds.width/2, y: screenBounds.height/2)
                    }
                    
                    // 将关闭按钮移到最上层
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: {
                                print("关闭按钮被点击")
                                // 触发震动反馈
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.prepare()
                                generator.impactOccurred()
                                
                                withAnimation {
                                    captureState.reset {
                                        onDismiss()
                                    }
                                }
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(width: 36, height: 36)
                                    .background(Color.black.opacity(0.35))
                                    .clipShape(Circle())
                            }
                            .padding(.top, 80)  // 增加顶部间距
                            Spacer()
                        }
                        Spacer()
                    }
                    .zIndex(100)  // 确保按钮在最上层
                }
            }
            .ignoresSafeArea()
            .zIndex(9)
        }
    }
    
    // 添加辅助方法
    private func getRotationAngle() -> Double {
        switch orientationManager.currentOrientation {
        case .landscapeLeft: return 90
        case .landscapeRight: return -90
        case .portraitUpsideDown: return 180
        default: return 0
        }
    }   
}   