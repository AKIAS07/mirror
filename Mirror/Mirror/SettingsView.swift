import SwiftUI

// 设置面板布局常量
public struct SettingsLayoutConfig {
    public static let panelWidth: CGFloat = 250
    public static let panelHeight: CGFloat = 300
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

// 设置面板视图
public struct SettingsPanel: View {
    @Binding var isPresented: Bool
    @State private var borderColor: Color = BorderStyle.selectedColor
    @State private var borderWidth: CGFloat = BorderStyle.selectedWidth
    @Environment(\.borderLightSettings) var borderLightSettings
    
    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }
    
    public var body: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(0.5)
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
                        ColorPicker("", selection: $borderColor)
                            .labelsHidden()
                    }
                    
                    // 宽度滑块
                    HStack {
                        Text("宽度")
                            .foregroundColor(.gray)
                        Slider(value: $borderWidth, in: 1...100) {
                            Text("")
                        }
                        Text("\(Int(borderWidth))")
                            .foregroundColor(.gray)
                            .frame(width: 30)
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
            .onChange(of: borderColor) { newValue in
                BorderStyle.selectedColor = newValue
            }
            .onChange(of: borderWidth) { newValue in
                BorderStyle.selectedWidth = newValue
            }
        }
        .transition(.opacity)
    }
}

// 预览
#Preview {
    SettingsPanel(isPresented: .constant(true))
} 