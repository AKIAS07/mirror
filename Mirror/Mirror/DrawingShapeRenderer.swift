import SwiftUI
import UIKit

// 形状绘制工具类
struct DrawingShapeRenderer {
    
    // MARK: - SwiftUI Canvas 渲染
    static func renderShape(_ shape: ShapeType, in rect: CGRect, context: GraphicsContext, settings: BrushSettings) {
        let color = settings.color.opacity(settings.opacity)
        let lineWidth = settings.lineWidth
        
        switch shape {
        case .rectangle:
            let path = Path(rect)
            if settings.shapeDrawingMode == .fill {
                context.fill(path, with: .color(color))
            } else {
                context.stroke(path, with: .color(color), lineWidth: lineWidth)
            }
            
        case .circle:
            let diameter = min(rect.width, rect.height)
            let circleRect = CGRect(x: rect.midX - diameter/2, y: rect.midY - diameter/2, width: diameter, height: diameter)
            let path = Path(ellipseIn: circleRect)
            if settings.shapeDrawingMode == .fill {
                context.fill(path, with: .color(color))
            } else {
                context.stroke(path, with: .color(color), lineWidth: lineWidth)
            }
            
        case .heart:
            var path = Path()
            let width = rect.width
            let height = rect.height
            
            let scale = min(width, height) / 32
            let centerX = rect.midX
            let centerY = rect.midY
            
            var first = true
            for i in stride(from: 0, through: Double.pi * 2, by: 0.01) {
                let x = 16 * pow(sin(i), 3)
                let y = 13 * cos(i) - 5 * cos(2 * i) - 2 * cos(3 * i) - cos(4 * i)
                
                let point = CGPoint(
                    x: centerX + x * scale,
                    y: centerY - y * scale
                )
                
                if first {
                    path.move(to: point)
                    first = false
                } else {
                    path.addLine(to: point)
                }
            }
            path.closeSubpath()
            
            if settings.shapeDrawingMode == .fill {
                context.fill(path, with: .color(color))
            } else {
                context.stroke(path, with: .color(color), lineWidth: lineWidth)
            }
            
        case .cross:
            var path = Path()
            let centerX = rect.midX
            let centerY = rect.midY
            let armLength = min(rect.width, rect.height) * 0.4
            
            path.move(to: CGPoint(x: centerX, y: centerY - armLength))
            path.addLine(to: CGPoint(x: centerX, y: centerY + armLength))
            path.move(to: CGPoint(x: centerX - armLength, y: centerY))
            path.addLine(to: CGPoint(x: centerX + armLength, y: centerY))
            
            context.stroke(path, with: .color(color), lineWidth: lineWidth)
            
        case .star:
            var path = Path()
            let centerX = rect.midX
            let centerY = rect.midY
            let radius = min(rect.width, rect.height) * 0.4
            let innerRadius = radius * 0.4
            
            for i in 0..<4 {
                let angle = Double(i) * .pi / 2
                let nextAngle = angle + .pi / 4
                
                let outerX = centerX + cos(angle) * radius
                let outerY = centerY + sin(angle) * radius
                
                let innerX = centerX + cos(nextAngle) * innerRadius
                let innerY = centerY + sin(nextAngle) * innerRadius
                
                if i == 0 {
                    path.move(to: CGPoint(x: outerX, y: outerY))
                } else {
                    path.addLine(to: CGPoint(x: outerX, y: outerY))
                }
                path.addLine(to: CGPoint(x: innerX, y: innerY))
            }
            path.closeSubpath()
            
            if settings.shapeDrawingMode == .fill {
                context.fill(path, with: .color(color))
            } else {
                context.stroke(path, with: .color(color), lineWidth: lineWidth)
            }
            
        case .none:
            break
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
            let diameter = min(rect.width, rect.height)
            let circleRect = CGRect(x: rect.midX - diameter/2, y: rect.midY - diameter/2, width: diameter, height: diameter)
            let path = UIBezierPath(ovalIn: circleRect)
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
            
            let scale = min(width, height) / 32
            let centerX = rect.midX
            let centerY = rect.midY
            
            var first = true
            for i in stride(from: 0, through: Double.pi * 2, by: 0.01) {
                let x = 16 * pow(sin(i), 3)
                let y = 13 * cos(i) - 5 * cos(2 * i) - 2 * cos(3 * i) - cos(4 * i)
                
                let point = CGPoint(
                    x: centerX + x * scale,
                    y: centerY - y * scale
                )
                
                if first {
                    path.move(to: point)
                    first = false
                } else {
                    path.addLine(to: point)
                }
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
            
        case .cross:
            let path = UIBezierPath()
            let centerX = rect.midX
            let centerY = rect.midY
            let armLength = min(rect.width, rect.height) * 0.4
            
            path.move(to: CGPoint(x: centerX, y: centerY - armLength))
            path.addLine(to: CGPoint(x: centerX, y: centerY + armLength))
            path.move(to: CGPoint(x: centerX - armLength, y: centerY))
            path.addLine(to: CGPoint(x: centerX + armLength, y: centerY))
            
            path.lineWidth = settings.lineWidth
            colorWithAlpha.setStroke()
            path.stroke()
            
        case .star:
            let path = UIBezierPath()
            let centerX = rect.midX
            let centerY = rect.midY
            let radius = min(rect.width, rect.height) * 0.4
            let innerRadius = radius * 0.4
            
            for i in 0..<4 {
                let angle = Double(i) * .pi / 2
                let nextAngle = angle + .pi / 4
                
                let outerX = centerX + cos(angle) * radius
                let outerY = centerY + sin(angle) * radius
                
                let innerX = centerX + cos(nextAngle) * innerRadius
                let innerY = centerY + sin(nextAngle) * innerRadius
                
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
            
        case .none:
            break
        }
    }
    
    // MARK: - 图像渲染
    static func renderDrawingToImage(lines: [Line], size: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let tempRenderer = UIGraphicsImageRenderer(size: size)
            let baseImage = tempRenderer.image { tempContext in
                UIColor.clear.setFill()
                tempContext.fill(CGRect(origin: .zero, size: size))
                
                // 首先绘制所有非橡皮擦的线条和形状
                for line in lines where !line.settings.isEraser {
                    if line.shape == ShapeType.none {
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
                        drawShape(line.shape, in: rect, with: line.settings, in: tempContext.cgContext)
                    }
                }
            }
            
            baseImage.draw(at: .zero)
            
            // 应用橡皮擦效果
            context.cgContext.setBlendMode(.clear)
            for line in lines where line.settings.isEraser {
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
            }
            context.cgContext.setBlendMode(.normal)
        }
    }
} 