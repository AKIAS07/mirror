import SwiftUI

struct DrawingDisplayView: View {
    @Binding var lines: [Line]
    let currentLine: Line?
    let isPinned: Bool
    let pinnedImage: UIImage?
    let gestureState: DrawingGestureState
    
    // 添加控制点和边框样式常量
    private let controlPointSize: CGFloat = 24  // 增大控制点大小
    private let controlPointHitArea: CGFloat = 44  // 增大控制点触控区域
    private let normalBorderWidth: CGFloat = 2
    private let highlightBorderWidth: CGFloat = 4
    private let normalBorderColor: Color = .blue
    private let highlightBorderColor: Color = .green
    
    // 检查是否处于拉伸相关状态
    private func isResizingState(_ gestureState: DrawingGestureState) -> Bool {
        switch gestureState {
        case .resizing:
            return true
        case .prepareResizing:
            return false  // 准备状态下保持蓝色
        default:
            return false
        }
    }
    
    // 形状变换处理
    func processShapeTransform(_ line: Line) -> (rect: CGRect, transform: CGAffineTransform, scale: (x: CGFloat, y: CGFloat)) {
        let rect = line.boundingRect ?? .zero
        var transform = CGAffineTransform.identity
        var scaleFactors = (x: CGFloat(1.0), y: CGFloat(1.0))  // 默认缩放因子
        
        // 只有未确认的形状才应用手势变换
        if !line.isConfirmed {
            switch gestureState {
            case .dragging(let translation):
                // 更新位置
                transform = transform.translatedBy(x: line.position.x + translation.x, y: line.position.y + translation.y)
                transform = transform.scaledBy(x: line.scale, y: line.scale)
                
            case .scaling(let scale):
                // 计算形状的中心点（在世界坐标系中）
                let worldCenterX = rect.midX * line.scale + line.position.x
                let worldCenterY = rect.midY * line.scale + line.position.y
                
                // 计算新的缩放值和位置
                let newScale = line.scale * scale
                let newPositionX = worldCenterX - (rect.midX * newScale)
                let newPositionY = worldCenterY - (rect.midY * newScale)
                
                transform = transform.translatedBy(x: newPositionX, y: newPositionY)
                transform = transform.scaledBy(x: newScale, y: newScale)
                
            case .resizing(let edge, let translation):
                let newScale = line.scale
                var newRect = rect
                var newPosition = line.position
                
                // 保存原始中心点
                let originalCenterX = rect.midX * line.scale + line.position.x
                let originalCenterY = rect.midY * line.scale + line.position.y
                
                // 计算拉伸后的宽高比例
                var widthScale = CGFloat(1.0)
                var heightScale = CGFloat(1.0)
                
                switch edge {
                case .top:
                    let heightChange = -translation.y / line.scale
                    newRect = CGRect(x: rect.minX, y: rect.minY - heightChange,
                                   width: rect.width, height: rect.height + heightChange)
                    heightScale = newRect.height / rect.height
                case .bottom:
                    let heightChange = translation.y / line.scale
                    newRect = CGRect(x: rect.minX, y: rect.minY,
                                   width: rect.width, height: rect.height + heightChange)
                    heightScale = newRect.height / rect.height
                case .left:
                    let widthChange = -translation.x / line.scale
                    newRect = CGRect(x: rect.minX - widthChange, y: rect.minY,
                                   width: rect.width + widthChange, height: rect.height)
                    widthScale = newRect.width / rect.width
                case .right:
                    let widthChange = translation.x / line.scale
                    newRect = CGRect(x: rect.minX, y: rect.minY,
                                   width: rect.width + widthChange, height: rect.height)
                    widthScale = newRect.width / rect.width
                }
                
                // 更新缩放因子
                scaleFactors = (x: widthScale, y: heightScale)
                
                // 计算新的中心点
                let newCenterX = newRect.midX * newScale
                let newCenterY = newRect.midY * newScale
                
                // 调整位置以保持中心点不变
                newPosition.x = originalCenterX - newCenterX
                newPosition.y = originalCenterY - newCenterY
                
                transform = transform.translatedBy(x: newPosition.x, y: newPosition.y)
                transform = transform.scaledBy(x: newScale, y: newScale)
                
                // 返回新的矩形和变换
                return (newRect, transform, scaleFactors)
                
            case .tapping, .none, .invalidSize, .prepareResizing:
                transform = transform.translatedBy(x: line.position.x, y: line.position.y)
                transform = transform.scaledBy(x: line.scale, y: line.scale)
            }
        } else {
            // 已确认的形状只使用其保存的位置和缩放
            transform = transform.translatedBy(x: line.position.x, y: line.position.y)
            transform = transform.scaledBy(x: line.scale, y: line.scale)
        }
        
        return (rect, transform, scaleFactors)
    }
    
    var body: some View {
        GeometryReader { geometry in
            if !isPinned {
                Canvas { context, size in
                    // 绘制已完成的线条
                    for line in lines {
                        if !line.isShape {
                            drawNormalLine(line, in: context)
                        } else {
                            let (rect, transform, scaleFactors) = processShapeTransform(line)
                            let transformedRect = rect.applying(transform)
                            
                            // 绘制形状，传入缩放因子
                            DrawingShapeRenderer.renderShape(
                                line.settings.shapeType,
                                in: transformedRect,
                                context: context,
                                settings: line.settings,
                                scaleFactors: scaleFactors
                            )
                            
                            // 如果形状未确认，绘制编辑控件
                            if !line.isConfirmed {
                                drawShapeControls(transformedRect, in: context)
                            }
                        }
                    }
                    
                    // 绘制当前线条
                    if let currentLine = currentLine {
                        if !currentLine.isShape {
                            drawNormalLine(currentLine, in: context)
                        } else if let rect = currentLine.boundingRect {
                            let (_, transform, scaleFactors) = processShapeTransform(currentLine)
                            let transformedRect = rect.applying(transform)
                            DrawingShapeRenderer.renderShape(
                                currentLine.settings.shapeType,
                                in: transformedRect,
                                context: context,
                                settings: currentLine.settings,
                                scaleFactors: scaleFactors
                            )
                            drawShapeControls(transformedRect, in: context)
                        }
                    }
                }
            }
            
            // 固定的图片层
            if isPinned, let image = pinnedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .allowsHitTesting(false)
            }
        }
    }
    
    private func drawNormalLine(_ line: Line, in context: GraphicsContext) {
        print("开始绘制线条 - 是否为橡皮擦: \(line.settings.isEraser)")
        var path = Path()
        guard let firstPoint = line.points.first else { 
            print("警告：线条没有点")
            return 
        }
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
                
                path.addQuadCurve(to: mid, control: current)
                
                if i == line.points.count - 2 {
                    path.addLine(to: next)
                }
            }
        } else {
            for point in line.points.dropFirst() {
                path.addLine(to: point)
            }
        }
        
        if line.settings.isEraser {
            print("应用橡皮擦效果 - 线宽: \(line.settings.lineWidth)")
            context.withCGContext { cgContext in
                cgContext.setBlendMode(.clear)
                let uiPath = UIBezierPath()
                uiPath.move(to: line.points[0])
                
                if line.points.count > 2 {
                    for i in 0..<line.points.count - 1 {
                        let current = line.points[i]
                        let next = line.points[i + 1]
                        let mid = CGPoint(
                            x: (current.x + next.x) / 2,
                            y: (current.y + next.y) / 2
                        )
                        
                        uiPath.addQuadCurve(to: mid, controlPoint: current)
                        
                        if i == line.points.count - 2 {
                            uiPath.addLine(to: next)
                        }
                    }
                } else {
                    for point in line.points.dropFirst() {
                        uiPath.addLine(to: point)
                    }
                }
                
                cgContext.setLineCap(.round)
                cgContext.setLineJoin(.round)
                cgContext.setLineWidth(line.settings.lineWidth)
                cgContext.addPath(uiPath.cgPath)
                cgContext.strokePath()
            }
            print("橡皮擦效果已应用")
        } else {
            context.stroke(path, with: .color(line.settings.color.opacity(line.settings.opacity)), style: StrokeStyle(
                lineWidth: line.settings.lineWidth,
                lineCap: .round,
                lineJoin: .round
            ))
        }
    }
    
    private func drawShapeControls(_ rect: CGRect, in context: GraphicsContext) {
        // 确定当前边框样式
        let borderWidth = isResizingState(gestureState) ? highlightBorderWidth : normalBorderWidth
        let borderColor = isResizingState(gestureState) ? highlightBorderColor : normalBorderColor
        
        // 绘制边框
        let borderPath = Path(rect)
        context.stroke(borderPath, with: .color(borderColor), lineWidth: borderWidth)
        
        // 绘制四个拉伸控制点
        // 上中控制点
        let topControlRect = CGRect(
            x: rect.midX - controlPointSize/2,
            y: rect.minY - controlPointSize/2,
            width: controlPointSize,
            height: controlPointSize
        )
        context.fill(Path(ellipseIn: topControlRect), with: .color(borderColor))
        
        // 下中控制点
        let bottomControlRect = CGRect(
            x: rect.midX - controlPointSize/2,
            y: rect.maxY - controlPointSize/2,
            width: controlPointSize,
            height: controlPointSize
        )
        context.fill(Path(ellipseIn: bottomControlRect), with: .color(borderColor))
        
        // 左中控制点
        let leftControlRect = CGRect(
            x: rect.minX - controlPointSize/2,
            y: rect.midY - controlPointSize/2,
            width: controlPointSize,
            height: controlPointSize
        )
        context.fill(Path(ellipseIn: leftControlRect), with: .color(borderColor))
        
        // 右中控制点
        let rightControlRect = CGRect(
            x: rect.maxX - controlPointSize/2,
            y: rect.midY - controlPointSize/2,
            width: controlPointSize,
            height: controlPointSize
        )
        context.fill(Path(ellipseIn: rightControlRect), with: .color(borderColor))
        
        // 绘制确认按钮
        let buttonRect = ConfirmButtonHelper.getButtonRect(for: rect)
        let buttonPath = Path(ellipseIn: buttonRect)
        context.fill(buttonPath, with: .color(.green))
        
        // 绘制勾号
        let buttonSize = ConfirmButtonHelper.buttonSize
        let checkmarkPath = Path { path in
            path.move(to: CGPoint(
                x: buttonRect.minX + buttonSize * 0.25,
                y: buttonRect.midY
            ))
            path.addLine(to: CGPoint(
                x: buttonRect.minX + buttonSize * 0.45,
                y: buttonRect.midY + buttonSize * 0.2
            ))
            path.addLine(to: CGPoint(
                x: buttonRect.minX + buttonSize * 0.75,
                y: buttonRect.midY - buttonSize * 0.2
            ))
        }
        context.stroke(checkmarkPath, with: .color(.white), lineWidth: 2)
    }
} 