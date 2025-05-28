import SwiftUI

public struct ReferenceGridView: View {
    let gridSpacing: CGFloat // 网格间距
    let lineWidth: CGFloat = 0.5  // 线条宽度
    let lineColor: Color // 线条颜色
    let lineOpacity: Double // 线条透明度
    @State private var gridImage: UIImage?
    
    public var body: some View {
        GeometryReader { geometry in
            if let image = gridImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .allowsHitTesting(false) // 允许点击事件穿透
            } else {
                Color.clear
                    .onAppear {
                        generateGridImage(size: geometry.size)
                    }
                    .onChange(of: geometry.size) { newSize in
                        generateGridImage(size: newSize)
                    }
            }
        }
        .onChange(of: gridSpacing) { _ in
            gridImage = nil // 触发重新生成
        }
        .onChange(of: lineColor) { _ in
            gridImage = nil
        }
        .onChange(of: lineOpacity) { _ in
            gridImage = nil
        }
        .edgesIgnoringSafeArea(.all)
    }
    
    private func generateGridImage(size: CGSize) {
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            let cgContext = context.cgContext
            
            // 设置线条颜色和透明度
            let uiColor = UIColor(lineColor)
            let components = uiColor.cgColor.components ?? [1, 1, 1, 1]
            cgContext.setStrokeColor(red: components[0], green: components[1], blue: components[2], alpha: components[3] * lineOpacity)
            cgContext.setLineWidth(lineWidth)
            
            // 计算中心点
            let centerX = size.width / 2
            let centerY = size.height / 2
            
            // 计算需要的网格线数量
            let horizontalLinesCount = Int(size.height / gridSpacing) + 1
            let verticalLinesCount = Int(size.width / gridSpacing) + 1
            
            // 绘制水平线（从中心向两边）
            for i in -horizontalLinesCount...horizontalLinesCount {
                let y = centerY + CGFloat(i) * gridSpacing
                if y >= 0 && y <= size.height {
                    cgContext.move(to: CGPoint(x: 0, y: y))
                    cgContext.addLine(to: CGPoint(x: size.width, y: y))
                    
                    // 中心线加粗
                    if i == 0 {
                        cgContext.setLineWidth(lineWidth * 2)
                        cgContext.strokePath()
                        cgContext.setLineWidth(lineWidth)
                    } else {
                        cgContext.strokePath()
                    }
                }
            }
            
            // 绘制垂直线（从中心向两边）
            for i in -verticalLinesCount...verticalLinesCount {
                let x = centerX + CGFloat(i) * gridSpacing
                if x >= 0 && x <= size.width {
                    cgContext.move(to: CGPoint(x: x, y: 0))
                    cgContext.addLine(to: CGPoint(x: x, y: size.height))
                    
                    // 中心线加粗
                    if i == 0 {
                        cgContext.setLineWidth(lineWidth * 2)
                        cgContext.strokePath()
                        cgContext.setLineWidth(lineWidth)
                    } else {
                        cgContext.strokePath()
                    }
                }
            }
        }
        
        // 保存生成的图片
        if let pngData = image.pngData() {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let gridImageURL = documentsPath.appendingPathComponent("gridsource.png")
            
            do {
                try pngData.write(to: gridImageURL)
                print("网格图片已保存到: \(gridImageURL.path)")
            } catch {
                print("保存网格图片失败: \(error)")
            }
        }
        
        gridImage = image
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