import SwiftUI

// 设置面板布局常量
public struct SettingsLayoutConfig {
    public static let panelWidth: CGFloat = 300  // 250 + 50
    public static let panelHeight: CGFloat = 400 // 300 + 100
    public static let cornerRadius: CGFloat = 16
    public static let closeButtonSize: CGFloat = 24
    public static let closeButtonPadding: CGFloat = 12
}

// 设置面板主题
public struct SettingsTheme {
    // 颜色
    static let titleColor = Color(red: 0.3, green: 0.3, blue: 0.3)  // 深灰色替代 UIColor.darkGray
    static let subtitleColor = Color.gray
    static let backgroundColor = Color.white
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
    @State private var showSaveSuccess = false
    @State private var showSaveAlert = false
    @State private var hasUnsavedChanges = false
    
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
                                .font(.system(size: 14))
                            Text("保存")
                                .font(.system(size: 14))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .cornerRadius(6)
                    }
                    
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
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                    .padding(.leading, 8)
                }
                .padding(.horizontal)
                .padding(.top, 20)
                .padding(.bottom, 10)
                .overlay(
                    Group {
                        if showSaveSuccess {
                            Text("已保存")
                                .font(.system(size: 12))
                                .foregroundColor(.green)
                                .transition(.opacity)
                                .offset(y: 16)
                        }
                    }
                )
                
                ScrollView {
                    VStack(spacing: SettingsTheme.itemSpacing) {  // 增加设置项之间的间距
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
                            VStack(spacing: SettingsTheme.buttonSpacing) {  // 添加垂直布局
                                HStack {
                                    Text("颜色")
                                        .foregroundColor(SettingsTheme.subtitleColor)
                                    Spacer()
                                    CustomColorPicker(selection: $styleManager.selectedColor) {
                                        styleManager.saveCurrentSettings()
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
                                            styleManager.updateStyle(color: color)
                                            styleManager.saveCurrentSettings()
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
                                    styleManager.saveCurrentSettings()
                                }
                            }
                        }
                        .padding(SettingsTheme.padding)  // 统一内边距
                        .background(SettingsTheme.backgroundColor)
                        .cornerRadius(12)
                        .shadow(color: SettingsTheme.shadowColor, radius: SettingsTheme.shadowRadius, x: SettingsTheme.shadowX, y: SettingsTheme.shadowY)
                        
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
                        
                        // 版本信息
                        VStack(spacing: SettingsTheme.buttonSpacing) {
                            Text("Mirror")
                                .font(.headline)
                                .foregroundColor(.gray)
                            Text("Version 1.0.0")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding(.top, SettingsTheme.buttonSpacing)
                        .padding(.bottom, SettingsTheme.buttonSpacing)
                    }
                    .padding(SettingsTheme.padding)  // 整体水平内边距
                    .padding(.top, SettingsTheme.buttonSpacing)
                }
                .background(SettingsTheme.panelBackgroundColor)  // 添加浅灰色背景
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white)
            .frame(width: SettingsLayoutConfig.panelWidth, height: SettingsLayoutConfig.panelHeight)
            .cornerRadius(SettingsLayoutConfig.cornerRadius)
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
                    // 恢复到初始状态
                    styleManager.selectedColor = initialState.borderLightColor
                    styleManager.selectedWidth = initialState.borderLightWidth
                    styleManager.isDefaultGesture = initialState.isDefaultGesture
                    styleManager.iconColor = initialState.iconColor
                    styleManager.splitScreenIconColor = initialState.splitScreenIconColor
                    withAnimation {
                        isPresented = false
                    }
                }
            )
        }
        .onAppear {
            // 保存初始状态
            initialState = SettingsState()
        }
    }
}

// 预览
#Preview {
    SettingsPanel(isPresented: .constant(true))
} 