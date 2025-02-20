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
    
    // 添加定格图片属性
    private(set) var originalPausedImage: UIImage?
    private(set) var mirroredPausedImage: UIImage?
    
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
    
    // 添加手电筒状态追踪
    @Published private var isFlashlightActiveOriginal = false
    @Published private var isFlashlightActiveMirrored = false
    @Published var showFlashlightAlert = false
    
    // 添加亮度控制相关属性
    private var originalBrightness: CGFloat = UIScreen.main.brightness
    private var isControllingBrightness = false
    private var flashlightBrightnessActive = false  // 新增：跟踪手电筒亮度控制状态
    
    // 添加记录定格时方向的属性
    private var pausedOriginalOrientation: UIDeviceOrientation?
    private var pausedMirroredOrientation: UIDeviceOrientation?
    
    // 添加缩放相关属性
    private var currentImageScale: CGFloat = 1.0
    private var currentMirroredImageScale: CGFloat = 1.0
    private var originalCameraScale: CGFloat = 1.0
    private var mirroredCameraScale: CGFloat = 1.0
    
    // 添加保存定格时摄像头比例的属性
    private var pausedOriginalCameraScale: CGFloat = 1.0
    private var pausedMirroredCameraScale: CGFloat = 1.0
    
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
    
    // 修改下载图片方法
    func downloadImage(for screenID: ScreenID) {
        print("------------------------")
        print("[下载功能] 开始")
        print("目标区域：\(screenID == .original ? "Original" : "Mirrored")屏幕")
        print("------------------------")
        
        // 获取要保存的图片
        let imageToSave = screenID == .original ? _originalPausedImage : _mirroredPausedImage
        
        guard let imageToSave = imageToSave else {
            print("------------------------")
            print("[下载功能] 错误：没有可保存的图片")
            print("------------------------")
            hideRectangle()
            return
        }
        
        // 获取定格时的方向
        let pausedOrientation = screenID == .original ? pausedOriginalOrientation : pausedMirroredOrientation
        
        // 裁剪图片为分屏大小
        let croppedImage = ImageCropUtility.shared.cropImageToScreenSize(
            imageToSave,
            for: screenID,
            offset: currentOffset,
            isLandscape: pausedOrientation?.isLandscape ?? false
        )
        
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
    
    // 修改设置定格图片的方法
    func setPausedImage(
        _ image: UIImage?,
        for screenID: ScreenID,
        scale: CGFloat = 1.0,
        cameraScale: CGFloat = 1.0,
        isDualScreenMode: Bool = false,
        otherScreenImage: UIImage? = nil
    ) {
        print("------------------------")
        print("[setPausedImage] 参数验证")
        print("1. 输入scale: \(Int(scale * 100))%")
        print("2. 输入cameraScale: \(Int(cameraScale * 100))%")
        print("3. 预期最终比例: \(Int(scale * cameraScale * 100))%")
        print("------------------------")
        
        // 移除 do-catch 块，直接进行空值检查
        guard let image = image else {
            print("------------------------")
            print("[setPausedImage] 错误：输入图片为空")
            print("------------------------")
            return
        }
        
        // 设置选中的屏幕ID
        selectedScreenID = screenID
        
        // 重置偏移量
        setOffset(.zero, maxOffset: .zero)
        
        // 记录当前设备方向
        let orientation = UIDevice.current.orientation
        let lastValidOrientation = DeviceOrientationManager.shared.validOrientation
        
        print("[方向信息]")
        print("当前方向: \(orientation.rawValue)")
        print("最后有效方向: \(lastValidOrientation.rawValue)")
        
        // 设置方向
        let finalOrientation = DeviceOrientationManager.shared.isAllowedOrientation(orientation) ? 
            orientation : lastValidOrientation
        
        if screenID == .original {
            pausedOriginalOrientation = finalOrientation
        } else {
            pausedMirroredOrientation = finalOrientation
        }
        
        // 根据当前方向和定格方向裁剪图片
        let currentOrientation = DeviceOrientationManager.shared.validOrientation
        let pausedOrientation = screenID == .original ? 
            pausedOriginalOrientation : pausedMirroredOrientation
        
        print("[裁剪前]")
        print("目标方向: \(currentOrientation.rawValue)")
        print("定格方向: \(pausedOrientation?.rawValue ?? -1)")
        print("原始图片尺寸: \(Int(image.size.width))x\(Int(image.size.height))")
        
        // 使用 ImageCropUtility 裁剪图片，强制使用1.0的scale
        let adjustedImage = ImageCropUtility.shared.cropPausedImage(
            image,
            for: screenID,
            targetOrientation: currentOrientation,
            pausedOrientation: pausedOrientation ?? currentOrientation,
            offset: .zero,
            scale: 1.0,  // 强制使用100%比例
            cameraScale: cameraScale  // 强制使用100%比例
        )
        
        guard adjustedImage.size.width > 0 && adjustedImage.size.height > 0 else {
            print("------------------------")
            print("[setPausedImage] 错误：裁剪后图片尺寸无效")
            print("------------------------")
            return
        }
        
        print("[裁剪后]")
        print("裁剪后图片尺寸: \(Int(adjustedImage.size.width))x\(Int(adjustedImage.size.height))")
        
        // 设置裁剪后的图片
        if screenID == .original {
            self.originalPausedImage = adjustedImage
            self._originalPausedImage = adjustedImage
            self.selectedImage = adjustedImage
            print("[Original] 图片已设置")
            print("- 公共属性 originalPausedImage: \(self.originalPausedImage != nil ? "存在" : "为空")")
            print("- 私有属性 _originalPausedImage: \(self._originalPausedImage != nil ? "存在" : "为空")")
            
            // 如果是双屏模式，同时设置另一个屏幕的图片
            if isDualScreenMode, let otherImage = otherScreenImage {
                self.mirroredPausedImage = otherImage
                self._mirroredPausedImage = otherImage
                print("[Mirrored] 双屏模式下的图片已设置")
            }
        } else {
            self.mirroredPausedImage = adjustedImage
            self._mirroredPausedImage = adjustedImage
            self.selectedImage = adjustedImage
            print("[Mirrored] 图片已设置")
            print("- 公共属性 mirroredPausedImage: \(self.mirroredPausedImage != nil ? "存在" : "为空")")
            print("- 私有属性 _mirroredPausedImage: \(self._mirroredPausedImage != nil ? "存在" : "为空")")
            
            // 如果是双屏模式，同时设置另一个屏幕的图片
            if isDualScreenMode, let otherImage = otherScreenImage {
                self.originalPausedImage = otherImage
                self._originalPausedImage = otherImage
                print("[Original] 双屏模式下的图片已设置")
            }
        }

        // 强制重置缩放比例为1.0（100%）
        if screenID == .original {
            print("重置 Original 缩放比例为: 100%")
            currentImageScale = 1.0
            originalCameraScale = 1.0
            pausedOriginalCameraScale = 1.0
            
            // 如果是双屏模式，同时重置另一个屏幕的缩放比例
            if isDualScreenMode {
                print("重置 Mirrored 缩放比例为: 100%（双屏模式）")
                currentMirroredImageScale = 1.0
                mirroredCameraScale = 1.0
                pausedMirroredCameraScale = 1.0
            }
        } else {
            print("重置 Mirrored 缩放比例为: 100%")
            currentMirroredImageScale = 1.0
            mirroredCameraScale = 1.0
            pausedMirroredCameraScale = 1.0
            
            // 如果是双屏模式，同时重置另一个屏幕的缩放比例
            if isDualScreenMode {
                print("重置 Original 缩放比例为: 100%（双屏模式）")
                currentImageScale = 1.0
                originalCameraScale = 1.0
                pausedOriginalCameraScale = 1.0
            }
        }
        
        // 如果是双屏模式，发送通知通知两个屏幕都需要重置缩放
        if isDualScreenMode {
            NotificationCenter.default.post(
                name: NSNotification.Name("ResetScreenScales"),
                object: nil
            )
        }
        
        print("------------------------")
    }
    
    // 添加设置偏移量的方法
    func setOffset(_ offset: CGSize, maxOffset: CGSize) {
        self.currentOffset = offset
        self.maxOffset = maxOffset
    }
    
    // 修改裁剪图片到屏幕大小的方法
    func cropImageToScreenSize(_ image: UIImage, for screenID: ScreenID) -> UIImage {
        // 获取设备方向
        let orientation = UIDevice.current.orientation
        
        // 使用ImageCropUtility进行裁剪，传入当前偏移量
        return ImageCropUtility.shared.cropImageToScreenSize(
            image,
            for: screenID,
            offset: currentOffset,
            isLandscape: orientation.isLandscape
        )
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
    
    // 检查手电筒状态
    private func canActivateFlashlight(for screenID: ScreenID) -> Bool {
        switch screenID {
        case .original:
            if isFlashlightActiveMirrored {
                showFlashlightAlert = true
                return false
            }
            return true
        case .mirrored:
            if isFlashlightActiveOriginal {
                showFlashlightAlert = true
                return false
            }
            return true
        }
    }
    
    // 修改设置手电筒状态的方法
    private func setFlashlightState(for screenID: ScreenID, active: Bool) {
        switch screenID {
        case .original:
            isFlashlightActiveOriginal = active
        case .mirrored:
            isFlashlightActiveMirrored = active
        }
        
        // 更新亮度控制
        updateBrightnessControl()
    }
    
    // 添加亮度控制更新方法
    private func updateBrightnessControl() {
        let shouldControlBrightness = isFlashlightActiveOriginal || isFlashlightActiveMirrored
        
        if shouldControlBrightness && !flashlightBrightnessActive {
            // 保存当前亮度并设置为最大
            originalBrightness = UIScreen.main.brightness
            UIScreen.main.brightness = 1.0
            flashlightBrightnessActive = true
            
            print("------------------------")
            print("[手电筒] 亮度控制已激活")
            print("原始亮度：\(originalBrightness)")
            print("当前亮度：1.0")
            print("------------------------")
            
        } else if !shouldControlBrightness && flashlightBrightnessActive {
            // 恢复原始亮度
            UIScreen.main.brightness = originalBrightness
            flashlightBrightnessActive = false
            
            print("------------------------")
            print("[手电筒] 亮度控制已解除")
            print("亮度已恢复：\(originalBrightness)")
            print("------------------------")
        }
    }
    
    // 修改直接设置矩形图片的方法
    func setRectangleImage(for screenID: ScreenID) {
        print("------------------------")
        print("[手电筒功能] 开始")
        print("目标区域：\(screenID == .original ? "Original" : "Mirrored")屏幕")
        print("------------------------")
        
        // 检查是否可以激活手电筒
        if !canActivateFlashlight(for: screenID) {
            print("------------------------")
            print("[手电筒功能] 已被阻止")
            print("原因：另一个分屏已在使用手电筒")
            print("------------------------")
            return
        }
        
        // 获取对应屏幕的矩形图片
        if let image = RectangleImageManager.shared.getImage(for: screenID) {
            // 设置选中的屏幕ID
            selectedScreenID = screenID
            
            // 开始图片处理
            startImageProcessing()
            
            // 直接设置定格图片
            setPausedImage(image, for: screenID)
            
            // 设置手电筒状态为激活
            setFlashlightState(for: screenID, active: true)
            
            // 结束图片处理
            endImageProcessing()
            
            print("------------------------")
            print("[手电筒功能] 完成")
            print("图片尺寸: \(Int(image.size.width))x\(Int(image.size.height))")
            print("------------------------")
        }
        
        // 隐藏上传控件
        hideRectangle()
    }
    
    // 修改关闭手电筒方法
    func closeFlashlight(for screenID: ScreenID) {
        print("------------------------")
        print("[手电筒功能] 开始关闭")
        print("区域：\(screenID == .original ? "Original" : "Mirrored")屏幕")
        print("当前状态：")
        print("  Original手电筒：\(isFlashlightActiveOriginal ? "开启" : "关闭")")
        print("  Mirrored手电筒：\(isFlashlightActiveMirrored ? "开启" : "关闭")")
        
        // 清除图片
        setPausedImage(nil, for: screenID)
        
        // 重置手电筒状态
        setFlashlightState(for: screenID, active: false)
        
        // 发送通知以退出定格状态
        NotificationCenter.default.post(
            name: NSNotification.Name("ExitPausedState"),
            object: nil,
            userInfo: ["screenID": screenID]
        )
        
        print("关闭后状态：")
        print("  Original手电筒：\(isFlashlightActiveOriginal ? "开启" : "关闭")")
        print("  Mirrored手电筒：\(isFlashlightActiveMirrored ? "开启" : "关闭")")
        print("------------------------")
    }
    
    // 检查是否有全屏灯激活
    func isFlashlightActive(for screenID: ScreenID) -> Bool {
        switch screenID {
        case .original:
            return isFlashlightActiveOriginal
        case .mirrored:
            return isFlashlightActiveMirrored
        }
    }
    
    // 添加分屏交换时的手电筒状态处理方法
    func handleScreenSwap() {
        print("------------------------")
        print("[分屏交换] 开始")
        print("交换前状态：")
        print("  Original手电筒：\(isFlashlightActiveOriginal ? "开启" : "关闭")")
        print("  Mirrored手电筒：\(isFlashlightActiveMirrored ? "开启" : "关闭")")
        
        // 交换手电筒状态
        let tempOriginal = isFlashlightActiveOriginal
        isFlashlightActiveOriginal = isFlashlightActiveMirrored
        isFlashlightActiveMirrored = tempOriginal
        
        // 交换定格图片
        let tempOriginalImage = pausedOriginalImage
        pausedOriginalImage = pausedMirroredImage
        pausedMirroredImage = tempOriginalImage
        
        print("交换后状态：")
        print("  Original手电筒：\(isFlashlightActiveOriginal ? "开启" : "关闭")")
        print("  Mirrored手电筒：\(isFlashlightActiveMirrored ? "开启" : "关闭")")
        print("------------------------")
        
        // 发送通知以更新界面
        NotificationCenter.default.post(
            name: NSNotification.Name("FlashlightStateDidChange"),
            object: nil,
            userInfo: [
                "originalActive": isFlashlightActiveOriginal,
                "mirroredActive": isFlashlightActiveMirrored
            ]
        )
    }
    
    // 修改关闭所有手电筒的方法
    func closeAllFlashlights() {
        print("------------------------")
        print("[手电筒功能] 开始关闭所有")
        print("当前状态：")
        print("  Original手电筒：\(isFlashlightActiveOriginal ? "开启" : "关闭")")
        print("  Mirrored手电筒：\(isFlashlightActiveMirrored ? "开启" : "关闭")")
        
        // 如果有任何手电筒开启，则关闭它们
        if isFlashlightActiveOriginal {
            closeFlashlight(for: .original)
        }
        if isFlashlightActiveMirrored {
            closeFlashlight(for: .mirrored)
        }
        
        print("关闭后状态：")
        print("  Original手电筒：\(isFlashlightActiveOriginal ? "开启" : "关闭")")
        print("  Mirrored手电筒：\(isFlashlightActiveMirrored ? "开启" : "关闭")")
        print("------------------------")
    }
    
    // 在 ImageUploader 类中添加上传成功的提示方法
    func showUploadSuccessToast() {
        self.toastMessage = "上传成功"
        self.showToast = true
        // 2秒后自动隐藏提示
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.showToast = false
        }
    }
    
    // 添加这些方法到 ImageUploader 类中
    func getOriginalCameraScale() -> CGFloat {
        return originalCameraScale
    }

    func getMirroredCameraScale() -> CGFloat {
        return mirroredCameraScale
    }
    
    // 修改定格图片相关的属性和方法
    private var _originalPausedImage: UIImage?
    private var _mirroredPausedImage: UIImage?
    
    // 获取当前摄像头画面
    func getCurrentFrame(for screenID: ScreenID) -> UIImage? {
        // 如果已经有定格的图片，返回定格的图片
        switch screenID {
        case .original:
            if let existingImage = _originalPausedImage {
                print("------------------------")
                print("[获取画面] 返回Original定格图片")
                print("图片尺寸：\(Int(existingImage.size.width))x\(Int(existingImage.size.height))")
                print("------------------------")
                return existingImage
            }
        case .mirrored:
            if let existingImage = _mirroredPausedImage {
                print("------------------------")
                print("[获取画面] 返回Mirrored定格图片")
                print("图片尺寸：\(Int(existingImage.size.width))x\(Int(existingImage.size.height))")
                print("------------------------")
                return existingImage
            }
        }
        
        // 如果没有定格的图片，返回 nil
        print("------------------------")
        print("[获取画面] 无定格图片：\(screenID == .original ? "Original" : "Mirrored")")
        print("------------------------")
        return nil
    }
    
    init() {
        // 添加手电筒状态检查通知监听
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("CheckFlashlightState"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            
            // 检查是否有任一手电筒处于活动状态
            let isActive = self.isFlashlightActiveOriginal || self.isFlashlightActiveMirrored
            
            // 如果通知中包含回调，则执行回调
            if let userInfo = notification.userInfo,
               let completion = userInfo["completion"] as? (Bool) -> Void {
                completion(isActive)
            }
            
            print("------------------------")
            print("[手电筒] 状态检查")
            print("Original：\(self.isFlashlightActiveOriginal ? "开启" : "关闭")")
            print("Mirrored：\(self.isFlashlightActiveMirrored ? "开启" : "关闭")")
            print("------------------------")
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
                    .alert(isPresented: $imageUploader.showFlashlightAlert) {
                        Alert(
                            title: Text("提示"),
                            message: Text("双屏无法同时开启全屏灯!"),
                            dismissButton: .default(Text("确定"))
                        )
                    }
                    
                    // 提示视图移到这里，确保显示在最上层
                    if imageUploader.showToast {
                        ZStack {
                            if imageUploader.showDownloadOverlay {
                                // 下载成功提示
                                VStack {
                                    Image(systemName: "square.and.arrow.down.fill")
                                        .font(.system(size: 80))
                                        .opacity(0)
                                        .padding(.bottom, 30)
                                    
                                    Text(imageUploader.toastMessage)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(Color.black.opacity(0.7))
                                        .cornerRadius(10)
                                }
                            } else {
                                // 上传成功提示
                                Text(imageUploader.toastMessage)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.black.opacity(0.7))
                                    .cornerRadius(10)
                            }
                        }
                        .rotationEffect(getRotationAngle(deviceOrientation))
                        .frame(width: 210, height: 210)
                        .contentShape(Rectangle())
                        .animation(.easeInOut(duration: 0.5), value: deviceOrientation)
                        .zIndex(999) // 确保显示在最上层
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
                    .contentShape(Rectangle())
                    .rotationEffect(getRotationAngle(deviceOrientation))  // 整体旋转
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
                    .contentShape(Rectangle())
                    .rotationEffect(getRotationAngle(deviceOrientation))  // 整体旋转
                    .onAppear {
                        print("------------------------")
                        print("[Mirrored屏幕] centerY值: \(centerY)")
                        print("屏幕高度: \(screenHeight)")
                        print("------------------------")
                    }
            }
            
            // 按钮容器
            HStack(spacing: 50) {
                // 手电筒按钮
                Button(action: {
                    // 触发震动反馈
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.prepare()
                    generator.impactOccurred()
                    
                    print("------------------------")
                    print("[手电筒按钮] 点击")
                    print("区域：\(screenID == .original ? "Original" : "Mirrored")屏幕")
                    print("当前设备方向：\(getOrientationDescription(deviceOrientation))")
                    print("------------------------")   
                    
                    // 直接设置矩形图片
                    imageUploader.setRectangleImage(for: screenID)
                }) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 80))
                        .frame(width: 80, height: 80)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle(normalColor: screenID == .original ? .white : .black))
                
                // 上传按钮
                Button(action: {
                    // 触发震动反馈
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.prepare()
                    generator.impactOccurred()
                    
                    print("------------------------")
                    print("[上传按钮] 点击")
                    print("区域：\(screenID == .original ? "Original" : "Mirrored")屏幕")
                    print("当前设备方向：\(getOrientationDescription(deviceOrientation))")
                    print("------------------------")   
                    imageUploader.uploadImage(for: screenID)
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 80))
                        .frame(width: 80, height: 80)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle(normalColor: screenID == .original ? .white : .black))
            }
            .rotationEffect(getRotationAngle(deviceOrientation))  // 按钮容器整体旋转
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
                // 触发震动反馈
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.prepare()
                generator.impactOccurred()
                
                print("------------------------")
                print("[下载按钮] 点击")
                print("区域：\(screenID == .original ? "Original" : "Mirrored")屏幕")
                print("当前设备方向：\(getOrientationDescription(deviceOrientation))")
                print("------------------------")   
                imageUploader.downloadImage(for: screenID)
            }) {
                Image(systemName: "square.and.arrow.down.fill")
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
                // 获取当前设备方向
                let orientation = UIDevice.current.orientation
                
                // 根据设备方向调整图片
                let rotatedImage: UIImage
                if DeviceOrientationManager.shared.isAllowedOrientation(orientation) {
                    switch orientation {
                    case .landscapeLeft:
                        rotatedImage = image.rotate(degrees: 0)  // 向左横屏时顺时针旋转90度
                    case .landscapeRight:
                        rotatedImage = image.rotate(degrees: 0) // 向右横屏时逆时针旋转90度
                    case .portraitUpsideDown:
                        // 对于倒置方向，两个分屏都保持一致的处理
                        rotatedImage = image.rotate(degrees: 0)
                    default:
                        rotatedImage = image
                    }
                } else {
                    // 如果不是允许的方向，使用最后一个有效方向
                    let lastValidOrientation = DeviceOrientationManager.shared.validOrientation
                    switch lastValidOrientation {
                    case .landscapeLeft:
                        rotatedImage = image.rotate(degrees: 0)
                    case .landscapeRight:
                        rotatedImage = image.rotate(degrees: 0)
                    case .portraitUpsideDown:
                        rotatedImage = image.rotate(degrees: 0)
                    default:
                        rotatedImage = image
                    }
                }
                
                // 裁剪旋转后的图片
                let croppedImage = self.parent.imageUploader?.cropImageToScreenSize(
                    rotatedImage,
                    for: self.parent.screenID
                ) ?? rotatedImage
                
                self.parent.selectedImage = croppedImage
                
                print("------------------------")
                print("[图片选择器] 已选择图片")
                print("原始尺寸：\(Int(image.size.width))x\(Int(image.size.height))")
                print("旋转后尺寸：\(Int(rotatedImage.size.width))x\(Int(rotatedImage.size.height))")
                print("裁剪后尺寸：\(Int(croppedImage.size.width))x\(Int(croppedImage.size.height))")
                print("设备方向：\(orientation.rawValue)")
                print("目标区域：\(self.parent.screenID == .original ? "Original" : "Mirrored")屏幕")
                print("------------------------")
                
                // 保存裁剪后的图片
                self.parent.imageUploader?.setPausedImage(croppedImage, for: self.parent.screenID)
                
                // 关闭图片选择器
                self.parent.presentationMode.wrappedValue.dismiss()
                
                // 显示上传成功提示
                self.parent.imageUploader?.showUploadSuccessToast()
                
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