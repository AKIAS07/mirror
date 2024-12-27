import SwiftUI

// 图片上传管理器
class ImageUploader: ObservableObject {
    @Published var showOriginalOverlay = false
    @Published var showMirroredOverlay = false
    @Published var isOverlayVisible: Bool = false
    @Published var showImagePicker = false
    @Published var selectedImage: UIImage?
    @Published var currentScreenID: ScreenID?
    
    private var hideTimer: Timer?
    
    var onUploadStateChanged: ((Bool) -> Void)?
    
    // 显示上传控件
    func showRectangle(for screenID: ScreenID) {
        // 如果已有计时器，先取消
        hideTimer?.invalidate()
        
        withAnimation {
            showOriginalOverlay = screenID == .original
            showMirroredOverlay = screenID == .mirrored
            isOverlayVisible = true
        }
        
        // 设置2秒后自动隐藏
        hideTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.hideRectangle()
        }
        
        print("------------------------")
        print("[上传控件] 显示")
        print("位置：\(screenID == .original ? "Original" : "Mirrored")屏幕")
        print("------------------------")
    }
    
    // 隐藏上传控件
    func hideRectangle() {
        // 取消计时器
        hideTimer?.invalidate()
        hideTimer = nil
        
        withAnimation {
            showOriginalOverlay = false
            showMirroredOverlay = false
            isOverlayVisible = false
        }
        
        onUploadStateChanged?(false)
        
        print("------------------------")
        print("[上传控件] 隐藏")
        print("状态：其他触控区已恢复")
        print("------------------------")
    }
    
    // 上传图片（待实现）
    func uploadImage(for screenID: ScreenID) {
        currentScreenID = screenID
        showImagePicker = true
    }
}

// 遮罩视图组件
struct OverlayView: View {
    let screenID: ScreenID
    let deviceOrientation: UIDeviceOrientation
    let screenWidth: CGFloat
    let centerY: CGFloat
    let screenHeight: CGFloat
    @ObservedObject var imageUploader: ImageUploader
    
    var body: some View {
        GeometryReader { geometry in
            if imageUploader.isOverlayVisible {  // 根据 isOverlayVisible 控制显示
                ZStack {
                    // 全屏遮罩
                    Color.black.opacity(0.01)
                        .edgesIgnoringSafeArea(.all)
                    
                    // 上传区域
                    VStack(spacing: 0) {
                        if screenID == .original {
                            uploadArea
                            Spacer()
                        } else {
                            Spacer()
                            uploadArea
                        }
                    }
                }
            }
        }
        .zIndex(999)
        .ignoresSafeArea()
    }
    
    private var uploadArea: some View {
        ZStack {
            // 背景
            Rectangle()
                .fill(screenID == .original ? Color.black : Color.white)
                .frame(height: centerY)
                .allowsHitTesting(false)
            
            // 上传按钮 - 增大到1000x1000
            Circle()
                .fill(Color.clear)
                .frame(width: 100, height: 100)
                .overlay(
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(screenID == .original ? Color.white : Color.black)
                )
                .contentShape(Circle())
                .onTapGesture {
                    print("------------------------")
                    print("[上传按钮] 点击")
                    print("区域：\(screenID == .original ? "Original" : "Mirrored")屏幕")
                    print("------------------------")   
                    imageUploader.uploadImage(for: screenID)
                }
        }
    }
} 