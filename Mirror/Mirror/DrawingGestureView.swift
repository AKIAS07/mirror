import SwiftUI

// 定义手势状态
enum GestureState {
    case none
    case dragging(translation: CGPoint)
    case scaling(scale: CGFloat)
    case tapping(location: CGPoint)
    case invalidSize(String)
    case resizing(edge: ResizeEdge, translation: CGPoint)  // 使用DrawingTypes.swift中的ResizeEdge
}

struct DrawingGestureView: View {
    @Binding var lines: [Line]
    @Binding var currentLine: Line?
    @Binding var undoManager: [Line]
    let currentTool: DrawingTool
    let brushSettings: BrushSettings
    
    // 手势状态回调
    let onGestureStateChanged: (DrawingGestureState) -> Void
    
    // 状态变量
    @State private var isScaling = false
    @State private var isDragging = false
    @State private var magnificationScale: CGFloat = 1.0
    @State private var dragTranslation: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var lastTranslation: CGPoint = .zero
    
    // 添加直线绘制相关状态
    @State private var isDrawingLine = false
    @State private var lineStartPoint: CGPoint?
    @State private var longPressTimer: Timer?
    
    // 尺寸限制
    private let minSize: CGFloat = 30
    private let maxSize: CGFloat = 3000
    
    // 添加移动检测
    @State private var hasMoved: Bool = false
    
    // 添加拉伸控制点状态
    @State private var currentResizeEdge: ResizeEdge?
    
    // 添加长按相关状态
    @State private var resizeTimer: Timer?
    @State private var resizeTouchLocation: CGPoint?
    @State private var potentialResizeEdge: ResizeEdge?
    
    // 尺寸检查函数
    private func validateShapeSize(_ line: Line) -> Bool {
        switch ShapeSizeValidator.validateLine(line) {
        case .success:
            return true
        case .failure(let error):
            onGestureStateChanged(.invalidSize(error.rawValue))
            return false
        }
    }
    
    // 添加控制点检测函数
    private func detectResizeEdge(point: CGPoint, rect: CGRect) -> ResizeEdge? {
        let controlPointSize: CGFloat = 44  // 增大触控区域
        
        // 上中控制点
        let topControlRect = CGRect(
            x: rect.midX - controlPointSize/2,
            y: rect.minY - controlPointSize/2,
            width: controlPointSize,
            height: controlPointSize
        )
        if topControlRect.contains(point) {
            return .top
        }
        
        // 下中控制点
        let bottomControlRect = CGRect(
            x: rect.midX - controlPointSize/2,
            y: rect.maxY - controlPointSize/2,
            width: controlPointSize,
            height: controlPointSize
        )
        if bottomControlRect.contains(point) {
            return .bottom
        }
        
        // 左中控制点
        let leftControlRect = CGRect(
            x: rect.minX - controlPointSize/2,
            y: rect.midY - controlPointSize/2,
            width: controlPointSize,
            height: controlPointSize
        )
        if leftControlRect.contains(point) {
            return .left
        }
        
        // 右中控制点
        let rightControlRect = CGRect(
            x: rect.maxX - controlPointSize/2,
            y: rect.midY - controlPointSize/2,
            width: controlPointSize,
            height: controlPointSize
        )
        if rightControlRect.contains(point) {
            return .right
        }
        
        return nil
    }
    
    // 添加长按检测函数
    private func startResizeTimer(at location: CGPoint, edge: ResizeEdge) {
        stopResizeTimer()
        resizeTouchLocation = location
        potentialResizeEdge = edge
        
        // 立即通知准备状态
        onGestureStateChanged(.prepareResizing(edge: edge))
        
        resizeTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            if let edge = potentialResizeEdge {
                currentResizeEdge = edge
                isDragging = false
                lastTranslation = .zero
            }
        }
    }
    
    private func stopResizeTimer() {
        resizeTimer?.invalidate()
        resizeTimer = nil
        resizeTouchLocation = nil
        potentialResizeEdge = nil
        // 如果不是在拉伸状态，恢复到普通状态
        if currentResizeEdge == nil {
            onGestureStateChanged(.none)
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if isScaling { return }
                            
                            print("手势触发 - 当前工具: \(currentTool), 橡皮擦状态: \(brushSettings.isEraser)")  // 添加调试信息
                            
                            if currentTool == .pencil || currentTool == .eraser {  // 修改这里，让橡皮擦也能触发
                                if currentLine == nil {
                                    print("开始新线条 - 工具: \(currentTool), 橡皮擦: \(brushSettings.isEraser)")
                                    lineStartPoint = value.location
                                    hasMoved = false
                                    startLongPressTimer()
                                    handleNormalDrawing(at: value.location)
                                } else if !isDrawingLine {
                                    if let start = lineStartPoint {
                                        let distance = hypot(value.location.x - start.x, value.location.y - start.y)
                                        if distance > 5 {
                                            hasMoved = true
                                            stopLongPressTimer()
                                        }
                                    }
                                    handleNormalDrawing(at: value.location)
                                } else {
                                    if let start = lineStartPoint {
                                        var line = Line(points: [start, value.location], settings: brushSettings)
                                        line.isShape = false
                                        currentLine = line
                                    }
                                }
                            } else if currentTool == .shape {
                                if let lastLine = lines.last, lastLine.isShape && !lastLine.isConfirmed {
                                    if !isDragging && currentResizeEdge == nil {
                                        if let rect = lastLine.boundingRect {
                                            let transform = CGAffineTransform.identity
                                                .translatedBy(x: lastLine.position.x, y: lastLine.position.y)
                                                .scaledBy(x: lastLine.scale, y: lastLine.scale)
                                            let transformedRect = rect.applying(transform)
                                            
                                            if ConfirmButtonHelper.isPointInButton(point: value.location, shapeRect: transformedRect) {
                                                onGestureStateChanged(.tapping(location: value.location))
                                                stopResizeTimer()
                                                return
                                            }
                                            
                                            // 检测是否在控制点上
                                            if resizeTimer == nil && currentResizeEdge == nil {
                                                if let edge = detectResizeEdge(point: value.location, rect: transformedRect) {
                                                    // 开始长按检测
                                                    startResizeTimer(at: value.location, edge: edge)
                                                    return
                                                }
                                            }
                                            
                                            // 检查是否正在长按控制点
                                            if let touchLoc = resizeTouchLocation {
                                                let distance = hypot(value.location.x - touchLoc.x, value.location.y - touchLoc.y)
                                                if distance > 5 { // 如果移动超过5个点，取消长按
                                                    stopResizeTimer()
                                                }
                                            }
                                            
                                            // 如果不是在控制点上长按，开始拖动
                                            if currentResizeEdge == nil && resizeTimer == nil {
                                                isDragging = true
                                                lastTranslation = .zero
                                            }
                                        }
                                    }
                                    
                                    if let edge = currentResizeEdge {
                                        // 处理拉伸
                                        let currentTranslation = CGPoint(
                                            x: value.translation.width - lastTranslation.x,
                                            y: value.translation.height - lastTranslation.y
                                        )
                                        onGestureStateChanged(.resizing(edge: edge, translation: currentTranslation))
                                        lastTranslation = CGPoint(x: value.translation.width, y: value.translation.height)
                                    } else if isDragging {
                                        // 处理拖动
                                        let currentTranslation = CGPoint(
                                            x: value.translation.width - lastTranslation.x,
                                            y: value.translation.height - lastTranslation.y
                                        )
                                        onGestureStateChanged(.dragging(translation: currentTranslation))
                                        lastTranslation = CGPoint(x: value.translation.width, y: value.translation.height)
                                    }
                                } else {
                                    handleShapeDrawing(at: value.location)
                                }
                            }
                        }
                        .onEnded { value in
                            print("手势结束 - 当前工具: \(currentTool)")  // 添加调试信息
                            stopResizeTimer()
                            stopLongPressTimer()
                            hasMoved = false
                            
                            if currentTool == .pencil || currentTool == .eraser {  // 修改这里，让橡皮擦也能结束
                                if let line = currentLine {
                                    lines.append(line)
                                    undoManager.removeAll()
                                    print("线条已添加到画布 - 是否为橡皮擦: \(line.settings.isEraser)")
                                }
                                currentLine = nil
                                isDrawingLine = false
                                lineStartPoint = nil
                            } else if currentTool == .shape {
                                if isDragging || currentResizeEdge != nil {
                                    isDragging = false
                                    currentResizeEdge = nil
                                    lastTranslation = .zero
                                    onGestureStateChanged(.none)
                                } else {
                                    if let line = currentLine {
                                        if line.isShape {
                                            if validateShapeSize(line) {
                                                lines.append(line)
                                                undoManager.removeAll()
                                                onGestureStateChanged(.none)
                                            } else {
                                                if let rect = line.boundingRect {
                                                    if rect.width < ShapeSizeValidator.minSize || rect.height < ShapeSizeValidator.minSize {
                                                        onGestureStateChanged(.invalidSize("尺寸过小"))
                                                    } else {
                                                        onGestureStateChanged(.invalidSize("尺寸过大"))
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    currentLine = nil
                                }
                            }
                        }
                )
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { scale in
                            if currentTool == .shape {
                                if let lastLine = lines.last, lastLine.isShape && !lastLine.isConfirmed {
                                    if !isScaling {
                                        isScaling = true
                                        lastScale = 1.0
                                    }
                                    let currentScale = scale / lastScale
                                    onGestureStateChanged(.scaling(scale: currentScale))
                                    lastScale = scale
                                }
                            }
                        }
                        .onEnded { _ in
                            isScaling = false
                            lastScale = 1.0
                            onGestureStateChanged(.none)
                        }
                )
        }
    }
    
    private func startLongPressTimer() {
        stopLongPressTimer() // 确保先停止之前的计时器
        
        longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            if currentTool == .pencil && !hasMoved {  // 只在未移动时触发
                isDrawingLine = true
            }
        }
    }
    
    private func stopLongPressTimer() {
        longPressTimer?.invalidate()
        longPressTimer = nil
    }
    
    private func handleShapeDrawing(at location: CGPoint) {
        if currentLine == nil {
            var line = Line(points: [location], settings: brushSettings)
            line.isShape = true
            line.isEditable = true
            currentLine = line
            print("开始创建新形状 - 起始点: \(location)")
        } else {
            let startPoint = currentLine?.points.first ?? location
            let rect = CGRect(
                x: min(startPoint.x, location.x),
                y: min(startPoint.y, location.y),
                width: abs(location.x - startPoint.x),
                height: abs(location.y - startPoint.y)
            )
            
            ShapeSizeValidator.logShapeSize(rect)
            currentLine?.boundingRect = rect
            onGestureStateChanged(.none)
        }
    }
    
    private func handleNormalDrawing(at location: CGPoint) {
        if currentLine == nil {
            print("创建新线条 - 位置: \(location), 工具: \(currentTool), 橡皮擦: \(brushSettings.isEraser)")
            var settings = brushSettings
            if currentTool == .eraser {
                settings.isEraser = true  // 确保橡皮擦状态正确设置
            }
            currentLine = Line(points: [location], settings: settings)
        } else if !isDrawingLine {
            currentLine?.points.append(location)
            if brushSettings.isEraser {
                print("橡皮擦添加点: \(location)")
            }
        }
    }
} 