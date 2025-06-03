import SwiftUI
import UIKit
import Foundation

// 导入自定义类型
@_exported import Foundation

// 确保所有自定义类型都可见
typealias Template = DrawingTemplate
typealias TemplateManager = DrawingTemplateManager

// 文字输入弹窗视图
struct TextInputDialog: View {
    @Binding var isPresented: Bool
    @Binding var text: String
    let onConfirm: (String, CustomTextAlignment) -> Void
    @State private var selectedAlignment: CustomTextAlignment = .center
    
    // 添加懒加载的TextEditor
    private let textEditor: TextEditor
    
    init(isPresented: Binding<Bool>, text: Binding<String>, onConfirm: @escaping (String, CustomTextAlignment) -> Void) {
        self._isPresented = isPresented
        self._text = text
        self.onConfirm = onConfirm
        // 预初始化TextEditor
        self.textEditor = TextEditor(text: text)
    }
    
    var body: some View {
        VStack(spacing: 10) {
            Text("请输入文字")
                .font(.headline)
                .padding(.top, 8)
            
            // 使用预初始化的TextEditor
            textEditor
                .frame(height: 60)
                .frame(width: 180)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray, lineWidth: 1)
                )
                .padding(.horizontal, 8)
            
            // 对齐方式按钮组
            alignmentButtons
            
            // 操作按钮
            actionButtons
        }
        .padding(8)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 8)
    }
    
    // 抽取对齐方式按钮组为单独的视图
    private var alignmentButtons: some View {
        HStack(spacing: 15) {
            ForEach([CustomTextAlignment.left, .center, .right], id: \.self) { alignment in
                Button(action: { selectedAlignment = alignment }) {
                    Image(systemName: getAlignmentIcon(alignment))
                        .foregroundColor(selectedAlignment == alignment ? .blue : .gray)
                }
            }
        }
        .font(.system(size: 20))
        .padding(.vertical, 4)
    }
    
    // 抽取操作按钮为单独的视图
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button("取消") {
                isPresented = false
            }
            .foregroundColor(.red)
            .font(.system(size: 14))
            
            Spacer()
            
            Button("确认") {
                onConfirm(text, selectedAlignment)
                isPresented = false
            }
            .foregroundColor(.blue)
            .font(.system(size: 14))
        }
        .padding(.horizontal, 8)
    }
    
    // 获取对齐方式图标
    private func getAlignmentIcon(_ alignment: CustomTextAlignment) -> String {
        switch alignment {
        case .left: return "text.alignleft"
        case .center: return "text.aligncenter"
        case .right: return "text.alignright"
        }
    }
}

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

// 形状选择器视图
struct ShapePickerView: View {
    @Binding var selectedShape: ShapeType
    @Binding var selectedMode: ShapeDrawingMode
    @Binding var isExpanded: Bool
    let position: CGPoint
    let canSelectShape: Bool
    
    private let shapes: [(ShapeType, String)] = [
        (.rectangle, "rectangle.fill"),
        (.circle, "circle.fill"),
        (.heart, "heart.fill"),
        (.cross, "plus"),
        (.star, "icon-star")
    ]
    
    private func shapeButton(shape: (ShapeType, String)) -> some View {
        Button(action: {
            if canSelectShape {
                selectedShape = shape.0
                withAnimation {
                    isExpanded = false
                }
            }
        }) {
            Group {
                if shape.0 == .star {
                    Image("icon-star")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: shape.1)
                        .font(.system(size: 20))
                }
            }
            .foregroundColor(.white)
            .frame(width: 32, height: 32)
            .background(selectedShape == shape.0 ? Color.white.opacity(0.3) : Color.clear)
            .cornerRadius(8)
            .scaleEffect(selectedShape == shape.0 ? 1.2 : 1.0)
        }
        .disabled(!canSelectShape)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedShape)
    }
    
    private func modeButton(mode: ShapeDrawingMode) -> some View {
        Button(action: {
            if canSelectShape {
                selectedMode = mode
            }
        }) {
            Image(systemName: mode == .stroke ? "rectangle" : "rectangle.fill")
                .font(.system(size: 20))
                .foregroundColor(selectedMode == mode ? .blue : .white)
                .frame(width: 32, height: 32)
                .background(selectedMode == mode ? Color.white.opacity(0.3) : Color.clear)
                .cornerRadius(8)
        }
        .disabled(!canSelectShape)
    }
    
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
                        shapeButton(shape: shape)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
                .frame(maxWidth: .infinity)
                
                // 绘制模式选择
                HStack(spacing: 16) {
                    modeButton(mode: .stroke)
                    modeButton(mode: .fill)
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
    var shapeType: ShapeType = .rectangle
    var shapeDrawingMode: ShapeDrawingMode = .fill
    var textAlignment: CustomTextAlignment = CustomTextAlignment.center
}

// 绘画线条结构体
struct Line {
    var points: [CGPoint]
    var settings: BrushSettings
    var isShape: Bool = false  // 修改为使用布尔值来区分是否为形状
    var boundingRect: CGRect?  // 形状的边界框
    var isEditable: Bool = false  // 是否处于可编辑状态
    var isConfirmed: Bool = false  // 是否已确认（点击勾）
    var position: CGPoint = .zero  // 形状的位置
    var scale: CGFloat = 1.0  // 形状的缩放比例
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
    // 修改提示信息状态
    @State private var showSizeAlert = false
    @State private var sizeAlertMessage = ""
    
    // 添加文字输入相关状态
    @State private var showTextInput = false
    @State private var inputText = ""
    @State private var textInputPosition: CGPoint = .zero
    
    // 添加模板相关状态
    @State private var showTemplateView = false
    @State private var selectedTemplate: DrawingTemplate? = nil
    @State private var showSaveTemplateAlert = false
    @State private var showOverrideTemplateAlert = false
    @ObservedObject private var templateManager = DrawingTemplateManager.shared
    
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
    
    // 添加新的状态变量
    @State private var showExitAlert = false
    @State private var showDeleteAlert = false
    
    // 工具栏位置
    @State private var toolbarOffset: CGFloat = 0
    
    // 添加用于存储按钮frame的属性
    @State private var colorButtonFrame: CGRect = .zero
    @State private var shapeButtonFrame: CGRect = .zero
    
    // 添加工具条显示状态
    @State private var showToolbar: Bool = true
    
    // 添加新的状态变量
    @State private var shouldHideToolbar: Bool = false
    @State private var currentGestureState: DrawingGestureState = .none
    
    // 修改提示信息状态管理
    @State private var alertTimer: Timer?
    
    // 检查是否有未确认的形状
    private var hasUnconfirmedShape: Bool {
        if let lastLine = lines.last {
            return lastLine.isShape && !lastLine.isConfirmed
        }
        return false
    }
    
    private var canSelectNewShape: Bool {
        // 检查是否存在未确认的形状
        if let lastLine = lines.last, lastLine.isShape && !lastLine.isConfirmed {
            return false
        }
        return true
    }
    
    private func showAlert(_ message: String) {
        // 取消之前的定时器
        alertTimer?.invalidate()
        
        // 显示新的提示
        sizeAlertMessage = message
        withAnimation {
            showSizeAlert = true
        }
        
        // 设置新的定时器
        alertTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            withAnimation {
                showSizeAlert = false
            }
        }
    }
    
    // 添加手势状态处理函数
    private func handleDragging(_ translation: CGPoint) {
        if let lastIndex = lines.indices.last,
           lines[lastIndex].isShape && !lines[lastIndex].isConfirmed {
            var updatedLine = lines[lastIndex]
            updatedLine.position.x += translation.x
            updatedLine.position.y += translation.y
            lines[lastIndex] = updatedLine
        }
    }
    
    private func handleScaling(_ scale: CGFloat) {
        if let lastIndex = lines.indices.last,
           lines[lastIndex].isShape && !lines[lastIndex].isConfirmed {
            var updatedLine = lines[lastIndex]
            if let rect = updatedLine.boundingRect {
                let newScale = updatedLine.scale * scale
                switch ShapeSizeValidator.validateRect(rect, scale: newScale) {
                case .success:
                    let worldCenterX = rect.midX * updatedLine.scale + updatedLine.position.x
                    let worldCenterY = rect.midY * updatedLine.scale + updatedLine.position.y
                    
                    updatedLine.scale = newScale
                    updatedLine.position.x = worldCenterX - (rect.midX * newScale)
                    updatedLine.position.y = worldCenterY - (rect.midY * newScale)
                    
                    lines[lastIndex] = updatedLine
                case .failure(let error):
                    showAlert(error.rawValue)
                }
            }
        }
    }
    
    private func handleResizing(edge: ResizeEdge, translation: CGPoint) {
        if let lastIndex = lines.indices.last,
           lines[lastIndex].isShape && !lines[lastIndex].isConfirmed {
            var updatedLine = lines[lastIndex]
            if var rect = updatedLine.boundingRect {
                // 保存原始中心点
                let originalCenterX = rect.midX * updatedLine.scale + updatedLine.position.x
                let originalCenterY = rect.midY * updatedLine.scale + updatedLine.position.y
                
                // 根据拉伸边缘调整矩形
                switch edge {
                case .top:
                    let heightChange = -translation.y / updatedLine.scale
                    rect = CGRect(x: rect.minX, y: rect.minY - heightChange,
                                width: rect.width, height: rect.height + heightChange)
                case .bottom:
                    let heightChange = translation.y / updatedLine.scale
                    rect = CGRect(x: rect.minX, y: rect.minY,
                                width: rect.width, height: rect.height + heightChange)
                case .left:
                    let widthChange = -translation.x / updatedLine.scale
                    rect = CGRect(x: rect.minX - widthChange, y: rect.minY,
                                width: rect.width + widthChange, height: rect.height)
                case .right:
                    let widthChange = translation.x / updatedLine.scale
                    rect = CGRect(x: rect.minX, y: rect.minY,
                                width: rect.width + widthChange, height: rect.height)
                }
                
                // 验证新的尺寸
                switch ShapeSizeValidator.validateRect(rect) {
                case .success:
                    // 计算新的中心点
                    let newCenterX = rect.midX * updatedLine.scale
                    let newCenterY = rect.midY * updatedLine.scale
                    
                    // 调整位置以保持中心点不变
                    updatedLine.position.x = originalCenterX - newCenterX
                    updatedLine.position.y = originalCenterY - newCenterY
                    updatedLine.boundingRect = rect
                    
                    lines[lastIndex] = updatedLine
                case .failure(let error):
                    showAlert(error.rawValue)
                }
            }
        }
    }
    
    private func handleTapping() {
        if let lastIndex = lines.indices.last,
           lines[lastIndex].isShape && !lines[lastIndex].isConfirmed {
            var updatedLine = lines[lastIndex]
            updatedLine.isConfirmed = true
            lines[lastIndex] = updatedLine
        }
    }
    
    // 添加退出绘画的通知名称
    private static let exitDrawingNotification = NSNotification.Name("ExitDrawingMode")

    private func handleExitDrawing() {
        withAnimation {
            isVisible = false
            lines.removeAll()
            currentLine = nil
            pinnedImage = nil
            isPinned = false
            // 更新 CaptureManager 中的状态
            CaptureManager.shared.updatePinnedDrawingImage(nil)
            CaptureManager.shared.isPinnedDrawingActive = false
            NotificationCenter.default.post(name: NSNotification.Name("ShowToolbars"), object: nil)
            // 发送退出绘画模式的通知
            NotificationCenter.default.post(name: DrawingCanvasView.exitDrawingNotification, object: nil)
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 绘画显示层
                DrawingDisplayView(
                    lines: $lines,
                    currentLine: currentLine,
                    isPinned: isPinned,
                    pinnedImage: pinnedImage,
                    gestureState: currentGestureState
                )
                
                // 手势控制层
                if !isPinned {
                    DrawingGestureView(
                        lines: $lines,
                        currentLine: $currentLine,
                        undoManager: $undoManager,
                        currentTool: currentTool,
                        brushSettings: brushSettings,
                        onGestureStateChanged: { state in
                            currentGestureState = state
                            
                            switch state {
                            case .dragging(let translation):
                                handleDragging(translation)
                            case .scaling(let scale):
                                handleScaling(scale)
                            case .resizing(let edge, let translation):
                                handleResizing(edge: edge, translation: translation)
                            case .tapping:
                                handleTapping()
                            case .none:
                                break
                            case .invalidSize(let message):
                                showAlert(message)
                            case .prepareResizing:
                                break
                            }
                        }
                    )
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
                                        if brushSettings.shapeType == .star {
                                            Image("icon-star")
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: 24, height: 24)
                                                .foregroundColor(currentTool == .shape ? brushSettings.color : .white)
                                                .opacity(currentTool == .shape ? 1 : 0.5)
                                        } else {
                                            Image(systemName: getShapeButtonIcon())
                                                .font(.system(size: 24))
                                                .foregroundColor(currentTool == .shape ? brushSettings.color : .white)
                                                .opacity(currentTool == .shape ? 1 : 0.5)
                                        }
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
                                    
                                    // 清空按钮
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
                                        if let image = DrawingRenderer.renderDrawingToImage(lines: lines, size: geometry.size) {
                                            withAnimation {
                                                pinnedImage = image
                                                isPinned = true
                                                selectedTemplate = nil
                                                // 更新CaptureManager中的绘画图片
                                                CaptureManager.shared.updatePinnedDrawingImage(image)
                                            }
                                        }
                                    }) {
                                        Image(systemName: "pin.square.fill")
                                            .font(.system(size: 35))
                                            .foregroundColor(.blue)
                                    }
                                    .disabled(lines.isEmpty || hasUnconfirmedShape)  // 添加禁用条件
                                    .opacity((lines.isEmpty || hasUnconfirmedShape) ? 0.5 : 1)
                                    
                                    // 关闭按钮
                                    Button(action: {
                                        showExitAlert = true  // 显示退出确认弹窗
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.white)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                
                                // 第二行：工具属性设置
                                if currentTool != .eraser {
                                    // 画笔和形状的属性设置
                                    HStack(spacing: 20) {
                                        // 线条粗细和不透明度控制
                                        VStack(spacing: 12) {
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
                                        }
                                        .padding(.leading, 8)
                                        
                                        Spacer()
                                        
                                        // 功能按钮组
                                        HStack(spacing: 20) {
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
                                            
                                            // 文字添加按钮
                                            Button(action: {
                                                textInputPosition = CGPoint(x: geometry.size.width/2, y: geometry.size.height/2)
                                                showTextInput = true
                                            }) {
                                                Image(systemName: "textformat")
                                                    .font(.system(size: 24))
                                                    .foregroundColor(.white)
                                            }
                                            .disabled(hasUnconfirmedShape)
                                            .opacity(hasUnconfirmedShape ? 0.5 : 1)
                                            
                                            // 模板选择按钮
                                            Button(action: {
                                                showTemplateView = true
                                            }) {
                                                Image(systemName: "heart.square.fill")
                                                    .font(.system(size: 24))
                                                    .foregroundColor(.white)
                                            }
                                            .disabled(hasUnconfirmedShape)
                                            .opacity(hasUnconfirmedShape ? 0.5 : 1)
                                        }
                                        .padding(.trailing, 8)
                                    }
                                    .frame(maxWidth: .infinity)
                                } else {
                                    // 橡皮擦粗细设置
                                    HStack {
                                        Image(systemName: "circle.dotted")
                                            .foregroundColor(.white)
                                        Slider(value: $brushSettings.lineWidth, in: 1...40)
                                            .frame(width: 200)
                                    }
                                    .padding(.horizontal)
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(15)
                            .padding(.top, 40)
                            .frame(maxWidth: geometry.size.width - 80)
                            .frame(width: geometry.size.width, alignment: .center)
                            
                            // 颜色选择器和形状选择器
                            Group {
                                if showColorPicker {
                                    ColorPickerView(
                                        selectedColor: $brushSettings.color,
                                        isExpanded: $showColorPicker,
                                        position: .zero
                                    )
                                    .transition(.opacity)
                                }
                                
                                if showShapePicker {
                                    ShapePickerView(
                                        selectedShape: $brushSettings.shapeType,
                                        selectedMode: $brushSettings.shapeDrawingMode,
                                        isExpanded: $showShapePicker,
                                        position: .zero,
                                        canSelectShape: canSelectNewShape
                                    )
                                    .transition(.opacity)
                                }
                            }
                            
                            // 添加模板选择视图
                            if showTemplateView {
                                Color.black.opacity(0.3)
                                    .edgesIgnoringSafeArea(.all)
                                    .overlay(
                                        DrawingTemplateView(
                                            isPresented: $showTemplateView,
                                            onTemplateSelected: { template in
                                                if let image = template.image {
                                                    // 清空当前画布
                                                    lines.removeAll()
                                                    currentLine = nil
                                                    
                                                    // 设置模板图片并执行pin
                                                    pinnedImage = image
                                                    isPinned = true
                                                    selectedTemplate = template
                                                    
                                                    // 更新CaptureManager中的状态
                                                    CaptureManager.shared.updatePinnedDrawingImage(image)
                                                    CaptureManager.shared.isPinnedDrawingActive = true
                                                    
                                                    // 发送显示工具栏的通知
                                                    NotificationCenter.default.post(name: NSNotification.Name("ShowToolbars"), object: nil)
                                                }
                                            }
                                        )
                                        .position(x: geometry.size.width/2, y: geometry.size.height/3 - 50)
                                    )
                            }
                        } else {
                            // 固定模式下的工具栏
                            pinnedToolbar(geometry)
                        }
                        
                        Spacer()
                    }
                }
                
                // 修改提示视图
                if showSizeAlert {
                    sizeAlertView
                }
            }
        }
        .ignoresSafeArea()
        .overlay(textInputOverlay)
        .alert("保存为模板", isPresented: $showSaveTemplateAlert) {
            Button("取消", role: .cancel) { }
            Button("确定") {
                saveNewTemplate()
            }
        } message: {
            Text("是否将此绘画作品加入模板？")
        }
        .alert("覆盖模板", isPresented: $showOverrideTemplateAlert) {
            Button("取消", role: .cancel) { }
            Button("确定", role: .destructive) {
                saveAsTemplate(at: templateManager.templates.count - 1)
            }
        } message: {
            Text("所有模板位置已满，继续操作将覆盖最后一个模板，是否继续？")
        }
        // 添加确认弹窗
        .alert("确认退出", isPresented: $showExitAlert) {
            Button("取消", role: .cancel) { }
            Button("确定", role: .destructive) {
                handleExitDrawing()
            }
        } message: {
            Text("确定退出绘画模式吗？")
        }
        // 添加删除确认弹窗
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("确定", role: .destructive) {
                handleExitDrawing()
            }
        } message: {
            Text("此操作将删除绘画作品")
        }
        .onAppear {
            NotificationCenter.default.post(name: NSNotification.Name("HideToolbars"), object: nil)
            
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("HideToolbars"),
                object: nil,
                queue: .main
            ) { _ in
                withAnimation {
                    shouldHideToolbar = true
                }
            }
            
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ShowToolbars"),
                object: nil,
                queue: .main
            ) { _ in
                withAnimation {
                    shouldHideToolbar = false
                }
            }
            
            showToolbar = true
        }
        .onChange(of: isPinned) { newValue in
            if newValue {
                NotificationCenter.default.post(name: NSNotification.Name("ShowToolbars"), object: nil)
                CaptureManager.shared.isPinnedDrawingActive = true
            } else {
                NotificationCenter.default.post(name: NSNotification.Name("HideToolbars"), object: nil)
                CaptureManager.shared.isPinnedDrawingActive = false
            }
        }
        .onDisappear {
            // 清理定时器
            alertTimer?.invalidate()
            alertTimer = nil
        }
    }
    
    // MARK: - 子视图
    
    // 固定模式下的工具栏
    private func pinnedToolbar(_ geometry: GeometryProxy) -> some View {
        HStack(spacing: 4) {  // 减小spacing值
            Spacer()
            
            // 保存按钮
            saveButton
            
            // 关闭按钮
            closeButton
        }
        .padding(.top, 40)
        .padding(.trailing, 10)  // 添加右侧padding
    }
    
    // 保存按钮
    private var saveButton: some View {
        Button(action: handleSaveButtonTap) {
            Image(systemName: "square.and.arrow.down.on.square.fill")
                .font(.system(size: 24))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 4)  // 减小水平padding
    }
    
    // 关闭按钮
    private var closeButton: some View {
        Button(action: {
            showDeleteAlert = true
        }) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 4)  // 减小水平padding
    }
    
    // 大小提示视图
    private var sizeAlertView: some View {
        Text(sizeAlertMessage)
            .foregroundColor(.white)
            .padding()
            .background(Color.black.opacity(0.7))
            .cornerRadius(8)
            .transition(.opacity)
    }
    
    // 文字输入覆盖层
    private var textInputOverlay: some View {
        Group {
            if showTextInput {
                Color.black.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                    .overlay(
                        TextInputDialog(
                            isPresented: $showTextInput,
                            text: $inputText,
                            onConfirm: { text, alignment in
                                handleTextInput(text: text, alignment: alignment)
                            }
                        )
                        .frame(width: 250)
                        .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 4)
                    )
            }
        }
    }
    
    // MARK: - 辅助方法
    
    // 处理保存按钮点击
    private func handleSaveButtonTap() {
        // 检查是否是从模板应用的
        if selectedTemplate != nil {
            showAlert("已经是模板啦")
            return
        }
        
        // 检查是否有可用的模板位置
        if !templateManager.hasAvailableSlot {
            showAlert("模板位置已满！")
            return
        }
        
        showSaveTemplateAlert = true
    }
    
    // 保存新模板
    private func saveNewTemplate() {
        if let index = templateManager.templates.firstIndex(where: { $0.image == nil }) {
            saveAsTemplate(at: index)
        }
    }
    
    // 处理文字输入
    private func handleTextInput(text: String, alignment: CustomTextAlignment) {
        var line = Line(points: [textInputPosition], settings: brushSettings)
        line.isShape = true
        
        // 计算文本行数和尺寸
        let textLines = text.components(separatedBy: "\n")
        let maxCharsPerLine = 9
        let totalLines = calculateTotalLines(textLines: textLines, maxCharsPerLine: maxCharsPerLine)
        
        // 创建边界矩形
        let rect = calculateTextRect(totalLines: totalLines, maxCharsPerLine: maxCharsPerLine)
        line.boundingRect = rect
        
        // 设置文本属性
        line.settings.shapeType = .text(text)
        line.settings.shapeDrawingMode = .stroke
        line.settings.opacity = 1.0
        line.settings.textAlignment = alignment
        line.isConfirmed = false
        
        // 添加到线条数组
        lines.append(line)
        inputText = ""
        
        // 切换到形状工具
        currentTool = .shape
    }
    
    // 计算总行数
    private func calculateTotalLines(textLines: [String], maxCharsPerLine: Int) -> Int {
        var totalLines = 0
        for textLine in textLines {
            if textLine.isEmpty {
                totalLines += 1
            } else {
                let chars = textLine.count
                let linesForThisText = (chars + maxCharsPerLine - 1) / maxCharsPerLine
                totalLines += linesForThisText
            }
        }
        return totalLines
    }
    
    // 计算文本矩形
    private func calculateTextRect(totalLines: Int, maxCharsPerLine: Int) -> CGRect {
        let charWidth: CGFloat = 10
        let lineHeight: CGFloat = 10
        let horizontalPadding: CGFloat = 10
        let verticalPadding: CGFloat = 8
        
        let width = charWidth * CGFloat(maxCharsPerLine) + horizontalPadding * 2
        let height = lineHeight * CGFloat(totalLines) + verticalPadding * 2
        
        return CGRect(
            x: textInputPosition.x - width/2,
            y: textInputPosition.y - height/2,
            width: width,
            height: height
        )
    }
    
    // 保存为模板
    private func saveAsTemplate(at index: Int) {
        if let image = DrawingRenderer.renderDrawingToImage(lines: lines, size: UIScreen.main.bounds.size) {
            templateManager.saveTemplateAt(image: image, index: index)
            showAlert("保存模板成功")
        }
    }
    
    // 获取形状按钮的图标
    private func getShapeButtonIcon() -> String {
        switch brushSettings.shapeType {
        case .rectangle:
            return "rectangle.fill"
        case .circle:
            return "circle.fill"
        case .heart:
            return "heart.fill"
        case .cross:
            return "plus"
        case .star:
            return "icon-star"
        case .text:
            return "text.bubble"
        }
    }
    
    private func handleButtonTap(_ buttonType: DrawingTool) {
        print("工具切换 - 当前选择: \(buttonType)")
        
        // 检查是否有未确认的形状
        if let lastLine = lines.last, lastLine.isShape && !lastLine.isConfirmed {
            print("有未确认的形状，禁止切换到其他工具")
            return  // 如果有未确认的形状，禁止切换工具
        }
        
        switch buttonType {
        case .pencil:
            currentTool = .pencil
            brushSettings.isEraser = false
            brushSettings.shapeType = .rectangle
            print("切换到画笔模式")
        case .shape:
            currentTool = .shape
            brushSettings.isEraser = false
            print("切换到形状模式")
        case .eraser:
            currentTool = .eraser
            brushSettings.isEraser = true
            brushSettings.shapeType = .rectangle
            print("切换到橡皮擦模式 - isEraser: \(brushSettings.isEraser)")
        }
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
            
            switch ShapeSizeValidator.validateRect(rect) {
            case .success:
                currentLine?.boundingRect = rect
            case .failure(let error):
                sizeAlertMessage = error.rawValue
                withAnimation {
                    showSizeAlert = true
                }
                currentLine = nil
            }
        }
    }
    
    private func validateAndAddShape(_ line: Line) -> Bool {
        switch ShapeSizeValidator.validateLine(line) {
        case .success:
            print("形状尺寸有效")
            return true
        case .failure(let error):
            sizeAlertMessage = error.rawValue
            withAnimation {
                showSizeAlert = true
            }
            print("形状尺寸无效：\(error.rawValue)")
            return false
        }
    }
}

@available(iOS 15.0, *)
#Preview {
    DrawingCanvasView(isVisible: .constant(true), isPinned: .constant(false))
} 

// 添加绘画渲染器
class DrawingRenderer {
    static func renderDrawingToImage(lines: [Line], size: CGSize, scale: CGFloat = UIScreen.main.scale) -> UIImage? {
        // 使用autoreleasepool来管理临时对象的内存
        return autoreleasepool { () -> UIImage? in
            let format = UIGraphicsImageRendererFormat()
            format.scale = scale
            format.opaque = false
            
            // 限制最大渲染尺寸
            let maxDimension: CGFloat = 4096
            var renderSize = size
            if size.width > maxDimension || size.height > maxDimension {
                let ratio = min(maxDimension / size.width, maxDimension / size.height)
                renderSize = CGSize(width: size.width * ratio, height: size.height * ratio)
            }
            
            let renderer = UIGraphicsImageRenderer(size: renderSize, format: format)
            
            let image = renderer.image { context in
                context.cgContext.setAllowsAntialiasing(true)
                context.cgContext.setShouldAntialias(true)
                
                for line in lines {
                    if line.isShape {
                        // 渲染形状
                        if let rect = line.boundingRect {
                            // 使用 DrawingShapeRenderer 的 UIKit 渲染方法
                            DrawingShapeRenderer.drawShape(
                                line.settings.shapeType,
                                in: rect.applying(CGAffineTransform.identity
                                    .translatedBy(x: line.position.x, y: line.position.y)
                                    .scaledBy(x: line.scale, y: line.scale)),
                                with: line.settings,
                                in: context.cgContext
                            )
                        }
                    } else {
                        // 渲染自由绘画线条
                        guard let start = line.points.first else { continue }
                        
                        let path = UIBezierPath()
                        path.lineWidth = line.settings.lineWidth
                        path.lineCapStyle = .round
                        path.lineJoinStyle = .round
                        
                        path.move(to: start)
                        
                        // 使用贝塞尔曲线进行平滑处理
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
                            // 点数较少时直接连线
                            for point in line.points.dropFirst() {
                                path.addLine(to: point)
                            }
                        }
                        
                        if line.settings.isEraser {
                            UIColor.clear.setStroke()
                            path.stroke(with: .clear, alpha: 1.0)
                        } else {
                            let color = UIColor(line.settings.color)
                            color.withAlphaComponent(line.settings.opacity).setStroke()
                            path.stroke()
                        }
                    }
                }
            }
            
            return image
        }
    }
} 
