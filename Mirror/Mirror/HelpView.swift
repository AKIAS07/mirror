import SwiftUI

public struct HelpPanel: View {
    @Binding var isPresented: Bool
    
    // 使用与设置面板相同的尺寸
    private let panelWidth: CGFloat = SettingsLayoutConfig.panelWidth + 50 // 帮助面板稍微宽一点，方便显示内容
    private let panelHeight: CGFloat = SettingsLayoutConfig.panelHeight + 100 // 帮助面板稍微高一点，方便滚动内容
    
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
            
            // 帮助面板
            VStack(spacing: 20) {
                // 标题
                HStack {
                    Text("使用帮助")
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
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        HelpItem(title: "基本操作", 
                                content: "• 双击屏幕：截图\n• 双指缩放：调整画面大小\n• 点击画面：开启/关闭补光")
                        
                        HelpItem(title: "模式切换", 
                                content: "• 左侧按钮：镜像模式\n• 右侧按钮：正常模式\n• 中间按钮：分屏模式")
                        
                        HelpItem(title: "拖拽操作", 
                                content: "• 上下拖动：展开/收起控制面板\n• 左右拖动：隐藏/显示控制面板")
                    }
                    .padding()
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.8))
            .frame(width: panelWidth, height: panelHeight)
            .cornerRadius(SettingsLayoutConfig.cornerRadius)
        }
        .transition(.opacity)
    }
}

public struct HelpItem: View {
    let title: String
    let content: String
    
    public init(title: String, content: String) {
        self.title = title
        self.content = content
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            Text(content)
                .font(.body)
                .foregroundColor(.gray)
                .lineSpacing(5)
        }
    }
}

// 预览
#Preview {
    HelpPanel(isPresented: .constant(true))
} 