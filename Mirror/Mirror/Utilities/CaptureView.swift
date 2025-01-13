import SwiftUI
import UIKit
import Photos

// 截图操作按钮样式
public struct CaptureButtonStyle {
    public static let buttonSize: CGFloat = 50
    public static let buttonSpacing: CGFloat = 30
    public static let buttonBackgroundOpacity: Double = 0.7
}

// 截图操作状态
public class CaptureState: ObservableObject {
    @Published public var capturedImage: UIImage?
    @Published public var showButtons: Bool = false
    @Published public var showSaveSuccess: Bool = false
    @Published public var showSaveError: Bool = false
    
    public init() {}
    
    // 保存图片到相册
    public func saveToPhotos() {
        guard let image = capturedImage else { return }
        
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                DispatchQueue.main.async {
                    self.showSaveError = true
                    print("相册权限未授权")
                }
                return
            }
            
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
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
        
        let activityViewController = UIActivityViewController(
            activityItems: [image],
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
    
    public init(systemName: String, 
         action: @escaping () -> Void, 
         feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        self.systemName = systemName
        self.action = action
        self.feedbackStyle = feedbackStyle
    }
    
    public var body: some View {
        Button(action: {
            // 触发震动反馈
            let generator = UIImpactFeedbackGenerator(style: feedbackStyle)
            generator.prepare()
            generator.impactOccurred()
            
            action()
        }) {
            Image(systemName: systemName)
                .font(.system(size: 24))
                .foregroundColor(.white)
                .frame(width: CaptureButtonStyle.buttonSize, 
                       height: CaptureButtonStyle.buttonSize)
                .background(Color.black.opacity(CaptureButtonStyle.buttonBackgroundOpacity))
                .clipShape(Circle())
        }
    }
}

// 截图操作视图
public struct CaptureActionsView: View {
    @ObservedObject var captureState: CaptureState
    @State private var showAlert = false
    @State private var alertType: AlertType = .success
    @State private var showButtons = true
    let onDismiss: () -> Void
    
    private enum AlertType {
        case success
        case error
    }
    
    public init(captureState: CaptureState, onDismiss: @escaping () -> Void) {
        self.captureState = captureState
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        if captureState.showButtons {
            GeometryReader { geometry in
                let availableHeight = geometry.size.height
                let containerFrame = CameraContainerFrame.frame
                
                ZStack {
                    if let image = captureState.capturedImage {
                        // 保持和相机画面相同的位置和布局
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: containerFrame.width, height: containerFrame.height)
                            .clipShape(RoundedRectangle(cornerRadius: CameraLayoutConfig.cornerRadius))
                            .position(x: containerFrame.midX, y: containerFrame.midY)
                            .onTapGesture {
                                withAnimation {
                                    showButtons.toggle()
                                }
                            }
                            .zIndex(10) // 确保图片在上层
                    }
                    
                    // 操作按钮
                    if showButtons {
                        VStack(spacing: 0) {
                            Spacer()
                            // 黑色半透明背景
                            Rectangle()
                                .fill(Color.black.opacity(0.5))
                                .frame(width: geometry.size.width, height: 120)
                                .overlay(
                                    HStack(spacing: 40) {
                                        Spacer()
                                        
                                        // 下载按钮
                                        CaptureActionButton(
                                            systemName: "square.and.arrow.down",
                                            action: captureState.saveToPhotos
                                        )
                                        
                                        // 分享按钮
                                        CaptureActionButton(
                                            systemName: "square.and.arrow.up",
                                            action: captureState.shareImage
                                        )
                                        
                                        // 关闭按钮
                                        CaptureActionButton(
                                            systemName: "xmark.circle.fill",
                                            action: {
                                                withAnimation {
                                                    captureState.reset {
                                                        onDismiss()
                                                    }
                                                }
                                            }
                                        )
                                        
                                        Spacer()
                                    }
                                )
                        }
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .ignoresSafeArea(.all, edges: .bottom)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(11) // 确保按钮在最上层
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .ignoresSafeArea()
            .zIndex(9) // 整个捕获视图在主界面上层
            .onChange(of: captureState.showSaveSuccess) { newValue in
                if newValue {
                    alertType = .success
                    showAlert = true
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
                        dismissButton: .default(Text("确定")) {
                            captureState.showSaveSuccess = false
                        }
                    )
                case .error:
                    return Alert(
                        title: Text("保存失败"),
                        message: Text("请确保已授予相册访问权限"),
                        dismissButton: .default(Text("确定")) {
                            captureState.showSaveError = false
                        }
                    )
                }
            }
        }
    }
} 