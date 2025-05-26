import SwiftUI
import UIKit

class DayNightManager: ObservableObject {
    static let shared = DayNightManager()
    
    @Published var isDayMode: Bool {
        didSet {
            print("------------------------")
            print("[昼夜模式] 切换")
            print("当前模式：\(isDayMode ? "白天" : "夜晚")")
            print("------------------------")
            
            // 保存设置
            UserDefaults.standard.set(isDayMode, forKey: "isDayMode")
            
            // 发送通知
            NotificationCenter.default.post(
                name: NSNotification.Name("DayNightModeChanged"),
                object: nil,
                userInfo: ["isDayMode": isDayMode]
            )
            
            // 根据模式切换背景颜色和功能
            if isDayMode {
                enableDayMode()
            } else {
                enableNightMode()
            }
        }
    }
    
    // 添加背景颜色属性
    @Published var backgroundColor: Color = .black
    
    // 添加弹窗状态
    @Published var showNightModeAlert = false
    
    private init() {
        // 从 UserDefaults 加载设置，如果没有保存过设置，默认为白天模式
        self.isDayMode = UserDefaults.standard.object(forKey: "isDayMode") as? Bool ?? true
        
        // 初始化时根据模式设置背景颜色
        if isDayMode {
            backgroundColor = .black
        } else {
            backgroundColor = UserSettingsManager.shared.loadBorderLightColor()
        }
        
        print("------------------------")
        print("[昼夜模式管理器] 初始化")
        print("初始模式：\(isDayMode ? "白天" : "夜晚")")
        print("------------------------")
        
        // 监听边框灯颜色变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBorderLightColorChanged),
            name: NSNotification.Name("BorderLightColorChanged"),
            object: nil
        )
    }
    
    // MARK: - 白天模式函数
    private func enableDayMode() {
        print("------------------------")
        print("[昼夜模式] 启用白天模式")
        print("------------------------")
        
        // 设置背景为黑色
        backgroundColor = .black
        
        // 发送背景颜色变化通知
        NotificationCenter.default.post(
            name: NSNotification.Name("BackgroundColorChanged"),
            object: nil,
            userInfo: ["backgroundColor": backgroundColor]
        )
    }
    
    // MARK: - 夜晚模式函数
    private func enableNightMode() {
        print("------------------------")
        print("[昼夜模式] 启用夜晚模式")
        print("------------------------")
        
        // 获取当前边框灯颜色
        let borderLightColor = UserSettingsManager.shared.loadBorderLightColor()
        backgroundColor = borderLightColor
        
        // 发送背景颜色变化通知
        NotificationCenter.default.post(
            name: NSNotification.Name("BackgroundColorChanged"),
            object: nil,
            userInfo: ["backgroundColor": backgroundColor]
        )
        
        // 获取当前闪光灯设置
        let currentSettings = UserSettingsManager.shared.loadFlashSettings()
        
        // 只有在设置不同时才更新
        if !currentSettings.isEnabled || currentSettings.intensity != .strong {
            // 1. 自动开启闪光并设置为强度
            AppConfig.AnimationConfig.Flash.isEnabled = true
            AppConfig.AnimationConfig.Flash.intensity = .strong
            
            // 保存闪光灯设置
            UserSettingsManager.shared.saveFlashSettings(
                isEnabled: true,
                intensity: .strong
            )
            
            // 发送闪光设置变化通知
            NotificationCenter.default.post(
                name: NSNotification.Name("FlashSettingChanged"),
                object: nil,
                userInfo: [
                    "isEnabled": true,
                    "intensity": AppConfig.AnimationConfig.Flash.Intensity.strong
                ]
            )
            
            print("------------------------")
            print("[昼夜模式] 更新闪光灯设置")
            print("- 开启状态：开启")
            print("- 闪光强度：强")
            print("------------------------")
        }
        
        // 2. 检查并开启灯光功能
        NotificationCenter.default.post(
            name: NSNotification.Name("CheckAndEnableLightInNightMode"),
            object: nil
        )
        
        // 3. 自动切换到全景模式
        NotificationCenter.default.post(
            name: NSNotification.Name("AutoEnterPanoramaMode"),
            object: nil
        )
    }
    
    // MARK: - 模式切换函数
    func toggleMode() {
        if isDayMode {
            // 如果要切换到夜晚模式，显示系统确认弹窗
            showSystemAlert()
        } else {
            // 如果要切换到白天模式，直接切换
            isDayMode = true
        }
    }
    
    // 显示系统确认弹窗
    private func showSystemAlert() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            
            let alertController = UIAlertController(
                title: "切换到夜间模式",
                message: "将有以下改动：\n• 开启灯光并切换至全景模式\n• 增加背景补光\n• 拍照时自动开启最强闪光",
                preferredStyle: .alert
            )
            
            alertController.addAction(UIAlertAction(title: "确认", style: .default) { [weak self] _ in
                self?.isDayMode = false
            })
            
            alertController.addAction(UIAlertAction(title: "取消", style: .cancel))
            
            rootViewController.present(alertController, animated: true)
        }
    }
    
    // MARK: - 通知处理
    @objc private func handleBorderLightColorChanged(_ notification: Notification) {
        // 只在夜晚模式下更新背景颜色
        if !isDayMode, let color = notification.userInfo?["color"] as? Color {
            print("------------------------")
            print("[昼夜模式] 接收到边框灯颜色变化")
            print("更新背景颜色")
            print("------------------------")
            
            withAnimation(.easeInOut(duration: 0.3)) {
                backgroundColor = color
            }
            
            // 发送背景颜色变化通知
            NotificationCenter.default.post(
                name: NSNotification.Name("BackgroundColorChanged"),
                object: nil,
                userInfo: ["backgroundColor": backgroundColor]
            )
        }
    }
} 