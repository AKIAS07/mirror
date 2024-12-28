import SwiftUI
import UIKit
import Photos

// 图片上传管理器
class ImageUploader: ObservableObject {
    @Published var showOriginalOverlay = false
    @Published var showMirroredOverlay = false
    @Published var isOverlayVisible: Bool = false
    @Published var showImagePicker = false
    @Published var selectedImage: UIImage?
    @Published var selectedScreenID: ScreenID?
    
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
        
        // 只有在不显示图片选择器时才设置自动隐藏计时器
        if !showImagePicker {
            hideTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                self?.hideRectangle()
            }
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
    
    // 添加权限检查方法
    func checkPhotoLibraryPermission(completion: @escaping (Bool) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
        case .authorized, .limited:
            completion(true)
        case .denied, .restricted:
            print("------------------------")
            print("[相册权限] 已被拒绝")
            print("------------------------")
            completion(false)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { status in
                DispatchQueue.main.async {
                    print("------------------------")
                    print("[相册权限] 申请结果：\(status == .authorized ? "已授权" : "已拒绝")")
                    print("------------------------")
                    completion(status == .authorized)
                }
            }
        @unknown default:
            completion(false)
        }
    }
    
    // 修改上传图片方法
    func uploadImage(for screenID: ScreenID) {
        selectedScreenID = screenID
        
        // 取消现有的隐藏计时器
        hideTimer?.invalidate()
        hideTimer = nil
        
        // 检查相册权限
        checkPhotoLibraryPermission { [weak self] granted in
            guard let self = self else { return }
            if granted {
                self.showImagePicker = true
                print("------------------------")
                print("[图片选择器] 打开")
                print("目标区域：\(screenID == .original ? "Original" : "Mirrored")屏幕")
                print("------------------------")
            } else {
                // 如果没有权限，显示提示并隐藏上传控件
                print("------------------------")
                print("[相册权限] 无法访问相册")
                print("------------------------")
                self.hideRectangle()
            }
        }
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
    @State private var showingImagePicker = false
    
    var body: some View {
        GeometryReader { geometry in
            if imageUploader.isOverlayVisible {
                ZStack {
                    // 全屏遮罩
                    Color.black.opacity(0.01)
                        .edgesIgnoringSafeArea(.all)
                    
                    // 上传区域
                    VStack(spacing: 0) {
                        if screenID == .original {
                            // Original屏幕（上半部分）
                            ZStack {
                                uploadArea
                                    .frame(height: geometry.size.height / 2)
                                    .background(
                                        GeometryReader { rectGeo in
                                            Color.clear
                                                .onAppear {
                                                    let screenCenter = CGPoint(x: geometry.size.width/2, y: geometry.size.height/4)
                                                    let rectCenter = CGPoint(
                                                        x: rectGeo.frame(in: .global).midX,
                                                        y: rectGeo.frame(in: .global).midY
                                                    )
                                                    print("------------------------")
                                                    print("[Original屏幕坐标]")
                                                    print("分屏中心: x=\(screenCenter.x), y=\(screenCenter.y)")
                                                    print("矩形中心: x=\(rectCenter.x), y=\(rectCenter.y)")
                                                    print("------------------------")
                                                }
                                        }
                                    )
                            }
                        } else {
                            // Mirrored屏幕（下半部分）
                            ZStack {
                                uploadArea
                                    .frame(height: geometry.size.height / 2)
                                    .background(
                                        GeometryReader { rectGeo in
                                            Color.clear
                                                .onAppear {
                                                    let screenCenter = CGPoint(x: geometry.size.width/2, y: geometry.size.height * 3/4)
                                                    let rectCenter = CGPoint(
                                                        x: rectGeo.frame(in: .global).midX,
                                                        y: rectGeo.frame(in: .global).midY
                                                    )
                                                    print("------------------------")
                                                    print("[Mirrored屏幕坐标]")
                                                    print("分屏中心: x=\(screenCenter.x), y=\(screenCenter.y)")
                                                    print("矩形中心: x=\(rectCenter.x), y=\(rectCenter.y)")
                                                    print("------------------------")
                                                }
                                        }
                                    )
                            }
                        }
                    }
                }
                .sheet(isPresented: $imageUploader.showImagePicker) {
                    ImagePicker(
                        selectedImage: $imageUploader.selectedImage,
                        screenID: screenID
                    )
                    .onDisappear {
                        imageUploader.hideRectangle()
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
            if screenID == .original {
                Rectangle()
                    .fill(Color.black)
                    .frame(height: centerY)
                    .allowsHitTesting(false)
                    .onAppear {
                        print("------------------------")
                        print("[Original屏幕] centerY值: \(centerY)")
                        print("屏幕高度: \(screenHeight)")
                        print("------------------------")
                    }
            } else {
                Rectangle()
                    .fill(Color.white)
                    .frame(height: centerY)  // 使用相同的高度设置
                    .allowsHitTesting(false)
                    .onAppear {
                        print("------------------------")
                        print("[Mirrored屏幕] centerY值: \(centerY)")
                        print("屏幕高度: \(screenHeight)")
                        print("------------------------")
                    }
            }
            
            // 上传按钮
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

// 添加 ImagePicker 结构体
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) private var presentationMode
    let screenID: ScreenID
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
                
                print("------------------------")
                print("[图片选择器] 已选择图片")
                print("图片尺寸：\(Int(image.size.width))x\(Int(image.size.height))")
                print("目标区域：\(parent.screenID == .original ? "Original" : "Mirrored")屏幕")
                print("------------------------")
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            print("------------------------")
            print("[图片选择器] 已取消选择")
            print("------------------------")
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
} 