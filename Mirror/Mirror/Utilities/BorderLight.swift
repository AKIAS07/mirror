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
    @Published public private(set) var isControllingBrightness = false
    @Published var isSettingsShowing = false
    
    init() {
        originalBrightness = UIScreen.main.brightness
        
        // 监听设置页面的显示状态
        NotificationCenter.default.addObserver(self, selector: #selector(handleSettingsPresented), name: NSNotification.Name("SettingsPresented"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleSettingsDismissed), name: NSNotification.Name("SettingsDismissed"), object: nil)
        
        // 添加手电筒状态变化监听
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFlashlightStateChange),
            name: NSNotification.Name("FlashlightStateDidChange"),
            object: nil
        )
    }
    
    // 修改亮度控制方法
    private func handleBrightnessChange(isOn: Bool) {
        if isSettingsShowing { return }
        
        // 发送通知获取手电筒状态
        var isAnyFlashlightActive = false
        NotificationCenter.default.post(
            name: NSNotification.Name("CheckFlashlightState"),
            object: nil,
            userInfo: ["completion": { (active: Bool) in
                isAnyFlashlightActive = active
            }]
        )
        
        if isOn && !isControllingBrightness && !isAnyFlashlightActive {
            isControllingBrightness = true
            originalBrightness = UIScreen.main.brightness
            UIScreen.main.brightness = 1.0
            print("------------------------")
            print("[边框灯] 亮度控制已激活")
            print("原始亮度：\(originalBrightness)")
            print("当前亮度：1.0")
            print("------------------------")
        } else if !showOriginalHighlight && !showMirroredHighlight {
            if isControllingBrightness && !isAnyFlashlightActive {  // 只有在没有手电筒开启时才恢复亮度
                UIScreen.main.brightness = originalBrightness
                isControllingBrightness = false
                print("------------------------")
                print("[边框灯] 亮度控制已解除")
                print("亮度已恢复：\(originalBrightness)")
                print("------------------------")
            }
        }
    }
    
    // 修改手电筒状态变化处理方法
    @objc private func handleFlashlightStateChange(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let originalActive = userInfo["originalActive"] as? Bool,
           let mirroredActive = userInfo["mirroredActive"] as? Bool {
            
            let isAnyFlashlightActive = originalActive || mirroredActive
            
            if isAnyFlashlightActive {
                // 如果有手电筒开启，保存当前亮度并设置为最大
                if !isControllingBrightness {
                    originalBrightness = UIScreen.main.brightness
                    UIScreen.main.brightness = 1.0
                    isControllingBrightness = true
                    print("------------------------")
                    print("[手电筒] 亮度控制已激活")
                    print("原始亮度：\(originalBrightness)")
                    print("当前亮度：1.0")
                    print("------------------------")
                }
            } else {
                // 如果所有手电筒都关闭了，检查是否需要恢复边框灯的亮度控制
                if isControllingBrightness && !showOriginalHighlight && !showMirroredHighlight {
                    UIScreen.main.brightness = originalBrightness
                    isControllingBrightness = false
                    print("------------------------")
                    print("[手电筒] 亮度控制已解除")
                    print("亮度已恢复：\(originalBrightness)")
                    print("------------------------")
                }
            }
        }
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
    
    // 更新亮度控制逻辑
    private func updateBrightnessControl() {
        // 发送通知获取手电筒状态
        var isAnyFlashlightActive = false
        NotificationCenter.default.post(
            name: NSNotification.Name("CheckFlashlightState"),
            object: nil,
            userInfo: ["completion": { (active: Bool) in
                isAnyFlashlightActive = active
            }]
        )
        
        // 如果有手电筒开启，保持最大亮度
        if isAnyFlashlightActive {
            if !isControllingBrightness {
                originalBrightness = UIScreen.main.brightness
                UIScreen.main.brightness = 1.0
                isControllingBrightness = true
            }
        } else if showOriginalHighlight || showMirroredHighlight {
            // 如果有边框灯开启，保持最大亮度
            if !isControllingBrightness {
                originalBrightness = UIScreen.main.brightness
                UIScreen.main.brightness = 1.0
                isControllingBrightness = true
            }
        } else {
            // 如果既没有手电筒也没有边框灯开启，恢复原始亮度
            if isControllingBrightness {
                UIScreen.main.brightness = originalBrightness
                isControllingBrightness = false
            }
        }
    }
}

// 边框灯视图
struct BorderLightView: View {
    let screenWidth: CGFloat
    let centerY: CGFloat
    let showOriginalHighlight: Bool
    let showMirroredHighlight: Bool
    let screenPosition: ScreenPosition?
    let isScreensSwapped: Bool
    
    @ObservedObject private var styleManager = BorderLightStyleManager.shared
    @ObservedObject private var borderLightManager = BorderLightManager.shared
    
    // 添加圆角控制方法
    private func getCornerRadii() -> (topLeading: CGFloat, topTrailing: CGFloat, bottomLeading: CGFloat, bottomTrailing: CGFloat) {
        let radius = CameraLayoutConfig.borderCornerRadius
        
        // 如果没有指定屏幕位置，说明是主页面，所有圆角都使用相同的值
        guard let position = screenPosition else {
            return (radius, radius, radius, radius)
        }
        
        // 在分屏页面，根据屏幕位置和交换状态设置圆角
        switch position {
        case .original:
            // Original 屏幕在上方时
            if !isScreensSwapped {
                return (radius, radius, 0, 0) // 上圆下直
            } else {
                return (0, 0, radius, radius) // 上直下圆
            }
        case .mirrored:
            // Mirrored 屏幕在上方时
            if isScreensSwapped {
                return (radius, radius, 0, 0) // 上圆下直
            } else {
                return (0, 0, radius, radius) // 上直下圆
            }
        }
    }
    
    // 修改获取线宽的方法
    private func getLineWidth(isHighlighted: Bool, cornerRadii: (topLeading: CGFloat, topTrailing: CGFloat, bottomLeading: CGFloat, bottomTrailing: CGFloat)) -> CGFloat {
        // 未高亮时使用默认宽度
        if !isHighlighted {
            return 0
        }
        
        // 如果是主页面，直接返回完整宽度
        guard let position = screenPosition else {
            return styleManager.selectedWidth
        }
        
        // 检查是否两个分屏都开启了边框灯
        let bothScreensHighlighted = showOriginalHighlight && showMirroredHighlight
        
        // 判断是否是需要减半宽度的边（直角边）
        let isReducedWidthEdge: Bool
        switch position {
        case .original:
            if !isScreensSwapped {
                // Original在上方时，检查下边
                isReducedWidthEdge = cornerRadii.bottomLeading == 0 && cornerRadii.bottomTrailing == 0
            } else {
                // Original在下方时，检查上边
                isReducedWidthEdge = cornerRadii.topLeading == 0 && cornerRadii.topTrailing == 0
            }
        case .mirrored:
            if isScreensSwapped {
                // Mirrored在上方时，检查下边
                isReducedWidthEdge = cornerRadii.bottomLeading == 0 && cornerRadii.bottomTrailing == 0
            } else {
                // Mirrored在下方时，检查上边
                isReducedWidthEdge = cornerRadii.topLeading == 0 && cornerRadii.topTrailing == 0
            }
        }
        
        // 如果两个屏幕都高亮且是直角边，返回一半宽度
        if bothScreensHighlighted && isReducedWidthEdge {
            print("边框宽度减半：\(styleManager.selectedWidth / 2)")
            return styleManager.selectedWidth / 2
        }
        
        return styleManager.selectedWidth
    }
    
    var body: some View {
        let isHighlighted = showOriginalHighlight || showMirroredHighlight || styleManager.isPreviewMode
        let cornerRadii = getCornerRadii()
        let lineWidth = getLineWidth(isHighlighted: isHighlighted, cornerRadii: cornerRadii)
        
        GeometryReader { geometry in
            // 计算实际的边框尺寸
            let frameWidth = screenWidth
            let frameHeight = centerY
            
            ZStack {
                // 发光边框
                CustomRoundedRectangle(
                    topLeadingRadius: cornerRadii.topLeading,
                    topTrailingRadius: cornerRadii.topTrailing,
                    bottomLeadingRadius: cornerRadii.bottomLeading,
                    bottomTrailingRadius: cornerRadii.bottomTrailing
                )
                .stroke(
                    isHighlighted ? styleManager.selectedColor : Color.gray.opacity(0.3),
                    lineWidth: lineWidth
                )
                .frame(width: frameWidth, height: frameHeight)
                .position(
                    x: frameWidth/2,
                    y: frameHeight/2
                )
                .overlay(
                    CustomRoundedRectangle(
                        topLeadingRadius: cornerRadii.topLeading,
                        topTrailingRadius: cornerRadii.topTrailing,
                        bottomLeadingRadius: cornerRadii.bottomLeading,
                        bottomTrailingRadius: cornerRadii.bottomTrailing
                    )
                    .stroke(Color.black.opacity(isHighlighted ? 0.3 : 1), lineWidth: 0)
                    .frame(width: frameWidth, height: frameHeight)
                    .position(
                        x: frameWidth/2,
                        y: frameHeight/2
                    )
                )
                .animation(.easeInOut(duration: 0.3), value: isHighlighted)
                .animation(.easeInOut(duration: 0.3), value: styleManager.selectedColor)
                .animation(.easeInOut(duration: 0.3), value: lineWidth)
            }
            .mask(
                CustomRoundedRectangle(
                    topLeadingRadius: cornerRadii.topLeading,
                    topTrailingRadius: cornerRadii.topTrailing,
                    bottomLeadingRadius: cornerRadii.bottomLeading,
                    bottomTrailingRadius: cornerRadii.bottomTrailing
                )
                .frame(width: frameWidth, height: frameHeight)
                .position(
                    x: frameWidth/2,
                    y: frameHeight/2
                )
            )
            .clipped()
            .scaleEffect(1.0, anchor: .center)
            .rotation3DEffect(.degrees(0), axis: (x: 0, y: 0, z: 1))
        }
    }
}

// 自定义不同圆角的矩形形状
struct CustomRoundedRectangle: Shape {
    let topLeadingRadius: CGFloat
    let topTrailingRadius: CGFloat
    let bottomLeadingRadius: CGFloat
    let bottomTrailingRadius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // 从左上角开始，顺时针绘制
        path.move(to: CGPoint(x: rect.minX + topLeadingRadius, y: rect.minY))
        
        // 上边
        path.addLine(to: CGPoint(x: rect.maxX - topTrailingRadius, y: rect.minY))
        // 右上角
        path.addArc(
            center: CGPoint(x: rect.maxX - topTrailingRadius, y: rect.minY + topTrailingRadius),
            radius: topTrailingRadius,
            startAngle: Angle(degrees: -90),
            endAngle: Angle(degrees: 0),
            clockwise: false
        )
        
        // 右边
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomTrailingRadius))
        // 右下角
        if bottomTrailingRadius > 0 {
            path.addArc(
                center: CGPoint(x: rect.maxX - bottomTrailingRadius, y: rect.maxY - bottomTrailingRadius),
                radius: bottomTrailingRadius,
                startAngle: Angle(degrees: 0),
                endAngle: Angle(degrees: 90),
                clockwise: false
            )
        }
        
        // 下边
        path.addLine(to: CGPoint(x: rect.minX + bottomLeadingRadius, y: rect.maxY))
        // 左下角
        if bottomLeadingRadius > 0 {
            path.addArc(
                center: CGPoint(x: rect.minX + bottomLeadingRadius, y: rect.maxY - bottomLeadingRadius),
                radius: bottomLeadingRadius,
                startAngle: Angle(degrees: 90),
                endAngle: Angle(degrees: 180),
                clockwise: false
            )
        }
        
        // 左边
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeadingRadius))
        // 左上角
        path.addArc(
            center: CGPoint(x: rect.minX + topLeadingRadius, y: rect.minY + topLeadingRadius),
            radius: topLeadingRadius,
            startAngle: Angle(degrees: 180),
            endAngle: Angle(degrees: 270),
            clockwise: false
        )
        
        return path
    }
}

// 添加屏幕位置枚举
enum ScreenPosition {
    case original
    case mirrored
} 
