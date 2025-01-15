import SwiftUI
import UIKit
import Photos

// 图片上传管理器
class ImageUploader: ObservableObject {
    @Published var showOriginalOverlay = false
    @Published var showMirroredOverlay = false
    @Published var isOverlayVisible: Bool = false
    @Published var showDownloadOverlay = false  // 添加下载遮罩状态
    @Published var isDownloadMode = false  // 添加下载模式状态
    @Published var showImagePicker = false {
        didSet {
            if showImagePicker {
                print("------------------------")
                print("[图片选择器] 开启")
                print("目标区域：\(selectedScreenID == .original ? "Original" : "Mirrored")屏幕")
                print("------------------------")
            } else {
                print("------------------------")
                print("[图片选择器] 关闭")
                print("------------------------")
            }
        }
    }
    @Published var selectedImage: UIImage?
    @Published var selectedScreenID: ScreenID?
    @Published var showPermissionAlert = false  // 添加权限提示弹窗状态
    @Published var permissionAlertType: PermissionAlertType = .initial  // 添加弹窗类型状态
    @Published var showToast = false  // 添加提示状态
    @Published var toastMessage = ""  // 添加提示文本
    
    private var hideTimer: Timer?
    
    // 添加权限提示弹窗类型枚举
    enum PermissionAlertType {
        case initial     // 首次使用时的提示
        case settings    // 引导去设置页面的提示
    }
    
    var onUploadStateChanged: ((Bool) -> Void)?
    var onCameraStateChanged: (() -> Void)?
    
    // 添加一个标志来防止重复操作
    private var isProcessingImage = false
    
    // 修改图片处理状态控制方法
    func startImageProcessing() {
        isProcessingImage = true
        print("------------------------")
        print("[图片处理] 开始")
        print("------------------------")
    }
    
    func endImageProcessing() {
        print("------------------------")
        print("[图片处理] 结束")
        print("------------------------")
        isProcessingImage = false
        
        // 在处理完成后恢复相机状态
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.onCameraStateChanged?()
        }
    }
    
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
        // 如果正在处理图片，不执行隐藏操作
        if isProcessingImage {
            return
        }
        
        // 取消计时器
        hideTimer?.invalidate()
        hideTimer = nil
        
        withAnimation {
            showOriginalOverlay = false
            showMirroredOverlay = false
            isOverlayVisible = false
            showImagePicker = false
            showDownloadOverlay = false  // 重置下载遮罩状态
            isDownloadMode = false  // 重置下载模式状态
        }
        
        // 确保在隐藏控件时恢复相机状态
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.onCameraStateChanged?()
        }
        
        onUploadStateChanged?(false)
        
        print("------------------------")
        print("[上传/下载控件] 隐藏")
        print("状态：其他触控区已恢复")
        print("------------------------")
    }
    
    // 修改权限检查方法
    func checkPhotoLibraryPermission(completion: @escaping (Bool) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
        case .authorized:
            print("------------------------")
            print("[相册权限] 已授权（完全访问）")
            print("------------------------")
            completion(true)
        case .limited:
            print("------------------------")
            print("[相册权限] 已授权（受限访问）")
            print("------------------------")
            completion(true)
        case .denied, .restricted:
            print("------------------------")
            print("[相册权限] 已被拒绝")
            print("------------------------")
            completion(false)
            // 确保在权限被拒绝时恢复相机状态
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.onCameraStateChanged?()
            }
        case .notDetermined:
            print("------------------------")
            print("[相册权限] 开始申请")
            print("------------------------")
            PHPhotoLibrary.requestAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    print("------------------------")
                    print("[相册权限] 申请结果：\(status == .authorized ? "完全访问" : status == .limited ? "受限访问" : "已拒绝")")
                    print("------------------------")
                    completion(status == .authorized || status == .limited)
                    
                    // 确保在权限申请完成后恢复相机状态
                    DispatchQueue.global(qos: .userInitiated).async {
                        self?.onCameraStateChanged?()
                    }
                }
            }
        @unknown default:
            completion(false)
            // 确保在未知状态时恢复相机状态
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.onCameraStateChanged?()
            }
        }
    }
    
    // 修改上传图片方法
    func uploadImage(for screenID: ScreenID) {
        // 如果正在处理图片，不执行上传操作
        if isProcessingImage {
            return
        }
        
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
            print("[图片选择器] 准备打开")
            print("目标区域：\(screenID == .original ? "Original" : "Mirrored")屏幕")
            print("------------------------")
            
            startImageProcessing()
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
    
    // 修改处理权限申请的方法
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
                    
                    // 如果是受限访问，等待系统的照片选择界面关闭后再显示我们的图片选择器
                    if status == .limited {
                        print("------------------------")
                        print("[相册权限] 受限访问模式")
                        print("------------------------")
                        // 延迟显示我们的图片选择器，等待系统界面消失
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            // 在显示图片选择器之前先暂停相机会话
                            DispatchQueue.global(qos: .userInitiated).async {
                                self.onCameraStateChanged?()
                                DispatchQueue.main.async {
                                    self.showImagePicker = true
                                }
                            }
                        }
                    } else {
                        // 完全访问权限，直接显示图片选择器
                        DispatchQueue.global(qos: .userInitiated).async {
                            self.onCameraStateChanged?()
                            DispatchQueue.main.async {
                                self.showImagePicker = true
                            }
                        }
                    }
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
    
    // 添加下载图片方法
    func downloadImage(for screenID: ScreenID) {
        print("------------------------")
        print("[下载功能] 开始")
        print("目标区域：\(screenID == .original ? "Original" : "Mirrored")屏幕")
        print("------------------------")
        
        // 获取要保存的图片
        guard let imageToSave = screenID == .original ? pausedOriginalImage : pausedMirroredImage else {
            print("------------------------")
            print("[下载功能] 错误：没有可保存的图片")
            print("------------------------")
            hideRectangle()
            return
        }
        
        // 裁剪图片为分屏大小
        let croppedImage = cropImageToScreenSize(imageToSave, for: screenID)
        
        // 检查相册权限并保存图片
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if status == .authorized || status == .limited {
                    print("------------------------")
                    print("[下载功能] 已获得权限")
                    print("------------------------")
                    
                    // 保存裁剪后的图片到相册
                    PHPhotoLibrary.shared().performChanges({
                        let request = PHAssetChangeRequest.creationRequestForAsset(from: croppedImage)
                        request.creationDate = Date()
                    }) { success, error in
                        DispatchQueue.main.async {
                            if success {
                                print("------------------------")
                                print("[下载功能] 图片保存成功")
                                print("------------------------")
                                // 显示保存成功提示
                                self.toastMessage = "保存成功"
                                self.showToast = true
                                // 2秒后自动隐藏提示
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    self.showToast = false
                                    self.hideRectangle()  // 在提示消失后再隐藏下载页面
                                }
                            } else {
                                print("------------------------")
                                print("[下载功能] 图片保存失败")
                                if let error = error {
                                    print("错误信息：\(error.localizedDescription)")
                                }
                                print("------------------------")
                                self.hideRectangle()
                            }
                        }
                    }
                } else {
                    print("------------------------")
                    print("[下载功能] 权限被拒绝")
                    print("------------------------")
                    // 显示权限提示弹窗
                    self.permissionAlertType = .settings
                    self.showPermissionAlert = true
                }
            }
        }
    }
    
    // 添加定格图片引用
    private var pausedOriginalImage: UIImage?
    private var pausedMirroredImage: UIImage?
    private var currentOffset: CGSize = .zero  // 添加当前偏移量
    private var maxOffset: CGSize = .zero      // 添加最大偏移量
    
    // 添加设置定格图片的方法
    func setPausedImage(_ image: UIImage?, for screenID: ScreenID) {
        switch screenID {
        case .original:
            pausedOriginalImage = image
        case .mirrored:
            pausedMirroredImage = image
        }
    }
    
    // 添加设置偏移量的方法
    func setOffset(_ offset: CGSize, maxOffset: CGSize) {
        self.currentOffset = offset
        self.maxOffset = maxOffset
    }
    
    // 添加图片裁剪方法
    private func cropImageToScreenSize(_ image: UIImage, for screenID: ScreenID) -> UIImage {
        let screenBounds = UIScreen.main.bounds
        let screenWidth = screenBounds.width
        let screenHeight = screenBounds.height
        
        // 计算显示区域的尺寸（屏幕的一半高度）
        let viewportWidth = screenWidth
        let viewportHeight = screenHeight / 2
        
        // 计算图片缩放后的实际尺寸
        let scale = image.size.width / screenWidth  // 图片相对于屏幕的缩放比例
        let scaledImageWidth = image.size.width
        let scaledImageHeight = image.size.height
        
        // 计算基础偏移（图片中心到显示区域中心的距离）
        let baseOffsetY = (scaledImageHeight - viewportHeight * scale) / 2
        
        // 计算可见区域在原始图片中的位置
        let visibleX = (scaledImageWidth - viewportWidth) / 2 - currentOffset.width * scale
        let visibleY = baseOffsetY - currentOffset.height * scale
        
        let visibleWidth = viewportWidth * scale
        let visibleHeight = viewportHeight * scale
        
        // 确保裁剪区域不超出图片范围
        let safeCropX = max(0, min(visibleX, image.size.width - visibleWidth))
        let safeCropY = max(0, min(visibleY, image.size.height - visibleHeight))
        let safeCropWidth = min(visibleWidth, image.size.width - safeCropX)
        let safeCropHeight = min(visibleHeight, image.size.height - safeCropY)
        
        // 创建裁剪区域
        let cropRect = CGRect(x: safeCropX, y: safeCropY, width: safeCropWidth, height: safeCropHeight)
        
        // 从原图中裁剪指定区域
        if let cgImage = image.cgImage?.cropping(to: cropRect) {
            let croppedImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
            return croppedImage
        }
        
        return image
    }
    
    // 显示下载控件
    func showDownloadOverlay(for screenID: ScreenID) {
        // 如果已有计时器，先取消
        hideTimer?.invalidate()
        
        withAnimation {
            showOriginalOverlay = screenID == .original
            showMirroredOverlay = screenID == .mirrored
            isOverlayVisible = true
            showDownloadOverlay = true
            isDownloadMode = true
        }
        
        // 设置自动隐藏计时器
        hideTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.hideRectangle()
        }
        
        print("------------------------")
        print("[下载控件] 显示")
        print("位置：\(screenID == .original ? "Original" : "Mirrored")屏幕")
        print("------------------------")
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
            ZStack {
                if imageUploader.isOverlayVisible {
                    ZStack {
                        // 全屏遮罩
                        Color.black.opacity(0.01)
                            .edgesIgnoringSafeArea(.all)
                            .onLongPressGesture(minimumDuration: 0.5) {
                                // 长按显示下载控件
                                imageUploader.showDownloadOverlay(for: screenID)
                            }
                        
                        // 上传/下载区域
                        VStack(spacing: 0) {
                            if screenID == .original {
                                // Original屏幕（上半部分）
                                ZStack {
                                    if imageUploader.showDownloadOverlay {
                                        downloadArea
                                            .frame(height: geometry.size.height / 2)
                                    } else {
                                        uploadArea
                                            .frame(height: geometry.size.height / 2)
                                    }
                                }
                            } else {
                                // Mirrored屏幕（下半部分）
                                ZStack {
                                    if imageUploader.showDownloadOverlay {
                                        downloadArea
                                            .frame(height: geometry.size.height / 2)
                                    } else {
                                        uploadArea
                                            .frame(height: geometry.size.height / 2)
                                    }
                                }
                            }
                        }
                        
                        // 提示视图
                        if imageUploader.showToast {
                            VStack {
                                Spacer()
                                Text(imageUploader.toastMessage)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.black.opacity(0.7))
                                    .cornerRadius(10)
                                    .padding(.bottom, 50)
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
            Button(action: {
                print("------------------------")
                print("[上传按钮] 点击")
                print("区域：\(screenID == .original ? "Original" : "Mirrored")屏幕")
                print("当前设备方向：\(getOrientationDescription(deviceOrientation))")
                print("------------------------")   
                imageUploader.uploadImage(for: screenID)
            }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 80))
                    .rotationEffect(getRotationAngle(deviceOrientation))
                    .frame(width: 80, height: 80)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle(normalColor: screenID == .original ? .white : .black))
        }
    }
    
    // 添加下载区域视图
    private var downloadArea: some View {
        ZStack {
            // 背景
            if screenID == .original {
                Rectangle()
                    .fill(Color.black)
                    .frame(height: centerY)
                    .allowsHitTesting(false)
            } else {
                Rectangle()
                    .fill(Color.white)
                    .frame(height: centerY)
                    .allowsHitTesting(false)
            }
            
            // 下载按钮
            Button(action: {
                print("------------------------")
                print("[下载按钮] 点击")
                print("区域：\(screenID == .original ? "Original" : "Mirrored")屏幕")
                print("当前设备方向：\(getOrientationDescription(deviceOrientation))")
                print("------------------------")   
                imageUploader.downloadImage(for: screenID)
            }) {
                Image(systemName: "arrow.down.to.line.circle.fill")
                    .font(.system(size: 80))
                    .rotationEffect(getRotationAngle(deviceOrientation))
                    .frame(width: 80, height: 80)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle(normalColor: screenID == .original ? .white : .black))
        }
    }
    
    // 修改按钮样式
    struct PressableButtonStyle: ButtonStyle {
        let normalColor: Color
        
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .foregroundColor(configuration.isPressed ? Color(red: 0.2, green: 0.2, blue: 0.9) : normalColor)
               // .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
               // .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
        }
    }
    
    // 添加获取旋转角度的方法
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
    
    // 添加获取方向描述的方法
    private func getOrientationDescription(_ orientation: UIDeviceOrientation) -> String {
        switch orientation {
        case .portrait:
            return "竖直"
        case .portraitUpsideDown:
            return "倒置竖屏"
        case .landscapeLeft:
            return "向左横屏"
        case .landscapeRight:
            return "向右横屏"
        default:
            return "其他"
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
                
                // 保存上传的图片
                self.parent.imageUploader?.setPausedImage(image, for: self.parent.screenID)
                
                // 关闭图片选择器
                self.parent.presentationMode.wrappedValue.dismiss()
                
                // 延迟结束处理状态
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.parent.imageUploader?.endImageProcessing()
                }
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            print("------------------------")
            print("[图片选择器] 已取消选择")
            print("------------------------")
            
            // 关闭图片选择器
            parent.presentationMode.wrappedValue.dismiss()
            
            // 执行清理工作并结束处理状态
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let imageUploader = self.parent.imageUploader {
                    imageUploader.hideRectangle()
                    imageUploader.endImageProcessing()
                }
            }
        }
    }
} 