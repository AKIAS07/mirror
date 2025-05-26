import SwiftUI

public struct ReferenceGridView: View {
    let gridSpacing: CGFloat // 网格间距
    let lineWidth: CGFloat = 0.5  // 线条宽度
    let lineColor: Color // 线条颜色
    let lineOpacity: Double // 线条透明度
    @State private var cachedGrid: UIImage? // 缓存的网格图片
    @State private var lastParameters: (spacing: CGFloat, color: Color, opacity: Double)? // 上次的参数
    
    // 添加静态方法用于生成网格图片
    public static func generateGrid(
        size: CGSize,
        spacing: CGFloat = 50,
        color: Color = .white,
        opacity: Double = 0.3,
        lineWidth: CGFloat = 0.5
    ) -> UIImage {
        print("------------------------")
        print("[网格生成] 开始")
        print("请求尺寸：\(size.width) x \(size.height)")
        print("网格间距：\(spacing)")
        
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            // 设置透明背景
            UIColor.clear.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            let centerX = size.width / 2
            let centerY = size.height / 2
            
            // 计算需要的网格线数量（向上取整以确保覆盖整个屏幕）
            let horizontalLinesCount = Int(ceil(size.height / spacing))
            let verticalLinesCount = Int(ceil(size.width / spacing))
            
            print("[网格生成] 计算结果")
            print("水平线数量：\(horizontalLinesCount * 2)")
            print("垂直线数量：\(verticalLinesCount * 2)")
            
            // 获取UIColor
            let uiColor = UIColor(color)
            
            // 设置绘制上下文
            let context = context.cgContext
            context.setLineCap(.butt)
            context.setAllowsAntialiasing(true)
            context.setShouldAntialias(true)
            
            // 绘制水平线（从中心向两边）
            for i in -horizontalLinesCount...horizontalLinesCount {
                let y = centerY + CGFloat(i) * spacing
                if y >= 0 && y <= size.height {
                    context.setLineWidth(i == 0 ? lineWidth * 2 : lineWidth)
                    context.setStrokeColor(uiColor.withAlphaComponent(i == 0 ? opacity * 1.5 : opacity).cgColor)
                    context.move(to: CGPoint(x: 0, y: y))
                    context.addLine(to: CGPoint(x: size.width, y: y))
                    context.strokePath()
                }
            }
            
            // 绘制垂直线（从中心向两边）
            for i in -verticalLinesCount...verticalLinesCount {
                let x = centerX + CGFloat(i) * spacing
                if x >= 0 && x <= size.width {
                    context.setLineWidth(i == 0 ? lineWidth * 2 : lineWidth)
                    context.setStrokeColor(uiColor.withAlphaComponent(i == 0 ? opacity * 1.5 : opacity).cgColor)
                    context.move(to: CGPoint(x: x, y: 0))
                    context.addLine(to: CGPoint(x: x, y: size.height))
                    context.strokePath()
                }
            }
        }
        
        print("[网格生成] 完成")
        print("生成图片尺寸：\(image.size.width) x \(image.size.height)")
        print("------------------------")
        
        return image
    }
    
    public var body: some View {
        GeometryReader { geometry in
            if let cachedImage = cachedGrid {
                Image(uiImage: cachedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .allowsHitTesting(false)  // 添加点击穿透
                    .onAppear {
                        print("------------------------")
                        print("[网格视图] 显示缓存图片")
                        print("视图尺寸：\(geometry.size.width) x \(geometry.size.height)")
                        print("图片尺寸：\(cachedImage.size.width) x \(cachedImage.size.height)")
                        print("网格参数：")
                        print("- 间距：\(gridSpacing)")
                        print("- 颜色：\(lineColor)")
                        print("- 透明度：\(lineOpacity)")
                        print("------------------------")
                    }
            } else {
                Color.clear
                    .onAppear {
                        print("------------------------")
                        print("[网格视图] 首次生成")
                        print("视图尺寸：\(geometry.size.width) x \(geometry.size.height)")
                        print("网格参数：")
                        print("- 间距：\(gridSpacing)")
                        print("- 颜色：\(lineColor)")
                        print("- 透明度：\(lineOpacity)")
                        print("------------------------")
                        updateGridImage(size: geometry.size)
                    }
            }
        }
        .onChange(of: gridSpacing) { _ in
            print("[网格视图] 间距变化，清除缓存")
            cachedGrid = nil
        }
        .onChange(of: lineColor) { _ in
            print("[网格视图] 颜色变化，清除缓存")
            cachedGrid = nil
        }
        .onChange(of: lineOpacity) { _ in
            print("[网格视图] 透明度变化，清除缓存")
            cachedGrid = nil
        }
        .edgesIgnoringSafeArea(.all)
    }
    
    private func updateGridImage(size: CGSize) {
        let currentParameters = (gridSpacing, lineColor, lineOpacity)
        
        // 检查参数是否变化
        if lastParameters?.0 != currentParameters.0 ||
           lastParameters?.1 != currentParameters.1 ||
           lastParameters?.2 != currentParameters.2 ||
           cachedGrid == nil {
            print("[网格视图] 参数变化或缓存为空，重新生成网格")
            cachedGrid = generateGridImage(size: size)
            lastParameters = currentParameters
        }
    }
    
    private func generateGridImage(size: CGSize) -> UIImage {
        print("[网格视图] 生成网格图片")
        print("请求尺寸：\(size.width) x \(size.height)")
        return ReferenceGridView.generateGrid(
            size: size,
            spacing: gridSpacing,
            color: lineColor,
            opacity: lineOpacity,
            lineWidth: lineWidth
        )
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