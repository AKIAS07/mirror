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
    @Published public var showSaveSuccess: Bool = false
    @Published public var showSaveError: Bool = false
    @Published public var currentScale: CGFloat = 1.0
    
    public init() {}
    
    // 根据缩放比例裁剪图片
    private func cropImage(_ image: UIImage, scale: CGFloat) -> UIImage {
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
    
    // 保存图片到相册
    public func saveToPhotos() {
        guard let image = capturedImage else { return }
        
        // 根据缩放比例处理图片
        let processedImage = cropImage(image, scale: currentScale)
        
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                DispatchQueue.main.async {
                    self.showSaveError = true
                    print("相册权限未授权")
                }
                return
            }
            
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: processedImage)
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        self.showSaveSuccess = true
                        print("图片已保存到相册")
                    } else {
                        self.showSaveError = true
                        if let error = error {
                            print("保存图片失败：\(error.localizedDescription)")
                        }
                    }
                }
            }
        }
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
    
    // 重置状态
    public func reset(onComplete: (() -> Void)? = nil) {
        capturedImage = nil
        showButtons = false
        showSaveSuccess = false
        showSaveError = false
        onComplete?()
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
}

// 截图操作视图
public struct CaptureActionsView: View {
    @ObservedObject var captureState: CaptureState
    @ObservedObject private var orientationManager = DeviceOrientationManager.shared
    @ObservedObject private var styleManager = BorderLightStyleManager.shared
    @State private var showAlert = false
    @State private var alertType: AlertType = .success
    @State private var showButtons = true
    let onDismiss: () -> Void
    
    private enum AlertType {
        case success
        case error
    }
    
    private var rotationAngle: Double {
        switch orientationManager.currentOrientation {
        case .landscapeLeft:
            return 90
        case .landscapeRight:
            return -90
        case .portraitUpsideDown:
            return 180
        default:
            return 0
        }
    }
    
    public init(captureState: CaptureState, onDismiss: @escaping () -> Void) {
        self.captureState = captureState
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        if captureState.showButtons {
            GeometryReader { geometry in
                let screenBounds = UIScreen.main.bounds
                
                ZStack {
                    // 添加一个全屏背景层来阻止点击事件穿透
                    Color.black.opacity(0.0001)
                        .frame(width: screenBounds.width, height: screenBounds.height)
                        .position(x: screenBounds.width/2, y: screenBounds.height/2)
                        .contentShape(Rectangle())
                    
                    // 图片层
                    if let image = captureState.capturedImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: screenBounds.width, height: screenBounds.height)
                            .scaleEffect(captureState.currentScale)
                            .position(x: screenBounds.width/2, y: screenBounds.height/2)
                            .background(GeometryReader { geometry in
                                Color.clear.onAppear {
                                    let frame = geometry.frame(in: .global)
                                    print("截图图片中心点: x=\(frame.midX), y=\(frame.midY)")
                                    print("截图图片尺寸: width=\(frame.width), height=\(frame.height)")
                                    print("截图图片缩放比例: \(captureState.currentScale)")
                                }
                            })
                    }
                    
                    // 半透明背景层（用于点击隐藏按钮）
                    Color.black.opacity(0.01)
                        .frame(width: screenBounds.width, height: screenBounds.height)
                        .position(x: screenBounds.width/2, y: screenBounds.height/2)
                        .onTapGesture(count: BorderLightStyleManager.shared.captureGestureCount) {
                            withAnimation {
                                captureState.reset {
                                    onDismiss()
                                }
                            }
                        }
                    
                    // 按钮控制层
                    if showButtons {
                        VStack(spacing: 0) {
                            Spacer()
                            
                            // 底部操作按钮
                            ZStack {
                                HStack(spacing: CaptureButtonStyle.buttonSpacing) {
                                    Spacer()
                                    
                                    // 下载按钮
                                    CaptureActionButton(
                                        systemName: "square.and.arrow.down.fill",
                                        action: captureState.saveToPhotos,
                                        color: styleManager.iconColor
                                    )
                                    .rotationEffect(.degrees(rotationAngle))
                                    .animation(.easeInOut(duration: 0.3), value: rotationAngle)
                                    .background(GeometryReader { geometry in
                                        Color.clear.onAppear {
                                            let frame = geometry.frame(in: .global)
                                            print("下载按钮位置: x=\(frame.midX), y=\(frame.midY)")
                                        }
                                    })
                                    
                                    // 分享按钮
                                    CaptureActionButton(
                                        systemName: "arrowshape.turn.up.right.fill",
                                        action: captureState.shareImage,
                                        color: styleManager.iconColor
                                    )
                                    .rotationEffect(.degrees(rotationAngle))
                                    .animation(.easeInOut(duration: 0.3), value: rotationAngle)
                                    .background(GeometryReader { geometry in
                                        Color.clear.onAppear {
                                            let frame = geometry.frame(in: .global)
                                            print("分享按钮位置: x=\(frame.midX), y=\(frame.midY)")
                                        }
                                    })
                                    
                                    Spacer()
                                }
                            }
                            .frame(height: 120)
                        }
                        .frame(width: screenBounds.width, height: screenBounds.height)
                    }
                }
            }
            .ignoresSafeArea()
            .zIndex(9)
            .onChange(of: captureState.showSaveSuccess) { newValue in
                if newValue {
                    alertType = .success
                    showAlert = true
                    // 1秒后自动关闭弹窗
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        captureState.showSaveSuccess = false
                        showAlert = false
                    }
                }
            }
            .onChange(of: captureState.showSaveError) { newValue in
                if newValue {
                    alertType = .error
                    showAlert = true
                }
            }
            .alert(isPresented: $showAlert) {
                switch alertType {
                case .success:
                    return Alert(
                        title: Text("保存成功"),
                        message: nil,
                        dismissButton: nil
                    )
                case .error:
                    return Alert(
                        title: Text("保存失败"),
                        message: Text("请确保已授予相册访问权限"),
                        dismissButton: .default(Text("确定")) {
                            captureState.showSaveError = false
                            showAlert = false
                        }
                    )
                }
            }
        }
    }
} 