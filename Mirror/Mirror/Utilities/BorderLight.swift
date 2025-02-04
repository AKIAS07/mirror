import SwiftUI
import UIKit

// 边框灯样式管理器
class BorderLightStyleManager: ObservableObject {
    static let shared = BorderLightStyleManager()
    
    // 当前显示的颜色和宽度（用于临时修改）
    @Published var selectedColor: Color = BorderStyle.selectedColor {
        didSet {
            // 当颜色改变时，立即更新 BorderStyle 的颜色，以便实时预览
            withAnimation(.easeInOut(duration: 0.3)) {
                BorderStyle.selectedColor = selectedColor
            }
        }
    }
    @Published var selectedWidth: CGFloat = BorderStyle.selectedWidth {
        didSet {
            // 当宽度改变时，立即更新 BorderStyle 的宽度，以便实时预览
            withAnimation(.easeInOut(duration: 0.3)) {
                BorderStyle.selectedWidth = selectedWidth
            }
        }
    }
    
    // 保存的颜色和宽度（用于恢复）
    private var savedColor: Color = BorderStyle.selectedColor
    private var savedWidth: CGFloat = BorderStyle.selectedWidth
    
    @Published var isDefaultGesture: Bool = true
    @Published var iconColor: Color = .white
    @Published var splitScreenIconColor: Color = .purple {
        didSet {
            print("分屏蝴蝶颜色已更新：\(splitScreenIconColor)")
            
            // 检查是否是第一个分屏颜色选项（原始颜色）
            if let firstSplitScreenColor = splitScreenColors.first,
               firstSplitScreenColor.useOriginalColor && compareColors(splitScreenIconColor, firstSplitScreenColor.color) {
                print("使用原始颜色图标")
            } else {
                print("使用白色图标并应用颜色")
            }
            
            // 当颜色改变时发送通知
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("UpdateButtonColors"), object: nil)
            }
        }
    }
    
    @Published var isPreviewMode: Bool = false  // 添加预览模式状态
    
    // 添加计算属性，根据手势模式返回对应的点击次数
    var captureGestureCount: Int {
        return isDefaultGesture ? 2 : 1  // 默认模式为双击，交换模式为单击
    }
    
    private init() {
        // 监听设置页面的显示状态
        NotificationCenter.default.addObserver(self, selector: #selector(handleSettingsPresented), name: NSNotification.Name("SettingsPresented"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleSettingsDismissed), name: NSNotification.Name("SettingsDismissed"), object: nil)
        
        // 检查是否有保存的用户配置
        let settings = UserSettingsManager.shared
        if settings.hasUserConfig() {
            print("BorderLightStyleManager - 检测到保存的用户配置，开始加载...")
            // 加载保存的设置
            self.savedColor = settings.loadBorderLightColor()
            self.savedWidth = settings.loadBorderLightWidth()
            self.selectedColor = self.savedColor
            self.selectedWidth = self.savedWidth
            self.isDefaultGesture = settings.loadGestureMode()
            self.iconColor = settings.loadIconColor()
            self.splitScreenIconColor = settings.loadSplitScreenIconColor()
            
            // 更新 BorderStyle
            BorderStyle.selectedColor = self.savedColor
            BorderStyle.selectedWidth = self.savedWidth
            
            print("BorderLightStyleManager - 配置加载完成")
        } else {
            print("BorderLightStyleManager - 使用默认配置")
            // 使用默认设置
            self.savedColor = BorderStyle.selectedColor
            self.savedWidth = BorderStyle.selectedWidth
            self.selectedColor = self.savedColor
            self.selectedWidth = self.savedWidth
            self.isDefaultGesture = true
            self.iconColor = .white
            self.splitScreenIconColor = .purple  // 使用.purple作为默认值
        }
    }
    
    // 处理设置页面显示
    @objc private func handleSettingsPresented() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isPreviewMode = true
        }
    }
    
    // 处理设置页面关闭
    @objc private func handleSettingsDismissed() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isPreviewMode = false
        }
    }
    
    // 临时更新样式（不保存）
    func updateStyle(color: Color? = nil, width: CGFloat? = nil) {
        if let color = color {
            withAnimation(.easeInOut(duration: 0.3)) {
                selectedColor = color
            }
        }
        if let width = width {
            withAnimation(.easeInOut(duration: 0.3)) {
                selectedWidth = width
            }
        }
    }
    
    // 保存当前设置
    func saveCurrentSettings() {
        savedColor = selectedColor
        savedWidth = selectedWidth
        
        BorderStyle.selectedColor = selectedColor
        BorderStyle.selectedWidth = selectedWidth
        
        UserSettingsManager.shared.saveBorderLightColor(selectedColor)
        UserSettingsManager.shared.saveBorderLightWidth(selectedWidth)
        UserSettingsManager.shared.saveGestureMode(isDefault: isDefaultGesture)
        UserSettingsManager.shared.saveIconColor(iconColor)
        UserSettingsManager.shared.saveSplitScreenIconColor(splitScreenIconColor)
    }
    
    // 恢复到上次保存的设置
    func restoreSettings() {
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedColor = savedColor
            selectedWidth = savedWidth
        }
    }
    
    // 添加颜色比较辅助方法
    private func compareColors(_ color1: Color, _ color2: Color) -> Bool {
        let uiColor1 = UIColor(color1)
        let uiColor2 = UIColor(color2)
        var red1: CGFloat = 0, green1: CGFloat = 0, blue1: CGFloat = 0, alpha1: CGFloat = 0
        var red2: CGFloat = 0, green2: CGFloat = 0, blue2: CGFloat = 0, alpha2: CGFloat = 0
        
        uiColor1.getRed(&red1, green: &green1, blue: &blue1, alpha: &alpha1)
        uiColor2.getRed(&red2, green: &green2, blue: &blue2, alpha: &alpha2)
        
        let tolerance: CGFloat = 0.01
        return abs(red1 - red2) < tolerance && 
               abs(green1 - green2) < tolerance && 
               abs(blue1 - blue2) < tolerance
    }
}

// 边框灯管理器
class BorderLightManager: ObservableObject {
    static let shared = BorderLightManager()
    
    @Published var showOriginalHighlight = false
    @Published var showMirroredHighlight = false
    @Published var isPreviewMode = false
    @ObservedObject private var styleManager = BorderLightStyleManager.shared
    
    // 添加亮度控制相关属性
    private var originalBrightness: CGFloat = UIScreen.main.brightness
    var isControllingBrightness = false
    @Published var isSettingsShowing = false
    
    init() {
        originalBrightness = UIScreen.main.brightness
        
        // 监听设置页面的显示状态
        NotificationCenter.default.addObserver(self, selector: #selector(handleSettingsPresented), name: NSNotification.Name("SettingsPresented"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleSettingsDismissed), name: NSNotification.Name("SettingsDismissed"), object: nil)
    }
    
    // 处理设置页面显示
    @objc private func handleSettingsPresented() {
        isPreviewMode = true
        isSettingsShowing = true
        showOriginalHighlight = true
        showMirroredHighlight = true
    }
    
    // 处理设置页面关闭
    @objc private func handleSettingsDismissed() {
        isPreviewMode = false
        isSettingsShowing = false
        if !isControllingBrightness {
            showOriginalHighlight = false
            showMirroredHighlight = false
        }
    }
    
    // 切换边框灯状态
    func toggleBorderLight(for screenID: ScreenID) {
        // 触发震动反馈
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        
        switch screenID {
        case .original:
            showOriginalHighlight.toggle()
            handleBrightnessChange(isOn: showOriginalHighlight)
            print("------------------------")
            print("Original屏幕被点击")
            print(showOriginalHighlight ? "边框灯已开启" : "边框灯已关闭")
            print("------------------------")
            
        case .mirrored:
            showMirroredHighlight.toggle()
            handleBrightnessChange(isOn: showMirroredHighlight)
            print("------------------------")
            print("Mirrored屏幕被点击")
            print(showMirroredHighlight ? "边框灯已开启" : "边框灯已关闭")
            print("------------------------")
        }
    }
    
    // 处理亮度变化
    private func handleBrightnessChange(isOn: Bool) {
        if isSettingsShowing { return }
        
        if isOn && !isControllingBrightness {
            isControllingBrightness = true
            originalBrightness = UIScreen.main.brightness
            UIScreen.main.brightness = 1.0
            print("设备亮度已调至最大")
        } else if !showOriginalHighlight && !showMirroredHighlight {
            if isControllingBrightness {
                UIScreen.main.brightness = originalBrightness
                isControllingBrightness = false
                print("设备亮度已恢复")
            }
        }
    }
    
    // 关闭所有边框灯
    func turnOffAllLights() {
        showOriginalHighlight = false
        showMirroredHighlight = false
        
        // 触发震动反馈
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        
        // 恢复原始亮度
        if isControllingBrightness {
            UIScreen.main.brightness = originalBrightness
            isControllingBrightness = false
            print("设备亮度已恢复")
        }
    }
    
    // 开启所有边框灯
    func turnOnAllLights() {
        showOriginalHighlight = true
        showMirroredHighlight = true
        
        // 触发震动反馈
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        
        // 设置最大亮度
        if !isControllingBrightness {
            originalBrightness = UIScreen.main.brightness
            UIScreen.main.brightness = 1.0
            isControllingBrightness = true
            print("设备亮度已调至最大")
        }
    }
}

// 边框灯视图
struct BorderLightView: View {
    let screenWidth: CGFloat
    let centerY: CGFloat
    let showOriginalHighlight: Bool
    let showMirroredHighlight: Bool
    @ObservedObject private var styleManager = BorderLightStyleManager.shared
    
    var body: some View {
        let isHighlighted = showOriginalHighlight || showMirroredHighlight || styleManager.isPreviewMode
        
        GeometryReader { geometry in
            // 计算实际的边框尺寸
            let frameWidth = screenWidth
            let frameHeight = centerY
            
            ZStack {
                // 发光边框
                RoundedRectangle(cornerRadius: CameraLayoutConfig.borderCornerRadius)
                    .stroke(
                        isHighlighted ? styleManager.selectedColor : Color.gray.opacity(0.3),
                        lineWidth: isHighlighted ? styleManager.selectedWidth : 1
                    )
                    .frame(width: frameWidth, height: frameHeight)
                    .position(
                        x: frameWidth/2,
                        y: frameHeight/2
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: CameraLayoutConfig.borderCornerRadius)
                            .stroke(Color.gray.opacity(isHighlighted ? 0.3 : 1), lineWidth: 1)
                            .frame(width: frameWidth, height: frameHeight)
                            .position(
                                x: frameWidth/2,
                                y: frameHeight/2
                            )
                    )
                    .animation(.easeInOut(duration: 0.3), value: isHighlighted)
                    .animation(.easeInOut(duration: 0.3), value: styleManager.selectedColor)
                    .animation(.easeInOut(duration: 0.3), value: styleManager.selectedWidth)
            }
            .mask(
                // 遮罩，只显示边框线内的部分
                RoundedRectangle(cornerRadius: CameraLayoutConfig.borderCornerRadius)
                    .frame(width: frameWidth - 1, height: frameHeight - 1)
                    .position(
                        x: frameWidth/2,
                        y: frameHeight/2
                    )
            )
            .clipped()
        }
    }
} 
