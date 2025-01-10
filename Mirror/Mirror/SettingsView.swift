import SwiftUI

// 设置面板布局常量
struct SettingsLayoutConfig {
    static let panelWidth: CGFloat = 300
    static let panelHeight: CGFloat = 400
    static let cornerRadius: CGFloat = 20
    static let closeButtonSize: CGFloat = 30
    static let closeButtonPadding: CGFloat = 15
}

// 设置面板视图
struct SettingsPanel: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isPresented = false
                    }
                }
            
            // 设置面板
            VStack {
                // 设置面板主体
                ZStack {
                    // 白色背景
                    RoundedRectangle(cornerRadius: SettingsLayoutConfig.cornerRadius)
                        .fill(Color.white)
                        .frame(width: SettingsLayoutConfig.panelWidth, 
                               height: SettingsLayoutConfig.panelHeight)
                    
                    // 关闭按钮
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isPresented = false
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: SettingsLayoutConfig.closeButtonSize))
                                    .foregroundColor(.gray)
                            }
                            .padding(.trailing, SettingsLayoutConfig.closeButtonPadding)
                            .padding(.top, SettingsLayoutConfig.closeButtonPadding)
                        }
                        Spacer()
                    }
                    .frame(width: SettingsLayoutConfig.panelWidth, 
                           height: SettingsLayoutConfig.panelHeight)
                    
                    // 设置内容
                    VStack(spacing: 20) {
                        Text("设置")
                            .font(.title)
                            .foregroundColor(.black)
                        
                        // 这里可以添加更多设置选项
                        Text("更多设置选项即将推出...")
                            .foregroundColor(.gray)
                    }
                }
                .frame(width: SettingsLayoutConfig.panelWidth, 
                       height: SettingsLayoutConfig.panelHeight)
            }
        }
        .transition(.opacity)
    }
}

// 预览
#Preview {
    SettingsPanel(isPresented: .constant(true))
} 