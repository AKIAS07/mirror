import SwiftUI

// 闪光动画视图
struct FlashAnimationView: View {
    @State private var isVisible = false
    @ObservedObject private var styleManager = BorderLightStyleManager.shared
    var frame: CGRect? = nil  // 添加可选的 frame 参数
    
    var body: some View {
        Rectangle()
            .fill(styleManager.selectedColor)
            .opacity(isVisible ? 1 : 0)
            .if(frame != nil) { view in
                view.frame(width: frame!.width, height: frame!.height)
                    .position(x: frame!.midX, y: frame!.midY)
            }
            .if(frame == nil) { view in
                view.frame(maxWidth: .infinity, maxHeight: .infinity)
                    .edgesIgnoringSafeArea(.all)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isVisible = true
                }
                // 0.3秒后消失
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isVisible = false
                    }
                }
            }
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

// 缩放提示动画视图
struct ScaleIndicatorView: View {
    let scale: CGFloat
    @State private var opacity: Double = 0
    
    private var scaleText: String {
        let scalePercentage = Int(scale * 100)
        
        // 在最小和最大缩放比例时显示固定值
        if scale <= 1.0 {
            return "100%"
        } else if scale >= 10.0 {
            return "1000%"
        }
        
        // 其他情况将百分比舍入到最接近的50的倍数
        let roundedPercentage = Int(round(Double(scalePercentage) / 50.0) * 50)
        return "\(roundedPercentage)%"
    }
    
    var body: some View {
        Text(scaleText)
            .font(.system(size: 40, weight: .bold))
            .foregroundColor(.white)
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.black.opacity(0.2))
            )
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.2)) {
                    opacity = 1
                }
            }
    }
} 