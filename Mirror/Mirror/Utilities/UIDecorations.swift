import SwiftUI

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