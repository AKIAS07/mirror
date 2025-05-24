import SwiftUI

// 用户设置的键名常量
private enum UserSettingsKeys {
    static let borderLightColorRed = "borderLightColorRed"
    static let borderLightColorGreen = "borderLightColorGreen"
    static let borderLightColorBlue = "borderLightColorBlue"
    static let borderLightColorAlpha = "borderLightColorAlpha"
    static let borderLightWidth = "borderLightWidth"
    static let gestureMode = "gestureMode"
    static let iconColorRed = "iconColorRed"
    static let iconColorGreen = "iconColorGreen"
    static let iconColorBlue = "iconColorBlue"
    static let iconColorAlpha = "iconColorAlpha"
    static let splitScreenIconColorRed = "splitScreenIconColorRed"
    static let splitScreenIconColorGreen = "splitScreenIconColorGreen"
    static let splitScreenIconColorBlue = "splitScreenIconColorBlue"
    static let splitScreenIconColorAlpha = "splitScreenIconColorAlpha"
    static let hasUserConfig = "hasUserConfig"  // 新增：是否有用户配置
    static let splitScreenIconUseOriginal = "splitScreenIconUseOriginal"
    static let isScreensSwapped = "isScreensSwapped"
    static let originalCameraScale = "originalCameraScale"
    static let mirroredCameraScale = "mirroredCameraScale"
    static let originalImageScale = "originalImageScale"
    static let mirroredImageScale = "mirroredImageScale"
    static let flashEnabled = "FlashEnabled"
    static let flashIntensity = "FlashIntensity"
    static let splitScreenIconImage = "splitScreenIconImage"
    static let autoEnterTwoOfMe = "autoEnterTwoOfMe"
    static let gridSpacing = "gridSpacing"
    static let gridLineColor = "gridLineColor"
    static let gridLineOpacity = "gridLineOpacity"
    static let watermarkEnabled = "watermarkEnabled"  // 添加水印开关键
}

// 添加默认白光颜色常量
private struct DefaultColors {
    static let whiteLight = Color(red: 241/255, green: 235/255, blue: 223/255)
    static let warmLight = Color(red: 245/255, green: 217/255, blue: 155/255)
    static let coolLight = Color(red: 198/255, green: 223/255, blue: 239/255)
}

// 用户设置管理器
class UserSettingsManager {
    static let shared = UserSettingsManager()
    private let defaults = UserDefaults.standard
    
    // 添加缓存
    private var cachedFlashSettings: (isEnabled: Bool, intensity: AppConfig.AnimationConfig.Flash.Intensity)?
    
    private init() {}
    
    // MARK: - 配置管理
    
    // 保存当前配置
    func saveCurrentConfig() {
        defaults.set(true, forKey: UserSettingsKeys.hasUserConfig)
        defaults.synchronize()
        print("已保存用户配置")
    }
    
    // 检查是否有保存的配置
    func hasUserConfig() -> Bool {
        return defaults.bool(forKey: UserSettingsKeys.hasUserConfig)
    }
    
    // 清除所有配置
    func clearAllConfig() {
        let dictionary = defaults.dictionaryRepresentation()
        dictionary.keys.forEach { key in
            defaults.removeObject(forKey: key)
        }
        defaults.synchronize()
        print("已清除所有配置")
    }
    
    // MARK: - 保存设置
    
    // 保存边框灯颜色
    func saveBorderLightColor(_ color: Color) {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        if uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            defaults.set(red, forKey: UserSettingsKeys.borderLightColorRed)
            defaults.set(green, forKey: UserSettingsKeys.borderLightColorGreen)
            defaults.set(blue, forKey: UserSettingsKeys.borderLightColorBlue)
            defaults.set(alpha, forKey: UserSettingsKeys.borderLightColorAlpha)
            defaults.synchronize()
            print("保存边框灯颜色设置 - R:\(red) G:\(green) B:\(blue) A:\(alpha)")
        }
    }
    
    // 保存边框灯宽度
    func saveBorderLightWidth(_ width: CGFloat) {
        defaults.set(width, forKey: UserSettingsKeys.borderLightWidth)
        defaults.synchronize()
        print("保存边框灯宽度设置：\(width)")
    }
    
    // 保存手势模式
    func saveGestureMode(isDefault: Bool) {
        defaults.set(isDefault, forKey: UserSettingsKeys.gestureMode)
        defaults.synchronize()
        print("保存手势模式设置：\(isDefault ? "默认" : "交换")")
    }
    
    // 保存图标颜色
    func saveIconColor(_ color: Color) {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        if uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            defaults.set(red, forKey: UserSettingsKeys.iconColorRed)
            defaults.set(green, forKey: UserSettingsKeys.iconColorGreen)
            defaults.set(blue, forKey: UserSettingsKeys.iconColorBlue)
            defaults.set(alpha, forKey: UserSettingsKeys.iconColorAlpha)
            defaults.synchronize()
            print("保存图标颜色设置 - R:\(red) G:\(green) B:\(blue) A:\(alpha)")
        }
    }
    
    // 保存分屏蝴蝶颜色
    func saveSplitScreenIconColor(_ color: Color) {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        if uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            defaults.set(red, forKey: UserSettingsKeys.splitScreenIconColorRed)
            defaults.set(green, forKey: UserSettingsKeys.splitScreenIconColorGreen)
            defaults.set(blue, forKey: UserSettingsKeys.splitScreenIconColorBlue)
            defaults.set(alpha, forKey: UserSettingsKeys.splitScreenIconColorAlpha)
            defaults.synchronize()
            print("保存分屏蝴蝶颜色设置 - R:\(red) G:\(green) B:\(blue) A:\(alpha)")
            
            // 检查是否是第一个分屏颜色选项
            if let firstSplitScreenColor = splitScreenColors.first,
               firstSplitScreenColor.useOriginalColor {
                let firstColor = UIColor(firstSplitScreenColor.color)
                var firstRed: CGFloat = 0, firstGreen: CGFloat = 0, firstBlue: CGFloat = 0, firstAlpha: CGFloat = 0
                firstColor.getRed(&firstRed, green: &firstGreen, blue: &firstBlue, alpha: &firstAlpha)
                
                if abs(red - firstRed) < 0.01 && abs(green - firstGreen) < 0.01 && abs(blue - firstBlue) < 0.01 {
                    print("保存原始颜色图标设置")
                    defaults.set(true, forKey: UserSettingsKeys.splitScreenIconUseOriginal)
                } else {
                    defaults.set(false, forKey: UserSettingsKeys.splitScreenIconUseOriginal)
                }
            }
        } else {
            print("保存分屏蝴蝶颜色失败")
        }
    }
    
    // 保存分屏蝴蝶设置
    func saveSplitScreenIconSettings(_ option: ColorOption) {
        defaults.set(option.image, forKey: UserSettingsKeys.splitScreenIconImage)
        
        if !option.image.hasPrefix("color") {
            // 只有非图片选项才保存颜色
            let uiColor = UIColor(option.color)
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            
            defaults.set(red, forKey: UserSettingsKeys.splitScreenIconColorRed)
            defaults.set(green, forKey: UserSettingsKeys.splitScreenIconColorGreen)
            defaults.set(blue, forKey: UserSettingsKeys.splitScreenIconColorBlue)
            defaults.set(alpha, forKey: UserSettingsKeys.splitScreenIconColorAlpha)
        }
        
        defaults.synchronize()
    }
    
    // 保存分屏蝴蝶图片
    func saveSplitScreenIconImage(_ image: String) {
        defaults.set(image, forKey: UserSettingsKeys.splitScreenIconImage)
        defaults.synchronize()
        print("保存分屏蝴蝶图片：\(image)")
    }
    
    // MARK: - 闪光灯设置
    
    // 保存闪光灯设置
    func saveFlashSettings(isEnabled: Bool, intensity: AppConfig.AnimationConfig.Flash.Intensity) {
        // 更新缓存
        cachedFlashSettings = (isEnabled: isEnabled, intensity: intensity)
        
        // 保存到 UserDefaults
        defaults.set(isEnabled, forKey: UserSettingsKeys.flashEnabled)
        defaults.set(intensity.rawValue, forKey: UserSettingsKeys.flashIntensity)
        
        // 打印保存操作
        print("------------------------")
        print("[闪光灯] 保存设置")
        print("- 开启状态：\(isEnabled ? "开启" : "关闭")")
        print("- 闪光强度：\(intensity)")
        print("------------------------")
    }
    
    // 加载闪光灯设置
    func loadFlashSettings() -> (isEnabled: Bool, intensity: AppConfig.AnimationConfig.Flash.Intensity) {
        // 如果有缓存且未过期，直接返回缓存
        if let cached = cachedFlashSettings {
            return cached
        }
        
        let isEnabled = defaults.bool(forKey: UserSettingsKeys.flashEnabled)
        let intensityRawValue = defaults.double(forKey: UserSettingsKeys.flashIntensity)
        let intensity = AppConfig.AnimationConfig.Flash.Intensity.allCases.first { $0.rawValue == intensityRawValue } ?? .medium
        
        // 更新缓存
        let settings = (isEnabled: isEnabled, intensity: intensity)
        cachedFlashSettings = settings
        
        return settings
    }
    
    // 添加清除缓存的方法
    func clearFlashSettingsCache() {
        cachedFlashSettings = nil
    }
    
    // MARK: - 网格设置
    
    // 保存网格设置
    func saveGridSettings(spacing: CGFloat, color: Color, opacity: Double) {
        print("------------------------")
        print("[网格设置] 保存设置")
        defaults.set(spacing, forKey: UserSettingsKeys.gridSpacing)
        
        // 保存颜色
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        if uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            let colorString = "\(red),\(green),\(blue)"
            defaults.set(colorString, forKey: UserSettingsKeys.gridLineColor)
        }
        
        defaults.set(opacity, forKey: UserSettingsKeys.gridLineOpacity)
        defaults.synchronize()
        
        print("- 网格间距：\(spacing)")
        print("- 线条颜色：\(color)")
        print("- 线条透明度：\(opacity)")
        print("------------------------")
    }
    
    // 加载网格设置
    func loadGridSettings() -> (spacing: CGFloat, color: Color, opacity: Double) {
        print("------------------------")
        print("[网格设置] 加载设置")
        
        let spacing = CGFloat(defaults.double(forKey: UserSettingsKeys.gridSpacing))
        let opacity = defaults.double(forKey: UserSettingsKeys.gridLineOpacity)
        
        // 加载颜色
        var color: Color = .white
        if let colorString = defaults.string(forKey: UserSettingsKeys.gridLineColor) {
            let components = colorString.split(separator: ",").compactMap { Double($0) }
            if components.count == 3 {
                color = Color(red: components[0], green: components[1], blue: components[2])
            }
        }
        
        print("- 网格间距：\(spacing == 0 ? 50 : spacing)")
        print("- 线条颜色：\(color)")
        print("- 线条透明度：\(opacity == 0 ? 0.3 : opacity)")
        print("------------------------")
        
        return (
            spacing: spacing == 0 ? 50 : spacing,
            color: color,
            opacity: opacity == 0 ? 0.3 : opacity
        )
    }
    
    // MARK: - 加载设置
    
    // 加载边框灯颜色
    func loadBorderLightColor() -> Color {
        if let red = defaults.object(forKey: UserSettingsKeys.borderLightColorRed) as? CGFloat,
           let green = defaults.object(forKey: UserSettingsKeys.borderLightColorGreen) as? CGFloat,
           let blue = defaults.object(forKey: UserSettingsKeys.borderLightColorBlue) as? CGFloat,
           let alpha = defaults.object(forKey: UserSettingsKeys.borderLightColorAlpha) as? CGFloat {
            
            print("加载边框灯颜色设置 - R:\(red) G:\(green) B:\(blue) A:\(alpha)")
            return Color(UIColor(red: red, green: green, blue: blue, alpha: alpha))
        }
        
        print("使用边框灯默认颜色")
        return DefaultColors.whiteLight  // 修改默认颜色为白光
    }
    
    // 加载边框灯宽度
    func loadBorderLightWidth() -> CGFloat {
        // 检查是否存在保存的值
        if defaults.object(forKey: UserSettingsKeys.borderLightWidth) == nil {
            return BorderStyle.selectedWidth // 默认宽度
        }
        let width = defaults.double(forKey: UserSettingsKeys.borderLightWidth)
        print("加载边框灯宽度设置：\(width)")
        return CGFloat(width)
    }
    
    // 加载手势模式
    func loadGestureMode() -> Bool {
        let isDefault = defaults.bool(forKey: UserSettingsKeys.gestureMode)
        print("加载手势模式设置：\(isDefault ? "默认" : "交换")")
        return isDefault
    }
    
    // 加载图标颜色
    func loadIconColor() -> Color {
        if let red = defaults.object(forKey: UserSettingsKeys.iconColorRed) as? CGFloat,
           let green = defaults.object(forKey: UserSettingsKeys.iconColorGreen) as? CGFloat,
           let blue = defaults.object(forKey: UserSettingsKeys.iconColorBlue) as? CGFloat,
           let alpha = defaults.object(forKey: UserSettingsKeys.iconColorAlpha) as? CGFloat {
            
            print("加载图标颜色设置 - R:\(red) G:\(green) B:\(blue) A:\(alpha)")
            return Color(UIColor(red: red, green: green, blue: blue, alpha: alpha))
        }
        
        print("使用图标默认颜色")
        return .white
    }
    
    // 加载分屏蝴蝶颜色
    func loadSplitScreenIconColor() -> Color {
        if let red = defaults.object(forKey: UserSettingsKeys.splitScreenIconColorRed) as? CGFloat,
           let green = defaults.object(forKey: UserSettingsKeys.splitScreenIconColorGreen) as? CGFloat,
           let blue = defaults.object(forKey: UserSettingsKeys.splitScreenIconColorBlue) as? CGFloat,
           let alpha = defaults.object(forKey: UserSettingsKeys.splitScreenIconColorAlpha) as? CGFloat {
            
            print("加载分屏蝴蝶颜色设置 - R:\(red) G:\(green) B:\(blue) A:\(alpha)")
            
            // 检查是否使用原始颜色
            let useOriginal = defaults.bool(forKey: UserSettingsKeys.splitScreenIconUseOriginal)
            if useOriginal,
               let firstSplitScreenColor = splitScreenColors.first,
               firstSplitScreenColor.useOriginalColor {
                print("使用原始颜色图标")
                return firstSplitScreenColor.color
            }
            
            return Color(UIColor(red: red, green: green, blue: blue, alpha: alpha))
        }
        
        print("使用分屏蝴蝶默认颜色")
        return .purple
    }
    
    // 加载分屏蝴蝶设置
    func loadSplitScreenIconSettings() -> (image: String, color: Color) {
        let image = defaults.string(forKey: UserSettingsKeys.splitScreenIconImage) ?? "icon-bf-color-1"
        
        if image.hasPrefix("color") {
            return (image, .clear)
        }
        
        // 加载颜色
        if let red = defaults.object(forKey: UserSettingsKeys.splitScreenIconColorRed) as? CGFloat,
           let green = defaults.object(forKey: UserSettingsKeys.splitScreenIconColorGreen) as? CGFloat,
           let blue = defaults.object(forKey: UserSettingsKeys.splitScreenIconColorBlue) as? CGFloat,
           let alpha = defaults.object(forKey: UserSettingsKeys.splitScreenIconColorAlpha) as? CGFloat {
            return (image, Color(UIColor(red: red, green: green, blue: blue, alpha: alpha)))
        }
        
        return (image, .purple)
    }
    
    // 加载分屏蝴蝶图片
    func loadSplitScreenIconImage() -> String {
        let image = defaults.string(forKey: UserSettingsKeys.splitScreenIconImage) ?? "icon-bf-color-1"
        print("加载分屏蝴蝶图片：\(image)")
        return image
    }
    
    // MARK: - 应用设置
    
    // 应用所有保存的设置
    func applySettings() {
        print("开始应用所有用户设置...")
        
        DispatchQueue.main.async {
            let styleManager = BorderLightStyleManager.shared
            
            // 应用边框灯颜色
            styleManager.selectedColor = self.loadBorderLightColor()
            
            // 应用边框灯宽度
            styleManager.selectedWidth = self.loadBorderLightWidth()
            
            // 应用手势模式
            styleManager.isDefaultGesture = self.loadGestureMode()
            
            // 应用图标颜色
            styleManager.iconColor = self.loadIconColor()
            
            // 应用分屏蝴蝶颜色
            styleManager.splitScreenIconColor = self.loadSplitScreenIconColor()
            
            // 应用分屏蝴蝶图片
            styleManager.splitScreenIconImage = self.loadSplitScreenIconImage()
            
            // 应用闪光灯设置
            let flashSettings = self.loadFlashSettings()
            AppConfig.AnimationConfig.Flash.isEnabled = flashSettings.isEnabled
            AppConfig.AnimationConfig.Flash.intensity = flashSettings.intensity
            
            print("所有用户设置已应用")
        }
    }
    
    // MARK: - TwoOfMe 配置管理
    
    // 重置 TwoOfMe 所有参数
    func resetTwoOfMeSettings() {
        print("------------------------")
        print("[TwoOfMe] 重置所有参数")
        
        // 重置屏幕交换状态
        defaults.set(false, forKey: UserSettingsKeys.isScreensSwapped)
        
        // 重置缩放比例
        defaults.set(1.0, forKey: UserSettingsKeys.originalCameraScale)
        defaults.set(1.0, forKey: UserSettingsKeys.mirroredCameraScale)
        defaults.set(1.0, forKey: UserSettingsKeys.originalImageScale)
        defaults.set(1.0, forKey: UserSettingsKeys.mirroredImageScale)
        
        defaults.synchronize()
        print("- 屏幕交换状态：重置为默认")
        print("- 所有缩放比例：重置为100%")
        print("------------------------")
    }
    
    // 保存 TwoOfMe 当前配置
    func saveTwoOfMeSettings(
        isScreensSwapped: Bool,
        originalCameraScale: CGFloat,
        mirroredCameraScale: CGFloat,
        originalImageScale: CGFloat,
        mirroredImageScale: CGFloat
    ) {
        print("------------------------")
        print("[TwoOfMe] 保存当前配置")
        
        // 保存屏幕交换状态
        defaults.set(isScreensSwapped, forKey: UserSettingsKeys.isScreensSwapped)
        
        // 保存缩放比例
        defaults.set(originalCameraScale, forKey: UserSettingsKeys.originalCameraScale)
        defaults.set(mirroredCameraScale, forKey: UserSettingsKeys.mirroredCameraScale)
        defaults.set(originalImageScale, forKey: UserSettingsKeys.originalImageScale)
        defaults.set(mirroredImageScale, forKey: UserSettingsKeys.mirroredImageScale)
        
        defaults.synchronize()
        print("- 屏幕交换状态：\(isScreensSwapped ? "已交换" : "默认")")
        print("- Original摄像头缩放：\(Int(originalCameraScale * 100))%")
        print("- Mirrored摄像头缩放：\(Int(mirroredCameraScale * 100))%")
        print("- Original定格缩放：\(Int(originalImageScale * 100))%")
        print("- Mirrored定格缩放：\(Int(mirroredImageScale * 100))%")
        print("------------------------")
    }
    
    // 加载 TwoOfMe 配置
    func loadTwoOfMeSettings() -> (
        isScreensSwapped: Bool,
        originalCameraScale: CGFloat,
        mirroredCameraScale: CGFloat,
        originalImageScale: CGFloat,
        mirroredImageScale: CGFloat
    ) {
        print("------------------------")
        print("[TwoOfMe] 加载配置")
        
        let isScreensSwapped = false
        let originalCameraScale = CGFloat(defaults.float(forKey: UserSettingsKeys.originalCameraScale))
        let mirroredCameraScale = CGFloat(defaults.float(forKey: UserSettingsKeys.mirroredCameraScale))
        let originalImageScale = CGFloat(defaults.float(forKey: UserSettingsKeys.originalImageScale))
        let mirroredImageScale = CGFloat(defaults.float(forKey: UserSettingsKeys.mirroredImageScale))
        
        print("- 屏幕交换状态：\(isScreensSwapped ? "已交换" : "默认")")
        print("- Original摄像头缩放：\(Int(originalCameraScale * 100))%")
        print("- Mirrored摄像头缩放：\(Int(mirroredCameraScale * 100))%")
        print("- Original定格缩放：\(Int(originalImageScale * 100))%")
        print("- Mirrored定格缩放：\(Int(mirroredImageScale * 100))%")
        print("------------------------")
        
        return (
            isScreensSwapped: isScreensSwapped,
            originalCameraScale: originalCameraScale == 0 ? 1.0 : originalCameraScale,
            mirroredCameraScale: mirroredCameraScale == 0 ? 1.0 : mirroredCameraScale,
            originalImageScale: originalImageScale == 0 ? 1.0 : originalImageScale,
            mirroredImageScale: mirroredImageScale == 0 ? 1.0 : mirroredImageScale
        )
    }
    
    // MARK: - 全局参数重置
    
    // 添加全局参数重置方法
    func resetToDefaultSettings() {
        print("------------------------")
        print("[全局参数] 开始重置")
        
        // 清除已有的用户配置标记
        defaults.set(false, forKey: UserSettingsKeys.hasUserConfig)
        
        // 重置边框灯颜色 (白色)
        let defaultColor = Color.white
        let uiColor = UIColor(defaultColor)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        if uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            defaults.set(red, forKey: UserSettingsKeys.borderLightColorRed)
            defaults.set(green, forKey: UserSettingsKeys.borderLightColorGreen)
            defaults.set(blue, forKey: UserSettingsKeys.borderLightColorBlue)
            defaults.set(alpha, forKey: UserSettingsKeys.borderLightColorAlpha)
            print("- 边框灯颜色已重置为白色")
        }
        
        // 重置边框灯宽度 (16)
        defaults.set(16.0, forKey: UserSettingsKeys.borderLightWidth)
        print("- 边框灯宽度已重置为16")
        
        // 重置手势模式 (默认模式：双击拍照，单击灯光)
        defaults.set(true, forKey: UserSettingsKeys.gestureMode)
        print("- 手势模式已重置为默认")
        
        // 重置主屏图标颜色 (白色)
        defaults.set(1.0, forKey: UserSettingsKeys.iconColorRed)
        defaults.set(1.0, forKey: UserSettingsKeys.iconColorGreen)
        defaults.set(1.0, forKey: UserSettingsKeys.iconColorBlue)
        defaults.set(1.0, forKey: UserSettingsKeys.iconColorAlpha)
        print("- 主屏图标颜色已重置为白色")
        
        // 重置分屏图标颜色 (紫色)
        let defaultSplitColor = Color.purple
        let uiSplitColor = UIColor(defaultSplitColor)
        var splitRed: CGFloat = 0
        var splitGreen: CGFloat = 0
        var splitBlue: CGFloat = 0
        var splitAlpha: CGFloat = 0
        
        if uiSplitColor.getRed(&splitRed, green: &splitGreen, blue: &splitBlue, alpha: &splitAlpha) {
            defaults.set(splitRed, forKey: UserSettingsKeys.splitScreenIconColorRed)
            defaults.set(splitGreen, forKey: UserSettingsKeys.splitScreenIconColorGreen)
            defaults.set(splitBlue, forKey: UserSettingsKeys.splitScreenIconColorBlue)
            defaults.set(splitAlpha, forKey: UserSettingsKeys.splitScreenIconColorAlpha)
            defaults.set(false, forKey: UserSettingsKeys.splitScreenIconUseOriginal)
            print("- 分屏图标颜色已重置为紫色")
        }
        
        // 重置闪光灯设置
        defaults.set(false, forKey: UserSettingsKeys.flashEnabled)
        defaults.set(AppConfig.AnimationConfig.Flash.Intensity.medium.rawValue, forKey: UserSettingsKeys.flashIntensity)
        print("- 闪光灯设置已重置（关闭状态，中等强度）")
        
        // 重置分屏图片
        defaults.set("icon-bf-color-1", forKey: UserSettingsKeys.splitScreenIconImage)
        
        // 重置水印设置（默认开启）
        defaults.set(true, forKey: UserSettingsKeys.watermarkEnabled)
        print("- 水印设置已重置为开启状态")
        
        // 同步到内存
        defaults.synchronize()
        
        // 更新 BorderLightStyleManager
        DispatchQueue.main.async {
            let styleManager = BorderLightStyleManager.shared
            styleManager.selectedColor = defaultColor
            styleManager.selectedWidth = 16.0
            styleManager.isDefaultGesture = true
            styleManager.iconColor = .white
            styleManager.splitScreenIconColor = .purple
            styleManager.splitScreenIconImage = "icon-bf-color-1"
            
            // 发送通知更新UI
            NotificationCenter.default.post(name: NSNotification.Name("UpdateButtonColors"), object: nil)
        }
        
        print("[全局参数] 重置完成")
        print("------------------------")
    }
    
    // MARK: - 自动进入双屏设置
    
    func saveAutoEnterTwoOfMe(_ enabled: Bool) {
        defaults.set(enabled, forKey: UserSettingsKeys.autoEnterTwoOfMe)
        defaults.synchronize()
        print("------------------------")
        print("[系统设置] 自动进入双屏")
        print("状态：\(enabled ? "开启" : "关闭")")
        print("------------------------")
    }
    
    func loadAutoEnterTwoOfMe() -> Bool {
        let enabled = defaults.bool(forKey: UserSettingsKeys.autoEnterTwoOfMe)
        print("------------------------")
        print("[系统设置] 加载自动进入双屏设置")
        print("状态：\(enabled ? "开启" : "关闭")")
        print("------------------------")
        return enabled
    }

    // MARK: - 水印设置
    
    // 保存水印开关状态
    func saveWatermarkEnabled(_ enabled: Bool) {
        print("------------------------")
        print("[水印设置] 保存设置")
        defaults.set(enabled, forKey: UserSettingsKeys.watermarkEnabled)
        defaults.synchronize()
        print("- 水印状态：\(enabled ? "开启" : "关闭")")
        print("------------------------")
    }
    
    // 加载水印开关状态
    func loadWatermarkEnabled() -> Bool {
        // 默认为开启状态
        let enabled = defaults.object(forKey: UserSettingsKeys.watermarkEnabled) == nil ? true : defaults.bool(forKey: UserSettingsKeys.watermarkEnabled)
        print("------------------------")
        print("[水印设置] 加载设置")
        print("- 水印状态：\(enabled ? "开启" : "关闭")")
        print("------------------------")
        return enabled
    }
    
    // 获取下一个灯光颜色
    func getNextLightColor(_ currentColor: Color) -> Color {
        let uiCurrentColor = UIColor(currentColor)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        uiCurrentColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // 将当前颜色与预设颜色进行比较
        let tolerance: CGFloat = 0.01
        
        // 检查是否为白光
        if abs(red - 241/255) < tolerance && abs(green - 235/255) < tolerance && abs(blue - 223/255) < tolerance {
            return DefaultColors.warmLight  // 切换到暖光
        }
        // 检查是否为暖光
        else if abs(red - 245/255) < tolerance && abs(green - 217/255) < tolerance && abs(blue - 155/255) < tolerance {
            return DefaultColors.coolLight  // 切换到冷光
        }
        // 其他情况（包括冷光）
        else {
            return DefaultColors.whiteLight  // 切换回白光
        }
    }
}

// MARK: - Color 扩展
extension Color {
    init(_ uiColor: UIColor) {
        self.init(red: Double(uiColor.cgColor.components?[0] ?? 0),
                 green: Double(uiColor.cgColor.components?[1] ?? 0),
                 blue: Double(uiColor.cgColor.components?[2] ?? 0),
                 opacity: Double(uiColor.cgColor.components?[3] ?? 1))
    }
} 