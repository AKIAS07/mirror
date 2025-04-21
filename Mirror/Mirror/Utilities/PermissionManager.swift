import SwiftUI
import Photos
import AVFoundation

// 权限类型枚举
enum PermissionType {
    case camera
    case photoLibrary
}

// 权限状态枚举
enum PermissionStatus {
    case notDetermined
    case denied
    case authorized
    case limited
    case restricted
}

// 修改全局权限管理视图
struct PermissionManagerView: View {
    @StateObject private var manager = PermissionManager.shared
    
    var body: some View {
        ZStack {
            EmptyView()
        }
        .alert(item: $manager.alertState) { state in
            manager.makeAlert()
        }
        .zIndex(999) // 确保 Alert 显示在最上层
    }
}

// 权限管理器
class PermissionManager: ObservableObject {
    static let shared = PermissionManager()
    
    @Published private(set) var photoLibraryStatus: PHAuthorizationStatus = .notDetermined
    @Published private(set) var cameraPermissionGranted = false
    
    // 添加一个属性来存储当前处理的图片
    private var currentImage: UIImage?
    
    // Alert 状态管理
    @Published var alertState: AlertState?
    
    // 添加全局权限状态
    @Published private(set) var permissionState: PermissionState = .unknown
    
    // 权限状态枚举
    enum PermissionState {
        case unknown
        case authorized
        case denied
        case notDetermined
        case limited
    }
    
    // Alert 状态枚举
    public enum AlertState: Identifiable, Equatable {
        case success
        case error
        case permission(isFirstRequest: Bool)
        
        public var id: String {
            switch self {
            case .success: return "success"
            case .error: return "error"
            case .permission: return "permission"
            }
        }
    }
    
    private init() {
        checkInitialCameraPermission()
        updatePermissionState()
    }
    
    // MARK: - 相册权限处理
    
    func handlePhotoLibraryAccess(for image: UIImage, completion: @escaping (Bool) -> Void) {
        currentImage = image
        
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        print("------------------------")
        print("[相册权限] 检查权限")
        print("当前状态: \(status.rawValue)")
        //print("图片是否存在: \(image != nil)")
        print("------------------------")
        
        DispatchQueue.main.async { [weak self] in
            switch status {
            case .authorized, .limited:
                print("[相册权限] 已授权，开始保存图片")
                self?.saveImageToPhotoLibrary(image) { success in
                    print("[相册权限] 保存结果: \(success ? "成功" : "失败")")
                    completion(success)
                }
                
            case .notDetermined:
                print("[相册权限] 未确定，显示自定义权限弹窗")
                self?.alertState = .permission(isFirstRequest: true)
                
            case .denied, .restricted:
                print("[相册权限] 已拒绝或受限，显示设置弹窗")
                self?.alertState = .permission(isFirstRequest: false)
                
            @unknown default:
                print("[相册权限] 未知状态")
                completion(false)
            }
        }
    }
    
    func handleAlertDismiss() {
        print("[权限管理] Alert关闭，重置处理状态")
        // 重置所有相关状态
        alertState = nil
        currentImage = nil
        
        // 重新获取并更新权限状态
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        print("[权限管理] 当前相册权限状态: \(currentStatus.rawValue)")
        photoLibraryStatus = currentStatus
        
        updatePermissionState()
    }
    
    // 修改权限确认处理方法
    func handlePhotoLibraryPermissionConfirmed(for image: UIImage, completion: @escaping (Bool) -> Void) {
        print("------------------------")
        print("[相册权限] 用户确认授权")
        print("------------------------")
        
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
            DispatchQueue.main.async {
                self?.photoLibraryStatus = status
                
                switch status {
                case .authorized, .limited:
                    print("[相册权限] 用户已授权，开始保存图片")
                    self?.saveImageToPhotoLibrary(image) { success in
                        print("[相册权限] 保存结果: \(success ? "成功" : "失败")")
                        completion(success)
                    }
                    
                default:
                    print("[相册权限] 用户未授权")
                    self?.alertState = .permission(isFirstRequest: false)
                    completion(false)
                }
            }
        }
    }
    
    // MARK: - 相机权限处理
    
    public func checkInitialCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraPermissionGranted = true
        case .notDetermined:
            requestCameraPermission()
        default:
            cameraPermissionGranted = false
        }
    }
    
    private func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                self?.cameraPermissionGranted = granted
            }
        }
    }
    
    // MARK: - 辅助方法
    
    private func saveImageToPhotoLibrary(_ image: UIImage, completion: @escaping (Bool) -> Void) {
        print("------------------------")
        print("[相册保存] 开始保存图片")
        print("图片尺寸: \(image.size.width) x \(image.size.height)")
        print("------------------------")

        PHPhotoLibrary.shared().performChanges({
            // 创建保存请求
            let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
            print("[相册保存] 创建请求: \(request)")
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("------------------------")
                    print("[相册保存] 保存成功")
                    print("------------------------")
                    completion(true)
                } else {
                    print("------------------------")
                    print("[相册保存] 保存失败")
                    if let error = error {
                        print("错误信息: \(error.localizedDescription)")
                        print("错误详情: \(error)")
                    }
                    print("------------------------")
                    completion(false)
                }
            }
        }
    }
    
    func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString),
           UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    // MARK: - Alert 视图
    
    func makeAlert() -> Alert {
        guard let state = alertState else {
            return Alert(title: Text(""))
        }
        
        switch state {
        case .success:
            return Alert(
                title: Text("保存成功"),
                message: nil,
                dismissButton: .default(Text("确定")) {
                    self.handleAlertDismiss()
                }
            )
            
        case .error:
            return Alert(
                title: Text("保存失败"),
                message: Text("请确保已授予相册访问权限"),
                dismissButton: .default(Text("确定")) {
                    self.handleAlertDismiss()
                }
            )
            
        case .permission(let isFirstRequest):
            return Alert(
                title: Text("提示"),
                message: Text("此功能需要您开启相册权限！"),
                primaryButton: .default(Text(isFirstRequest ? "确定" : "去设置")) {
                    if isFirstRequest {
                        if let image = self.currentImage {
                            self.handlePhotoLibraryPermissionConfirmed(for: image) { success in
                                if !success {
                                    self.handleAlertDismiss()
                                }
                            }
                        }
                    } else {
                        self.openSettings()
                        self.handleAlertDismiss()
                    }
                },
                secondaryButton: .cancel(Text("取消")) {
                    self.handleAlertDismiss()
                }
            )
        }
    }
    
    // 添加相册权限检查方法
    func checkPhotoLibraryPermission(completion: @escaping (Bool) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        switch status {
        case .authorized, .limited:
            completion(true)
            
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                DispatchQueue.main.async {
                    completion(newStatus == .authorized || newStatus == .limited)
                }
            }
            
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.alertState = .permission(isFirstRequest: false)
                completion(false)
            }
            
        @unknown default:
            DispatchQueue.main.async {
                completion(false)
            }
        }
        
        updatePermissionState()
    }
    
    // 添加全局权限状态更新方法
    func updatePermissionState() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        photoLibraryStatus = status
        
        switch status {
        case .authorized:
            permissionState = .authorized
        case .denied:
            permissionState = .denied
        case .notDetermined:
            permissionState = .notDetermined
        case .limited:
            permissionState = .limited
        case .restricted:
            permissionState = .denied
        @unknown default:
            permissionState = .unknown
        }
        
        objectWillChange.send()
    }
}

// 相机权限请求视图
struct CameraPermissionView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 50) { // 添加固定间距
                    // 图片保持原位置
                    Image("icon-bf-white")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .position(x: geometry.size.width/2, y: geometry.size.height/2-100)
                        .foregroundColor(.white)
                        .font(.largeTitle)
                    
                    // 文字和按钮向上移动并居中
                    VStack(spacing: 265) { // 文字和按钮之间的间距

                        
                        Button(action: {
                            PermissionManager.shared.openSettings()
                        }) {
                            Text("授权相机")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.gray)
                                .cornerRadius(8)
                        }

                        Text("使用此APP需要您开启相机权限")
                            .foregroundColor(.white)
                            .padding()
                    }
                    //.offset(y: -300) // 整体向上偏移
                }
            }
        }
    }
}

// 修改相册权限提示弹窗
public struct PhotoLibraryPermissionAlert {
    let isFirstRequest: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    // 返回 Alert 视图
    func makeAlert() -> Alert {
        print("------------------------")
        print("[Alert] 创建权限弹窗")
        print("[Alert] 按钮文本：\(isFirstRequest ? "确定" : "去设置")")
        print("------------------------")
        
        return Alert(
            title: Text("提示"),
            message: Text("此功能需要您开启相册权限！"),
            primaryButton: .default(Text(isFirstRequest ? "确定" : "去设置")) {
                print("[Alert] 触发确定/去设置回调")
                onConfirm()
            },
            secondaryButton: .cancel(Text("取消")) {
                print("[Alert] 触发取消回调")
                onCancel()
            }
        )
    }
} 
