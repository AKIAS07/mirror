import SwiftUI

struct YellowMaskView: View {
    let screenWidth: CGFloat
    let screenHeight: CGFloat
    let overflowAmount: CGFloat = 50 // 边框溢出量
    
    var body: some View {
        GeometryReader { geometry in
            // 创建一个包含溢出区域的黄色遮罩
            Path { path in
                // 外部矩形（包含溢出区域）
                let outerRect = CGRect(
                    x: -overflowAmount,
                    y: -overflowAmount,
                    width: screenWidth + (overflowAmount * 2),
                    height: screenHeight + (overflowAmount * 2)
                )
                path.addRect(outerRect)
                
                // 内部镂空矩形（设备屏幕大小）
                let innerRect = CGRect(
                    x: 0,
                    y: 0,
                    width: screenWidth,
                    height: screenHeight
                )
                path.addRect(innerRect)
            }
            .fill(style: FillStyle(eoFill: true)) // 使用 even-odd 规则创建镂空效果
            .foregroundColor(.black)
        }
        .allowsHitTesting(false) // 确保遮罩不会影响触摸事件
    }
} 