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
        case .text(let text):
            TextRenderer.renderText(text, in: rect, with: settings, context: context, alignment: settings.textAlignment, scaleFactors: scaleFactors)
            return
            
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
    static func drawShape(_ shape: ShapeType, in rect: CGRect, with settings: BrushSettings, in context: CGContext, scaleFactors: (x: CGFloat, y: CGFloat) = (x: 1.0, y: 1.0)) {
        let uiColor = UIColor(settings.color)
        let colorWithAlpha = uiColor.withAlphaComponent(settings.opacity)
        
        switch shape {
        case .text(let text):
            TextRenderer.drawText(text, in: rect, with: settings, in: context, alignment: settings.textAlignment, scaleFactors: scaleFactors)
            return
            
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
} 