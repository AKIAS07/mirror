import SwiftUI

// 添加高亮文本组件
struct HighlightText: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color.gray.opacity(0.7))
            .cornerRadius(8)
    }
}

// 添加带说明的高亮文本行组件
struct LabeledHighlightRow: View {
    let highlightText: String
    let description: String
    
    var body: some View {
        HStack(spacing: 8) {
            HighlightText(text: highlightText)
                .frame(width: 85, alignment: .center)
            Text(description)
                .foregroundColor(SettingsTheme.subtitleColor)
                .frame(width: 150, alignment: .center)
        }
    }
}

public struct HelpPanel: View {
    @Binding var isPresented: Bool
    @ObservedObject private var orientationManager = DeviceOrientationManager.shared
    
    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }
    
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
            VStack(spacing: 0) {
                // 标题
                HStack {
                    Text("使用帮助")
                        .font(.title2)
                        .foregroundColor(.black)
                    Spacer()
                    Button(action: {
                        withAnimation {
                            isPresented = false
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

                        VStack(alignment: .center, spacing: SettingsTheme.contentSpacing) {
                            Text("主屏模式")
                                .font(.headline)
                                .foregroundColor(SettingsTheme.titleColor)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        
                        // 模式切换
                        VStack(alignment: .leading, spacing: SettingsTheme.contentSpacing) {
                            Text("主屏显示")
                                .font(.headline)
                                .foregroundColor(SettingsTheme.titleColor)
                                .frame(maxWidth: .infinity, alignment: .center)
                            Text("（支持旋转）")
                                .font(.subheadline)
                                .foregroundColor(SettingsTheme.subtitleColor)
                                .frame(maxWidth: .infinity, alignment: .center)
                            
                            VStack(alignment: .leading, spacing: 5) {
                                LabeledHighlightRow(
                                    highlightText: "左侧按钮",
                                    description: "正常镜"
                                )
                                LabeledHighlightRow(
                                    highlightText: "右侧按钮",
                                    description: "翻转镜"
                                )
                                LabeledHighlightRow(
                                    highlightText: "中间按钮",
                                    description: "双屏模式"
                                )
                            }
                            .font(.body)
                        }
                        .padding(SettingsTheme.padding)
                        .background(SettingsTheme.backgroundColor)
                        .cornerRadius(12)
                        .shadow(color: SettingsTheme.shadowColor, radius: SettingsTheme.shadowRadius, x: SettingsTheme.shadowX, y: SettingsTheme.shadowY)
                        .frame(width: isLandscape ? SettingsLayoutConfig.panelHeight - SettingsTheme.padding * 2 : nil)
                        
                        // 基本操作
                        VStack(alignment: .leading, spacing: SettingsTheme.contentSpacing) {
                            Text("屏幕功能")
                                .font(.headline)
                                .foregroundColor(SettingsTheme.titleColor)
                                .frame(maxWidth: .infinity, alignment: .center)
                            Text("（拍照/边框灯 手势可切换）")
                                .font(.subheadline)
                                .foregroundColor(SettingsTheme.subtitleColor)
                                .frame(maxWidth: .infinity, alignment: .center)

                            VStack(alignment: .leading, spacing: 5) {
                                LabeledHighlightRow(
                                    highlightText: "双指拖动",
                                    description: "缩放摄像头"
                                )
                                LabeledHighlightRow(
                                    highlightText: "双击",
                                    description: "拍照 拍摄/退出"
                                )
                                LabeledHighlightRow(
                                    highlightText: "单击",
                                    description: "边框灯 开启/关闭"
                                )
                                LabeledHighlightRow(
                                    highlightText: "下载/分享",
                                    description: "图片 下载/分享"
                                )
                            }
                            .font(.body)
                        }
                        .padding(SettingsTheme.padding)
                        .background(SettingsTheme.backgroundColor)
                        .cornerRadius(12)
                        .shadow(color: SettingsTheme.shadowColor, radius: SettingsTheme.shadowRadius, x: SettingsTheme.shadowX, y: SettingsTheme.shadowY)
                        .frame(width: isLandscape ? SettingsLayoutConfig.panelHeight - SettingsTheme.padding * 2 : nil)

                        // 拖拽操作
                        VStack(alignment: .leading, spacing: SettingsTheme.contentSpacing) {
                            Text("面板功能")
                                .font(.headline)
                                .foregroundColor(SettingsTheme.titleColor)
                                .frame(maxWidth: .infinity, alignment: .center)
                            
                            VStack(alignment: .leading, spacing: 5) {
                                LabeledHighlightRow(
                                    highlightText: "上下拖动",
                                    description: "面板 扩展/还原"
                                )
                                LabeledHighlightRow(
                                    highlightText: "左右拖动",
                                    description: "面板 隐藏/显示"
                                )
                            }
                            .font(.body)
                        }
                        .padding(SettingsTheme.padding)
                        .background(SettingsTheme.backgroundColor)
                        .cornerRadius(12)
                        .shadow(color: SettingsTheme.shadowColor, radius: SettingsTheme.shadowRadius, x: SettingsTheme.shadowX, y: SettingsTheme.shadowY)
                        .frame(width: isLandscape ? SettingsLayoutConfig.panelHeight - SettingsTheme.padding * 2 : nil)
                        
                        VStack(alignment: .center, spacing: SettingsTheme.contentSpacing) {
                            Text("双屏模式")
                                .font(.headline)
                                .foregroundColor(SettingsTheme.titleColor)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        
                        // 模式切换
                        VStack(alignment: .leading, spacing: SettingsTheme.contentSpacing) {
                            Text("双屏显示")
                                .font(.headline)
                                .foregroundColor(SettingsTheme.titleColor)
                                .frame(maxWidth: .infinity, alignment: .center)
                            Text("（支持旋转）")
                                .font(.subheadline)
                                .foregroundColor(SettingsTheme.subtitleColor)
                                .frame(maxWidth: .infinity, alignment: .center)

                            VStack(alignment: .leading, spacing: 5) {
                                LabeledHighlightRow(
                                    highlightText: "上下分屏",
                                    description: "正常镜 + 翻转镜"
                                )
                                LabeledHighlightRow(
                                    highlightText: "左右分屏",
                                    description: "正常镜 + 翻转镜"
                                )
                            }
                            .font(.body)
                        }
                        .padding(SettingsTheme.padding)
                        .background(SettingsTheme.backgroundColor2)
                        .cornerRadius(12)
                        .shadow(color: SettingsTheme.shadowColor, radius: SettingsTheme.shadowRadius, x: SettingsTheme.shadowX, y: SettingsTheme.shadowY)
                        .frame(width: isLandscape ? SettingsLayoutConfig.panelHeight - SettingsTheme.padding * 2 : nil)
                        
                        // 基本操作
                        VStack(alignment: .leading, spacing: SettingsTheme.contentSpacing) {
                            Text("单屏功能")
                                .font(.headline)
                                .foregroundColor(SettingsTheme.titleColor)
                                .frame(maxWidth: .infinity, alignment: .center)
                            Text("（拍照/边框灯 手势可切换）")
                                .font(.subheadline)
                                .foregroundColor(SettingsTheme.subtitleColor)
                                .frame(maxWidth: .infinity, alignment: .center)
                            
                            VStack(alignment: .leading, spacing: 5) {
                                LabeledHighlightRow(
                                    highlightText: "双击",
                                    description: "拍照 拍摄/退出"
                                )
                                LabeledHighlightRow(
                                    highlightText: "单击",
                                    description: "边框灯 开启/关闭"
                                )
                                LabeledHighlightRow(
                                    highlightText: "长按全屏灯",
                                    description: "全屏灯 开启/关闭"
                                )
                                LabeledHighlightRow(
                                    highlightText: "双指拖动",
                                    description: "缩放 摄像头/图片"
                                )
                                LabeledHighlightRow(
                                    highlightText: "长按上传",
                                    description: "图片上传"
                                )
                                LabeledHighlightRow(
                                    highlightText: "单指拖动",
                                    description: "移动图片位置"
                                )
                                LabeledHighlightRow(
                                    highlightText: "长按下载",
                                    description: "图片下载"
                                )
                            }
                            .font(.body)
                        }
                        .padding(SettingsTheme.padding)
                        .background(SettingsTheme.backgroundColor2)
                        .cornerRadius(12)
                        .shadow(color: SettingsTheme.shadowColor, radius: SettingsTheme.shadowRadius, x: SettingsTheme.shadowX, y: SettingsTheme.shadowY)
                        .frame(width: isLandscape ? SettingsLayoutConfig.panelHeight - SettingsTheme.padding * 2 : nil)

                        // 拖拽操作
                        VStack(alignment: .leading, spacing: SettingsTheme.contentSpacing) {
                            Text("双屏功能")
                                .font(.headline)
                                .foregroundColor(SettingsTheme.titleColor)
                                .frame(maxWidth: .infinity, alignment: .center)
                            Text("（拍照/边框灯 手势可切换）")
                                .font(.subheadline)
                                .foregroundColor(SettingsTheme.subtitleColor)
                                .frame(maxWidth: .infinity, alignment: .center)
                            
                            VStack(alignment: .leading, spacing: 5) {
                                LabeledHighlightRow(
                                    highlightText: "双击蝴蝶",
                                    description: "拍照 拍摄/退出"
                                )
                                LabeledHighlightRow(
                                    highlightText: "单击蝴蝶",
                                    description: "边框灯 开启/关闭"
                                )
                                LabeledHighlightRow(
                                    highlightText: "长按蝴蝶",
                                    description: "分屏位置切换"
                                )
                            }
                            .font(.body)
                        }
                        .padding(SettingsTheme.padding)
                        .background(SettingsTheme.backgroundColor2)
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
            }
            .onDisappear {
                // 恢复默认滚动条样式
                UIScrollView.appearance().indicatorStyle = .default
            }
        }
        .transition(.opacity)
    }
}

// 预览
#Preview {
    HelpPanel(isPresented: .constant(true))
} 