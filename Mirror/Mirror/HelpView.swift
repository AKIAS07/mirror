import SwiftUI

// 帮助面板布局常量
struct HelpLayoutConfig {
    static let panelWidth: CGFloat = 300
    static let panelHeight: CGFloat = 400
    static let cornerRadius: CGFloat = 20
    static let closeButtonSize: CGFloat = 30
    static let closeButtonPadding: CGFloat = 15
}

// 帮助面板视图
struct HelpPanel: View {
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
            
            // 帮助面板
            VStack {
                // 帮助面板主体
                ZStack {
                    // 白色背景
                    RoundedRectangle(cornerRadius: HelpLayoutConfig.cornerRadius)
                        .fill(Color.white)
                        .frame(width: HelpLayoutConfig.panelWidth, 
                               height: HelpLayoutConfig.panelHeight)
                    
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
                                    .font(.system(size: HelpLayoutConfig.closeButtonSize))
                                    .foregroundColor(.gray)
                            }
                            .padding(.trailing, HelpLayoutConfig.closeButtonPadding)
                            .padding(.top, HelpLayoutConfig.closeButtonPadding)
                        }
                        Spacer()
                    }
                    .frame(width: HelpLayoutConfig.panelWidth, 
                           height: HelpLayoutConfig.panelHeight)
                    
                    // 帮助内容
                    VStack(spacing: 20) {
                        Text("使用帮助")
                            .font(.title)
                            .foregroundColor(.black)
                        
                        VStack(alignment: .leading, spacing: 15) {
                            HelpItem(icon: "arrow.left.and.right.righttriangle.left.righttriangle.right", 
                                   title: "镜像模式",
                                   description: "左侧按钮可切换到镜像模式")
                            
                            HelpItem(icon: "rectangle.split.2x1", 
                                   title: "分屏模式",
                                   description: "中间按钮可进入分屏模式")
                            
                            HelpItem(icon: "camera", 
                                   title: "正常模式",
                                   description: "右侧按钮可切换到正常模式")
                            
                            HelpItem(icon: "suit.diamond.fill", 
                                   title: "拖动手势",
                                   description: "可上下左右拖动控制面板")
                            
                            HelpItem(icon: "hand.draw.fill", 
                                   title: "点击操作",
                                   description: "点击屏幕可调节亮度")
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .frame(width: HelpLayoutConfig.panelWidth, 
                       height: HelpLayoutConfig.panelHeight)
            }
        }
        .transition(.opacity)
    }
}

// 帮助项目组件
struct HelpItem: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
    }
}

// 预览
#Preview {
    HelpPanel(isPresented: .constant(true))
} 