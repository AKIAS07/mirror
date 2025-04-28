import SwiftUI

public struct ReferenceGridView: View {
    let gridSpacing: CGFloat // 网格间距
    let lineWidth: CGFloat = 0.5  // 线条宽度
    let lineColor: Color // 线条颜色
    let lineOpacity: Double // 线条透明度
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 计算中心点
                let centerX = geometry.size.width / 2
                let centerY = geometry.size.height / 2
                
                // 计算需要的网格线数量
                let horizontalLinesCount = Int(geometry.size.height / gridSpacing) + 1
                let verticalLinesCount = Int(geometry.size.width / gridSpacing) + 1
                
                // 绘制水平线（从中心向两边）
                ForEach(-horizontalLinesCount...horizontalLinesCount, id: \.self) { i in
                    let y = centerY + CGFloat(i) * gridSpacing
                    if y >= 0 && y <= geometry.size.height {
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                        }
                        .stroke(lineColor, lineWidth: i == 0 ? lineWidth * 2 : lineWidth)
                        .opacity(i == 0 ? lineOpacity * 1.5 : lineOpacity)
                    }
                }
                
                // 绘制垂直线（从中心向两边）
                ForEach(-verticalLinesCount...verticalLinesCount, id: \.self) { i in
                    let x = centerX + CGFloat(i) * gridSpacing
                    if x >= 0 && x <= geometry.size.width {
                        Path { path in
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                        }
                        .stroke(lineColor, lineWidth: i == 0 ? lineWidth * 2 : lineWidth)
                        .opacity(i == 0 ? lineOpacity * 1.5 : lineOpacity)
                    }
                }
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
    
    public init(gridSpacing: CGFloat = 50, lineColor: Color = .white, lineOpacity: Double = 0.3) {
        self.gridSpacing = gridSpacing
        self.lineColor = lineColor
        self.lineOpacity = lineOpacity
    }
}

#Preview {
    ReferenceGridView()
} 