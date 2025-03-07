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
            // 已经有权限，初始化方向管理器
            _ = DeviceOrientationManager.shared
        case .notDetermined:
            print("相机权限状态：未确定")
            print("------------------------")
            // 请求权限
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    print("------------------------")
                    print("用户首次授予相机权限")
                    print("------------------------")
                    DispatchQueue.main.async {
                        _ = DeviceOrientationManager.shared
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
    
    deinit {
        // 不再需要处理方向监测的清理，由 DeviceOrientationManager 负责
    }
}
