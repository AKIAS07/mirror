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
    static let backgroundColor2 = Color.gray.opacity(0.2)
    static let panelBackgroundColor = Color(red: 0.95, green: 0.95, blue: 0.97)  // 浅灰色替代 UIColor.systemGray6
    static let borderColor = Color.gray
    static let selectedBorderColor = Color.black
    
    // 边框
    static let normalBorderWidth: CGFloat = 1
    static let selectedBorderWidth: CGFloat = 3  // 增加选中边框的粗细
    static let buttonBorderColor = Color.gray.opacity(0.5)  // 统一按钮边框颜色
    static let selectedButtonBorderColor = Color.black  // 统一选中按钮边框颜色
    
    // 间距
    static let itemSpacing: CGFloat = 24  // 设置项之间的间距
    static let contentSpacing: CGFloat = 16  // 设置项内容的间距
    static let buttonSpacing: CGFloat = 12  // 按钮之间的间距
    static let padding: CGFloat = 16  // 内边距
    
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

// 设置面板视图
public struct SettingsPanel: View {
    @Binding var isPresented: Bool
    @ObservedObject private var styleManager = BorderLightStyleManager.shared
    @ObservedObject private var borderLightManager = BorderLightManager.shared
    @ObservedObject private var orientationManager = DeviceOrientationManager.shared
    @State private var showSaveSuccess = false
    @State private var showSaveAlert = false
    @State private var hasUnsavedChanges = false
    
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
    
    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }
    
    // 保存当前设置状态的结构体
    private struct SettingsState {
        var borderLightColor: Color = BorderLightStyleManager.shared.selectedColor
        var borderLightWidth: CGFloat = BorderLightStyleManager.shared.selectedWidth
        var isDefaultGesture: Bool = BorderLightStyleManager.shared.isDefaultGesture
        var iconColor: Color = BorderLightStyleManager.shared.iconColor
        var splitScreenIconColor: Color = BorderLightStyleManager.shared.splitScreenIconColor
    }
    
    // 检查是否有未保存的更改
    private func checkForChanges() -> Bool {
        return initialState.borderLightColor != styleManager.selectedColor ||
               initialState.borderLightWidth != styleManager.selectedWidth ||
               initialState.isDefaultGesture != styleManager.isDefaultGesture ||
               initialState.iconColor != styleManager.iconColor ||
               initialState.splitScreenIconColor != styleManager.splitScreenIconColor
    }
    
    // 保存设置
    private func saveSettings() {
        UserSettingsManager.shared.saveCurrentConfig()
        styleManager.saveCurrentSettings()
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
    
    public var body: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    if checkForChanges() {
                        showSaveAlert = true
                    } else {
                        withAnimation {
                            isPresented = false
                        }
                    }
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
                    
                    Button(action: {
                        if checkForChanges() {
                            showSaveAlert = true
                        } else {
                            withAnimation {
                                isPresented = false
                            }
                        }
                    }) {
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
                            HStack {
                                Spacer()
                                Text("边框灯设置")
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
                                HStack(spacing: SettingsTheme.buttonSpacing) {
                                    ForEach([
                                        Color(red: 1, green: 0.8, blue: 0.8),  // 柔和粉红
                                        Color(red: 0.9, green: 0.9, blue: 0.6),  // 柔和黄色
                                        Color(red: 0.8, green: 0.9, blue: 1),  // 柔和蓝色
                                        Color(red: 0.8, green: 1, blue: 0.8),  // 柔和绿色
                                        Color(red: 0.9, green: 0.8, blue: 1),  // 柔和紫色
                                        Color.white,
                                        Color(white: 0.2)  // 深灰色替代纯黑
                                    ], id: \.self) { color in
                                        Button(action: {
                                            // 不再立即保存，只更新显示
                                            styleManager.updateStyle(color: color)
                                        }) {
                                            Circle()
                                                .fill(color)
                                                .frame(width: 24, height: 24)
                                                .overlay(Circle().stroke(SettingsTheme.buttonBorderColor, lineWidth: SettingsTheme.normalBorderWidth))
                                                .overlay(Circle().stroke(SettingsTheme.selectedButtonBorderColor, 
                                                    lineWidth: styleManager.selectedColor == color ? SettingsTheme.selectedBorderWidth : 0))
                                        }
                                    }
                                }
                            }
                            
                            // 宽度选择
                            HStack {
                                Text("宽度")
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
                        .background(SettingsTheme.backgroundColor)
                        .cornerRadius(12)
                        .shadow(color: SettingsTheme.shadowColor, radius: SettingsTheme.shadowRadius, x: SettingsTheme.shadowX, y: SettingsTheme.shadowY)
                        .frame(width: isLandscape ? SettingsLayoutConfig.panelHeight - SettingsTheme.padding * 2 : nil)
                        
                        // 手势设置
                        VStack(alignment: .leading, spacing: SettingsTheme.contentSpacing) {
                            HStack {
                                Spacer()
                                Text("手势设置")
                                    .font(.headline)
                                    .foregroundColor(SettingsTheme.titleColor)
                                Spacer()
                            }
                            
                            HStack {
                                VStack(alignment: .leading, spacing: SettingsTheme.buttonSpacing) {
                                    Text(styleManager.isDefaultGesture ? "边框灯：单击" : "边框灯：双击")
                                        .foregroundColor(SettingsTheme.subtitleColor)
                                    Text(styleManager.isDefaultGesture ? "拍照：双击" : "拍照：单击")
                                        .foregroundColor(SettingsTheme.subtitleColor)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    withAnimation {
                                        styleManager.isDefaultGesture.toggle()
                                        styleManager.saveCurrentSettings()
                                    }
                                }) {
                                    Image(systemName: "arrow.up.arrow.down")
                                        .font(.title3)
                                        .foregroundColor(.black)
                                        .padding(SettingsTheme.buttonSpacing)
                                        .background(Color.gray.opacity(0.2))
                                        .clipShape(Circle())
                                }
                            }
                        }
                        .padding(SettingsTheme.padding)
                        .background(SettingsTheme.backgroundColor)
                        .cornerRadius(12)
                        .shadow(color: SettingsTheme.shadowColor, radius: SettingsTheme.shadowRadius, x: SettingsTheme.shadowX, y: SettingsTheme.shadowY)
                        .frame(width: isLandscape ? SettingsLayoutConfig.panelHeight - SettingsTheme.padding * 2 : nil)
                        
                        // 主屏蝴蝶颜色设置
                        VStack(alignment: .leading, spacing: SettingsTheme.contentSpacing) {
                            HStack {
                                Spacer()
                                Text("主屏蝴蝶颜色")
                                    .font(.headline)
                                    .foregroundColor(SettingsTheme.titleColor)
                                Spacer()
                            }
                            
                            HStack(spacing: SettingsTheme.buttonSpacing) {
                                // 白色图标按钮
                                Button(action: {
                                    styleManager.iconColor = .white
                                    styleManager.saveCurrentSettings()
                                    // 发送通知以更新主屏按钮颜色
                                    NotificationCenter.default.post(name: NSNotification.Name("UpdateButtonColors"), object: nil)
                                }) {
                                    Image("icon-bf-white")
                                        .resizable()
                                        .frame(width: 24, height: 24)
                                        .colorMultiply(.white)
                                        .background(Color.gray.opacity(0.3))
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(SettingsTheme.buttonBorderColor, lineWidth: SettingsTheme.normalBorderWidth))
                                        .overlay(
                                            Circle().stroke(
                                                SettingsTheme.selectedButtonBorderColor,
                                                lineWidth: styleManager.iconColor == .white ? SettingsTheme.selectedBorderWidth : 0
                                            )
                                        )
                                }
                                
                                // 温暖白图标按钮
                                Button(action: {
                                    styleManager.iconColor = Color(red: 1, green: 0.95, blue: 0.8)
                                    styleManager.saveCurrentSettings()
                                    // 发送通知以更新主屏按钮颜色
                                    NotificationCenter.default.post(name: NSNotification.Name("UpdateButtonColors"), object: nil)
                                }) {
                                    Image("icon-bf-white")
                                        .resizable()
                                        .frame(width: 24, height: 24)
                                        .colorMultiply(Color(red: 1, green: 0.95, blue: 0.8))
                                        .overlay(Circle().stroke(SettingsTheme.buttonBorderColor, lineWidth: SettingsTheme.normalBorderWidth))
                                        .overlay(
                                            Circle().stroke(
                                                SettingsTheme.selectedButtonBorderColor,
                                                lineWidth: styleManager.iconColor == Color(red: 1, green: 0.95, blue: 0.8) ? SettingsTheme.selectedBorderWidth : 0
                                            )
                                        )
                                }
                                
                                // 清新白图标按钮
                                Button(action: {
                                    styleManager.iconColor = Color(red: 0.9, green: 1, blue: 0.9)
                                    styleManager.saveCurrentSettings()
                                    // 发送通知以更新主屏按钮颜色
                                    NotificationCenter.default.post(name: NSNotification.Name("UpdateButtonColors"), object: nil)
                                }) {
                                    Image("icon-bf-white")
                                        .resizable()
                                        .frame(width: 24, height: 24)
                                        .colorMultiply(Color(red: 0.9, green: 1, blue: 0.9))
                                        .overlay(Circle().stroke(SettingsTheme.buttonBorderColor, lineWidth: SettingsTheme.normalBorderWidth))
                                        .overlay(
                                            Circle().stroke(
                                                SettingsTheme.selectedButtonBorderColor,
                                                lineWidth: styleManager.iconColor == Color(red: 0.9, green: 1, blue: 0.9) ? SettingsTheme.selectedBorderWidth : 0
                                            )
                                        )
                                }
                                
                                // 冷调白图标按钮
                                Button(action: {
                                    styleManager.iconColor = Color(red: 0.9, green: 0.95, blue: 1)
                                    styleManager.saveCurrentSettings()
                                    // 发送通知以更新主屏按钮颜色
                                    NotificationCenter.default.post(name: NSNotification.Name("UpdateButtonColors"), object: nil)
                                }) {
                                    Image("icon-bf-white")
                                        .resizable()
                                        .frame(width: 24, height: 24)
                                        .colorMultiply(Color(red: 0.9, green: 0.95, blue: 1))
                                        .overlay(Circle().stroke(SettingsTheme.buttonBorderColor, lineWidth: SettingsTheme.normalBorderWidth))
                                        .overlay(
                                            Circle().stroke(
                                                SettingsTheme.selectedButtonBorderColor,
                                                lineWidth: styleManager.iconColor == Color(red: 0.9, green: 0.95, blue: 1) ? SettingsTheme.selectedBorderWidth : 0
                                            )
                                        )
                                }
                                
                                // 黑色图标按钮
                                Button(action: {
                                    styleManager.iconColor = .black
                                    styleManager.saveCurrentSettings()
                                    // 发送通知以更新主屏按钮颜色
                                    NotificationCenter.default.post(name: NSNotification.Name("UpdateButtonColors"), object: nil)
                                }) {
                                    Image("icon-bf-white")
                                        .resizable()
                                        .frame(width: 24, height: 24)
                                        .colorMultiply(.black)
                                        .overlay(Circle().stroke(SettingsTheme.buttonBorderColor, lineWidth: SettingsTheme.normalBorderWidth))
                                        .overlay(
                                            Circle().stroke(
                                                SettingsTheme.selectedButtonBorderColor,
                                                lineWidth: styleManager.iconColor == .black ? SettingsTheme.selectedBorderWidth : 0
                                            )
                                        )
                                }
                                
                                Spacer()  // 添加这行来填充剩余空间
                            }
                            .frame(maxWidth: .infinity)  // 添加这行来强制使用最大宽度
                        }
                        .padding(SettingsTheme.padding)
                        .background(SettingsTheme.backgroundColor)
                        .cornerRadius(12)
                        .shadow(color: SettingsTheme.shadowColor, radius: SettingsTheme.shadowRadius, x: SettingsTheme.shadowX, y: SettingsTheme.shadowY)
                        .frame(width: isLandscape ? SettingsLayoutConfig.panelHeight - SettingsTheme.padding * 2 : nil)
                        
                        // 分屏蝴蝶颜色设置
                        VStack(alignment: .leading, spacing: SettingsTheme.contentSpacing) {
                            HStack {
                                Spacer()
                                Text("分屏蝴蝶颜色")
                                    .font(.headline)
                                    .foregroundColor(SettingsTheme.titleColor)
                                Spacer()
                            }
                            
                            HStack(spacing: SettingsTheme.buttonSpacing) {
                                // 彩色图标按钮
                                Button(action: {
                                    styleManager.splitScreenIconColor = Color(red: 0.8, green: 0.4, blue: 1.0)
                                    styleManager.saveCurrentSettings()
                                    // 发送通知以更新主屏按钮颜色
                                    NotificationCenter.default.post(name: NSNotification.Name("UpdateButtonColors"), object: nil)
                                }) {
                                    Image("icon-bf-color-1")
                                        .resizable()
                                        .frame(width: 24, height: 24)
                                        .overlay(Circle().stroke(SettingsTheme.buttonBorderColor, lineWidth: SettingsTheme.normalBorderWidth))
                                        .overlay(
                                            Circle().stroke(
                                                SettingsTheme.selectedButtonBorderColor,
                                                lineWidth: styleManager.splitScreenIconColor == Color(red: 0.8, green: 0.4, blue: 1.0) ? SettingsTheme.selectedBorderWidth : 0
                                            )
                                        )
                                }
                                
                                // 白色图标按钮
                                Button(action: {
                                    styleManager.splitScreenIconColor = .white
                                    styleManager.saveCurrentSettings()
                                    // 发送通知以更新主屏按钮颜色
                                    NotificationCenter.default.post(name: NSNotification.Name("UpdateButtonColors"), object: nil)
                                }) {
                                    Image("icon-bf-white")
                                        .resizable()
                                        .frame(width: 24, height: 24)
                                        .colorMultiply(.white)
                                        .background(Color.gray.opacity(0.3))
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(SettingsTheme.buttonBorderColor, lineWidth: SettingsTheme.normalBorderWidth))
                                        .overlay(
                                            Circle().stroke(
                                                SettingsTheme.selectedButtonBorderColor,
                                                lineWidth: styleManager.splitScreenIconColor == .white ? SettingsTheme.selectedBorderWidth : 0
                                            )
                                        )
                                }
                                
                                // 黑色图标按钮
                                Button(action: {
                                    styleManager.splitScreenIconColor = .black
                                    styleManager.saveCurrentSettings()
                                    // 发送通知以更新主屏按钮颜色
                                    NotificationCenter.default.post(name: NSNotification.Name("UpdateButtonColors"), object: nil)
                                }) {
                                    Image("icon-bf-white")
                                        .resizable()
                                        .frame(width: 24, height: 24)
                                        .colorMultiply(.black)
                                        .overlay(Circle().stroke(SettingsTheme.buttonBorderColor, lineWidth: SettingsTheme.normalBorderWidth))
                                        .overlay(
                                            Circle().stroke(
                                                SettingsTheme.selectedButtonBorderColor,
                                                lineWidth: styleManager.splitScreenIconColor == .black ? SettingsTheme.selectedBorderWidth : 0
                                            )
                                        )
                                }
                                
                                Spacer()  // 添加这行来填充剩余空间
                            }
                            .frame(maxWidth: .infinity)  // 添加这行来强制使用最大宽度
                        }
                        .padding(SettingsTheme.padding)
                        .background(SettingsTheme.backgroundColor)
                        .cornerRadius(12)
                        .shadow(color: SettingsTheme.shadowColor, radius: SettingsTheme.shadowRadius, x: SettingsTheme.shadowX, y: SettingsTheme.shadowY)
                        .frame(width: isLandscape ? SettingsLayoutConfig.panelHeight - SettingsTheme.padding * 2 : nil)
                        
                        // 版本信息
                        VStack(spacing: SettingsTheme.buttonSpacing) {
                            Text("Mirror")
                                .font(.headline)
                                .foregroundColor(.gray)
                            Text("Version 1.0.0")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            // 添加评价按钮
                            Button(action: {
                                // App Store 链接占位符
                                if let url = URL(string: "https://apps.apple.com/app/idXXXXXXXXXX") {
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
                            
                            // 添加更多应用栏目
                            VStack(spacing: 12) {
                                Text("更多应用")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                    .padding(.top, 16)
                                
                                HStack(spacing: 24) {
                                    // 第一个应用
                                    Button(action: {
                                        if let url = URL(string: "https://apps.apple.com/app/idYYYYYYYYYY") {
                                            UIApplication.shared.open(url)
                                        }
                                    }) {
                                        VStack(spacing: 4) {
                                            Image("app-1-icon") // 替换为实际的应用图标
                                                .resizable()
                                                .frame(width: 50, height: 50)
                                                .cornerRadius(12)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                                )
                                            Text("应用名称1")
                                                .font(.system(size: 12))
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    
                                    // 第二个应用
                                    Button(action: {
                                        if let url = URL(string: "https://apps.apple.com/app/idZZZZZZZZZZ") {
                                            UIApplication.shared.open(url)
                                        }
                                    }) {
                                        VStack(spacing: 4) {
                                            Image("app-2-icon") // 替换为实际的应用图标
                                                .resizable()
                                                .frame(width: 50, height: 50)
                                                .cornerRadius(12)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                                )
                                            Text("应用名称2")
                                                .font(.system(size: 12))
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
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
                // 设置滚动条样式
                UIScrollView.appearance().indicatorStyle = .black
                
                // 保存初始状态
                initialState = SettingsState()
                // 进入预览模式，显示边框灯
                borderLightManager.showOriginalHighlight = true
                borderLightManager.showMirroredHighlight = true
                // 发送设置页面显示通知
                NotificationCenter.default.post(name: NSNotification.Name("SettingsPresented"), object: nil)
            }
            .onDisappear {
                // 恢复默认滚动条样式
                UIScrollView.appearance().indicatorStyle = .default
                
                // 退出预览模式，关闭边框灯
                if !borderLightManager.isControllingBrightness {
                    borderLightManager.showOriginalHighlight = false
                    borderLightManager.showMirroredHighlight = false
                }
                // 发送设置页面关闭通知
                NotificationCenter.default.post(name: NSNotification.Name("SettingsDismissed"), object: nil)
            }
        }
        .transition(.opacity)
        .alert(isPresented: $showSaveAlert) {
            Alert(
                title: Text("未保存的更改"),
                message: Text("您有未保存的更改，是否保存？"),
                primaryButton: .default(Text("保存")) {
                    saveSettings()
                    withAnimation {
                        isPresented = false
                    }
                },
                secondaryButton: .destructive(Text("不保存")) {
                    // 恢复到上次保存的设置
                    styleManager.restoreSettings()
                    withAnimation {
                        isPresented = false
                    }
                }
            )
        }
    }
}

// 预览
#Preview {
    SettingsPanel(isPresented: .constant(true))
} 