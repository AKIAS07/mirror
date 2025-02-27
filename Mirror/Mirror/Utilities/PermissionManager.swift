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

// 权限管理器
class PermissionManager: ObservableObject {
    static let shared = PermissionManager()
    
    @Published private(set) var photoLibraryStatus: PHAuthorizationStatus = .notDetermined
    @Published private(set) var cameraPermissionGranted = false
    
    // 添加一个属性来存储当前处理的图片
    private var currentImage: UIImage?
    
    // Alert 状态管理
    @Published var alertState: AlertState?
    
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
    }
    
    // MARK: - 相册权限处理
    
    func handlePhotoLibraryAccess(for image: UIImage, completion: @escaping (Bool) -> Void) {
        currentImage = image
        
        // 每次请求时重新获取最新的权限状态
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        print("[相册权限] 当前状态: \(status.rawValue)")
        photoLibraryStatus = status  // 更新状态
        
        switch status {
        case .authorized, .limited:
            print("[相册权限] 已授权，直接保存")
            saveImageToPhotoLibrary(image) { success in
                DispatchQueue.main.async {
                    self.alertState = success ? .success : .error
                    completion(success)
                }
            }
            
        case .notDetermined:
            print("[相册权限] 未确定，显示首次授权弹窗")
            DispatchQueue.main.async {
                self.alertState = .permission(isFirstRequest: true)
            }
            
        case .denied, .restricted:
            print("[相册权限] 已拒绝或受限，显示设置弹窗")
            DispatchQueue.main.async {
                self.alertState = .permission(isFirstRequest: false)
            }
            
        @unknown default:
            DispatchQueue.main.async {
                self.alertState = .error
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
    }
    
    // 修改权限确认处理方法
    func handlePhotoLibraryPermissionConfirmed(for image: UIImage, completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
            DispatchQueue.main.async {
                self?.photoLibraryStatus = status  // 更新状态
                
                switch status {
                case .authorized, .limited:
                    print("[相册权限] 用户已授权")
                    self?.saveImageToPhotoLibrary(image) { success in
                        DispatchQueue.main.async {
                            self?.alertState = success ? .success : .error
                            completion(success)
                        }
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
                        // 使用保存的图片
                        if let image = self.currentImage {
                            self.handlePhotoLibraryPermissionConfirmed(for: image) { success in
                                if !success {
                                    self.handleAlertDismiss()
                                }
                            }
                        } else {
                            self.handleAlertDismiss()
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
    }
}

// 相机权限请求视图
struct CameraPermissionView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.yellow.edgesIgnoringSafeArea(.all)
                
                VStack {
                    Image("icon-bf-white")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                        .position(x: geometry.size.width/2, y: geometry.size.height/2-100)
                        .foregroundColor(.white)
                        .font(.largeTitle)
                    Text("使用此APP需要您开启相机权限")
                        .foregroundColor(.white)
                        .position(x: geometry.size.width/2, y: geometry.size.height/2)
                        .padding()
                    Button(action: {
                        PermissionManager.shared.openSettings()
                    }) {
                        Text("授权相机")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black)
                            .cornerRadius(8)
                    }
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