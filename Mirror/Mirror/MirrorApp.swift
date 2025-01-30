//
//  MirrorApp.swift
//  Mirror
//
//  Created by 林喵 on 2024/12/16.
//

import SwiftUI
import AVFoundation

@main
struct MirrorApp: App {
    // 添加应用程序代理
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// 添加应用程序代理类
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        // 只允许竖屏
        return .portrait
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        print("------------------------")
        print("应用启动")
        print("------------------------")
        // 检查相机权限状态
        checkCameraPermission()
        return true
    }
    
    private func checkCameraPermission() {
        print("------------------------")
        print("检查相机权限")
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            print("相机权限状态：已授权")
            print("------------------------")
            // 已经有权限，直接开始监测设备方向
            startOrientationMonitoring()
        case .notDetermined:
            print("相机权限状态：未确定")
            print("------------------------")
            // 请求权限
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    print("------------------------")
                    print("用户首次授予相机权限")
                    print("------------------------")
                    DispatchQueue.main.async {
                        self?.startOrientationMonitoring()
                    }
                } else {
                    print("------------------------")
                    print("用户首次拒绝相机权限")
                    print("------------------------")
                }
            }
        case .denied:
            print("相机权限状态：已拒绝")
            print("------------------------")
        case .restricted:
            print("相机权限状态：受限制")
            print("------------------------")
        @unknown default:
            print("相机权限状态：未知")
            print("------------------------")
        }
    }
    
    private func startOrientationMonitoring() {
        // 设置允许的设备方向
        let allowedOrientations: [UIDeviceOrientation] = [
            .portrait,
            .portraitUpsideDown,
            .landscapeLeft,
            .landscapeRight
        ]
        
        // 添加设备方向变化通知监听，使用 block 方式以便过滤方向
        NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            let orientation = UIDevice.current.orientation
            
            // 只处理允许的方向
            guard allowedOrientations.contains(orientation) else {
                return
            }
            
            self?.handleOrientationChange(orientation)
        }
        
        // 开启设备方向监测
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        
        // 立即获取一次当前方向
        if allowedOrientations.contains(UIDevice.current.orientation) {
            handleOrientationChange(UIDevice.current.orientation)
        }
    }
    
    private func handleOrientationChange(_ orientation: UIDeviceOrientation) {
        print("------------------------")
        print("设备方向发生变化")
        print("时间：\(Date())")
        
        switch orientation {
        case .portrait:
            print("当前方向：竖屏")
        case .portraitUpsideDown:
            print("当前方向：倒置竖屏")
        case .landscapeLeft:
            print("当前方向：向左横屏")
        case .landscapeRight:
            print("当前方向：向右横屏")
        default:
            break
        }
        
        print("原始值：\(orientation.rawValue)")
        print("------------------------")
    }
    
    deinit {
        // 停止设备方向监测
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.removeObserver(self)
    }
}
