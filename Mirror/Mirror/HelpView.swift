import SwiftUI

// 添加高亮文本组件
struct HighlightText: View {
    let text: String
    var systemImage: String? = nil
    
    var body: some View {
        HStack(spacing: 4) {
            Text(text)
            if let imageName = systemImage {
                if imageName.hasPrefix("icon-bf") {
                    // 使用自定义图片
                    Image(imageName)
                        .resizable()
                        .frame(width: 15, height: 15)
                } else {
                    // 使用系统图标
                    Image(systemName: imageName)
                        .font(.system(size: 12))
                }
            }
        }
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
    let description: any View
    var proLabel: Bool = false  // 添加 proLabel 参数
    var freeLabel: Bool = false  // 添加 freeLabel 参数
    var systemImage: String? = nil  // 添加可选的系统图标
    
    init(highlightText: String, description: some View, proLabel: Bool = false, freeLabel: Bool = false, systemImage: String? = nil) {
        self.highlightText = highlightText
        self.description = description
        self.proLabel = proLabel
        self.freeLabel = freeLabel
        self.systemImage = systemImage
    }
    
    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                
                if proLabel {
                    ProLabel(text: "Pro")
                }
                if freeLabel {
                    FreeLabel(text: "Free")
                }
                HighlightText(text: highlightText, systemImage: systemImage)
            }
            .frame(width:110, alignment: .leading)
            
            AnyView(description)
                .foregroundColor(SettingsTheme.subtitleColor)
                .frame(width: 140, alignment: .center)
        }
    }
}

// 添加自定义分段按钮样式
struct CustomSegmentButton: View {
    let title: String
    let iconName: String
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 14))
            Image(iconName)
                .resizable()
                .frame(width: 20, height: 20)
        }
        .foregroundColor(isSelected ? .black : .gray.opacity(0.5))
        .padding(.vertical, 4)
    }
}

public struct HelpPanel: View {
    @Binding var isPresented: Bool
    @ObservedObject private var orientationManager = DeviceOrientationManager.shared
    @State private var selectedMode: Int = 0 // 添加状态变量来跟踪选中的模式
    
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
                // 标题栏
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
                
                // 替换原有的 Picker 为自定义分段控制器
                HStack(spacing: 0) {
                    Button(action: { selectedMode = 0 }) {
                        CustomSegmentButton(
                            title: "主屏模式",
                            iconName: "icon-bf-white",
                            isSelected: selectedMode == 0
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .background(selectedMode == 0 ? Color.black.opacity(0.1) : Color.clear)
                    
                    Button(action: { selectedMode = 1 }) {
                        CustomSegmentButton(
                            title: "双屏模式",
                            iconName: "icon-bf-color-1",
                            isSelected: selectedMode == 1
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .background(selectedMode == 1 ? Color.black.opacity(0.1) : Color.clear)
                }
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                // 内容区域
                ScrollView(showsIndicators: true) {
                    VStack(spacing: SettingsTheme.itemSpacing) {
                        if selectedMode == 0 {
                            // 主屏模式内容
                            Group {
                                
                                // 模式切换
                                VStack(alignment: .leading, spacing: SettingsTheme.contentSpacing) {
                                    Text("显示功能")
                                        .font(.headline)
                                        .foregroundColor(SettingsTheme.titleColor)
                                        .frame(maxWidth: .infinity, alignment: .center)

                                    HStack(spacing: 4) {
                                        ProLabel(text: "Pro")
                                        Text("（支持旋转）")
                                            .font(.subheadline)
                                            .foregroundColor(SettingsTheme.subtitleColor)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .center)

                                    
                                    VStack(alignment: .leading, spacing: 5) {
                                        LabeledHighlightRow(
                                            highlightText: "左侧按钮",
                                            description: HStack(spacing: 4) {
                                                Text("正常镜")
                                            },
                                            freeLabel: true
                                        )
                                        LabeledHighlightRow(
                                            highlightText: "右侧按钮",
                                            description: HStack(spacing: 4) {
                                                Text("翻转镜")
                                            },
                                            freeLabel: true
                                        )
                                        LabeledHighlightRow(
                                            highlightText: "中间按钮",
                                            description: HStack(spacing: 4) {
                                                Text("双屏模式")
                                            },
                                            freeLabel: true
                                        )
                                        LabeledHighlightRow(
                                            highlightText: "设置",
                                            description: HStack(spacing: 4) {
                                                Text("基础设置")
                                            },
                                            freeLabel: true
                                        )
                                        LabeledHighlightRow(
                                            highlightText: "帮助",
                                            description: HStack(spacing: 4) {
                                                Text("使用帮助")
                                            },
                                            freeLabel: true
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

                                    HStack(spacing: 4) {
                                        ProLabel(text: "Pro")
                                        Text("（手势可切换）")
                                            .font(.subheadline)
                                            .foregroundColor(SettingsTheme.subtitleColor)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .center)

                                    VStack(alignment: .leading, spacing: 5) {
                                        LabeledHighlightRow(
                                            highlightText: "双击",
                                            description: HStack(spacing: 4) {
                                                Text("拍照 拍摄/退出")
                                            },
                                            freeLabel: true
                                        )
                                        LabeledHighlightRow(
                                            highlightText: "闪光",
                                            description: HStack(spacing: 4) {
                                                Text("拍照时闪光")
                                            },
                                            proLabel: true
                                        )
                                        LabeledHighlightRow(
                                            highlightText: "单击",
                                            description: HStack(spacing: 4) {
                                                Text("边灯 开启/关闭")
                                            },
                                            freeLabel: true
                                        )
                                        LabeledHighlightRow(
                                            highlightText: "双指",
                                            description: HStack(spacing: 4) {
                                                Text("缩放画面")
                                            },
                                            freeLabel: true
                                        )
                                        LabeledHighlightRow(
                                            highlightText: "下载分享",
                                            description: HStack(spacing: 4) {
                                                Text("图片 下载/分享")
                                            },
                                            freeLabel: true
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
                                            description: HStack(spacing: 4) {
                                                Text("面板 扩展/还原")
                                            },
                                            freeLabel: true
                                        )
                                        LabeledHighlightRow(
                                            highlightText: "左右拖动",
                                            description: HStack(spacing: 4) {
                                                Text("面板 隐藏/显示")
                                            },
                                            freeLabel: true
                                        )
                                    }
                                    .font(.body)
                                }
                                .padding(SettingsTheme.padding)
                                .background(SettingsTheme.backgroundColor)
                                .cornerRadius(12)
                                .shadow(color: SettingsTheme.shadowColor, radius: SettingsTheme.shadowRadius, x: SettingsTheme.shadowX, y: SettingsTheme.shadowY)
                                .frame(width: isLandscape ? SettingsLayoutConfig.panelHeight - SettingsTheme.padding * 2 : nil)
                            }
                        } else {
                            // 双屏模式内容
                            Group {
                                
                                // 模式切换
                                VStack(alignment: .leading, spacing: SettingsTheme.contentSpacing) {
                                    Text("显示功能")
                                        .font(.headline)
                                        .foregroundColor(SettingsTheme.titleColor)
                                        .frame(maxWidth: .infinity, alignment: .center)

                                    HStack(spacing: 4) {
                                        ProLabel(text: "Pro")
                                        Text("（支持旋转）")
                                            .font(.subheadline)
                                            .foregroundColor(SettingsTheme.subtitleColor)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .center)


                                    VStack(alignment: .leading, spacing: 5) {
                                        LabeledHighlightRow(
                                            highlightText: "上下分屏",
                                            description: HStack(spacing: 4) {
                                                Text("正常镜 + 翻转镜")
                                            },
                                            freeLabel: true
                                        )
                                        LabeledHighlightRow(
                                            highlightText: "左右分屏",
                                            description: HStack(spacing: 4) {
                                                Text("正常镜 + 翻转镜")
                                            },
                                            proLabel: true
                                        )
                                    }
                                    .font(.body)
                                }
                                .padding(SettingsTheme.padding)
                                .background(SettingsTheme.backgroundColor2)
                                .cornerRadius(12)
                                .shadow(color: SettingsTheme.shadowColor, radius: SettingsTheme.shadowRadius, x: SettingsTheme.shadowX, y: SettingsTheme.shadowY)
                                .frame(width: isLandscape ? SettingsLayoutConfig.panelHeight - SettingsTheme.padding * 2 : nil)
                                
                              //双屏
                                VStack(alignment: .leading, spacing: SettingsTheme.contentSpacing) {
                                    Text("双屏功能")
                                        .font(.headline)
                                        .foregroundColor(SettingsTheme.titleColor)
                                        .frame(maxWidth: .infinity, alignment: .center)

                                    HStack(spacing: 4) {
                                        ProLabel(text: "Pro")
                                        Text("（手势可切换）")
                                            .font(.subheadline)
                                            .foregroundColor(SettingsTheme.subtitleColor)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .center)

                                    VStack(alignment: .leading, spacing: 5) {
                                        LabeledHighlightRow(
                                            highlightText: "双击",
                                            description: Text("拍照 拍摄/退出"),
                                            proLabel: true,
                                            systemImage: "icon-bf-color-1"
                                        )
                                        LabeledHighlightRow(
                                            highlightText: "单击",
                                            description: Text("边灯 开启/关闭"),
                                            proLabel: true,
                                            systemImage: "icon-bf-color-1"
                                        )
                                        LabeledHighlightRow(
                                            highlightText: "长按",
                                            description: Text("分屏位置切换"),
                                            proLabel: true,
                                            systemImage: "icon-bf-color-1"
                                        )
                                        LabeledHighlightRow(
                                            highlightText: "下载分享",
                                            description: HStack(spacing: 4) {
                                                Text("图片 下载/分享")
                                            },
                                            proLabel: true
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
                                    
                                    HStack(spacing: 4) {
                                        ProLabel(text: "Pro")
                                        Text("（手势可切换）")
                                            .font(.subheadline)
                                            .foregroundColor(SettingsTheme.subtitleColor)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    
                                    VStack(alignment: .leading, spacing: 5) {
                                        LabeledHighlightRow(
                                            highlightText: "双击",
                                            description: HStack(spacing: 4) {
                                                Text("拍照 拍摄/退出")
                                            },
                                            freeLabel: true
                                        )
                                        LabeledHighlightRow(
                                            highlightText: "闪光",
                                            description: HStack(spacing: 4) {
                                                Text("拍照时闪光")
                                            },
                                            proLabel: true
                                        )
                                        LabeledHighlightRow(
                                            highlightText: "单击",
                                            description: HStack(spacing: 4) {
                                                Text("边灯 开启/关闭")
                                            },
                                            freeLabel: true
                                        )
                                        LabeledHighlightRow(
                                            highlightText: "双指",
                                            description: HStack(spacing: 4) {
                                                Text("缩放画面")
                                            },
                                            proLabel: true
                                        )
                                        // LabeledHighlightRow(
                                        //     highlightText: "单指",
                                        //     description: HStack(spacing: 4) {
                                        //         Text("移动图片位置")
                                        //     },
                                        //     proLabel: true
                                        // )
                                        LabeledHighlightRow(
                                            highlightText: "长按",
                                            description: HStack(spacing: 4) {
                                                Text("照明灯功能")
                                            },
                                            proLabel: true,
                                            systemImage: "sun.max.fill"
                                        )
                                        LabeledHighlightRow(
                                            highlightText: "长按",
                                            description: Text("图片上传"),
                                            proLabel: true,
                                            systemImage: "square.and.arrow.up"
                                        )
                                        LabeledHighlightRow(
                                            highlightText: "长按",
                                            description: HStack(spacing: 4) {
                                                Text("图片下载")
                                            },
                                            proLabel: true,
                                            systemImage: "square.and.arrow.down"
                                        )

                                    }
                                    .font(.body)
                                }
                                .padding(SettingsTheme.padding)
                                .background(SettingsTheme.backgroundColor2)
                                .cornerRadius(12)
                                .shadow(color: SettingsTheme.shadowColor, radius: SettingsTheme.shadowRadius, x: SettingsTheme.shadowX, y: SettingsTheme.shadowY)
                                .frame(width: isLandscape ? SettingsLayoutConfig.panelHeight - SettingsTheme.padding * 2 : nil)
                            }
                        }

                        // 版本信息
                        VStack(spacing: SettingsTheme.buttonSpacing) {
                            Text("Mira")
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