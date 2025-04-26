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
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        // 检查点是否在显示区域内
                        guard displayFrame.contains(value.location) else { return }
                        
                        let location = value.location
                        
                        print("------------------------")
                        print("[绘画] 触摸位置")
                        print("原始位置：\(value.location)")
                        print("显示区域：\(displayFrame)")
                        print("图片区域：\(imageFrame)")
                        print("------------------------")
                        
                        if currentPath == nil {
                            currentPath = DrawingPath(points: [location], tool: tool)
                        } else {
                            currentPath?.points.append(location)
                        }
                    }
                    .onEnded { value in
                        if let path = currentPath {
                            if tool == .brush && !path.points.isPathClosed() {
                                // 如果是画笔工具且路径未闭合，显示提示
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
        guard !path.points.isEmpty else { return }
        
        // 判断路径是否闭合
        let isPathComplete: Bool
        switch path.tool {
        case .brush:
            isPathComplete = path.points.isPathClosed()
        case .rectangle, .circle:
            isPathComplete = path.points.count >= 2
        }
        
        // 设置绘制颜色
        let drawingColor: Color = isPathComplete ? .blue : .red
        
        // 创建绘制路径
        let drawPath = Path { p in
            switch path.tool {
            case .brush:
                p.move(to: path.points[0])
                for point in path.points.dropFirst() {
                    p.addLine(to: point)
                }
                if isPathComplete {
                    p.closeSubpath()
                }
                
            case .rectangle:
                let start = path.points[0]
                let end = path.points.last ?? start
                let rect = CGRect(
                    x: min(start.x, end.x),
                    y: min(start.y, end.y),
                    width: abs(end.x - start.x),
                    height: abs(end.y - start.y)
                )
                p.addRect(rect)
                
            case .circle:
                let start = path.points[0]
                let end = path.points.last ?? start
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
            }
        }
        
        // 如果路径闭合，先填充
        if isPathComplete {
            context.fill(drawPath, with: .color(drawingColor.opacity(0.2)))
        }
        
        // 绘制边框
        context.stroke(drawPath, with: .color(drawingColor), lineWidth: 2)
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
    @Environment(\.dismiss) private var dismiss
    
    // 当前编辑状态
    @State private var paths: [DrawingPath] = []
    @State private var currentPath: DrawingPath?
    @State private var selectedTool: ImageSelectionTool = .brush
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showResetAlert = false
    @State private var showCancelAlert = false
    @State private var initialPaths: [DrawingPath] = []  // 添加初始路径状态
    
    // 初始化时加载编辑状态
    init(sourceImage: UIImage, editedImage: Binding<UIImage?>, editingKey: String) {
        self.sourceImage = sourceImage
        self._editedImage = editedImage
        self.editingKey = editingKey
        
        // 如果editedImage不为nil，说明之前保存过，需要加载上次的状态
        if editedImage.wrappedValue != nil,
           let data = UserDefaults.standard.data(forKey: editingKey),
           let state = try? JSONDecoder().decode(EditState.self, from: data) {
            self._paths = State(initialValue: state.paths)
            self._initialPaths = State(initialValue: state.paths)  // 保存初始状态
        } else {
            // 如果editedImage为nil，说明是首次编辑，不加载任何状态
            self._paths = State(initialValue: [])
            self._initialPaths = State(initialValue: [])  // 初始状态为空
        }
    }
    
    // 取消编辑，恢复到初始状态
    private func cancelEditing() {
        print("------------------------")
        print("[取消编辑] 开始")
        print("当前路径数量: \(paths.count)")
        print("初始路径数量: \(initialPaths.count)")
        
        // 恢复到初始状态
        paths = initialPaths
        currentPath = nil
        
        print("[取消编辑] 已恢复到初始状态")
        print("恢复后路径数量: \(paths.count)")
        print("[取消编辑] 结束")
        
        dismiss()
    }
    
    // 保存状态
    func saveState() {
        print("------------------------")
        print("[保存状态] 开始")
        print("当前路径数量: \(paths.count)")
        
        // 保存到UserDefaults
        if let data = try? JSONEncoder().encode(EditState(paths: paths)) {
            UserDefaults.standard.set(data, forKey: editingKey)
            print("[保存状态] 成功保存到UserDefaults")
        } else {
            print("[保存状态] 编码失败")
        }
        
        print("[保存状态] 结束")
        print("当前路径数量: \(paths.count)")
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
        
        dismiss()
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // 工具栏
                HStack(spacing: 20) {
                    // 画笔工具
                    Button(action: { selectedTool = .brush }) {
                        Image(systemName: "pencil")
                            .foregroundColor(selectedTool == .brush ? .blue : .gray)
                    }
                    
                    // 矩形工具
                    Button(action: { selectedTool = .rectangle }) {
                        Image(systemName: "rectangle")
                            .foregroundColor(selectedTool == .rectangle ? .blue : .gray)
                    }
                    
                    // 圆形工具
                    Button(action: { selectedTool = .circle }) {
                        Image(systemName: "circle")
                            .foregroundColor(selectedTool == .circle ? .blue : .gray)
                    }
                    
                    Spacer()
                    
                    // 重置按钮
                    Button(action: { showResetAlert = true }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
                .padding()
                
                // 绘制区域
                DrawingCanvas(
                    image: sourceImage,
                    paths: $paths,
                    currentPath: $currentPath,
                    tool: selectedTool,
                    showAlert: $showAlert,
                    alertMessage: $alertMessage
                )
                .padding()
                .onChange(of: paths) { _ in
                    // 每当paths发生变化时打印日志
                    print("------------------------")
                    print("[路径变化] 当前路径数量: \(paths.count)")
                    print("[路径变化] 初始路径数量: \(initialPaths.count)")
                }
            }
            .navigationBarItems(
                leading: Button("取消") {
                    showCancelAlert = true
                },
                trailing: Button(paths.isEmpty ? "恢复图片" : "保存") {
                    if paths.isEmpty {
                        restoreOriginalImage()
                    } else {
                        saveImage()
                    }
                }
            )
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
    }
    
    private func saveImage() {
        guard !paths.isEmpty else {
            showAlert = true
            alertMessage = "请至少绘制一个区域"
            return
        }
        
        print("[保存] 开始处理图片")
        print("[保存] 原始图片尺寸: \(sourceImage.size)")
        
        // 使用固定的4:3显示区域
        let displayWidth: CGFloat = 329.0  // 固定与绘制时相同的宽度
        let displayHeight = displayWidth * 4 / 3
        
        let displayFrame = CGRect(
            x: 16,
            y: 80.33333333333334,  // 固定与绘制时相同的Y坐标
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
                
                // 转换坐标的辅助函数
                func convertPoint(_ point: CGPoint) -> CGPoint {
                    let relativeX = point.x - imageFrame.minX
                    let relativeY = point.y - imageFrame.minY
                    return CGPoint(
                        x: relativeX * scaleX,
                        y: relativeY * scaleY
                    )
                }
                
                let subPath = UIBezierPath()
                
                switch drawingPath.tool {
                case .brush:
                    let firstPoint = convertPoint(drawingPath.points[0])
                    subPath.move(to: firstPoint)
                    
                    for point in drawingPath.points.dropFirst() {
                        subPath.addLine(to: convertPoint(point))
                    }
                    
                    // 检查路径是否闭合
                    if drawingPath.points.isPathClosed() {
                        subPath.close()
                    }
                    
                case .rectangle:
                    let start = drawingPath.points[0]
                    let end = drawingPath.points.last ?? start
                    let convertedStart = convertPoint(start)
                    let convertedEnd = convertPoint(end)
                    
                    let rect = CGRect(
                        x: min(convertedStart.x, convertedEnd.x),
                        y: min(convertedStart.y, convertedEnd.y),
                        width: abs(convertedEnd.x - convertedStart.x),
                        height: abs(convertedEnd.y - convertedStart.y)
                    )
                    subPath.append(UIBezierPath(rect: rect))
                    
                case .circle:
                    let start = drawingPath.points[0]
                    let end = drawingPath.points.last ?? start
                    
                    // 先计算相对坐标
                    let relativeStart = CGPoint(
                        x: start.x - imageFrame.minX,
                        y: start.y - imageFrame.minY
                    )
                    let relativeEnd = CGPoint(
                        x: end.x - imageFrame.minX,
                        y: end.y - imageFrame.minY
                    )
                    
                    // 计算圆心和半径（使用相对坐标）
                    let center = CGPoint(
                        x: (relativeStart.x + relativeEnd.x) / 2 * scaleX,
                        y: (relativeStart.y + relativeEnd.y) / 2 * scaleY
                    )
                    let radius = sqrt(
                        pow(relativeEnd.x - relativeStart.x, 2) +
                        pow(relativeEnd.y - relativeStart.y, 2)
                    ) / 2 * scaleX
                    
                    subPath.addArc(
                        withCenter: center,
                        radius: radius,
                        startAngle: 0,
                        endAngle: .pi * 2,
                        clockwise: true
                    )
                }
                
                // 将子路径添加到主路径
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
        dismiss()
    }
}

#Preview {
    ImageEditView(
        sourceImage: UIImage(systemName: "photo")!,
        editedImage: .constant(nil),
        editingKey: "preview"
    )
} 