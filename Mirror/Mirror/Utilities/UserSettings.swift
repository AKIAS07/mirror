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
}

// 用户设置管理器
class UserSettingsManager {
    static let shared = UserSettingsManager()
    private let defaults = UserDefaults.standard
    
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
        }
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
        return BorderStyle.selectedColor
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
            return Color(UIColor(red: red, green: green, blue: blue, alpha: alpha))
        }
        
        print("使用分屏蝴蝶默认颜色")
        return Color(red: 0.8, green: 0.4, blue: 1.0)
    }
    
    // MARK: - 应用设置
    
    // 应用所有保存的设置
    func applySettings() {
        print("开始应用所有用户设置...")
        
        DispatchQueue.main.async {
            let styleManager = BorderLightStyleManager.shared
            
            // 应用边框灯颜色
            let color = self.loadBorderLightColor()
            styleManager.selectedColor = color
            BorderStyle.selectedColor = color
            print("应用边框灯颜色：\(color)")
            
            // 应用边框灯宽度
            let width = self.loadBorderLightWidth()
            styleManager.selectedWidth = width
            BorderStyle.selectedWidth = width
            print("应用边框灯宽度：\(width)")
            
            // 应用手势模式
            styleManager.isDefaultGesture = self.loadGestureMode()
            print("应用手势模式：\(styleManager.isDefaultGesture ? "默认" : "交换")")
            
            // 应用图标颜色
            styleManager.iconColor = self.loadIconColor()
            print("应用图标颜色")
            
            // 应用分屏蝴蝶颜色
            styleManager.splitScreenIconColor = self.loadSplitScreenIconColor()
            print("应用分屏蝴蝶颜色")
            
            print("完成应用所有用户设置")
        }
    }
}

// MARK: - BorderLightStyleManager 扩展
extension BorderLightStyleManager {
    // 保存当前设置
    func saveCurrentSettings() {
        let settings = UserSettingsManager.shared
        settings.saveBorderLightColor(selectedColor)
        settings.saveBorderLightWidth(selectedWidth)
        settings.saveGestureMode(isDefault: isDefaultGesture)
        settings.saveIconColor(iconColor)
        settings.saveSplitScreenIconColor(splitScreenIconColor)
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