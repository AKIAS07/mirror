import SwiftUI
import AVFoundation

class ContentRestartManager: ObservableObject {
    static let shared = ContentRestartManager()
    
    @Published var isCameraActive = true
    @Published var showRestartHint = false
    
    private init() {}
    
    // 方法1: 当 RestartCameraView 显示时，自动触发摄像头关闭
    func handleRestartViewAppear(cameraManager: CameraManager) {
        print("------------------------")
        print("RestartCameraView 显示，自动关闭摄像头")
        print("------------------------")
        
        // 停止相机会话
        cameraManager.safelyStopSession()
        isCameraActive = false
    }
    
    // 方法2: 点击 RestartCameraView 时，触发 restartCamera
    func restartCamera(cameraManager: CameraManager) {
        if !cameraManager.permissionGranted {
            print("无相机权限，无法重启相机")
            return
        }
        
        print("重启相机会话")
        
        // 在后台线程重启相机
        DispatchQueue.global(qos: .userInitiated).async {
            // 确保相机完全停止
            cameraManager.safelyStopSession()
            
            // 添加短暂延迟确保会话完全停止
            Thread.sleep(forTimeInterval: 0.3)
            
            // 重新设置相机
            cameraManager.setupCamera()
            
            // 在主线程更新 UI 状态
            DispatchQueue.main.async {
                self.isCameraActive = true
                self.showRestartHint = false
                print("相机会话已重启")
            }
        }
    }
    
    // 方法3: 处理应用进入后台
    func handleAppWillResignActive(cameraManager: CameraManager) {
        print("------------------------")
        print("应用即将进入后台")
        print("------------------------")
        
        cameraManager.safelyStopSession()
        isCameraActive = false
        showRestartHint = true
    }
    
    // 方法4: 处理应用返回前台
    func handleAppDidBecomeActive() {
        print("------------------------")
        print("应用已返回前台")
        print("------------------------")
        
        isCameraActive = false
        showRestartHint = true
    }
} 