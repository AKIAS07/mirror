//
//  MirrorApp.swift
//  Mirror
//
//  Created by 林喵 on 2024/12/16.
//

import SwiftUI

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
        // 添加设备方向变化通知监听
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(orientationDidChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
        
        // 开启设备方向监测
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        
        return true
    }
    
    @objc func orientationDidChange() {
        let orientation = UIDevice.current.orientation
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
        case .faceUp:
            print("当前方向：面朝上平放")
        case .faceDown:
            print("当前方向：面朝下平放")
        case .unknown:
            print("当前方向：未知方向")
        @unknown default:
            print("当前方向：其他未知方向")
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
