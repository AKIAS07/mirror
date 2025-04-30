import SwiftUI
import UIKit

// 预设颜色选择器视图
struct ColorPickerView: View {
    @Binding var selectedColor: Color
    @Binding var isExpanded: Bool
    let position: CGPoint
    
    // 预设颜色数组
    private let colors: [Color] = [
        Color(red: 255/255, green: 255/255, blue: 255/255),  //颜色1
        Color(red: 104/255, green: 109/255, blue: 203/255),  //颜色2
        Color(red: 58/255, green: 187/255, blue: 201/255),   //颜色3
        Color(red: 155/255, green: 202/255, blue: 62/255),   //颜色4
        Color(red: 254/255, green: 235/255, blue: 81/255),   //颜色5
        Color(red: 237/255, green: 83/255, blue: 20/255),   //颜色6
        Color(red: 207/255, green: 3/255, blue: 92/255),    //颜色7
    ]
    
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 4) {
                // 关闭按钮
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation {
                            isExpanded = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 16))
                    }
                    .padding(4)
                }
                
                HStack(spacing: 8) {
                    ForEach(colors, id: \.self) { color in
                        Button(action: {
                            selectedColor = color
                            withAnimation {
                                isExpanded = false
                            }
                        }) {
                            Circle()
                                .fill(color)
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: selectedColor == color ? 2 : 0)
                                )
                                .scaleEffect(selectedColor == color ? 1.2 : 1.0)
                        }
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedColor)
                    }
                    
                    // 添加自定义颜色选择器
                    ColorPicker("", selection: $selectedColor)
                        .labelsHidden()
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 1)
                        )
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity)
            }
            .frame(width: 300)
            .background(Color.black.opacity(0.7))
            .cornerRadius(8)
            .position(x: geometry.size.width/2, y: geometry.size.height/2 - 300)
        }
    }
}

// 形状类型枚举
enum ShapeType {
    case none
    case rectangle
    case circle
    case heart
    case cross
    case star
}

// 形状绘制模式
enum ShapeDrawingMode {
    case stroke
    case fill
}

// 形状选择器视图
struct ShapePickerView: View {
    @Binding var selectedShape: ShapeType
    @Binding var selectedMode: ShapeDrawingMode
    @Binding var isExpanded: Bool
    let position: CGPoint
    
    private let shapes: [(ShapeType, String)] = [
        (.rectangle, "rectangle"),
        (.circle, "circle"),
        (.heart, "heart"),
        (.cross, "plus"),
        (.star, "star")
    ]
    
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 4) {
                // 关闭按钮
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation {
                            isExpanded = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 16))
                    }
                    .padding(4)
                }
                
                // 形状选择
                HStack(spacing: 16) {
                    ForEach(shapes, id: \.0) { shape in
                        Button(action: {
                            selectedShape = shape.0
                            withAnimation {
                                isExpanded = false
                            }
                        }) {
                            Image(systemName: shape.1)
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(selectedShape == shape.0 ? Color.white.opacity(0.3) : Color.clear)
                                .cornerRadius(8)
                                .scaleEffect(selectedShape == shape.0 ? 1.2 : 1.0)
                        }
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedShape)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
                .frame(maxWidth: .infinity)
                
                // 绘制模式选择
                HStack(spacing: 16) {
                    Button(action: {
                        selectedMode = .stroke
                        withAnimation {
                            isExpanded = false
                        }
                    }) {
                        Image(systemName: "rectangle.on.rectangle")
                            .font(.system(size: 20))
                            .foregroundColor(selectedMode == .stroke ? .blue : .white)
                            .frame(width: 32, height: 32)
                            .background(selectedMode == .stroke ? Color.white.opacity(0.3) : Color.clear)
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        selectedMode = .fill
                        withAnimation {
                            isExpanded = false
                        }
                    }) {
                        Image(systemName: "rectangle.fill.on.rectangle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(selectedMode == .fill ? .blue : .white)
                            .frame(width: 32, height: 32)
                            .background(selectedMode == .fill ? Color.white.opacity(0.3) : Color.clear)
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity)
            }
            .frame(width: 280)
            .background(Color.black.opacity(0.7))
            .cornerRadius(8)
            .position(x: geometry.size.width/2, y: geometry.size.height/2 - 300)
        }
    }
}

// 画笔设置结构体
struct BrushSettings {
    var color: Color = .white
    var lineWidth: CGFloat = 10
    var opacity: Double = 0.5
    var isEraser: Bool = false
    var shapeType: ShapeType = .heart  // 修改默认形状为爱心
    var shapeDrawingMode: ShapeDrawingMode = .fill  // 修改默认模式为填充
}

// 绘画线条结构体
struct Line {
    var points: [CGPoint]
    var settings: BrushSettings
    var shape: ShapeType = .none  // 添加形状类型
    var boundingRect: CGRect?  // 添加形状边界框
}

// 添加工具类型枚举
enum DrawingTool {
    case pencil
    case shape
    case eraser
}

// 绘画画布视图
@available(iOS 15.0, *)
struct DrawingCanvasView: View {
    @Binding var isVisible: Bool
    @Binding var isPinned: Bool
    @State private var lines: [Line] = []
    @State private var currentLine: Line?
    @State private var currentTool: DrawingTool = .pencil
    @State private var brushSettings = BrushSettings()
    @State private var showColorPicker = false
    @State private var showShapePicker = false
    @State private var undoManager: [Line] = []
    @State private var pinnedImage: UIImage? = nil
    @State private var showClearAlert = false
    
    // 工具栏位置
    @State private var toolbarOffset: CGFloat = 0
    
    // 添加用于存储按钮frame的属性
    @State private var colorButtonFrame: CGRect = .zero
    @State private var shapeButtonFrame: CGRect = .zero
    
    // 添加工具条显示状态
    @State private var showToolbar: Bool = true
    
    // 添加缩放状态
    @State private var isScaling = false
    
    // 添加长按直线相关状态
    @State private var isLongPressing = false
    @State private var longPressStartPoint: CGPoint?
    @State private var showStraightLine = false
    @State private var straightLinePreview: Line?
    
    // 添加新的状态变量
    @State private var shouldHideToolbar: Bool = false  // 仅控制工具栏的显示/隐藏
    
    // 初始化时设置画笔状态
    init(isVisible: Binding<Bool>, isPinned: Binding<Bool>) {
        self._isVisible = isVisible
        self._isPinned = isPinned
        
        // 初始化画笔设置
        var initialSettings = BrushSettings()
        initialSettings.shapeType = .none  // 确保初始状态为画笔模式
        self._brushSettings = State(initialValue: initialSettings)
    }
    
    // 获取形状按钮的图标
    private func getShapeButtonIcon() -> String {
        switch brushSettings.shapeType {
        case .none:
            return "square.on.circle"
        case .rectangle:
            return "rectangle"
        case .circle:
            return "circle"
        case .heart:
            return "heart"
        case .cross:
            return "plus"
        case .star:
            return "star"
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 绘画层
                if !isPinned {
                    Canvas { context, size in
                        // 绘制已完成的线条
                        for line in lines {
                            if line.shape == ShapeType.none {
                                var path = Path()
                                guard let firstPoint = line.points.first else { continue }
                                path.move(to: firstPoint)
                                
                                // 使用贝塞尔曲线平滑线条
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
                                    context.blendMode = .clear
                                    context.stroke(path, with: .color(.white), style: StrokeStyle(
                                        lineWidth: line.settings.lineWidth,
                                        lineCap: .round,
                                        lineJoin: .round
                                    ))
                                    context.blendMode = .normal
                                } else {
                                    context.stroke(path, with: .color(line.settings.color.opacity(line.settings.opacity)), style: StrokeStyle(
                                        lineWidth: line.settings.lineWidth,
                                        lineCap: .round,
                                        lineJoin: .round
                                    ))
                                }
                            } else if let rect = line.boundingRect {
                                DrawingShapeRenderer.renderShape(line.shape, in: rect, context: context, settings: line.settings)
                            }
                        }
                        
                        // 绘制当前线条或预览直线
                        if let currentLine = straightLinePreview ?? currentLine {
                            if currentLine.shape == ShapeType.none {
                                var path = Path()
                                guard let firstPoint = currentLine.points.first else { return }
                                
                                if isLongPressing {
                                    // 绘制直线预览
                                    guard let lastPoint = currentLine.points.last else { return }
                                    path.move(to: firstPoint)
                                    path.addLine(to: lastPoint)
                                } else {
                                    // 正常绘制当前线条
                                    path.move(to: firstPoint)
                                    
                                    if currentLine.points.count > 2 {
                                        for i in 0..<currentLine.points.count - 1 {
                                            let current = currentLine.points[i]
                                            let next = currentLine.points[i + 1]
                                            let mid = CGPoint(
                                                x: (current.x + next.x) / 2,
                                                y: (current.y + next.y) / 2
                                            )
                                            
                                            if i == 0 {
                                                path.move(to: current)
                                            }
                                            
                                            path.addQuadCurve(to: mid, control: current)
                                            
                                            if i == currentLine.points.count - 2 {
                                                path.addLine(to: next)
                                            }
                                        }
                                    } else {
                                        for point in currentLine.points.dropFirst() {
                                            path.addLine(to: point)
                                        }
                                    }
                                }
                                
                                if currentLine.settings.isEraser {
                                    context.blendMode = .clear
                                    context.stroke(path, with: .color(.white), style: StrokeStyle(
                                        lineWidth: currentLine.settings.lineWidth,
                                        lineCap: .round,
                                        lineJoin: .round
                                    ))
                                    context.blendMode = .normal
                                } else {
                                    // 为预览直线添加虚线效果
                                    let strokeStyle = StrokeStyle(
                                        lineWidth: currentLine.settings.lineWidth,
                                        lineCap: .round,
                                        lineJoin: .round,
                                        dash: isLongPressing ? [5, 5] : []
                                    )
                                    context.stroke(path, with: .color(currentLine.settings.color.opacity(currentLine.settings.opacity)), style: strokeStyle)
                                }
                            } else if let rect = currentLine.boundingRect {
                                DrawingShapeRenderer.renderShape(currentLine.shape, in: rect, context: context, settings: currentLine.settings)
                            }
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                // 如果正在进行缩放，则不进行绘画
                                if isScaling {
                                    return
                                }
                                
                                let point = value.location
                                
                                // 处理长按直线绘制
                                if isLongPressing {
                                    // 更新预览直线
                                    if let startPoint = longPressStartPoint {
                                        straightLinePreview = Line(
                                            points: [startPoint, point],
                                            settings: brushSettings
                                        )
                                    }
                                    return
                                }
                                
                                // 正常绘画逻辑
                                if currentLine == nil {
                                    var line = Line(points: [point], settings: brushSettings)
                                    line.shape = brushSettings.shapeType
                                    if brushSettings.shapeType == ShapeType.none {
                                        currentLine = line
                                        // 保存起始点，用于检测长按
                                        longPressStartPoint = point
                                    } else {
                                        line.boundingRect = CGRect(origin: point, size: .zero)
                                        currentLine = line
                                    }
                                } else {
                                    currentLine?.points.append(point)
                                    if currentLine?.shape != ShapeType.none {
                                        // 更新形状的边界框
                                        let startPoint = currentLine?.points.first ?? point
                                        let rect = CGRect(
                                            x: min(startPoint.x, point.x),
                                            y: min(startPoint.y, point.y),
                                            width: abs(point.x - startPoint.x),
                                            height: abs(point.y - startPoint.y)
                                        )
                                        currentLine?.boundingRect = rect
                                    }
                                }
                            }
                            .onEnded { _ in
                                // 处理长按直线绘制结束
                                if isLongPressing {
                                    if let line = straightLinePreview {
                                        lines.append(line)
                                        undoManager.removeAll()
                                    }
                                    isLongPressing = false
                                    straightLinePreview = nil
                                    longPressStartPoint = nil
                                    return
                                }
                                
                                // 正常绘画结束逻辑
                                if let line = currentLine {
                                    lines.append(line)
                                    undoManager.removeAll()
                                    currentLine = nil
                                    longPressStartPoint = nil
                                }
                            }
                    )
                    .simultaneousGesture(
                        MagnificationGesture()
                            .onChanged { _ in
                                isScaling = true
                            }
                            .onEnded { _ in
                                isScaling = false
                            }
                    )
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.5)
                            .onEnded { _ in
                                if let _ = longPressStartPoint {
                                    isLongPressing = true
                                    // 清除当前的自由绘制线条
                                    currentLine = nil
                                }
                            }
                    )
                }
                
                // 固定的图片层
                if isPinned, let image = pinnedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .allowsHitTesting(false)
                }
                
                // UI层
                if isVisible && showToolbar && !shouldHideToolbar {
                    VStack {
                        if !isPinned {
                            VStack(spacing: 15) {
                                // 第一行：基本工具
                                HStack(spacing: 12) {
                                    // 画笔按钮
                                    Button(action: {
                                        handleButtonTap(.pencil)
                                    }) {
                                        Image(systemName: "pencil.tip.crop.circle")
                                            .font(.system(size: 24))
                                            .foregroundColor(currentTool == .pencil ? brushSettings.color : .white)
                                            .opacity(currentTool == .pencil ? 1 : 0.5)
                                    }
                                    
                                    // 形状按钮
                                    Button(action: {
                                        handleButtonTap(.shape)
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            showShapePicker.toggle()
                                            if showShapePicker {
                                                showColorPicker = false
                                            }
                                        }
                                    }) {
                                        Image(systemName: getShapeButtonIcon())
                                            .font(.system(size: 24))
                                            .foregroundColor(currentTool == .shape ? brushSettings.color : .white)
                                            .opacity(currentTool == .shape ? 1 : 0.5)
                                    }
                                    .background(
                                        GeometryReader { geo -> Color in
                                            DispatchQueue.main.async {
                                                shapeButtonFrame = geo.frame(in: .global)
                                            }
                                            return Color.clear
                                        }
                                    )
                                    
                                    // 橡皮擦按钮
                                    Button(action: {
                                        handleButtonTap(.eraser)
                                    }) {
                                        Image(systemName: "eraser")
                                            .font(.system(size: 24))
                                            .foregroundColor(currentTool == .eraser ? .white : .white.opacity(0.5))
                                    }
                                    
                                    // 撤销按钮
                                    Button(action: {
                                        if let lastLine = lines.last {
                                            undoManager.append(lastLine)
                                            lines.removeLast()
                                        }
                                    }) {
                                        Image(systemName: "arrow.uturn.backward.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.white)
                                    }
                                    .disabled(lines.isEmpty)
                                    .opacity(lines.isEmpty ? 0.5 : 1)
                                    
                                    // 重做按钮
                                    Button(action: {
                                        if let lastUndo = undoManager.last {
                                            lines.append(lastUndo)
                                            undoManager.removeLast()
                                        }
                                    }) {
                                        Image(systemName: "arrow.uturn.forward.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.white)
                                    }
                                    .disabled(undoManager.isEmpty)
                                    .opacity(undoManager.isEmpty ? 0.5 : 1)
                                    
                                    // 修改清空按钮，添加确认弹窗
                                    Button(action: {
                                        showClearAlert = true
                                    }) {
                                        Image(systemName: "trash.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.white)
                                    }
                                    .disabled(lines.isEmpty)
                                    .opacity(lines.isEmpty ? 0.5 : 1)
                                    .alert("确认清空", isPresented: $showClearAlert) {
                                        Button("取消", role: .cancel) { }
                                        Button("确定", role: .destructive) {
                                            undoManager = lines
                                            lines.removeAll()
                                        }
                                    } message: {
                                        Text("确定要清空画布吗？此操作无法撤销。")
                                    }
                                    
                                    Spacer()
                                    
                                    // Pin按钮
                                    Button(action: {
                                        if let image = DrawingShapeRenderer.renderDrawingToImage(lines: lines, size: geometry.size) {
                                            withAnimation {
                                                pinnedImage = image
                                                isPinned = true
                                            }
                                        }
                                    }) {
                                        Image(systemName: "pin.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.white)
                                    }
                                    .disabled(lines.isEmpty)
                                    .opacity(lines.isEmpty ? 0.5 : 1)
                                    
                                    // 关闭按钮
                                    Button(action: {
                                        withAnimation {
                                            isVisible = false
                                            lines.removeAll()
                                            currentLine = nil
                                            pinnedImage = nil
                                            isPinned = false
                                            // 添加显示工具条的通知
                                            NotificationCenter.default.post(name: NSNotification.Name("ShowToolbars"), object: nil)
                                        }
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.white)
                                    }
                                }
                                .frame(maxWidth: .infinity) // 让HStack占满宽度
                                
                                // 第二行：工具属性设置
                                if currentTool != .eraser {
                                    // 画笔和形状的属性设置
                                    HStack(spacing: 20) {
                                        // 线条粗细滑块
                                        HStack {
                                            Image(systemName: "line.horizontal.3")
                                                .foregroundColor(.white)
                                            Slider(value: $brushSettings.lineWidth, in: 1...20)
                                                .frame(width: 100)
                                        }
                                        
                                        // 透明度滑块
                                        HStack {
                                            Image(systemName: "circle.bottomhalf.filled")
                                                .foregroundColor(.white)
                                            Slider(value: $brushSettings.opacity, in: 0.1...1)
                                                .frame(width: 100)
                                        }
                                        
                                        // 颜色选择按钮
                                        Button(action: {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                showColorPicker.toggle()
                                                if showColorPicker {
                                                    showShapePicker = false
                                                }
                                            }
                                        }) {
                                            Circle()
                                                .fill(brushSettings.color)
                                                .frame(width: 30, height: 30)
                                                .overlay(
                                                    Circle()
                                                        .stroke(Color.white, lineWidth: 2)
                                                )
                                        }
                                        .background(
                                            GeometryReader { geo -> Color in
                                                DispatchQueue.main.async {
                                                    colorButtonFrame = geo.frame(in: .global)
                                                }
                                                return Color.clear
                                            }
                                        )
                                    }
                                    .frame(maxWidth: .infinity) // 让HStack占满宽度
                                } else {
                                    // 橡皮擦粗细设置
                                    HStack {
                                        Image(systemName: "circle.dotted")
                                            .foregroundColor(.white)
                                        Slider(value: $brushSettings.lineWidth, in: 1...40)
                                            .frame(width: 200)
                                    }
                                    .frame(maxWidth: .infinity) // 让HStack占满宽度
                                }
                            }
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(15)
                            .padding(.top, 40)
                            .frame(maxWidth: geometry.size.width - 80) // 减小宽度，从40改为80
                            .frame(width: geometry.size.width, alignment: .center)
                            
                            // 颜色选择器和形状选择器
                            Group {
                                if showColorPicker {
                                    ColorPickerView(
                                        selectedColor: $brushSettings.color,
                                        isExpanded: $showColorPicker,
                                        position: .zero // 位置由GeometryReader处理
                                    )
                                    .transition(.opacity)
                                }
                                
                                if showShapePicker {
                                    ShapePickerView(
                                        selectedShape: $brushSettings.shapeType,
                                        selectedMode: $brushSettings.shapeDrawingMode,
                                        isExpanded: $showShapePicker,
                                        position: .zero // 位置由GeometryReader处理
                                    )
                                    .transition(.opacity)
                                }
                            }
                        } else {
                            // 固定模式下的关闭按钮
                            HStack {
                                Spacer()
                                Button(action: {
                                    withAnimation {
                                        isVisible = false
                                        isPinned = false
                                        pinnedImage = nil
                                        // 恢复工具条显示
                                        NotificationCenter.default.post(name: NSNotification.Name("ShowToolbars"), object: nil)
                                    }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                }
                                .padding()
                            }
                            .padding(.top, 40)
                        }
                        
                        Spacer()
                    }
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            // 当绘画视图出现时，隐藏工具条
            NotificationCenter.default.post(name: NSNotification.Name("HideToolbars"), object: nil)
            
            // 添加通知监听器
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("HideToolbars"),
                object: nil,
                queue: .main
            ) { _ in
                withAnimation {
                    shouldHideToolbar = true  // 只隐藏工具栏，不影响整个视图
                }
            }
            
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ShowToolbars"),
                object: nil,
                queue: .main
            ) { _ in
                withAnimation {
                    shouldHideToolbar = false  // 只显示工具栏，不影响整个视图
                }
            }
            
            showToolbar = true
        }
        .onChange(of: isPinned) { newValue in
            if newValue {
                NotificationCenter.default.post(name: NSNotification.Name("ShowToolbars"), object: nil)
            } else {
                NotificationCenter.default.post(name: NSNotification.Name("HideToolbars"), object: nil)
            }
        }
    }
    
    private func handleButtonTap(_ buttonType: DrawingTool) {
        switch buttonType {
        case .pencil:
            currentTool = .pencil
            brushSettings.isEraser = false
            brushSettings.shapeType = .none  // 切换到画笔时清除形状
        case .shape:
            currentTool = .shape
            brushSettings.isEraser = false
        case .eraser:
            currentTool = .eraser
            brushSettings.isEraser = true
            brushSettings.shapeType = .none  // 切换到橡皮擦时清除形状
        }
    }
}

@available(iOS 15.0, *)
#Preview {
    DrawingCanvasView(isVisible: .constant(true), isPinned: .constant(false))
} 