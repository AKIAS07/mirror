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
    @Published var showPermissionAlert = false  // 添加权限提示弹窗状态
    @Published var permissionAlertType: PermissionAlertType = .initial  // 添加弹窗类型状态
    
    private var hideTimer: Timer?
    
    // 添加权限提示弹窗类型枚举
    enum PermissionAlertType {
        case initial     // 首次使用时的提示
        case settings    // 引导去设置页面的提示
    }
    
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
        
        // 检查相册权限状态
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        switch status {
        case .notDetermined:
            // 首次使用，显示提示弹窗
            print("------------------------")
            print("[相册权限] 首次使用，显示提示弹窗")
            print("------------------------")
            permissionAlertType = .initial
            showPermissionAlert = true
            
        case .denied:
            // 之前拒绝过，显示设置页面提示弹窗
            print("------------------------")
            print("[相册权限] 之前拒绝，显示设置提示弹窗")
            print("------------------------")
            permissionAlertType = .settings
            showPermissionAlert = true
            
        case .authorized, .limited:
            // 已有权限，直接显示图片选择器
            print("------------------------")
            print("[图片选择器] 打开")
            print("目标区域：\(screenID == .original ? "Original" : "Mirrored")屏幕")
            print("------------------------")
            showImagePicker = true
            
        case .restricted:
            // 受限制（比如家长控制），隐藏上传控件
            print("------------------------")
            print("[相册权限] 访问受限")
            print("------------------------")
            hideRectangle()
            
        @unknown default:
            hideRectangle()
        }
    }
    
    // 添加处理权限申请的方法
    func handlePermissionRequest() {
        print("------------------------")
        print("[相册权限] 用户确认提示，开始申请权限")
        print("------------------------")
        
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if status == .authorized || status == .limited {
                    print("------------------------")
                    print("[相册权限] 用户已授权")
                    print("------------------------")
                    self.showImagePicker = true
                } else {
                    print("------------------------")
                    print("[相册权限] 用户已拒绝")
                    print("------------------------")
                    self.hideRectangle()
                }
            }
        }
    }
    
    // 添加处理设置页面跳转的方法
    func handleSettingsNavigation() {
        print("------------------------")
        print("[相册权限] 用户确认提示，准备跳转设置页面")
        print("------------------------")
        
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            if UIApplication.shared.canOpenURL(settingsUrl) {
                UIApplication.shared.open(settingsUrl)
                print("------------------------")
                print("[相册权限] 已打开设置页面")
                print("------------------------")
            }
        }
        hideRectangle()
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
            ZStack {
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
                    .alert(isPresented: $imageUploader.showPermissionAlert) {
                        Alert(
                            title: Text("提示"),
                            message: Text("此功能需要您开启相册权限！"),
                            primaryButton: .default(Text(imageUploader.permissionAlertType == .initial ? "确定" : "去设置")) {
                                if imageUploader.permissionAlertType == .initial {
                                    imageUploader.handlePermissionRequest()
                                } else {
                                    imageUploader.handleSettingsNavigation()
                                }
                            },
                            secondaryButton: .cancel(Text("取消")) {
                                imageUploader.hideRectangle()
                            }
                        )
                    }
                }
            }
            .sheet(isPresented: $imageUploader.showImagePicker) {
                ImagePicker(
                    selectedImage: $imageUploader.selectedImage,
                    screenID: screenID,
                    imageUploader: imageUploader
                )
                .onDisappear {
                    imageUploader.hideRectangle()
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
                    .frame(height: centerY)
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
    let imageUploader: ImageUploader?
    
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
                self.parent.selectedImage = image
                
                print("------------------------")
                print("[图片选择器] 已选择图片")
                print("图片尺寸：\(Int(image.size.width))x\(Int(image.size.height))")
                print("目标区域：\(self.parent.screenID == .original ? "Original" : "Mirrored")屏幕")
                print("------------------------")
                
                // 延迟关闭图片选择器
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.parent.presentationMode.wrappedValue.dismiss()
                }
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            print("------------------------")
            print("[图片选择器] 已取消选择")
            print("------------------------")
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
} 