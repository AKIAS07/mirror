import SwiftUI

// 设置面板布局常量
public struct SettingsLayoutConfig {
    public static let panelWidth: CGFloat = 300
    public static let panelHeight: CGFloat = 400
    public static let cornerRadius: CGFloat = 20
    public static let closeButtonSize: CGFloat = 30
    public static let closeButtonPadding: CGFloat = 15
}

// 设置面板视图
public struct SettingsPanel: View {
    @Binding var isPresented: Bool
    
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
            VStack(spacing: 20) {
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
        }
        .transition(.opacity)
    }
}

// 预览
#Preview {
    SettingsPanel(isPresented: .constant(true))
} 