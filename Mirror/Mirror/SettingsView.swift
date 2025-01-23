import SwiftUI

// 设置面板布局常量
public struct SettingsLayoutConfig {
    public static let panelWidth: CGFloat = 300  // 250 + 50
    public static let panelHeight: CGFloat = 400 // 300 + 100
    public static let cornerRadius: CGFloat = 16
    public static let closeButtonSize: CGFloat = 24
    public static let closeButtonPadding: CGFloat = 12
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
    
    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }
    
    public var body: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    withAnimation {
                        isPresented = false
                    }
                }
            
            // 设置面板
            VStack(spacing: 15) {
                // 标题
                HStack {
                    Text("设置")
                        .font(.title2)
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: {
                        withAnimation {
                            isPresented = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal)
                
                // 边框灯设置
                VStack(alignment: .leading, spacing: 12) {
                    Text("边框灯设置")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    // 颜色选择器
                    HStack {
                        Text("颜色")
                            .foregroundColor(.gray)
                        Spacer()
                        CustomColorPicker(selection: $styleManager.selectedColor) {
                            styleManager.saveCurrentSettings()
                        }
                    }
                    
                    // 常用颜色快捷选择
                    HStack(spacing: 12) {
                        ForEach([Color.red, .yellow, .blue, .green, .purple, .black, .white], id: \.self) { color in
                            Button(action: {
                                styleManager.updateStyle(color: color)
                                styleManager.saveCurrentSettings()
                            }) {
                                Circle()
                                    .fill(color)
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: styleManager.selectedColor == color ? 2 : 0)
                                    )
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    
                    // 宽度选择
                    HStack {
                        Text("宽度")
                            .foregroundColor(.gray)
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
                .padding(.horizontal)
                
                // 添加手势设置
                VStack(alignment: .leading, spacing: 12) {
                    Text("手势设置")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(styleManager.isDefaultGesture ? "边框灯：单击" : "边框灯：双击")
                                .foregroundColor(.gray)
                            Text(styleManager.isDefaultGesture ? "拍照：双击" : "拍照：单击")
                                .foregroundColor(.gray)
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
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.gray.opacity(0.3))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // 版本信息
                VStack(spacing: 10) {
                    Text("Mirror")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Version 1.0.0")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.8))
            .frame(width: SettingsLayoutConfig.panelWidth, height: SettingsLayoutConfig.panelHeight)
            .cornerRadius(SettingsLayoutConfig.cornerRadius)
        }
        .transition(.opacity)
    }
}

// 预览
#Preview {
    SettingsPanel(isPresented: .constant(true))
} 