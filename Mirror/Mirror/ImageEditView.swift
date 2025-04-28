import SwiftUI
import UIKit

// 路径闭合检查扩展
extension Array where Element == CGPoint {
    func isPathClosed(tolerance: CGFloat = 20.0) -> Bool {
        guard self.count > 2 else { return false }
        let start = self[0]
        let end = self.last!
        let distance = sqrt(pow(end.x - start.x, 2) + pow(end.y - start.y, 2))
        return distance <= tolerance
    }
}

// 自定义绘制视图
struct DrawingCanvas: View {
    let image: UIImage
    @Binding var paths: [DrawingPath]
    @Binding var currentPath: DrawingPath?
    let tool: ImageSelectionTool
    @Binding var showAlert: Bool
    @Binding var alertMessage: String
    @State private var dragOffset: CGPoint = .zero
    @State private var isDragging = false
    
    // 删除按钮的大小
    private let deleteButtonSize: CGFloat = 20
    
    // 获取删除按钮的位置
    private func deleteButtonPosition(for path: DrawingPath) -> CGPoint {
        let boundingBox = path.getBoundingBox()
        return CGPoint(x: boundingBox.maxX, y: boundingBox.minY)
    }
    
    // 固定4:3显示区域的尺寸计算
    private func calculateDisplayFrame(in geometry: GeometryProxy) -> CGRect {
        let viewWidth = geometry.size.width - 32  // 左右各留16点边距
        let displayWidth = viewWidth
        let displayHeight = displayWidth * 4 / 3   // 保持4:3比例
        
        let frame = CGRect(
            x: 16,  // 左边距16点
            y: (geometry.size.height - displayHeight) / 2,  // 垂直居中
            width: displayWidth,
            height: displayHeight
        )
        
        print("[显示区域] size=\(frame.size), origin=\(frame.origin)")
        return frame
    }
    
    // 计算图片在显示区域内的实际尺寸和位置
    private func calculateImageFrame(in displayFrame: CGRect) -> CGRect {
        let imageSize = image.size
        let displaySize = displayFrame.size
        let imageAspect = imageSize.width / imageSize.height
        let displayAspect = displaySize.width / displaySize.height
        
        var imageFrame = CGRect.zero
        
        if imageAspect > displayAspect {
            // 图片较宽，以宽度为准，高度会小于显示区域
            let scaledHeight = displayFrame.width / imageAspect
            imageFrame = CGRect(
                x: displayFrame.minX,
                y: displayFrame.minY + (displayFrame.height - scaledHeight) / 2,
                width: displayFrame.width,
                height: scaledHeight
            )
        } else {
            // 图片较高，以高度为准，宽度会小于显示区域
            let scaledWidth = displayFrame.height * imageAspect
            imageFrame = CGRect(
                x: displayFrame.minX + (displayFrame.width - scaledWidth) / 2,
                y: displayFrame.minY,
                width: scaledWidth,
                height: displayFrame.height
            )
        }
        
        print("[图片显示区域] 四个角坐标：")
        print("左上角：(\(imageFrame.minX), \(imageFrame.minY))")
        print("右上角：(\(imageFrame.maxX), \(imageFrame.minY))")
        print("左下角：(\(imageFrame.minX), \(imageFrame.maxY))")
        print("右下角：(\(imageFrame.maxX), \(imageFrame.maxY))")
        
        return imageFrame
    }
    
    var body: some View {
        GeometryReader { geometry in
            let displayFrame = calculateDisplayFrame(in: geometry)
            let imageFrame = calculateImageFrame(in: displayFrame)
            
            ZStack {
                // 灰色背景显示区域
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: displayFrame.width, height: displayFrame.height)
                    .position(x: displayFrame.midX, y: displayFrame.midY)
                
                // 显示原始图片
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: imageFrame.width, height: imageFrame.height)
                    .position(x: imageFrame.midX, y: imageFrame.midY)
                
                // 绘画层
                Canvas { context, size in
                    // 绘制所有已完成的路径
                    for path in paths {
                        drawPath(context: context, size: size, path: path, displayFrame: displayFrame)
                    }
                    
                    // 绘制当前正在绘制的路径
                    if let currentPath = currentPath {
                        drawPath(context: context, size: size, path: currentPath, displayFrame: displayFrame)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                
                // 删除按钮层
                ForEach(paths.indices, id: \.self) { index in
                    if paths[index].isSelected {
                        let buttonPosition = deleteButtonPosition(for: paths[index])
                        Button(action: {
                            paths.remove(at: index)
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .frame(width: deleteButtonSize, height: deleteButtonSize)
                        }
                        .position(x: buttonPosition.x, y: buttonPosition.y)
                    }
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard displayFrame.contains(value.location) else { return }
                        
                        if currentPath == nil && !isDragging {
                            // 检查是否点击了现有路径
                            if let index = paths.firstIndex(where: { $0.contains(value.location) }) {
                                // 涂抹笔不支持选中和拖动
                                if paths[index].tool != .smudge {
                                    // 取消其他路径的选中状态
                                    for i in paths.indices {
                                        paths[i].isSelected = (i == index)
                                    }
                                    isDragging = true
                                    dragOffset = value.location
                                }
                            } else {
                                // 取消所有路径的选中状态
                                for i in paths.indices {
                                    paths[i].isSelected = false
                                }
                                // 开始新的绘制
                                if tool == .smudge {
                                    currentPath = DrawingPath(points: [value.location], tool: tool)
                                } else {
                                    currentPath = DrawingPath(points: [value.location], tool: tool)
                                }
                            }
                        } else if isDragging {
                            // 更新选中路径的位置
                            if let index = paths.firstIndex(where: { $0.isSelected }) {
                                let delta = CGPoint(
                                    x: value.location.x - dragOffset.x,
                                    y: value.location.y - dragOffset.y
                                )
                                paths[index].offset = CGPoint(
                                    x: paths[index].offset.x + delta.x,
                                    y: paths[index].offset.y + delta.y
                                )
                                dragOffset = value.location
                            }
                        } else if tool == .smudge {
                            // 涂抹笔的处理逻辑
                            if currentPath == nil {
                                currentPath = DrawingPath(points: [value.location], tool: tool)
                            } else {
                                currentPath?.points.append(value.location)
                            }
                        } else {
                            // 其他工具的绘制逻辑
                            currentPath?.points.append(value.location)
                        }
                    }
                    .onEnded { value in
                        if isDragging {
                            isDragging = false
                        } else if let path = currentPath {
                            if tool == .brush && !path.points.isPathClosed() {
                                showAlert = true
                                alertMessage = "请重新绘画，闭合区域"
                                currentPath = nil
                            } else {
                                paths.append(path)
                                currentPath = nil
                            }
                        }
                    }
            )
        }
    }
    
    private func drawPath(context: GraphicsContext, size: CGSize, path: DrawingPath, displayFrame: CGRect) {
        // 设置绘制颜色
        let drawingColor: Color
        if path.tool == .smudge {
            drawingColor = .blue.opacity(0.2)
        } else {
            drawingColor = path.isSelected ? .green : (isPathComplete(path) ? .blue : .red)
        }
        
        // 创建绘制路径
        let drawPath = Path { p in
            // 应用偏移量到所有点
            let offsetPoints = path.points.map { CGPoint(x: $0.x + path.offset.x, y: $0.y + path.offset.y) }
            
            switch path.tool {
            case .brush:
                let firstPoint = offsetPoints[0]
                p.move(to: firstPoint)
                for point in offsetPoints.dropFirst() {
                    p.addLine(to: point)
                }
                if isPathComplete(path) {
                    p.closeSubpath()
                }
                
            case .smudge:
                guard offsetPoints.count >= 2 else { break }
                
                // 创建平滑的路径
                let points = offsetPoints
                let strokeWidth: CGFloat = 20.0  // 涂抹笔的宽度
                
                if points.count == 2 {
                    // 只有两个点时，直接连接并加宽
                    let start = points[0]
                    let end = points[1]
                    
                    // 计算垂直偏移
                    let dx = end.x - start.x
                    let dy = end.y - start.y
                    let angle = atan2(dy, dx)
                    let perpendicular = angle + .pi/2
                    
                    // 计算四个角点
                    let offsetX = strokeWidth/2 * cos(perpendicular)
                    let offsetY = strokeWidth/2 * sin(perpendicular)
                    
                    // 绘制加宽的路径
                    p.move(to: CGPoint(x: start.x + offsetX, y: start.y + offsetY))
                    p.addLine(to: CGPoint(x: end.x + offsetX, y: end.y + offsetY))
                    p.addLine(to: CGPoint(x: end.x - offsetX, y: end.y - offsetY))
                    p.addLine(to: CGPoint(x: start.x - offsetX, y: start.y - offsetY))
                    p.closeSubpath()
                } else {
                    // 三个或更多点时，使用平滑曲线
                    var pathPoints = [CGPoint]()
                    
                    // 为每个点创建扩展的轮廓点
                    for i in 0..<points.count {
                        let current = points[i]
                        let prev = i > 0 ? points[i-1] : current
                        let next = i < points.count - 1 ? points[i+1] : current
                        
                        // 计算方向向量
                        let dx1 = current.x - prev.x
                        let dy1 = current.y - prev.y
                        let dx2 = next.x - current.x
                        let dy2 = next.y - current.y
                        
                        // 计算平均方向
                        let angle = atan2((dy1 + dy2)/2, (dx1 + dx2)/2)
                        let perpendicular = angle + .pi/2
                        
                        // 添加扩展点
                        let offsetX = strokeWidth/2 * cos(perpendicular)
                        let offsetY = strokeWidth/2 * sin(perpendicular)
                        
                        pathPoints.append(CGPoint(x: current.x + offsetX, y: current.y + offsetY))
                    }
                    
                    // 添加返回路径的点（反向）
                    for i in (0..<points.count).reversed() {
                        let current = points[i]
                        let prev = i > 0 ? points[i-1] : current
                        let next = i < points.count - 1 ? points[i+1] : current
                        
                        let dx1 = current.x - prev.x
                        let dy1 = current.y - prev.y
                        let dx2 = next.x - current.x
                        let dy2 = next.y - current.y
                        
                        let angle = atan2((dy1 + dy2)/2, (dx1 + dx2)/2)
                        let perpendicular = angle + .pi/2
                        
                        let offsetX = strokeWidth/2 * cos(perpendicular)
                        let offsetY = strokeWidth/2 * sin(perpendicular)
                        
                        pathPoints.append(CGPoint(x: current.x - offsetX, y: current.y - offsetY))
                    }
                    
                    // 绘制平滑路径
                    p.move(to: pathPoints[0])
                    
                    // 使用贝塞尔曲线连接点
                    for i in 0..<pathPoints.count {
                        let current = pathPoints[i]
                        let next = pathPoints[(i + 1) % pathPoints.count]
                        
                        if i == 0 {
                            p.move(to: current)
                        } else {
                            let control1 = CGPoint(
                                x: current.x + (next.x - current.x) * 0.5,
                                y: current.y + (next.y - current.y) * 0.5
                            )
                            p.addQuadCurve(to: next, control: control1)
                        }
                    }
                    p.closeSubpath()
                }
                
            case .rectangle:
                let start = offsetPoints[0]
                let end = offsetPoints.last ?? start
                let rect = CGRect(
                    x: min(start.x, end.x),
                    y: min(start.y, end.y),
                    width: abs(end.x - start.x),
                    height: abs(end.y - start.y)
                )
                p.addRect(rect)
                
            case .circle:
                let start = offsetPoints[0]
                let end = offsetPoints.last ?? start
                let center = CGPoint(
                    x: (start.x + end.x) / 2,
                    y: (start.y + end.y) / 2
                )
                let radius = sqrt(
                    pow(end.x - start.x, 2) +
                    pow(end.y - start.y, 2)
                ) / 2
                p.addEllipse(in: CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                ))
                
            case .mouth:
                let start = offsetPoints[0]
                let end = offsetPoints.last ?? start
                let width = abs(end.x - start.x)
                let height = abs(end.y - start.y)
                let rect = CGRect(
                    x: min(start.x, end.x),
                    y: min(start.y, end.y),
                    width: width,
                    height: height
                )
                
                // 绘制嘴巴轮廓（M形状的上唇和弧形的下唇）
                let mouthPath = Path { p in
                    // 起点（左边）
                    p.move(to: CGPoint(x: rect.minX, y: rect.midY))
                    
                    // 上唇左半部分
                    p.addCurve(
                        to: CGPoint(x: rect.minX + width * 0.5, y: rect.midY - height * 0.1),
                        control1: CGPoint(x: rect.minX + width * 0.15, y: rect.midY),
                        control2: CGPoint(x: rect.minX + width * 0.35, y: rect.minY + height * 0.3)
                    )
                    
                    // 上唇右半部分
                    p.addCurve(
                        to: CGPoint(x: rect.maxX, y: rect.midY),
                        control1: CGPoint(x: rect.minX + width * 0.65, y: rect.minY + height * 0.3),
                        control2: CGPoint(x: rect.minX + width * 0.85, y: rect.midY)
                    )
                    
                    // 下唇
                    p.addCurve(
                        to: CGPoint(x: rect.minX, y: rect.midY),
                        control1: CGPoint(x: rect.maxX - width * 0.25, y: rect.maxY - height * 0.2),
                        control2: CGPoint(x: rect.minX + width * 0.25, y: rect.maxY - height * 0.2)
                    )
                }
                p.addPath(mouthPath)
                
            case .eyebrow:
                let start = offsetPoints[0]
                let end = offsetPoints.last ?? start
                let width = abs(end.x - start.x)
                let height = abs(end.y - start.y)
                let rect = CGRect(
                    x: min(start.x, end.x),
                    y: min(start.y, end.y),
                    width: width,
                    height: height
                )
                
                // 绘制眉毛轮廓（弧形）
                let eyebrowPath = Path { p in
                    p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
                    p.addQuadCurve(
                        to: CGPoint(x: rect.maxX, y: rect.maxY),
                        control: CGPoint(x: rect.midX, y: rect.minY)
                    )
                    // 添加一点厚度
                    p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY + height * 0.2))
                    p.addQuadCurve(
                        to: CGPoint(x: rect.minX, y: rect.maxY + height * 0.2),
                        control: CGPoint(x: rect.midX, y: rect.minY + height * 0.2)
                    )
                    p.closeSubpath()
                }
                p.addPath(eyebrowPath)
            }
        }
        
        // 根据工具类型决定绘制方式
        if path.tool == .smudge {
            context.fill(drawPath, with: .color(drawingColor))
        } else {
            if isPathComplete(path) {
                context.fill(drawPath, with: .color(drawingColor.opacity(0.2)))
                context.stroke(drawPath, with: .color(drawingColor), lineWidth: 2)
            } else {
                context.stroke(drawPath, with: .color(.red), lineWidth: 2)
            }
        }
    }
    
    private func isPathComplete(_ path: DrawingPath) -> Bool {
        switch path.tool {
        case .brush:
            return path.points.isPathClosed()
        case .smudge:
            return currentPath == nil
        case .rectangle, .circle, .mouth, .eyebrow:
            return path.points.count >= 2
        }
    }
}

// 用于存储编辑状态的结构体
private struct EditState: Codable {
    var paths: [DrawingPath]
}

struct ImageEditView: View {
    let sourceImage: UIImage
    @Binding var editedImage: UIImage?
    let editingKey: String
    @Binding var isPresented: Bool
    @StateObject private var restartManager = ContentRestartManager.shared  // 添加 RestartManager 引用
    let cameraManager: CameraManager  // 添加 CameraManager 引用
    
    // 当前编辑状态
    @State private var paths: [DrawingPath] = []
    @State private var currentPath: DrawingPath?
    @State private var selectedTool: ImageSelectionTool = .brush
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showResetAlert = false
    @State private var showCancelAlert = false
    @State private var initialPaths: [DrawingPath] = []
    
    // 初始化时加载编辑状态
    init(sourceImage: UIImage, editedImage: Binding<UIImage?>, editingKey: String, isPresented: Binding<Bool>, cameraManager: CameraManager) {
        self.sourceImage = sourceImage
        self._editedImage = editedImage
        self.editingKey = editingKey
        self._isPresented = isPresented
        self.cameraManager = cameraManager
        
        // 如果editedImage不为nil，说明之前保存过，需要加载上次的状态
        if editedImage.wrappedValue != nil,
           let data = UserDefaults.standard.data(forKey: editingKey),
           let state = try? JSONDecoder().decode(EditState.self, from: data) {
            self._paths = State(initialValue: state.paths)
            self._initialPaths = State(initialValue: state.paths)
        } else {
            self._paths = State(initialValue: [])
            self._initialPaths = State(initialValue: [])
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // 顶部工具栏
                HStack {
                    Button("取消") {
                        showCancelAlert = true
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    Button(paths.isEmpty ? "恢复图片" : "保存") {
                        if paths.isEmpty {
                            restoreOriginalImage()
                        } else {
                            saveImage()
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 44)
                .background(Color.white)
                
                // 工具栏
                HStack(spacing: 20) {
                    Button(action: { selectedTool = .brush }) {
                        Image(systemName: "pencil")
                            .foregroundColor(selectedTool == .brush ? .blue : .gray)
                    }
                    
                    Button(action: { selectedTool = .smudge }) {
                        Image(systemName: "paintbrush.pointed.fill")
                            .foregroundColor(selectedTool == .smudge ? .blue : .gray)
                    }
                    
                    Button(action: { selectedTool = .rectangle }) {
                        Image(systemName: "rectangle")
                            .foregroundColor(selectedTool == .rectangle ? .blue : .gray)
                    }
                    
                    Button(action: { selectedTool = .circle }) {
                        Image(systemName: "circle")
                            .foregroundColor(selectedTool == .circle ? .blue : .gray)
                    }
                    
                    Button(action: { selectedTool = .mouth }) {
                        Image(systemName: "mouth")
                            .foregroundColor(selectedTool == .mouth ? .blue : .gray)
                    }
                    
                    Button(action: { selectedTool = .eyebrow }) {
                        Image(systemName: "eyebrow")
                            .foregroundColor(selectedTool == .eyebrow ? .blue : .gray)
                    }
                    
                    Spacer()
                    
                    Button(action: { showResetAlert = true }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
                .padding()
                .background(Color.white)
                
                // 绘制区域
                DrawingCanvas(
                    image: sourceImage,
                    paths: $paths,
                    currentPath: $currentPath,
                    tool: selectedTool,
                    showAlert: $showAlert,
                    alertMessage: $alertMessage
                )
                .background(Color.gray.opacity(0.2))
            }
        }
        .alert("提示", isPresented: $showAlert) {
            Button("确定") {}
        } message: {
            Text(alertMessage)
        }
        .alert("重置确认", isPresented: $showResetAlert) {
            Button("取消", role: .cancel) {}
            Button("确定", role: .destructive) {
                reset()
            }
        } message: {
            Text("确定要清除所有编辑内容吗？")
        }
        .alert("取消确认", isPresented: $showCancelAlert) {
            Button("继续编辑", role: .cancel) {}
            Button("确认取消", role: .destructive) {
                cancelEditing()
            }
        } message: {
            Text("点击取消，本次绘图操作不会保存")
        }
    }
    
    // 取消编辑，恢复到初始状态
    private func cancelEditing() {
        paths = initialPaths
        currentPath = nil
        isPresented = false
        
        // 重启摄像头
        restartManager.handleRestartViewAppear(cameraManager: cameraManager)
    }
    
    // 保存状态
    private func saveImage() {
        guard !paths.isEmpty else {
            showAlert = true
            alertMessage = "请至少绘制一个区域"
            return
        }
        
        print("[保存] 开始处理图片")
        print("[保存] 原始图片尺寸: \(sourceImage.size)")
        
        // 使用固定的4:3显示区域
        let displayWidth: CGFloat = 321.7  // 与绘制时保持一致
        let displayHeight = displayWidth * 4 / 3
        
        let displayFrame = CGRect(
            x: 16,
            y: 39.4666666666667,  // 与绘制时保持一致
            width: displayWidth,
            height: displayHeight
        )
        
        // 计算图片显示区域
        let imageSize = sourceImage.size
        let displaySize = displayFrame.size
        let imageAspect = imageSize.width / imageSize.height
        let displayAspect = displaySize.width / displaySize.height
        
        var imageFrame = CGRect.zero
        
        if imageAspect > displayAspect {
            // 图片较宽，以宽度为准
            let scaledHeight = displayFrame.width / imageAspect
            imageFrame = CGRect(
                x: displayFrame.minX,
                y: displayFrame.minY + (displayFrame.height - scaledHeight) / 2,
                width: displayFrame.width,
                height: scaledHeight
            )
        } else {
            // 图片较高，以高度为准
            let scaledWidth = displayFrame.height * imageAspect
            imageFrame = CGRect(
                x: displayFrame.minX + (displayFrame.width - scaledWidth) / 2,
                y: displayFrame.minY,
                width: scaledWidth,
                height: displayFrame.height
            )
        }
        
        // 计算坐标转换比例
        let scaleX = sourceImage.size.width / imageFrame.width
        let scaleY = sourceImage.size.height / imageFrame.height
        
        print("[保存] 显示区域: \(displayFrame)")
        print("[保存] 图片区域: \(imageFrame)")
        print("[保存] X轴缩放比例: \(scaleX)")
        print("[保存] Y轴缩放比例: \(scaleY)")
        
        // 转换坐标的辅助函数
        func convertPoint(_ point: CGPoint) -> CGPoint {
            let relativeX = point.x - imageFrame.minX
            let relativeY = point.y - imageFrame.minY
            return CGPoint(
                x: relativeX * scaleX,
                y: relativeY * scaleY
            )
        }
        
        // 创建图像上下文
        let renderer = UIGraphicsImageRenderer(size: sourceImage.size)
        let maskedImage = renderer.image { context in
            // 清除背景
            UIColor.clear.setFill()
            context.fill(CGRect(origin: .zero, size: sourceImage.size))
            
            // 创建路径
            let path = UIBezierPath()
            
            // 转换所有绘制路径的坐标
            for drawingPath in paths {
                guard !drawingPath.points.isEmpty else { continue }
                
                let subPath = UIBezierPath()
                
                switch drawingPath.tool {
                case .brush:
                    let firstPoint = convertPoint(drawingPath.points[0])
                    let firstPointWithOffset = CGPoint(
                        x: firstPoint.x + drawingPath.offset.x * scaleX,
                        y: firstPoint.y + drawingPath.offset.y * scaleY
                    )
                    subPath.move(to: firstPointWithOffset)
                    
                    for point in drawingPath.points.dropFirst() {
                        let convertedPoint = convertPoint(point)
                        let pointWithOffset = CGPoint(
                            x: convertedPoint.x + drawingPath.offset.x * scaleX,
                            y: convertedPoint.y + drawingPath.offset.y * scaleY
                        )
                        subPath.addLine(to: pointWithOffset)
                    }
                    
                    if drawingPath.points.isPathClosed() {
                        subPath.close()
                    }
                    
                case .smudge:
                    guard drawingPath.points.count >= 2 else { break }
                    
                    // 使用较粗的笔触连接点
                    let strokeWidth: CGFloat = 20.0 * scaleX  // 根据缩放比例调整涂抹笔的宽度
                    let points = drawingPath.points.map { convertPoint($0) }
                    
                    if points.count == 2 {
                        // 只有两个点时，直接连接并加宽
                        let start = points[0]
                        let end = points[1]
                        
                        // 计算垂直偏移
                        let dx = end.x - start.x
                        let dy = end.y - start.y
                        let angle = atan2(dy, dx)
                        let perpendicular = angle + .pi/2
                        
                        // 计算四个角点
                        let offsetX = strokeWidth/2 * cos(perpendicular)
                        let offsetY = strokeWidth/2 * sin(perpendicular)
                        
                        // 绘制加宽的路径
                        subPath.move(to: CGPoint(x: start.x + offsetX, y: start.y + offsetY))
                        subPath.addLine(to: CGPoint(x: end.x + offsetX, y: end.y + offsetY))
                        subPath.addLine(to: CGPoint(x: end.x - offsetX, y: end.y - offsetY))
                        subPath.addLine(to: CGPoint(x: start.x - offsetX, y: start.y - offsetY))
                    } else {
                        // 三个或更多点时，使用平滑曲线
                        var path = [CGPoint]()
                        
                        // 为每个点创建扩展的轮廓点
                        for i in 0..<points.count {
                            let current = points[i]
                            let prev = i > 0 ? points[i-1] : current
                            let next = i < points.count - 1 ? points[i+1] : current
                            
                            // 计算方向向量
                            let dx1 = current.x - prev.x
                            let dy1 = current.y - prev.y
                            let dx2 = next.x - current.x
                            let dy2 = next.y - current.y
                            
                            // 计算平均方向
                            let angle = atan2((dy1 + dy2)/2, (dx1 + dx2)/2)
                            let perpendicular = angle + .pi/2
                            
                            // 添加扩展点
                            let offsetX = strokeWidth/2 * cos(perpendicular)
                            let offsetY = strokeWidth/2 * sin(perpendicular)
                            
                            path.append(CGPoint(x: current.x + offsetX, y: current.y + offsetY))
                        }
                        
                        // 添加返回路径的点（反向）
                        for i in (0..<points.count).reversed() {
                            let current = points[i]
                            let prev = i > 0 ? points[i-1] : current
                            let next = i < points.count - 1 ? points[i+1] : current
                            
                            let dx1 = current.x - prev.x
                            let dy1 = current.y - prev.y
                            let dx2 = next.x - current.x
                            let dy2 = next.y - current.y
                            
                            let angle = atan2((dy1 + dy2)/2, (dx1 + dx2)/2)
                            let perpendicular = angle + .pi/2
                            
                            let offsetX = strokeWidth/2 * cos(perpendicular)
                            let offsetY = strokeWidth/2 * sin(perpendicular)
                            
                            path.append(CGPoint(x: current.x - offsetX, y: current.y - offsetY))
                        }
                        
                        // 绘制平滑路径
                        subPath.move(to: path[0])
                        
                        // 使用贝塞尔曲线连接点
                        for i in 0..<path.count {
                            let current = path[i]
                            let next = path[(i + 1) % path.count]
                            
                            if i == 0 {
                                subPath.move(to: current)
                            } else {
                                let control1 = CGPoint(
                                    x: current.x + (next.x - current.x) * 0.5,
                                    y: current.y + (next.y - current.y) * 0.5
                                )
                                subPath.addQuadCurve(to: next, controlPoint: control1)
                            }
                        }
                    }
                    
                    subPath.close()
                    
                case .rectangle:
                    let start = drawingPath.points[0]
                    let end = drawingPath.points.last ?? start
                    let convertedStart = convertPoint(start)
                    let convertedEnd = convertPoint(end)
                    
                    // 应用偏移量
                    let startWithOffset = CGPoint(
                        x: convertedStart.x + drawingPath.offset.x * scaleX,
                        y: convertedStart.y + drawingPath.offset.y * scaleY
                    )
                    let endWithOffset = CGPoint(
                        x: convertedEnd.x + drawingPath.offset.x * scaleX,
                        y: convertedEnd.y + drawingPath.offset.y * scaleY
                    )
                    
                    let rect = CGRect(
                        x: min(startWithOffset.x, endWithOffset.x),
                        y: min(startWithOffset.y, endWithOffset.y),
                        width: abs(endWithOffset.x - startWithOffset.x),
                        height: abs(endWithOffset.y - startWithOffset.y)
                    )
                    subPath.append(UIBezierPath(rect: rect))
                    
                case .circle:
                    let start = drawingPath.points[0]
                    let end = drawingPath.points.last ?? start
                    let convertedStart = convertPoint(start)
                    let convertedEnd = convertPoint(end)
                    
                    // 应用偏移量
                    let startWithOffset = CGPoint(
                        x: convertedStart.x + drawingPath.offset.x * scaleX,
                        y: convertedStart.y + drawingPath.offset.y * scaleY
                    )
                    let endWithOffset = CGPoint(
                        x: convertedEnd.x + drawingPath.offset.x * scaleX,
                        y: convertedEnd.y + drawingPath.offset.y * scaleY
                    )
                    
                    let center = CGPoint(
                        x: (startWithOffset.x + endWithOffset.x) / 2,
                        y: (startWithOffset.y + endWithOffset.y) / 2
                    )
                    let radius = sqrt(
                        pow(endWithOffset.x - startWithOffset.x, 2) +
                        pow(endWithOffset.y - startWithOffset.y, 2)
                    ) / 2
                    
                    subPath.addArc(
                        withCenter: center,
                        radius: radius,
                        startAngle: 0,
                        endAngle: .pi * 2,
                        clockwise: true
                    )
                    
                case .mouth:
                    let start = drawingPath.points[0]
                    let end = drawingPath.points.last ?? start
                    let convertedStart = convertPoint(start)
                    let convertedEnd = convertPoint(end)
                    
                    // 应用偏移量
                    let startWithOffset = CGPoint(
                        x: convertedStart.x + drawingPath.offset.x * scaleX,
                        y: convertedStart.y + drawingPath.offset.y * scaleY
                    )
                    let endWithOffset = CGPoint(
                        x: convertedEnd.x + drawingPath.offset.x * scaleX,
                        y: convertedEnd.y + drawingPath.offset.y * scaleY
                    )
                    
                    let width = abs(endWithOffset.x - startWithOffset.x)
                    let height = abs(endWithOffset.y - startWithOffset.y)
                    let rect = CGRect(
                        x: min(startWithOffset.x, endWithOffset.x),
                        y: min(startWithOffset.y, endWithOffset.y),
                        width: width,
                        height: height
                    )
                    
                    // 绘制嘴巴轮廓（M形状的上唇和弧形的下唇）
                    // 起点（左边）
                    subPath.move(to: CGPoint(x: rect.minX, y: rect.midY))
                    
                    // 上唇左半部分
                    subPath.addCurve(
                        to: CGPoint(x: rect.minX + width * 0.5, y: rect.midY - height * 0.1),
                        controlPoint1: CGPoint(x: rect.minX + width * 0.15, y: rect.midY),
                        controlPoint2: CGPoint(x: rect.minX + width * 0.35, y: rect.minY + height * 0.3)
                    )
                    
                    // 上唇右半部分
                    subPath.addCurve(
                        to: CGPoint(x: rect.maxX, y: rect.midY),
                        controlPoint1: CGPoint(x: rect.minX + width * 0.65, y: rect.minY + height * 0.3),
                        controlPoint2: CGPoint(x: rect.minX + width * 0.85, y: rect.midY)
                    )
                    
                    // 下唇
                    subPath.addCurve(
                        to: CGPoint(x: rect.minX, y: rect.midY),
                        controlPoint1: CGPoint(x: rect.maxX - width * 0.25, y: rect.maxY - height * 0.2),
                        controlPoint2: CGPoint(x: rect.minX + width * 0.25, y: rect.maxY - height * 0.2)
                    )
                    
                    subPath.close()
                    
                case .eyebrow:
                    let start = drawingPath.points[0]
                    let end = drawingPath.points.last ?? start
                    let convertedStart = convertPoint(start)
                    let convertedEnd = convertPoint(end)
                    
                    // 应用偏移量
                    let startWithOffset = CGPoint(
                        x: convertedStart.x + drawingPath.offset.x * scaleX,
                        y: convertedStart.y + drawingPath.offset.y * scaleY
                    )
                    let endWithOffset = CGPoint(
                        x: convertedEnd.x + drawingPath.offset.x * scaleX,
                        y: convertedEnd.y + drawingPath.offset.y * scaleY
                    )
                    
                    let width = abs(endWithOffset.x - startWithOffset.x)
                    let height = abs(endWithOffset.y - startWithOffset.y)
                    let rect = CGRect(
                        x: min(startWithOffset.x, endWithOffset.x),
                        y: min(startWithOffset.y, endWithOffset.y),
                        width: width,
                        height: height
                    )
                    
                    // 绘制眉毛轮廓（弧形）
                    subPath.move(to: CGPoint(x: rect.minX, y: rect.maxY))
                    subPath.addQuadCurve(
                        to: CGPoint(x: rect.maxX, y: rect.maxY),
                        controlPoint: CGPoint(x: rect.midX, y: rect.minY)
                    )
                    // 添加一点厚度
                    subPath.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY + height * 0.2))
                    subPath.addQuadCurve(
                        to: CGPoint(x: rect.minX, y: rect.maxY + height * 0.2),
                        controlPoint: CGPoint(x: rect.midX, y: rect.minY + height * 0.2)
                    )
                    subPath.close()
                }
                
                path.append(subPath)
            }
            
            // 保存当前图形状态
            context.cgContext.saveGState()
            
            // 设置路径为裁剪区域
            path.addClip()
            
            // 绘制原始图片
            sourceImage.draw(in: CGRect(origin: .zero, size: sourceImage.size))
            
            // 恢复图形状态
            context.cgContext.restoreGState()
        }
        
        print("[保存] 完成")
        
        editedImage = maskedImage
        // 保存当前状态到UserDefaults
        if let data = try? JSONEncoder().encode(EditState(paths: paths)) {
            UserDefaults.standard.set(data, forKey: editingKey)
            print("[保存] 成功保存编辑状态")
        }
        isPresented = false
        
        // 重启摄像头
        restartManager.handleRestartViewAppear(cameraManager: cameraManager)
    }
    
    // 恢复原始图片
    private func restoreOriginalImage() {
        print("------------------------")
        print("[恢复原始图片] 开始")
        print("当前路径数量: \(paths.count)")
        print("初始路径数量: \(initialPaths.count)")
        
        // 清空所有路径
        paths.removeAll()
        initialPaths.removeAll()
        currentPath = nil
        
        // 清除UserDefaults中保存的状态
        UserDefaults.standard.removeObject(forKey: editingKey)
        
        // 恢复原始图片
        editedImage = sourceImage
        
        print("[恢复原始图片] 已清空所有路径")
        print("[恢复原始图片] 已清除保存的状态")
        print("[恢复原始图片] 已设置为原始图片")
        print("清空后路径数量: \(paths.count)")
        print("清空后初始路径数量: \(initialPaths.count)")
        print("[恢复原始图片] 结束")
        
        isPresented = false  // 恢复后关闭弹窗
        
        // 重启摄像头
        restartManager.handleRestartViewAppear(cameraManager: cameraManager)
    }
    
    // 重置
    func reset() {
        print("------------------------")
        print("[重置] 开始")
        print("当前路径数量: \(paths.count)")
        
        // 清空当前路径
        paths.removeAll()
        currentPath = nil
        print("[重置] 已清空当前路径")
        
        print("[重置] 结束")
        print("当前路径数量: \(paths.count)")
    }
}

#Preview {
    ImageEditView(
        sourceImage: UIImage(systemName: "photo")!,
        editedImage: .constant(nil),
        editingKey: "preview",
        isPresented: .constant(true),
        cameraManager: CameraManager()
    )
} 