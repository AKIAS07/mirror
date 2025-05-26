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
    let canSelectShape: Bool
    
    private let shapes: [(ShapeType, String)] = [
        (.rectangle, "rectangle.fill"),
        (.circle, "circle.fill"),
        (.heart, "heart.fill"),
        (.cross, "plus"),
        (.star, "icon-star")
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
                            if canSelectShape {
                                selectedShape = shape.0
                                withAnimation {
                                    isExpanded = false
                                }
                            }
                        }) {
                            if shape.0 == .star {
                                Image("icon-star")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 20, height: 20)
                                    .foregroundColor(.white)  // 始终保持白色
                                    .frame(width: 32, height: 32)
                                    .background(selectedShape == shape.0 ? Color.white.opacity(0.3) : Color.clear)
                                    .cornerRadius(8)
                                    .scaleEffect(selectedShape == shape.0 ? 1.2 : 1.0)
                            } else {
                                Image(systemName: shape.1)
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)  // 始终保持白色
                                    .frame(width: 32, height: 32)
                                    .background(selectedShape == shape.0 ? Color.white.opacity(0.3) : Color.clear)
                                    .cornerRadius(8)
                                    .scaleEffect(selectedShape == shape.0 ? 1.2 : 1.0)
                            }
                        }
                        .disabled(!canSelectShape)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedShape)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
                .frame(maxWidth: .infinity)
                
                // 绘制模式选择
                HStack(spacing: 16) {
                    Button(action: {
                        if canSelectShape {
                            selectedMode = .stroke
                        }
                    }) {
                        Image(systemName: "rectangle")
                            .font(.system(size: 20))
                            .foregroundColor(selectedMode == .stroke ? .blue : .white)
                            .frame(width: 32, height: 32)
                            .background(selectedMode == .stroke ? Color.white.opacity(0.3) : Color.clear)
                            .cornerRadius(8)
                    }
                    .disabled(!canSelectShape)
                    
                    Button(action: {
                        if canSelectShape {
                            selectedMode = .fill
                        }
                    }) {
                        Image(systemName: "rectangle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(selectedMode == .fill ? .blue : .white)
                            .frame(width: 32, height: 32)
                            .background(selectedMode == .fill ? Color.white.opacity(0.3) : Color.clear)
                            .cornerRadius(8)
                    }
                    .disabled(!canSelectShape)
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
    var shapeType: ShapeType = .rectangle  // 修改默认形状为矩形
    var shapeDrawingMode: ShapeDrawingMode = .fill
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
                                if let lastIndex = lines.indices.last,
                                   lines[lastIndex].isShape && !lines[lastIndex].isConfirmed {
                                    var updatedLine = lines[lastIndex]
                                    updatedLine.position.x += translation.x
                                    updatedLine.position.y += translation.y
                                    lines[lastIndex] = updatedLine
                                }
                                
                            case .scaling(let scale):
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
                                
                            case .resizing(let edge, let translation):
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
                                
                            case .tapping:
                                if let lastIndex = lines.indices.last,
                                   lines[lastIndex].isShape && !lines[lastIndex].isConfirmed {
                                    var updatedLine = lines[lastIndex]
                                    updatedLine.isConfirmed = true
                                    lines[lastIndex] = updatedLine
                                }
                                
                            case .none:
                                break
                            
                            case .invalidSize(let message):
                                showAlert(message)
                                
                            case .prepareResizing:
                                break  // 准备拉伸状态不需要额外处理，只需要更新视觉反馈
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
                                    .frame(maxWidth: .infinity)
                                } else {
                                    // 橡皮擦粗细设置
                                    HStack {
                                        Image(systemName: "circle.dotted")
                                            .foregroundColor(.white)
                                        Slider(value: $brushSettings.lineWidth, in: 1...40)
                                            .frame(width: 200)
                                    }
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
                        } else {
                            // 固定模式下的关闭按钮
                            HStack {
                                Spacer()
                                Button(action: {
                                    showDeleteAlert = true  // 显示删除确认弹窗
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
                
                // 修改提示视图
                if showSizeAlert {
                    Text(sizeAlertMessage)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                        .transition(.opacity)
                }
            }
        }
        .ignoresSafeArea()
        // 添加确认弹窗
        .alert("确认退出", isPresented: $showExitAlert) {
            Button("取消", role: .cancel) { }
            Button("确定", role: .destructive) {
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
                }
            }
        } message: {
            Text("确定退出绘画模式吗？")
        }
        // 添加删除确认弹窗
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("确定", role: .destructive) {
                withAnimation {
                    isVisible = false
                    isPinned = false
                    pinnedImage = nil
                    // 更新 CaptureManager 中的状态
                    CaptureManager.shared.updatePinnedDrawingImage(nil)
                    CaptureManager.shared.isPinnedDrawingActive = false
                    NotificationCenter.default.post(name: NSNotification.Name("ShowToolbars"), object: nil)
                }
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
                        for point in line.points.dropFirst() {
                            path.addLine(to: point)
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
