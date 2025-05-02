import SwiftUI
import UIKit

// 形状绘制工具类
struct DrawingShapeRenderer {
    
    // MARK: - SwiftUI Canvas 渲染
    static func renderShape(
        _ type: ShapeType,
        in rect: CGRect,
        context: GraphicsContext,
        settings: BrushSettings,
        scaleFactors: (x: CGFloat, y: CGFloat) = (x: 1.0, y: 1.0)
    ) {
        var path = Path()
        
        switch type {
        case .rectangle:
            path = Path(rect)
            
        case .circle:
            // 对于圆形，我们需要考虑非均匀缩放
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radiusX = rect.width / 2 * scaleFactors.x
            let radiusY = rect.height / 2 * scaleFactors.y
            path = Path { path in
                path.addEllipse(in: CGRect(
                    x: center.x - radiusX,
                    y: center.y - radiusY,
                    width: radiusX * 2,
                    height: radiusY * 2
                ))
            }
            
        case .heart:
            // 心形需要根据缩放因子调整控制点
            let width = rect.width
            let height = rect.height
            path = Path { path in
                path.move(to: CGPoint(x: rect.midX, y: rect.minY + height * 0.25))
                
                // 左上曲线
                path.addCurve(
                    to: CGPoint(x: rect.minX, y: rect.minY + height * 0.25),
                    control1: CGPoint(x: rect.midX - width * 0.2 * scaleFactors.x, y: rect.minY),
                    control2: CGPoint(x: rect.minX, y: rect.minY + height * 0.05 * scaleFactors.y)
                )
                
                // 左下曲线
                path.addCurve(
                    to: CGPoint(x: rect.midX, y: rect.maxY),
                    control1: CGPoint(x: rect.minX, y: rect.minY + height * 0.6 * scaleFactors.y),
                    control2: CGPoint(x: rect.midX - width * 0.2 * scaleFactors.x, y: rect.maxY - height * 0.2 * scaleFactors.y)
                )
                
                // 右下曲线
                path.addCurve(
                    to: CGPoint(x: rect.maxX, y: rect.minY + height * 0.25),
                    control1: CGPoint(x: rect.midX + width * 0.2 * scaleFactors.x, y: rect.maxY - height * 0.2 * scaleFactors.y),
                    control2: CGPoint(x: rect.maxX, y: rect.minY + height * 0.6 * scaleFactors.y)
                )
                
                // 右上曲线
                path.addCurve(
                    to: CGPoint(x: rect.midX, y: rect.minY + height * 0.25),
                    control1: CGPoint(x: rect.maxX, y: rect.minY + height * 0.05 * scaleFactors.y),
                    control2: CGPoint(x: rect.midX + width * 0.2 * scaleFactors.x, y: rect.minY)
                )
            }
            
        case .cross:
            // 加号需要考虑非均匀缩放
            let strokeWidth = min(rect.width, rect.height) * 0.2
            path = Path { path in
                // 水平线
                path.move(to: CGPoint(x: rect.minX, y: rect.midY - strokeWidth/2))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY - strokeWidth/2))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY + strokeWidth/2))
                path.addLine(to: CGPoint(x: rect.minX, y: rect.midY + strokeWidth/2))
                path.closeSubpath()
                
                // 垂直线
                path.move(to: CGPoint(x: rect.midX - strokeWidth/2, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.midX + strokeWidth/2, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.midX + strokeWidth/2, y: rect.maxY))
                path.addLine(to: CGPoint(x: rect.midX - strokeWidth/2, y: rect.maxY))
                path.closeSubpath()
            }
            
        case .star:
            // 星形需要根据缩放因子调整点的位置
            let centerX = rect.midX
            let centerY = rect.midY
            let radiusX = rect.width * 0.4  // 使用宽度作为水平半径
            let radiusY = rect.height * 0.4  // 使用高度作为垂直半径
            let innerRadiusX = radiusX * 0.4  // 内部点的水平半径
            let innerRadiusY = radiusY * 0.4  // 内部点的垂直半径
            
            path = Path { path in
                for i in 0..<4 {
                    let angle = Double(i) * .pi / 2
                    let nextAngle = angle + .pi / 4
                    
                    // 计算外部点的位置（使用椭圆方程）
                    let outerX = centerX + cos(angle) * radiusX
                    let outerY = centerY + sin(angle) * radiusY
                    
                    // 计算内部点的位置（使用椭圆方程）
                    let innerX = centerX + cos(nextAngle) * innerRadiusX
                    let innerY = centerY + sin(nextAngle) * innerRadiusY
                    
                    if i == 0 {
                        path.move(to: CGPoint(x: outerX, y: outerY))
                    } else {
                        path.addLine(to: CGPoint(x: outerX, y: outerY))
                    }
                    path.addLine(to: CGPoint(x: innerX, y: innerY))
                }
                path.closeSubpath()
            }
        }
        
        // 应用颜色和填充
        if settings.shapeDrawingMode == .fill {
            context.fill(path, with: .color(settings.color.opacity(settings.opacity)))
        } else {
            context.stroke(path, with: .color(settings.color.opacity(settings.opacity)), lineWidth: settings.lineWidth)
        }
    }
    
    // MARK: - UIKit Context 渲染
    static func drawShape(_ shape: ShapeType, in rect: CGRect, with settings: BrushSettings, in context: CGContext) {
        let uiColor = UIColor(settings.color)
        let colorWithAlpha = uiColor.withAlphaComponent(settings.opacity)
        
        switch shape {
        case .rectangle:
            let path = UIBezierPath(rect: rect)
            path.lineWidth = settings.lineWidth
            
            if settings.shapeDrawingMode == .fill {
                colorWithAlpha.setFill()
                path.fill()
            } else {
                colorWithAlpha.setStroke()
                path.stroke()
            }
            
        case .circle:
            let path = UIBezierPath(ovalIn: rect)
            path.lineWidth = settings.lineWidth
            
            if settings.shapeDrawingMode == .fill {
                colorWithAlpha.setFill()
                path.fill()
            } else {
                colorWithAlpha.setStroke()
                path.stroke()
            }
            
        case .heart:
            let path = UIBezierPath()
            let width = rect.width
            let height = rect.height
            
            // 移动到顶部中点
            path.move(to: CGPoint(x: rect.midX, y: rect.minY + height * 0.25))
            
            // 左上曲线
            path.addCurve(
                to: CGPoint(x: rect.minX, y: rect.minY + height * 0.25),
                controlPoint1: CGPoint(x: rect.midX - width * 0.2, y: rect.minY),
                controlPoint2: CGPoint(x: rect.minX, y: rect.minY + height * 0.05)
            )
            
            // 左下曲线
            path.addCurve(
                to: CGPoint(x: rect.midX, y: rect.maxY),
                controlPoint1: CGPoint(x: rect.minX, y: rect.minY + height * 0.6),
                controlPoint2: CGPoint(x: rect.midX - width * 0.2, y: rect.maxY - height * 0.2)
            )
            
            // 右下曲线
            path.addCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY + height * 0.25),
                controlPoint1: CGPoint(x: rect.midX + width * 0.2, y: rect.maxY - height * 0.2),
                controlPoint2: CGPoint(x: rect.maxX, y: rect.minY + height * 0.6)
            )
            
            // 右上曲线
            path.addCurve(
                to: CGPoint(x: rect.midX, y: rect.minY + height * 0.25),
                controlPoint1: CGPoint(x: rect.maxX, y: rect.minY + height * 0.05),
                controlPoint2: CGPoint(x: rect.midX + width * 0.2, y: rect.minY)
            )
            
            path.close()
            path.lineWidth = settings.lineWidth
            
            if settings.shapeDrawingMode == .fill {
                colorWithAlpha.setFill()
                path.fill()
            } else {
                colorWithAlpha.setStroke()
                path.stroke()
            }
            
        case .cross:
            let path = UIBezierPath()
            let strokeWidth = min(rect.width, rect.height) * 0.2
            
            // 水平线
            path.move(to: CGPoint(x: rect.minX, y: rect.midY - strokeWidth/2))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY - strokeWidth/2))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY + strokeWidth/2))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.midY + strokeWidth/2))
            path.close()
            
            // 垂直线
            path.move(to: CGPoint(x: rect.midX - strokeWidth/2, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX + strokeWidth/2, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX + strokeWidth/2, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.midX - strokeWidth/2, y: rect.maxY))
            path.close()
            
            path.lineWidth = settings.lineWidth
            
            if settings.shapeDrawingMode == .fill {
                colorWithAlpha.setFill()
                path.fill()
            } else {
                colorWithAlpha.setStroke()
                path.stroke()
            }
            
        case .star:
            let path = UIBezierPath()
            let centerX = rect.midX
            let centerY = rect.midY
            let radiusX = rect.width * 0.4  // 使用宽度作为水平半径
            let radiusY = rect.height * 0.4  // 使用高度作为垂直半径
            let innerRadiusX = radiusX * 0.4  // 内部点的水平半径
            let innerRadiusY = radiusY * 0.4  // 内部点的垂直半径
            
            for i in 0..<4 {
                let angle = Double(i) * .pi / 2
                let nextAngle = angle + .pi / 4
                
                // 计算外部点的位置
                let outerX = centerX + cos(angle) * radiusX
                let outerY = centerY + sin(angle) * radiusY
                
                // 计算内部点的位置
                let innerX = centerX + cos(nextAngle) * innerRadiusX
                let innerY = centerY + sin(nextAngle) * innerRadiusY
                
                if i == 0 {
                    path.move(to: CGPoint(x: outerX, y: outerY))
                } else {
                    path.addLine(to: CGPoint(x: outerX, y: outerY))
                }
                path.addLine(to: CGPoint(x: innerX, y: innerY))
            }
            path.close()
            
            path.lineWidth = settings.lineWidth
            
            if settings.shapeDrawingMode == .fill {
                colorWithAlpha.setFill()
                path.fill()
            } else {
                colorWithAlpha.setStroke()
                path.stroke()
            }
        }
    }
    
    // MARK: - 图像渲染
    static func renderDrawingToImage(lines: [Line], size: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // 设置透明背景
            UIColor.clear.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // 按顺序处理每一条线
            for line in lines {
                if line.settings.isEraser {
                    // 橡皮擦模式
                    context.cgContext.setBlendMode(.clear)
                    let path = UIBezierPath()
                    guard let firstPoint = line.points.first else { continue }
                    path.move(to: firstPoint)
                    
                    if line.points.count > 2 {
                        for i in 0..<line.points.count - 1 {
                            let current = line.points[i]
                            let next = line.points[i + 1]
                            let mid = CGPoint(
                                x: (current.x + next.x) / 2,
                                y: (current.y + next.y) / 2
                            )
                            
                            if i == 0 {
                                path.move(to: current)
                            }
                            
                            path.addQuadCurve(to: mid, controlPoint: current)
                            
                            if i == line.points.count - 2 {
                                path.addLine(to: next)
                            }
                        }
                    } else {
                        for point in line.points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    
                    UIColor.white.setStroke()
                    path.lineWidth = line.settings.lineWidth
                    path.lineCapStyle = .round
                    path.lineJoinStyle = .round
                    path.stroke()
                    
                    // 恢复正常绘制模式
                    context.cgContext.setBlendMode(.normal)
                } else {
                    // 非橡皮擦内容
                    if !line.isShape {
                        // 绘制普通线条
                        let path = UIBezierPath()
                        guard let firstPoint = line.points.first else { continue }
                        path.move(to: firstPoint)
                        
                        if line.points.count > 2 {
                            for i in 0..<line.points.count - 1 {
                                let current = line.points[i]
                                let next = line.points[i + 1]
                                let mid = CGPoint(
                                    x: (current.x + next.x) / 2,
                                    y: (current.y + next.y) / 2
                                )
                                
                                if i == 0 {
                                    path.move(to: current)
                                }
                                
                                path.addQuadCurve(to: mid, controlPoint: current)
                                
                                if i == line.points.count - 2 {
                                    path.addLine(to: next)
                                }
                            }
                        } else {
                            for point in line.points.dropFirst() {
                                path.addLine(to: point)
                            }
                        }
                        
                        let uiColor = UIColor(line.settings.color)
                        uiColor.withAlphaComponent(line.settings.opacity).setStroke()
                        path.lineWidth = line.settings.lineWidth
                        path.lineCapStyle = .round
                        path.lineJoinStyle = .round
                        path.stroke()
                    } else if let rect = line.boundingRect {
                        // 绘制形状
                        context.cgContext.saveGState()
                        
                        // 计算变换后的矩形
                        let transformedRect = rect.applying(CGAffineTransform.identity
                            .translatedBy(x: line.position.x, y: line.position.y)
                            .scaledBy(x: line.scale, y: line.scale))
                        
                        // 使用 UIKit 渲染器绘制形状
                        drawShape(
                            line.settings.shapeType,
                            in: transformedRect,
                            with: line.settings,
                            in: context.cgContext
                        )
                        
                        context.cgContext.restoreGState()
                    }
                }
            }
        }
    }
} 