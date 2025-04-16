import SwiftUI
import Combine

// 添加 Color 转换扩展
extension Color {
    var uiColor: UIColor {
        UIColor(self)
    }
}

// 闪光动画视图
struct FlashAnimationView: View {
    @State private var isVisible = false
    @ObservedObject private var styleManager = BorderLightStyleManager.shared
    var frame: CGRect? = nil
    
    var body: some View {
        if AppConfig.AnimationConfig.Flash.isEnabled {
            Rectangle()
                .fill(styleManager.selectedColor)
                .opacity(isVisible ? AppConfig.AnimationConfig.Flash.intensity.rawValue : 0) // 使用配置的强度
                .if(frame != nil) { view in
                    view.frame(width: frame!.width, height: frame!.height)
                        .position(x: frame!.midX, y: frame!.midY)
                }
                .if(frame == nil) { view in
                    view.frame(maxWidth: .infinity, maxHeight: .infinity)
                        .edgesIgnoringSafeArea(.all)
                }
                .onAppear {
                    withAnimation(.easeIn(duration: AppConfig.AnimationConfig.Flash.fadeInDuration)) {
                        isVisible = true
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + AppConfig.AnimationConfig.Flash.displayDuration) {
                        withAnimation(.easeOut(duration: AppConfig.AnimationConfig.Flash.fadeOutDuration)) {
                            isVisible = false
                        }
                    }
                }
        }
    }
}

// 矩形图片管理器
class RectangleImageManager: ObservableObject {
    static let shared = RectangleImageManager()
    @Published private(set) var originalImage: UIImage?  // Original 屏幕的图片
    @Published private(set) var mirroredImage: UIImage?  // Mirrored 屏幕的图片
    private let imageSize = CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height / 2)  // 修改为屏幕尺寸
    @ObservedObject private var styleManager = BorderLightStyleManager.shared
    
    private init() {
        print("------------------------")
        print("[矩形图片管理器] 初始化")
        print("------------------------")
        updateRectangleImages()
        
        // 监听边框灯颜色变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBorderColorChange),
            name: NSNotification.Name("BorderColorDidChange"),
            object: nil
        )
        
        // 添加对selectedColor的监听
        styleManager.objectWillChange.sink { [weak self] _ in
            self?.updateRectangleImages()
        }.store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    @objc private func handleBorderColorChange() {
        print("------------------------")
        print("[矩形图片管理器] 颜色变化")
        print("------------------------")
        updateRectangleImages()
    }
    
    private func updateRectangleImages() {
        print("------------------------")
        print("[矩形图片管理器] 开始更新图片")
        print("尺寸: \(imageSize.width)x\(imageSize.height)")
        print("颜色: \(styleManager.selectedColor)")
        
        let renderer = UIGraphicsImageRenderer(size: imageSize)
        let newImage = renderer.image { context in
            // 获取当前边框灯颜色
            let color = styleManager.selectedColor
            color.uiColor.setFill()
            
            // 创建一个矩形路径
            let rectangle = CGRect(x: 0, y: 0, width: imageSize.width, height: imageSize.height)
            context.fill(rectangle)
        }
        
        // 为两个屏幕创建独立的图片实例
        originalImage = newImage.copy() as? UIImage
        mirroredImage = newImage.copy() as? UIImage
        
        print("图片更新完成")
        print("------------------------")
    }
    
    // 根据屏幕ID获取对应的图片
    func getImage(for screenID: ScreenID) -> UIImage? {
        print("------------------------")
        print("[矩形图片管理器] 获取图片")
        print("区域：\(screenID == .original ? "Original" : "Mirrored")屏幕")
        let image = screenID == .original ? originalImage : mirroredImage
        print("结果：\(image != nil ? "成功" : "失败")")
        print("------------------------")
        return image
    }
}

// 四角动画视图
struct SquareCornerAnimationView: View {
    let screenWidth = UIScreen.main.bounds.width
    let screenHeight = UIScreen.main.bounds.height
    
    // 定义触控区1的尺寸和位置
    private let touchZoneWidth: CGFloat = 150
    private let touchZoneHeight: CGFloat = 560
    private let cornerLength: CGFloat = 40  // L形标记的长度
    private let lineWidth: CGFloat = 5      // 线条宽度
    private let padding: CGFloat = 75       // 与触控区的间距
    
    var body: some View {
        ZStack {
            // 计算屏幕中心位置
            let centerX = screenWidth/2
            let centerY = screenHeight/2
            
            // 计算四个角的位置（固定在屏幕中心）
            let left = centerX - touchZoneWidth/2 - padding
            let right = centerX + touchZoneWidth/2 + padding
            let top = centerY - touchZoneHeight/2 - padding
            let bottom = centerY + touchZoneHeight/2 + padding
            
            // 四角L形动画
            Group {
                // 左上角
                Path { path in
                    path.move(to: CGPoint(x: left, y: top + cornerLength))
                    path.addLine(to: CGPoint(x: left, y: top))
                    path.addLine(to: CGPoint(x: left + cornerLength, y: top))
                }
                .stroke(Color.white.opacity(0.5), lineWidth: lineWidth)
                
                // 右上角
                Path { path in
                    path.move(to: CGPoint(x: right - cornerLength, y: top))
                    path.addLine(to: CGPoint(x: right, y: top))
                    path.addLine(to: CGPoint(x: right, y: top + cornerLength))
                }
                .stroke(Color.white.opacity(0.5), lineWidth: lineWidth)
                
                // 左下角
                Path { path in
                    path.move(to: CGPoint(x: left, y: bottom - cornerLength))
                    path.addLine(to: CGPoint(x: left, y: bottom))
                    path.addLine(to: CGPoint(x: left + cornerLength, y: bottom))
                }
                .stroke(Color.white.opacity(0.5), lineWidth: lineWidth)
                
                // 右下角
                Path { path in
                    path.move(to: CGPoint(x: right - cornerLength, y: bottom))
                    path.addLine(to: CGPoint(x: right, y: bottom))
                    path.addLine(to: CGPoint(x: right, y: bottom - cornerLength))
                }
                .stroke(Color.white.opacity(0.5), lineWidth: lineWidth)
            }
        }
    }
}

// 修改缩放提示动画视图
struct ScaleIndicatorView: View {
    let scale: CGFloat
    let deviceOrientation: UIDeviceOrientation
    let isMinScale: Bool
    @State private var opacity: Double = 0
    
    private var scaleText: String {
        // 如果是最小比例，显示小屏模式
        if isMinScale {
            return "小屏模式"
        }
        
        // 如果是 100%，显示全屏模式
        if abs(scale - 1.0) < 0.01 {
            return "全屏模式"
        }
        
        let scalePercentage = Int(scale * 100)
        
        // 在最大缩放比例时显示固定值
        if scale >= 10.0 {
            return "1000%"
        }
        
        // 其他情况将百分比舍入到最接近的50的倍数
        let roundedPercentage = Int(round(Double(scalePercentage) / 50.0) * 50)
        return "\(roundedPercentage)%"
    }
    
    private func getRotationAngle(_ orientation: UIDeviceOrientation) -> Angle {
        switch orientation {
        case .landscapeLeft:
            return .degrees(90)
        case .landscapeRight:
            return .degrees(-90)
        case .portraitUpsideDown:
            return .degrees(180)
        default:
            return .degrees(0)
        }
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // 当比例为 100% 时显示"全屏模式"
            if abs(scale - 1.0) < 0.01 {
                Text("100%")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
            }
            Text(scaleText)
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.black.opacity(0.2))
        )
        .rotationEffect(getRotationAngle(deviceOrientation))
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.2)) {
                opacity = 1
            }
        }
        .onChange(of: scale) { newScale in
            withAnimation(.interpolatingSpring(stiffness: 300, damping: 15)) {
                opacity = 1
            }
        }
    }
}