import SwiftUI

// 用户设置的键名常量
private enum UserSettingsKeys {
    static let borderLightColorRed = "borderLightColorRed"
    static let borderLightColorGreen = "borderLightColorGreen"
    static let borderLightColorBlue = "borderLightColorBlue"
    static let borderLightColorAlpha = "borderLightColorAlpha"
    static let borderLightWidth = "borderLightWidth"
    static let gestureMode = "gestureMode"
}

// 用户设置管理器
class UserSettingsManager {
    static let shared = UserSettingsManager()
    private let defaults = UserDefaults.standard
    
    private init() {}
    
    // MARK: - 保存设置
    
    // 保存边框灯颜色
    func saveBorderLightColor(_ color: Color) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        defaults.set(red, forKey: UserSettingsKeys.borderLightColorRed)
        defaults.set(green, forKey: UserSettingsKeys.borderLightColorGreen)
        defaults.set(blue, forKey: UserSettingsKeys.borderLightColorBlue)
        defaults.set(alpha, forKey: UserSettingsKeys.borderLightColorAlpha)
        defaults.synchronize()
        print("保存边框灯颜色设置")
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
    
    // MARK: - 加载设置
    
    // 加载边框灯颜色
    func loadBorderLightColor() -> Color {
        let red = defaults.double(forKey: UserSettingsKeys.borderLightColorRed)
        let green = defaults.double(forKey: UserSettingsKeys.borderLightColorGreen)
        let blue = defaults.double(forKey: UserSettingsKeys.borderLightColorBlue)
        let alpha = defaults.double(forKey: UserSettingsKeys.borderLightColorAlpha)
        
        if red == 0 && green == 0 && blue == 0 && alpha == 0 {
            return BorderStyle.selectedColor // 默认颜色
        }
        
        let uiColor = UIColor(red: CGFloat(red), 
                            green: CGFloat(green), 
                            blue: CGFloat(blue), 
                            alpha: CGFloat(alpha))
        print("加载边框灯颜色设置")
        return Color(uiColor)
    }
    
    // 加载边框灯宽度
    func loadBorderLightWidth() -> CGFloat {
        let width = defaults.double(forKey: UserSettingsKeys.borderLightWidth)
        if width == 0 {
            return BorderStyle.selectedWidth // 默认宽度
        }
        print("加载边框灯宽度设置：\(width)")
        return CGFloat(width)
    }
    
    // 加载手势模式
    func loadGestureMode() -> Bool {
        let isDefault = defaults.bool(forKey: UserSettingsKeys.gestureMode)
        print("加载手势模式设置：\(isDefault ? "默认" : "交换")")
        return isDefault
    }
    
    // MARK: - 应用设置
    
    // 应用所有保存的设置
    func applySettings() {
        DispatchQueue.main.async {
            let styleManager = BorderLightStyleManager.shared
            
            // 应用边框灯颜色
            let color = self.loadBorderLightColor()
            styleManager.selectedColor = color
            BorderStyle.selectedColor = color
            
            // 应用边框灯宽度
            let width = self.loadBorderLightWidth()
            styleManager.selectedWidth = width
            BorderStyle.selectedWidth = width
            
            // 应用手势模式
            styleManager.isDefaultGesture = self.loadGestureMode()
            
            print("已应用所有用户设置")
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