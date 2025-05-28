import SwiftUI

// 设置面板布局常量
public struct SettingsLayoutConfig {
    public static let panelWidth: CGFloat = 300  // 250 + 50
    public static let panelHeight: CGFloat = 400 // 300 + 100
    public static let cornerRadius: CGFloat = 16
    public static let closeButtonSize: CGFloat = 24
    public static let closeButtonPadding: CGFloat = 12
    public static let titleBarHeight: CGFloat = 44  // 添加标题栏高度常量
}

// 设置面板主题
public struct SettingsTheme {
    // 颜色
    static let titleColor = Color(red: 0.3, green: 0.3, blue: 0.3)  // 深灰色替代 UIColor.darkGray
    static let subtitleColor = Color.gray
    static let backgroundColor = Color.white
    static let backgroundColor2 = Color.yellow.opacity(0.1)
    static let panelBackgroundColor = Color(red: 0.95, green: 0.95, blue: 0.97)  // 浅灰色替代 UIColor.systemGray6
    static let borderColor = Color.gray
    static let selectedBorderColor = Color.black
    
    // 边框
    static let normalBorderWidth: CGFloat = 1
    static let selectedBorderWidth: CGFloat = 4  // 增加选中边框的粗细
    static let buttonBorderColor = Color.gray.opacity(0.5)  // 统一按钮边框颜色
    static let selectedButtonBorderColor = Color.gray    // 选中按钮边框颜色
    
    // 间距
    static let itemSpacing: CGFloat = 24  // 设置项之间的间距
    static let contentSpacing: CGFloat = 16  // 设置项内容的间距
    static let buttonSpacing: CGFloat = 7  // 按钮之间的间距
    static let padding: CGFloat = 10  // 内边距
    
    // 阴影
    static let shadowColor = Color.black.opacity(0.05)
    static let shadowRadius: CGFloat = 5
    static let shadowX: CGFloat = 0
    static let shadowY: CGFloat = 2
}

// 边框灯设置的环境键
public struct BorderLightSettingsKey: EnvironmentKey {
    public static let defaultValue: (Color, CGFloat) = (BorderStyle.selectedColor, BorderStyle.selectedWidth)
}

extension EnvironmentValues {
    public var borderLightSettings: (Color, CGFloat) {
        get { self[BorderLightSettingsKey.self] }
        set { self[BorderLightSettingsKey.self] = newValue }
    }
}

// 添加自定义的 ColorPicker 包装视图
struct CustomColorPicker: View {
    @Binding var selection: Color
    let onChange: () -> Void
    
    var body: some View {
        ColorPicker("", selection: $selection)
            .labelsHidden()
            .onChange(of: selection) { _ in
                onChange()
            }
    }
}

// 颜色选择按钮视图
private struct ColorButton: View {
    let option: ColorOption
    let isSelected: Bool
    let action: () -> Void
    @ObservedObject private var styleManager = BorderLightStyleManager.shared
    
    // 添加颜色比较辅助方法
    private func compareColors(_ color1: Color, _ color2: Color) -> Bool {
        let uiColor1 = color1.toUIColor()
        let uiColor2 = color2.toUIColor()
        
        var red1: CGFloat = 0, green1: CGFloat = 0, blue1: CGFloat = 0, alpha1: CGFloat = 0
        var red2: CGFloat = 0, green2: CGFloat = 0, blue2: CGFloat = 0, alpha2: CGFloat = 0
        
        uiColor1.getRed(&red1, green: &green1, blue: &blue1, alpha: &alpha1)
        uiColor2.getRed(&red2, green: &green2, blue: &blue2, alpha: &alpha2)
        
        let tolerance: CGFloat = 0.01
        return abs(red1 - red2) < tolerance && 
               abs(green1 - green2) < tolerance && 
               abs(blue1 - blue2) < tolerance
    }
    
    private var isColorSelected: Bool {
        // 主屏小蝴蝶的选择逻辑
        if mainScreenColors.contains(where: { $0.image == option.image }) {
            return compareColors(option.color, styleManager.iconColor)
        }
        // 分屏蝴蝶的选择逻辑
        else if splitScreenColors.contains(where: { $0.image == option.image }) {
            return styleManager.splitScreenIconImage == option.image
        }
        return false
    }
    
    var body: some View {
        Button(action: action) {
            Image(option.image)
                .resizable()
                .frame(width: 24, height: 24)
                .if(!option.useOriginalColor) { view in
                    view.colorMultiply(option.color)
                }
                .background(option.background)
                .clipShape(Circle())
                .padding(isColorSelected ? 4 : 0)
                .overlay(Circle().stroke(SettingsTheme.buttonBorderColor, lineWidth: SettingsTheme.normalBorderWidth))
                .overlay(
                    Circle().stroke(
                        SettingsTheme.selectedButtonBorderColor,
                        lineWidth: isColorSelected ? SettingsTheme.selectedBorderWidth : 0
                    )
                )
        }
    }
}

// 添加 View 扩展来支持条件修饰符
extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// 设置面板视图
public struct SettingsPanel: View {
    @Binding var isPresented: Bool
    @ObservedObject private var styleManager = BorderLightStyleManager.shared
    @ObservedObject private var borderLightManager = BorderLightManager.shared
    @ObservedObject private var orientationManager = DeviceOrientationManager.shared
    @ObservedObject private var proManager = ProManager.shared
    @State private var showSaveSuccess = false
    @State private var showSaveAlert = false
    @State private var hasUnsavedChanges = false
    @State private var previousBrightness: CGFloat = UIScreen.main.brightness
    @State private var isFlashEnabled = AppConfig.AnimationConfig.Flash.isEnabled
    @State private var flashIntensity = AppConfig.AnimationConfig.Flash.intensity
    @State private var autoEnterTwoOfMe: Bool = UserSettingsManager.shared.loadAutoEnterTwoOfMe()
    @State private var isWatermarkEnabled: Bool = UserSettingsManager.shared.loadWatermarkEnabled()
    
    // 添加网格设置状态
    @State private var gridSpacing: CGFloat = UserSettingsManager.shared.loadGridSettings().spacing
    @State private var gridLineColor: Color = UserSettingsManager.shared.loadGridSettings().color
    @State private var gridLineOpacity: Double = UserSettingsManager.shared.loadGridSettings().opacity
    
    // 修改预设颜色数组，将黄色替换为指定的橙色
    private let gridColors: [Color] = [
        .white,
        .red,
        Color(red: 255/255, green: 185/255, blue: 42/255),  // 替换原来的 .yellow
        .green,
        .blue,
        .black
    ]
    
    private var isLandscape: Bool {
        orientationManager.currentOrientation == .landscapeLeft || orientationManager.currentOrientation == .landscapeRight
    }
    
    private var rotationAngle: Double {
        switch orientationManager.currentOrientation {
        case .landscapeLeft:
            return 90
        case .landscapeRight:
            return -90
        default:
            return 0
        }
    }
    
    private var offsetX: CGFloat {
        switch orientationManager.currentOrientation {
        case .landscapeLeft:
            return -80
        case .landscapeRight:
            return 80
        default:
            return 0
        }
    }
    
    private var offsetY: CGFloat {
        isLandscape ? 0 : -80
    }
    
    // 保存初始状态
    @State private var initialState: SettingsState = SettingsState()
    
    // 添加颜色比较函数
    private func compareColors(_ color1: Color, _ color2: Color) -> Bool {
        let uiColor1 = color1.toUIColor()
        let uiColor2 = color2.toUIColor()
        
        var red1: CGFloat = 0, green1: CGFloat = 0, blue1: CGFloat = 0, alpha1: CGFloat = 0
        var red2: CGFloat = 0, green2: CGFloat = 0, blue2: CGFloat = 0, alpha2: CGFloat = 0
        
        uiColor1.getRed(&red1, green: &green1, blue: &blue1, alpha: &alpha1)
        uiColor2.getRed(&red2, green: &green2, blue: &blue2, alpha: &alpha2)
        
        let tolerance: CGFloat = 0.01
        return abs(red1 - red2) < tolerance && 
               abs(green1 - green2) < tolerance && 
               abs(blue1 - blue2) < tolerance
    }
    
    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }
    
    // 保存当前设置状态的结构体
    private struct SettingsState: CustomStringConvertible {
        var borderLightColor: Color
        var borderLightWidth: CGFloat
        var isDefaultGesture: Bool
        var iconColor: Color
        var splitScreenIconColor: Color
        var splitScreenIconImage: String
        var isFlashEnabled: Bool
        var flashIntensity: AppConfig.AnimationConfig.Flash.Intensity
        var autoEnterTwoOfMe: Bool
        var gridSpacing: CGFloat
        var gridLineColor: Color
        var gridLineOpacity: Double
        var isWatermarkEnabled: Bool
        
        init() {
            self.borderLightColor = BorderLightStyleManager.shared.selectedColor
            self.borderLightWidth = BorderLightStyleManager.shared.selectedWidth
            self.isDefaultGesture = BorderLightStyleManager.shared.isDefaultGesture
            self.iconColor = BorderLightStyleManager.shared.iconColor
            self.splitScreenIconColor = BorderLightStyleManager.shared.splitScreenIconColor
            self.splitScreenIconImage = BorderLightStyleManager.shared.splitScreenIconImage
            self.isFlashEnabled = AppConfig.AnimationConfig.Flash.isEnabled
            self.flashIntensity = AppConfig.AnimationConfig.Flash.intensity
            self.autoEnterTwoOfMe = UserSettingsManager.shared.loadAutoEnterTwoOfMe()
            
            let gridSettings = UserSettingsManager.shared.loadGridSettings()
            self.gridSpacing = gridSettings.spacing
            self.gridLineColor = gridSettings.color
            self.gridLineOpacity = gridSettings.opacity
            
            self.isWatermarkEnabled = UserSettingsManager.shared.loadWatermarkEnabled()
            
            print("------------------------")
            print("[设置] 初始状态已保存")
            print("边框灯颜色：\(self.borderLightColor)")
            print("边框灯宽度：\(self.borderLightWidth)")
            print("手势模式：\(self.isDefaultGesture ? "默认" : "交换")")
            print("图标颜色：\(self.iconColor)")
            print("分屏图标颜色：\(self.splitScreenIconColor)")
            print("分屏图标：\(self.splitScreenIconImage)")
            print("闪光灯：\(self.isFlashEnabled ? "开启" : "关闭")")
            print("闪光强度：\(self.flashIntensity)")
            print("自动进入双屏：\(self.autoEnterTwoOfMe ? "是" : "否")")
            print("网格间距：\(self.gridSpacing)")
            print("网格颜色：\(self.gridLineColor)")
            print("网格透明度：\(self.gridLineOpacity)")
            print("水印：\(self.isWatermarkEnabled ? "开启" : "关闭")")
            print("------------------------")
        }
        
        // 添加描述方法，方便调试
        var description: String {
            return """
            边框灯颜色：\(borderLightColor)
            边框灯宽度：\(borderLightWidth)
            手势模式：\(isDefaultGesture ? "默认" : "交换")
            图标颜色：\(iconColor)
            分屏图标颜色：\(splitScreenIconColor)
            分屏图标：\(splitScreenIconImage)
            闪光灯：\(isFlashEnabled ? "开启" : "关闭")
            闪光强度：\(flashIntensity)
            自动进入双屏：\(autoEnterTwoOfMe ? "是" : "否")
            网格间距：\(gridSpacing)
            网格颜色：\(gridLineColor)
            网格透明度：\(gridLineOpacity)
            水印：\(isWatermarkEnabled ? "开启" : "关闭")
            """
        }
    }
    
    // 检查是否有未保存的更改
    private func checkForChanges() -> Bool {
        print("------------------------")
        print("[设置] 检查更改状态")
        print("初始状态：")
        print(initialState)
        print("\n当前状态：")
        print("""
            边框灯颜色：\(styleManager.selectedColor)
            边框灯宽度：\(styleManager.selectedWidth)
            手势模式：\(styleManager.isDefaultGesture ? "默认" : "交换")
            图标颜色：\(styleManager.iconColor)
            分屏图标颜色：\(styleManager.splitScreenIconColor)
            分屏图标：\(styleManager.splitScreenIconImage)
            闪光灯：\(isFlashEnabled ? "开启" : "关闭")
            闪光强度：\(flashIntensity)
            自动进入双屏：\(autoEnterTwoOfMe ? "是" : "否")
            网格间距：\(gridSpacing)
            网格颜色：\(gridLineColor)
            网格透明度：\(gridLineOpacity)
            水印：\(isWatermarkEnabled ? "开启" : "关闭")
            """)
        
        var changes: [String] = []
        
        if !compareColors(initialState.borderLightColor, styleManager.selectedColor) {
            changes.append("边框灯颜色")
        }
        if initialState.borderLightWidth != styleManager.selectedWidth {
            changes.append("边框灯宽度")
        }
        if initialState.isDefaultGesture != styleManager.isDefaultGesture {
            changes.append("手势模式")
        }
        if !compareColors(initialState.iconColor, styleManager.iconColor) {
            changes.append("图标颜色")
        }
        if !compareColors(initialState.splitScreenIconColor, styleManager.splitScreenIconColor) {
            changes.append("分屏图标颜色")
        }
        if initialState.splitScreenIconImage != styleManager.splitScreenIconImage {
            changes.append("分屏图标")
        }
        if initialState.isFlashEnabled != isFlashEnabled {
            changes.append("闪光灯状态")
        }
        if initialState.flashIntensity != flashIntensity {
            changes.append("闪光强度")
        }
        if initialState.autoEnterTwoOfMe != autoEnterTwoOfMe {
            changes.append("自动进入双屏")
        }
        if initialState.gridSpacing != gridSpacing {
            changes.append("网格间距")
        }
        if !compareColors(initialState.gridLineColor, gridLineColor) {
            changes.append("网格颜色")
        }
        if initialState.gridLineOpacity != gridLineOpacity {
            changes.append("网格透明度")
        }
        if initialState.isWatermarkEnabled != isWatermarkEnabled {
            changes.append("水印设置")
        }
        
        let hasChanges = !changes.isEmpty
        print("\n是否有未保存的更改：\(hasChanges)")
        if hasChanges {
            print("发现以下更改：")
            changes.forEach { print("- \($0)已更改") }
        }
        print("------------------------")
        
        return hasChanges
    }
    
    // 保存设置
    private func saveSettings() {
        UserSettingsManager.shared.saveCurrentConfig()
        styleManager.saveCurrentSettings()
        
        // 使用 UserSettingsManager 保存闪光灯设置
        UserSettingsManager.shared.saveFlashSettings(
            isEnabled: isFlashEnabled,
            intensity: flashIntensity
        )
        
        // 保存网格设置
        UserSettingsManager.shared.saveGridSettings(
            spacing: gridSpacing,
            color: gridLineColor,
            opacity: gridLineOpacity
        )
        
        // 保存水印设置
        UserSettingsManager.shared.saveWatermarkEnabled(isWatermarkEnabled)
        
        // 同步 TwoOfMe 相关设置
        NotificationCenter.default.post(
            name: NSNotification.Name("SyncTwoOfMeSettings"),
            object: nil
        )
        
        initialState = SettingsState()  // 更新初始状态
        hasUnsavedChanges = false
        
        // 显示保存成功提示
        withAnimation {
            showSaveSuccess = true
        }
        
        // 2秒后隐藏提示
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showSaveSuccess = false
            }
        }
    }
    
    // 修改恢复设置的逻辑
    private func restoreSettings() {
        // 恢复边框灯设置
        styleManager.selectedColor = initialState.borderLightColor
        styleManager.selectedWidth = initialState.borderLightWidth
        
        // 恢复手势设置
        styleManager.isDefaultGesture = initialState.isDefaultGesture
        
        // 恢复图标颜色设置
        styleManager.iconColor = initialState.iconColor
        styleManager.splitScreenIconColor = initialState.splitScreenIconColor
        styleManager.splitScreenIconImage = initialState.splitScreenIconImage
        
        // 恢复闪光灯设置
        isFlashEnabled = initialState.isFlashEnabled
        flashIntensity = initialState.flashIntensity
        AppConfig.AnimationConfig.Flash.isEnabled = initialState.isFlashEnabled
        AppConfig.AnimationConfig.Flash.intensity = initialState.flashIntensity
        
        // 恢复自动进入双屏设置
        autoEnterTwoOfMe = initialState.autoEnterTwoOfMe
        UserSettingsManager.shared.saveAutoEnterTwoOfMe(initialState.autoEnterTwoOfMe)
        
        // 恢复网格设置
        gridSpacing = initialState.gridSpacing
        gridLineColor = initialState.gridLineColor
        gridLineOpacity = initialState.gridLineOpacity
        
        // 恢复水印设置
        isWatermarkEnabled = initialState.isWatermarkEnabled
        
        // 发送通知更新预览
        NotificationCenter.default.post(
            name: NSNotification.Name("UpdateGridSettings"),
            object: nil,
            userInfo: [
                "spacing": initialState.gridSpacing,
                "color": initialState.gridLineColor,
                "opacity": initialState.gridLineOpacity
            ]
        )
        
        // 发送通知更新 UI
        NotificationCenter.default.post(name: NSNotification.Name("UpdateButtonColors"), object: nil)
    }
    
    // 添加背景色获取方法
    private func getSettingBackground(_ type: SettingType) -> Color {
        proManager.isFreeSetting(type) ? SettingsTheme.backgroundColor : Color(UIColor.systemGray5)
    }
    
    public var body: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
                .contentShape(Rectangle())
                .onTapGesture {
                    handleClose()
                }
            
            // 设置面板
            VStack(spacing: 0) {
                // 标题
                HStack {
                    Text("设置")
                        .font(.title2)
                        .foregroundColor(.black)
                    Spacer()
                    
                    // 保存配置按钮
                    Button(action: saveSettings) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 15))
                            Text("保存")
                                .font(.system(size: 15))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.blue)
                        .cornerRadius(4)
                    }
                    .scaleEffect(0.9)
                    
                    Button(action: handleClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                    }
                    .padding(.leading, 4)
                }
                .padding(.horizontal, 12)
                .frame(width: isLandscape ? SettingsLayoutConfig.panelHeight : SettingsLayoutConfig.panelWidth, 
                       height: SettingsLayoutConfig.titleBarHeight)
                
                ScrollView(showsIndicators: true) {
                    VStack(spacing: SettingsTheme.itemSpacing) {
                        // 边框灯设置
                        VStack(alignment: .leading, spacing: SettingsTheme.contentSpacing) {
                            HStack(spacing: 4) {
                                Spacer()
                                Text("灯光设置")
                                    .font(.headline)
                                    .foregroundColor(SettingsTheme.titleColor)
                                Spacer()
                            }
                            
                            // 颜色选择器
                            VStack(spacing: SettingsTheme.buttonSpacing) {
                                HStack {
                                    Text("颜色")
                                        .foregroundColor(SettingsTheme.subtitleColor)
                                    Spacer()
                                    CustomColorPicker(selection: $styleManager.selectedColor) {
                                        // 确保边框灯在预览模式下显示
                                        borderLightManager.showOriginalHighlight = true
                                        borderLightManager.showMirroredHighlight = true
                                    }
                                }
                                
                                // 常用颜色快捷选择
                                VStack(spacing: SettingsTheme.buttonSpacing) {
                                    // 第一排颜色
                                    HStack(spacing: SettingsTheme.buttonSpacing) {
                                        ForEach([
                                            Color(red: 234/255, green: 189/255, blue: 124/255),  //暖光1
                                            Color(red: 245/255, green: 217/255, blue: 155/255),  // 暖光2
                                            Color(red: 248/255, green: 237/255, blue: 206/255),   // 暖光3
                                            Color(red: 241/255, green: 235/255, blue: 223/255),    // 白光
                                            Color(red: 200/255, green: 210/255, blue: 213/255),    // 冷光1
                                            Color(red: 198/255, green: 223/255, blue: 239/255),   // 冷光2
                                            Color(red: 190/255, green: 229/255, blue: 246/255)     // 冷光3
                                        ], id: \.self) { color in
                                            Button(action: {
                                                styleManager.updateStyle(color: color)
                                            }) {
                                                Circle()
                                                    .fill(color)
                                                    .frame(width: 24, height: 24)
                                                    .padding(styleManager.selectedColor == color ? 4 : 0)
                                                    .overlay(Circle().stroke(SettingsTheme.buttonBorderColor, lineWidth: SettingsTheme.normalBorderWidth))
                                                    .overlay(
                                                        Circle().stroke(
                                                            SettingsTheme.selectedButtonBorderColor,
                                                            lineWidth: styleManager.selectedColor == color ? SettingsTheme.selectedBorderWidth : 0
                                                        )
                                                    )
                                            }
                                        }
                                    }
                                    
                                    // 第二排颜色
                                    HStack(spacing: SettingsTheme.buttonSpacing) {
                                        ForEach([
                                            Color(red: 255/255, green: 255/255, blue: 255/255),  // 颜色1
                                            Color(red: 104/255, green: 109/255, blue: 203/255),  //颜色2
                                            Color(red: 58/255, green: 187/255, blue: 201/255),   //颜色3
                                            Color(red: 155/255, green: 202/255, blue: 62/255),   //颜色4
                                            Color(red: 254/255, green: 235/255, blue: 81/255),   //颜色5
                                            Color(red: 255/255, green: 185/255, blue: 42/255),   //颜色6
                                            Color(red: 237/255, green: 83/255, blue: 20/255)     //颜色7 
                                        ], id: \.self) { color in
                                            Button(action: {
                                                styleManager.updateStyle(color: color)
                                            }) {
                                                Circle()
                                                    .fill(color)
                                                    .frame(width: 24, height: 24)
                                                    .padding(styleManager.selectedColor == color ? 4 : 0)
                                                    .overlay(Circle().stroke(SettingsTheme.buttonBorderColor, lineWidth: SettingsTheme.normalBorderWidth))
                                                    .overlay(
                                                        Circle().stroke(
                                                            SettingsTheme.selectedButtonBorderColor,
                                                            lineWidth: styleManager.selectedColor == color ? SettingsTheme.selectedBorderWidth : 0
                                                        )
                                                    )
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // 宽度选择
                            HStack {
                                Text("边灯宽度")
                                    .foregroundColor(SettingsTheme.subtitleColor)
                                Picker("", selection: $styleManager.selectedWidth) {
                                    Text("1").tag(CGFloat(8))
                                    Text("2").tag(CGFloat(16))
                                    Text("3").tag(CGFloat(24))
                                    Text("4").tag(CGFloat(32))
                                    Text("5").tag(CGFloat(40))
                                }
                                .pickerStyle(.segmented)
                                .frame(maxWidth: .infinity)
                                .onChange(of: styleManager.selectedWidth) { _ in
                                    // 不再立即保存，只更新显示
                                    styleManager.updateStyle(width: styleManager.selectedWidth)
                                }
                            }
                        }
                        .padding(SettingsTheme.padding)
                        .background(getSettingBackground(.light))
                        .cornerRadius(12)
                        .shadow(color: SettingsTheme.shadowColor, radius: SettingsTheme.shadowRadius, x: SettingsTheme.shadowX, y: SettingsTheme.shadowY)
                        .frame(width: isLandscape ? SettingsLayoutConfig.panelHeight - SettingsTheme.padding * 2 : nil)


                        // 闪光灯设置
                        VStack(alignment: .leading, spacing: SettingsTheme.contentSpacing) {
                            ZStack {
                                HStack {
                                    Spacer()
                                    Text("闪光设置")
                                        .font(.headline)
                                        .foregroundColor(SettingsTheme.titleColor)
                                    Spacer()
                                }
                                HStack {
                                    ProLabel(text: "Pro")
                                        .padding(.leading, 50)
                                    Spacer()
                                }
                            }
                            
                            // 开关设置
                            HStack {
                                Text("开启闪光")
                                    .foregroundColor(SettingsTheme.subtitleColor)
                                Spacer()
                                Toggle("", isOn: $isFlashEnabled)
                                    .labelsHidden()
                                    .onChange(of: isFlashEnabled) { newValue in
                                        // 更新 AppConfig
                                        AppConfig.AnimationConfig.Flash.isEnabled = newValue
                                        // 保存设置
                                        UserSettingsManager.shared.saveFlashSettings(
                                            isEnabled: newValue,
                                            intensity: flashIntensity
                                        )
                                        // 发送通知同步工具栏按钮状态
                                        NotificationCenter.default.post(
                                            name: NSNotification.Name("FlashSettingChanged"),
                                            object: nil,
                                            userInfo: ["isEnabled": newValue]
                                        )
                                    }
                            }
                            
                            // 强度设置
                            HStack {
                                Text("闪光强度")
                                    .foregroundColor(SettingsTheme.subtitleColor)
                                Picker("", selection: $flashIntensity) {
                                    ForEach(AppConfig.AnimationConfig.Flash.Intensity.allCases, id: \.self) { intensity in
                                        Text(intensity.description).tag(intensity)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .frame(maxWidth: .infinity)
                                .disabled(!isFlashEnabled) // 当闪光灯关闭时禁用强度选择
                                .opacity(isFlashEnabled ? 1.0 : 0.5) // 当闪光灯关闭时降低透明度
                                .onChange(of: flashIntensity) { newValue in
                                    // 更新 AppConfig
                                    AppConfig.AnimationConfig.Flash.intensity = newValue
                                    // 保存设置
                                    UserDefaults.standard.set(newValue.rawValue, forKey: "FlashIntensity")
                                }
                            }
                        }
                        .padding(SettingsTheme.padding)
                        .background(getSettingBackground(.flash))
                        .cornerRadius(12)
                        .shadow(color: SettingsTheme.shadowColor, radius: SettingsTheme.shadowRadius, x: SettingsTheme.shadowX, y: SettingsTheme.shadowY)
                        .frame(width: isLandscape ? SettingsLayoutConfig.panelHeight - SettingsTheme.padding * 2 : nil)
                        .overlay(proManager.proFeatureOverlay(.flash))
                        
                        // 参数设置
                        VStack(alignment: .leading, spacing: SettingsTheme.contentSpacing) {
                            HStack {
                                Spacer()
                                Text("参数设置")
                                    .font(.headline)
                                    .foregroundColor(SettingsTheme.titleColor)
                                Spacer()
                            }
                            
                            // 网格设置
                            VStack(alignment: .leading, spacing: SettingsTheme.contentSpacing) {
                                HStack {
                                    Text("网格参数")
                                        .font(.subheadline)
                                        .foregroundColor(SettingsTheme.titleColor)
                                    Spacer()
                                }
                                .padding(.bottom, 4)
                                
                                // 网格间距
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("网格间距")
                                            .font(.system(size: 15))
                                            .foregroundColor(SettingsTheme.subtitleColor)
                                        Spacer()
                                        Text("\(Int(gridSpacing))")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(.blue)
                                            .frame(width: 35, alignment: .trailing)
                                    }
                                    
                                    Slider(value: $gridSpacing, in: 5...100, step: 10)
                                        .accentColor(.blue)
                                        .onChange(of: gridSpacing) { newValue in
                                            // 只发送通知更新预览，不保存设置
                                            NotificationCenter.default.post(
                                                name: NSNotification.Name("UpdateGridSettings"),
                                                object: nil,
                                                userInfo: [
                                                    "spacing": newValue,
                                                    "color": gridLineColor,
                                                    "opacity": gridLineOpacity
                                                ]
                                            )
                                        }
                                }
                                
                                // 线条颜色
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("线条颜色")
                                        .font(.system(size: 15))
                                        .foregroundColor(SettingsTheme.subtitleColor)
                                    
                                    HStack(spacing: SettingsTheme.buttonSpacing) {
                                        ForEach(gridColors, id: \.self) { color in
                                            Button(action: {
                                                gridLineColor = color
                                                // 只发送通知更新预览，不保存设置
                                                NotificationCenter.default.post(
                                                    name: NSNotification.Name("UpdateGridSettings"),
                                                    object: nil,
                                                    userInfo: [
                                                        "spacing": gridSpacing,
                                                        "color": color,
                                                        "opacity": gridLineOpacity
                                                    ]
                                                )
                                            }) {
                                                Circle()
                                                    .fill(color)
                                                    .frame(width: 28, height: 28)
                                                    .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                                                    .overlay(
                                                        Circle()
                                                            .stroke(Color.blue, lineWidth: gridLineColor == color ? 2 : 0)
                                                    )
                                                    .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                                            }
                                        }
                                        Spacer()
                                    }
                                }
                                
                                // 线条透明度
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("线条透明度")
                                            .font(.system(size: 15))
                                            .foregroundColor(SettingsTheme.subtitleColor)
                                        Spacer()
                                        Text(String(format: "%.1f", gridLineOpacity))
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(.blue)
                                            .frame(width: 35, alignment: .trailing)
                                    }
                                    
                                    Slider(value: $gridLineOpacity, in: 0.1...1.0, step: 0.1)
                                        .accentColor(.blue)
                                        .onChange(of: gridLineOpacity) { newValue in
                                            // 只发送通知更新预览，不保存设置
                                            NotificationCenter.default.post(
                                                name: NSNotification.Name("UpdateGridSettings"),
                                                object: nil,
                                                userInfo: [
                                                    "spacing": gridSpacing,
                                                    "color": gridLineColor,
                                                    "opacity": newValue
                                                ]
                                            )
                                        }
                                }
                            }
                        }
                        .padding(SettingsTheme.padding)
                        .background(SettingsTheme.backgroundColor)
                        .cornerRadius(12)
                        .shadow(color: SettingsTheme.shadowColor, radius: SettingsTheme.shadowRadius, x: SettingsTheme.shadowX, y: SettingsTheme.shadowY)
                        .frame(width: isLandscape ? SettingsLayoutConfig.panelHeight - SettingsTheme.padding * 2 : nil)
                        
                        // 手势设置
                        VStack(alignment: .leading, spacing: SettingsTheme.contentSpacing) {
                            ZStack {
                                HStack {
                                    Spacer()
                                    Text("手势设置")
                                        .font(.headline)
                                        .foregroundColor(SettingsTheme.titleColor)
                                    Spacer()
                                }
                                HStack {
                                    ProLabel(text: "Pro")
                                        .padding(.leading, 50)
                                    Spacer()
                                }
                            }
                            
                            HStack {
                                Spacer()
                                
                                VStack(alignment: .center, spacing: SettingsTheme.buttonSpacing) {
                                    HStack(spacing: 4) {
                                        Text("拍照")
                                            .foregroundColor(SettingsTheme.subtitleColor)
                                            .frame(width: 75, alignment: .center)
                                        Text(styleManager.isDefaultGesture ? "双击" : "单击")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(styleManager.isDefaultGesture ? Color.red.opacity(0.5) : Color.blue.opacity(0.5))  
                                            .cornerRadius(8)
                                    }

                                    HStack(spacing: 4) {
                                        Text("边灯")
                                            .foregroundColor(SettingsTheme.subtitleColor)
                                            .frame(width: 75, alignment: .center)
                                        Text(styleManager.isDefaultGesture ? "单击" : "双击")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(styleManager.isDefaultGesture ? Color.blue.opacity(0.5) : Color.red.opacity(0.5))
                                            .cornerRadius(8)
                                    }

                                }
                                
                                Button(action: {
                                    withAnimation {
                                        styleManager.isDefaultGesture.toggle()
                                        styleManager.saveCurrentSettings()
                                    }
                                }) {
                                    Image(systemName: "arrow.up.and.down.circle.fill")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 35, height: 35)
                                        .foregroundColor(Color.gray.opacity(0.7))
                                        .padding(0)
                                        .background(Color.gray.opacity(0.2))
                                        .clipShape(Circle())
                                }
                                .padding(.leading, 20)
                                
                                Spacer()
                            }
                        }
                        .padding(SettingsTheme.padding)
                        .background(getSettingBackground(.gesture))
                        .cornerRadius(12)
                        .shadow(color: SettingsTheme.shadowColor, radius: SettingsTheme.shadowRadius, x: SettingsTheme.shadowX, y: SettingsTheme.shadowY)
                        .frame(width: isLandscape ? SettingsLayoutConfig.panelHeight - SettingsTheme.padding * 2 : nil)
                        .overlay(proManager.proFeatureOverlay(.gesture))
                        
                        // 主屏蝴蝶颜色设置
                        VStack(alignment: .center, spacing: SettingsTheme.contentSpacing) {
                            HStack(spacing: 4) {
                                Spacer()
                                Text("主题设置")
                                    .font(.headline)
                                    .foregroundColor(SettingsTheme.titleColor)
                                Spacer()
                            }
                            
                            HStack(spacing: SettingsTheme.buttonSpacing) {
                                ForEach(mainScreenColors) { option in
                                    ColorButton(
                                        option: option,
                                        isSelected: styleManager.iconColor == option.color
                                    ) {
                                        styleManager.iconColor = option.color
                                        styleManager.saveCurrentSettings()
                                        NotificationCenter.default.post(name: NSNotification.Name("UpdateButtonColors"), object: nil)
                                    }
                                }
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(SettingsTheme.padding)
                        .background(getSettingBackground(.theme))
                        .cornerRadius(12)
                        .shadow(color: SettingsTheme.shadowColor, radius: SettingsTheme.shadowRadius, x: SettingsTheme.shadowX, y: SettingsTheme.shadowY)
                        .frame(width: isLandscape ? SettingsLayoutConfig.panelHeight - SettingsTheme.padding * 2 : nil)
                        
                        // 双屏陪伴设置
                        VStack(alignment: .leading, spacing: SettingsTheme.contentSpacing) {
                            ZStack {
                                HStack {
                                    Spacer()
                                    Text("陪伴设置")
                                        .font(.headline)
                                        .foregroundColor(SettingsTheme.titleColor)
                                    Spacer()
                                }
                                HStack {
                                    ProLabel(text: "Pro")
                                        .padding(.leading, 50)
                                    Spacer()
                                }
                            }
                            
                            HStack(spacing: SettingsTheme.buttonSpacing) {
                                ForEach(splitScreenColors) { option in
                                    ColorButton(
                                        option: option,
                                        isSelected: styleManager.splitScreenIconImage == option.image,
                                        action: {
                                            // 更新选择逻辑
                                            styleManager.saveSplitScreenIconSettings(option)
                                            styleManager.saveCurrentSettings()
                                            NotificationCenter.default.post(name: NSNotification.Name("UpdateButtonColors"), object: nil)
                                        }
                                    )
                                }
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(SettingsTheme.padding)
                        .background(getSettingBackground(.companion))
                        .cornerRadius(12)
                        .shadow(color: SettingsTheme.shadowColor, radius: SettingsTheme.shadowRadius, x: SettingsTheme.shadowX, y: SettingsTheme.shadowY)
                        .frame(width: isLandscape ? SettingsLayoutConfig.panelHeight - SettingsTheme.padding * 2 : nil)
                        .overlay(proManager.proFeatureOverlay(.companion))
                        
                        // 系统设置
                        VStack(alignment: .leading, spacing: SettingsTheme.contentSpacing) {
                            ZStack {
                                HStack {
                                    Spacer()
                                    Text("系统设置")
                                        .font(.headline)
                                        .foregroundColor(SettingsTheme.titleColor)
                                    Spacer()
                                }
                                HStack {
                                    ProLabel(text: "Pro")
                                        .padding(.leading, 50)
                                    Spacer()
                                }
                            }
                            
                            HStack {
                                Text("开启App时直接进入双屏模式")
                                    .foregroundColor(SettingsTheme.subtitleColor)
                                Spacer()
                                Toggle("", isOn: $autoEnterTwoOfMe)
                                    .labelsHidden()
                                    .onChange(of: autoEnterTwoOfMe) { newValue in
                                        // 保存设置
                                        UserSettingsManager.shared.saveAutoEnterTwoOfMe(newValue)
                                    }
                            }
                            
                            HStack {
                                Text("照片水印")
                                    .foregroundColor(SettingsTheme.subtitleColor)
                                Spacer()
                                Toggle("", isOn: $isWatermarkEnabled)
                                    .labelsHidden()
                                    .onChange(of: isWatermarkEnabled) { newValue in
                                        // 保存设置
                                        UserSettingsManager.shared.saveWatermarkEnabled(newValue)
                                        // 发送通知更新水印状态
                                        NotificationCenter.default.post(name: NSNotification.Name("WatermarkSettingChanged"), object: nil)
                                    }
                            }
                        }
                        .padding(SettingsTheme.padding)
                        .background(getSettingBackground(.system))
                        .cornerRadius(12)
                        .shadow(color: SettingsTheme.shadowColor, radius: SettingsTheme.shadowRadius, x: SettingsTheme.shadowX, y: SettingsTheme.shadowY)
                        .frame(width: isLandscape ? SettingsLayoutConfig.panelHeight - SettingsTheme.padding * 2 : nil)
                        .overlay(proManager.proFeatureOverlay(.system))
                        
                        // 版本信息
                        VStack(spacing: SettingsTheme.buttonSpacing) {
                            Text("Mira")
                                .font(.headline)
                                .foregroundColor(.gray)
                            Text("Version 1.1")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            // 添加评价按钮
                            Button(action: {
                                // App Store 链接占位符
                                if let url = URL(string: "https://apps.apple.com/app/id6743115750") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.yellow)
                                    Text("评价我们")
                                        .foregroundColor(.black)
                                        .fontWeight(.medium)
                                }
                                .font(.system(size: 15))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.white)
                                .cornerRadius(18)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(Color.yellow.opacity(0.5), lineWidth: 1.5)
                                )
                                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                                .padding(.top, 12)
                            }
                        }
                        .padding(.top, SettingsTheme.buttonSpacing)
                        .padding(.bottom, SettingsTheme.buttonSpacing)
                    }
                    .padding(SettingsTheme.padding)
                    .padding(.top, SettingsTheme.buttonSpacing)
                }
                .background(SettingsTheme.panelBackgroundColor)
                .frame(width: isLandscape ? SettingsLayoutConfig.panelHeight : SettingsLayoutConfig.panelWidth)
            }
            .frame(width: isLandscape ? SettingsLayoutConfig.panelHeight : SettingsLayoutConfig.panelWidth,
                   height: isLandscape ? SettingsLayoutConfig.panelWidth : SettingsLayoutConfig.panelHeight)
            .background(Color.white)
            .cornerRadius(SettingsLayoutConfig.cornerRadius)
            .offset(x: offsetX, y: offsetY)
            .rotationEffect(.degrees(rotationAngle))
            .onAppear {
                // 使用 UserSettingsManager 加载闪光灯设置
                let flashSettings = UserSettingsManager.shared.loadFlashSettings()
                isFlashEnabled = flashSettings.isEnabled
                flashIntensity = flashSettings.intensity
                
                // 保存当前亮度并设置为最大
                previousBrightness = UIScreen.main.brightness
                UIScreen.main.brightness = 1.0
                print("------------------------")
                print("设置页面显示")
                print("保存原始亮度：\(previousBrightness)")
                print("设置最大亮度：1.0")
                print("------------------------")
                
                // 设置滚动条样式为黑色
                UIScrollView.appearance().indicatorStyle = .black
                // 确保滚动条显示
                UIScrollView.appearance().showsVerticalScrollIndicator = true
                UIScrollView.appearance().showsHorizontalScrollIndicator = false
                
                // 保存初始状态
                initialState = SettingsState()
                // 进入预览模式，显示边框灯
                borderLightManager.showOriginalHighlight = true
                borderLightManager.showMirroredHighlight = true
                
                // 添加闪光灯状态变化监听
                NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("FlashSettingChanged"),
                    object: nil,
                    queue: .main
                ) { notification in
                    if let isEnabled = notification.userInfo?["isEnabled"] as? Bool {
                        isFlashEnabled = isEnabled
                    }
                }
                
                // 添加颜色更新监听
                NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("UpdateButtonColors"),
                    object: nil,
                    queue: .main
                ) { _ in
                    // 强制刷新视图以更新颜色选择器的状态
                    withAnimation {
                        initialState = SettingsState()
                    }
                }
            }
            .onDisappear {
                // 恢复原始亮度
                UIScreen.main.brightness = previousBrightness
                print("------------------------")
                print("设置页面关闭")
                print("恢复原始亮度：\(previousBrightness)")
                print("------------------------")
                
                // 恢复默认滚动条样式
                UIScrollView.appearance().indicatorStyle = .default
                
                // 退出预览模式，关闭边框灯
                if !borderLightManager.isControllingBrightness {
                    borderLightManager.showOriginalHighlight = false
                    borderLightManager.showMirroredHighlight = false
                }
                // 发送设置页面关闭通知
                NotificationCenter.default.post(name: NSNotification.Name("SettingsDismissed"), object: nil)
                
                // 移除通知监听器
                NotificationCenter.default.removeObserver(
                    self,
                    name: NSNotification.Name("UpdateButtonColors"),
                    object: nil
                )
            }
            
            // 保存提示弹窗
            if showSaveAlert {
                Color.black.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                
                VStack {
                    VStack(spacing: 8) {
                        Text("未保存的更改")
                            .font(.headline)
                        
                        Text("您有未保存的更改，是否保存？")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    
                    Divider()
                    
                    HStack {
                        Button(action: {
                            showSaveAlert = false
                            restoreSettings()
                            isPresented = false
                        }) {
                            Text("不保存")
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                        }
                        
                        Divider()
                        
                        Button(action: {
                            showSaveAlert = false
                            saveSettings()
                            isPresented = false
                        }) {
                            Text("保存")
                                .bold()
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 44)
                }
                .frame(width: 270)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(14)
            }
        }
        .transition(.opacity)
    }
    
    // 处理关闭操作
    private func handleClose() {
        if checkForChanges() {
            showSaveAlert = true
            print("------------------------")
            print("[设置] 显示保存提示")
            print("------------------------")
        } else {
            isPresented = false
        }
    }
}

// 预览
#Preview {
    SettingsPanel(isPresented: .constant(true))
}

#if DEBUG
struct SettingsPanel_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // 竖屏 iPhone 预览
            SettingsPanel(isPresented: .constant(true))
                .previewDevice(PreviewDevice(rawValue: "iPhone 15 Pro"))
                .previewDisplayName("iPhone 15 Pro")
            
            // iPad 预览
            SettingsPanel(isPresented: .constant(true))
                .previewDevice(PreviewDevice(rawValue: "iPad Pro (12.9-inch) (6th generation)"))
                .previewDisplayName("iPad Pro")
            
            // 深色模式预览
            SettingsPanel(isPresented: .constant(true))
                .previewDevice(PreviewDevice(rawValue: "iPhone 15 Pro"))
                .previewDisplayName("深色模式")
                .preferredColorScheme(.dark)
            
            // 小屏幕 iPhone 预览
            SettingsPanel(isPresented: .constant(true))
                .previewDevice(PreviewDevice(rawValue: "iPhone SE (3rd generation)"))
                .previewDisplayName("iPhone SE")
            
            // 动态字体大小预览
            SettingsPanel(isPresented: .constant(true))
                .previewDevice(PreviewDevice(rawValue: "iPhone 15 Pro"))
                .previewDisplayName("动态字体")
                .environment(\.sizeCategory, .accessibilityLarge)
        }
    }
}
#endif 
