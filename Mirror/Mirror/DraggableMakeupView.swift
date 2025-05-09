import SwiftUI
import PhotosUI

// 添加主题变化的观察者类
class ThemeObserver: NSObject {
    var styleManager = BorderLightStyleManager.shared
    
    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleThemeChange),
            name: NSNotification.Name("UpdateButtonColors"),
            object: nil
        )
    }
    
    @objc func handleThemeChange() {
        print("------------------------")
        print("[化妆视图] 接收到主题颜色变化通知")
        print("当前主题颜色：\(styleManager.iconColor)")
        print("------------------------")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

struct DraggableMakeupView: View {
    @Binding var isVisible: Bool
    @State private var position = CGPoint(x: UIScreen.main.bounds.width / 2, y: 200)
    @State private var dragOffset = CGSize.zero
    @State private var selectedImage: UIImage?
    @State private var originalImage: UIImage?
    @State private var showImagePicker = false
    @State private var isEditing: Bool = false
    @State private var showImageEditor = false
    @StateObject private var permissionManager = PermissionManager.shared
    @StateObject private var proManager = ProManager.shared  // 添加 ProManager 引用
    @State private var isSimplifiedMode: Bool = false  // 添加简化模式状态
    @StateObject private var restartManager = ContentRestartManager.shared  // 添加 RestartManager 引用
    let cameraManager: CameraManager  // 添加 CameraManager 引用
    
    // 使用DeviceOrientationManager替代原有的设备方向控制
    @StateObject private var orientationManager = DeviceOrientationManager.shared
    
    // 添加图片缩放和位置状态
    @State private var imageScale: CGFloat = 1.0
    @State private var lastImageScale: CGFloat = 1.0
    @State private var imageOffset: CGSize = .zero
    @State private var lastImageOffset: CGSize = .zero
    
    // 添加主题管理器
    @ObservedObject private var styleManager = BorderLightStyleManager.shared
    
    // 处理主题变化的通知观察者
    private let themeObserver = ThemeObserver()
    
    // 添加CaptureManager引用
    @ObservedObject private var captureManager = CaptureManager.shared
    
    // 定义视图尺寸
    private let totalWidth: CGFloat = 240
    private let totalHeight: CGFloat = 240
    
    // 定义缩放限制
    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 10.0
    
    // 计算各区域高度
    private var topAreaHeight: CGFloat { totalHeight / 8 }
    private var bottomAreaHeight: CGFloat { totalHeight / 8 }
    private var centerAreaHeight: CGFloat { totalHeight / 8 * 6 }
    
    // 计算视图宽高比
    private var viewAspectRatio: CGFloat { totalWidth / centerAreaHeight }
    
    // 移动边界矩形参数
    @State private var movableBoundsRect: CGRect = .zero
    
    // 添加记录图片上传时的设备方向
    @State private var imageUploadOrientation: UIDeviceOrientation = .portrait
    
    // 计算图片初始尺寸
    private func calculateInitialImageSize(_ image: UIImage) -> (width: CGFloat, height: CGFloat) {
        let imageAspectRatio = image.size.width / image.size.height
        
        print("------------------------")
        print("[化妆视图] 计算图片尺寸")
        print("原始尺寸：\(image.size.width) x \(image.size.height)")
        print("原始比例：\(imageAspectRatio)")
        print("视图比例：\(viewAspectRatio)")
        print("------------------------")
        
        if imageAspectRatio > viewAspectRatio {
            // 图片较宽，高度匹配
            let height = centerAreaHeight
            let width = height * imageAspectRatio
            print("调整后尺寸：\(width) x \(height)")
            print("------------------------")
            return (width, height)
        } else {
            // 图片较高，宽度匹配
            let width = totalWidth
            let height = width / imageAspectRatio
            print("调整后尺寸：\(width) x \(height)")
            print("------------------------")
            return (width, height)
        }
    }
    
    // 计算设备方向对应的旋转角度
    private func calculateRotationAngle(_ orientation: UIDeviceOrientation) -> Angle {
        return orientationManager.getRotationAngle(orientation)
    }
    
    // 修改计算相对旋转角度的方法
    private func calculateRelativeRotationAngle(from sourceOrientation: UIDeviceOrientation, to targetOrientation: UIDeviceOrientation) -> Angle {
        print("------------------------")
        print("[旋转角度计算]")
        print("源方向：\(sourceOrientation.rawValue)")
        print("目标方向：\(targetOrientation.rawValue)")
        
        let sourceAngle = calculateRotationAngle(sourceOrientation)
        let targetAngle = calculateRotationAngle(targetOrientation)
        let relativeAngle = targetAngle - sourceAngle
        
        print("源角度：\(sourceAngle.degrees)°")
        print("目标角度：\(targetAngle.degrees)°")
        print("相对角度：\(relativeAngle.degrees)°")
        print("------------------------")
        
        return relativeAngle
    }
    
    // 添加生成模拟图片的方法
    private func generateSimulatedMakeupImage() -> UIImage? {
        let screenSize = UIScreen.main.bounds.size
        let safeAreaInsets = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets ?? .zero
        
        // 创建绘图上下文，设置透明背景
        let renderer = UIGraphicsImageRenderer(size: screenSize, format: {
            let format = UIGraphicsImageRendererFormat()
            format.opaque = false // 设置非不透明，支持透明通道
            return format
        }())
        
        let image = renderer.image { ctx in
            // 清除背景（完全透明）
            UIColor.clear.setFill()
            ctx.fill(CGRect(origin: .zero, size: screenSize))
            
            // 获取当前有效的设备方向
            let currentOrientation = orientationManager.validOrientation
            
            // 根据设备方向确定矩形尺寸
            let isLandscape = currentOrientation.isLandscape
            let rectWidth: CGFloat = isLandscape ? 180 : 240  // 横屏时宽度变小
            let rectHeight: CGFloat = isLandscape ? 240 : 180  // 横屏时高度变大
            
            // 计算矩形中心点相对于屏幕的偏移比例
            let centerX = position.x
            let centerY = position.y
            let screenCenterX = screenSize.width / 2
            let screenCenterY = screenSize.height / 2
            
            // 计算偏移量（考虑安全区域）
            let offsetX = centerX - screenCenterX
            let offsetY = centerY - screenCenterY + safeAreaInsets.top
            
            // 计算矩形位置（考虑偏移）
            let rectX = (screenSize.width - rectWidth) / 2 + offsetX
            let rectY = (screenSize.height - rectHeight) / 2 + offsetY
            
            // 绘制黑色矩形（半透明）
            UIColor.black.withAlphaComponent(0).setFill()
            ctx.fill(CGRect(x: rectX, y: rectY, width: rectWidth, height: rectHeight))
            
            // 如果有选中的图片，在黑色矩形上绘制图片
            if let selectedImage = selectedImage {
                // 计算图片在视图中的实际位置和大小
                let imageSize = calculateInitialImageSize(selectedImage)
                let scaledWidth = imageSize.width * imageScale
                let scaledHeight = imageSize.height * imageScale
                
                // 保存当前上下文状态
                ctx.cgContext.saveGState()
                
                // 创建裁剪路径（矩形区域，无圆角）
                let clipPath = UIBezierPath(
                    rect: CGRect(
                        x: rectX,
                        y: rectY,
                        width: rectWidth,
                        height: rectHeight
                    )
                )
                clipPath.addClip()
                
                // 计算图片的绘制区域（考虑缩放和偏移）
                let imageRect = CGRect(
                    x: rectX + (rectWidth - scaledWidth)/2 + imageOffset.width,
                    y: rectY + (rectHeight - scaledHeight)/2 + imageOffset.height,
                    width: scaledWidth,
                    height: scaledHeight
                )
                
                // 计算相对旋转角度（当前方向相对于上传时的方向）
                let relativeRotationAngle = calculateRelativeRotationAngle(
                    from: imageUploadOrientation,
                    to: currentOrientation
                )
                
                // 设置旋转中心点
                let rotationCenter = CGPoint(
                    x: rectX + rectWidth/2,
                    y: rectY + rectHeight/2
                )
                
                // 应用旋转变换
                ctx.cgContext.translateBy(x: rotationCenter.x, y: rotationCenter.y)
                ctx.cgContext.rotate(by: relativeRotationAngle.radians)
                ctx.cgContext.translateBy(x: -rotationCenter.x, y: -rotationCenter.y)
                
                // 绘制图片（保持原始透明度）
                selectedImage.draw(in: imageRect, blendMode: .normal, alpha: 1.0)
                
                // 恢复上下文状态
                ctx.cgContext.restoreGState()
                
                print("------------------------")
                print("[化妆视图] 生成模拟图片")
                print("屏幕尺寸：\(screenSize.width) x \(screenSize.height)")
                print("安全区域：top=\(safeAreaInsets.top), bottom=\(safeAreaInsets.bottom)")
                print("视图位置：x=\(centerX), y=\(centerY)")
                print("矩形位置：x=\(rectX), y=\(rectY)")
                print("矩形尺寸：\(rectWidth) x \(rectHeight)")
                print("图片尺寸：\(scaledWidth) x \(scaledHeight)")
                print("图片偏移：x=\(imageOffset.width), y=\(imageOffset.height)")
                print("上传方向：\(imageUploadOrientation.rawValue)")
                print("当前方向：\(currentOrientation.rawValue)")
                print("相对旋转角度：\(relativeRotationAngle.degrees)°")
                print("------------------------")
            } else {
                print("------------------------")
                print("[化妆视图] 生成模拟图片")
                print("状态：无图片")
                print("位置：x=\(centerX), y=\(centerY)")
                print("矩形：\(rectX), \(rectY), \(rectWidth) x \(rectHeight)")
                print("------------------------")
            }
        }
        
        return image
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 添加半透明红色矩形显示可移动范围
                Rectangle()
                    .stroke(Color.red.opacity(0), lineWidth: 2)
                    .background(Color.clear)
                    .frame(width: geometry.size.width - totalWidth, height: geometry.size.height - totalHeight)
                    .position(x: geometry.size.width/2, y: geometry.size.height/2)
                    .allowsHitTesting(false)
                    .onAppear {
                        let minX = totalWidth/2
                        let maxX = geometry.size.width - totalWidth/2
                        let minY = totalHeight/2
                        let maxY = geometry.size.height - totalHeight/2
                        
                        movableBoundsRect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
                        
                        print("------------------------")
                        print("[可移动范围] 初始化")
                        print("左上角：(\(minX), \(minY))")
                        print("右下角：(\(maxX), \(maxY))")
                        print("矩形大小：\(maxX - minX) x \(maxY - minY)")
                        print("------------------------")
                        
                        print("------------------------")
                        print("[化妆视图] 初始化位置")
                        print("位置：x=\(position.x), y=\(position.y)")
                        print("------------------------")
                        
                        // 设置设备方向监听
                        setupOrientationNotification()
                    }
                
                VStack(spacing: 0) {
                    // 上区 - 保持结构但在简化模式下透明且不可交互
                    HStack {
                        Spacer()
                        if selectedImage != nil {
                            Button(action: {
                                if !isSimplifiedMode {
                                    showImageEditor = true
                                    print("------------------------")
                                    print("[化妆视图] 编辑按钮点击")
                                    print("显示图片编辑器")
                                    print("------------------------")
                                    
                                    // 关闭摄像头
                                    restartManager.isCameraActive = false
                                    restartManager.showRestartHint = true
                                }
                            }) {
                                Image(systemName: "pencil.and.outline")
                                    .font(.system(size: 20))
                                    .foregroundColor(isSimplifiedMode ? .clear : styleManager.iconColor)
                            }
                            .frame(width: 40, height: topAreaHeight)
                            .contentShape(Rectangle())
                            .allowsHitTesting(!isSimplifiedMode)
                        }
                        Button(action: {
                            if !isSimplifiedMode {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isVisible = false
                                }
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(isSimplifiedMode ? .clear : styleManager.iconColor)
                        }
                        .frame(width: 40, height: topAreaHeight)
                        .contentShape(Rectangle())
                        .allowsHitTesting(!isSimplifiedMode)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: topAreaHeight)
                    .background(isSimplifiedMode ? Color.clear : Color.black.opacity(0.15))
                    .zIndex(2)
                    
                    // 中央区 - 显示选择的图片或上传按钮
                    ZStack {
                        if let image = selectedImage {
                            let imageSize = calculateInitialImageSize(image)
                            GeometryReader { imageGeometry in
                                ZStack {
                                    // 触控区层
                                    Color.black.opacity(0.01)
                                        .frame(width: totalWidth, height: centerAreaHeight)
                                        .background(Color.clear)
                                        .contentShape(Rectangle())
                                        .onAppear {
                                            print("------------------------")
                                            print("[触控区] 初始化")
                                            print("触控区大小：\(totalWidth) x \(centerAreaHeight)")
                                            print("触控区位置：x=\(totalWidth/2), y=\(centerAreaHeight/2)")
                                            print("------------------------")
                                        }
                                        .gesture(
                                            DragGesture()
                                                .onChanged { value in
                                                    let translation = value.translation
                                                    // 计算边界限制
                                                    let scaledWidth = imageSize.width * imageScale
                                                    let scaledHeight = imageSize.height * imageScale
                                                    let maxOffsetX = max(0, (scaledWidth - totalWidth) / 2)
                                                    let maxOffsetY = max(0, (scaledHeight - centerAreaHeight) / 2)
                                                    
                                                    let proposedX = lastImageOffset.width + translation.width
                                                    let proposedY = lastImageOffset.height + translation.height
                                                    
                                                    imageOffset = CGSize(
                                                        width: max(-maxOffsetX, min(maxOffsetX, proposedX)),
                                                        height: max(-maxOffsetY, min(maxOffsetY, proposedY))
                                                    )
                                                    
                                                    // 更新模拟图片
                                                    if captureManager.isMakeupViewActive {
                                                        captureManager.makeupImage = generateSimulatedMakeupImage()
                                                    }
                                                }
                                                .onEnded { _ in
                                                    lastImageOffset = imageOffset
                                                }
                                        )
                                        .simultaneousGesture(
                                            MagnificationGesture()
                                                .onChanged { value in
                                                    let proposedScale = value.magnitude * lastImageScale
                                                    imageScale = min(max(proposedScale, minScale), maxScale)
                                                    
                                                    // 在缩放改变时重新计算位置边界
                                                    let scaledWidth = imageSize.width * imageScale
                                                    let scaledHeight = imageSize.height * imageScale
                                                    let maxOffsetX = max(0, (scaledWidth - totalWidth) / 2)
                                                    let maxOffsetY = max(0, (scaledHeight - centerAreaHeight) / 2)
                                                    
                                                    imageOffset = CGSize(
                                                        width: max(-maxOffsetX, min(maxOffsetX, imageOffset.width)),
                                                        height: max(-maxOffsetY, min(maxOffsetY, imageOffset.height))
                                                    )
                                                    
                                                    // 更新模拟图片
                                                    if captureManager.isMakeupViewActive {
                                                        captureManager.makeupImage = generateSimulatedMakeupImage()
                                                    }
                                                }
                                                .onEnded { _ in
                                                    lastImageScale = imageScale
                                                }
                                        )
                                        .zIndex(10) // 提高触控区的层级
                                    
                                    // 图片层
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: imageSize.width, height: imageSize.height)
                                        .scaleEffect(imageScale)
                                        .offset(x: imageOffset.width, y: imageOffset.height)
                                        .clipped()
                                        .allowsHitTesting(false) // 让图片层穿透手势事件
                                        .onAppear {
                                            print("------------------------")
                                            print("[图片层] 初始化")
                                            print("图片大小：\(imageSize.width) x \(imageSize.height)")
                                            print("当前缩放：\(imageScale)")
                                            print("当前偏移：\(imageOffset)")
                                            print("------------------------")
                                        }
                                }
                                .position(x: totalWidth/2, y: centerAreaHeight/2)
                            }
                            .frame(width: totalWidth, height: centerAreaHeight)
                            .clipped()
                        } else {
                            Button(action: {
                                if proManager.isPro {
                                    checkAndRequestPhotoAccess()
                                } else {
                                    print("------------------------")
                                    print("[化妆视图] 点击上传按钮")
                                    print("状态：需要升级")
                                    print("动作：显示升级弹窗")
                                    print("------------------------")
                                    proManager.showProUpgrade()
                                }
                            }) {
                                VStack(spacing: 10) {
                                    if !proManager.isPro {
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 30))
                                            .foregroundColor(styleManager.iconColor)
                                            .padding(.bottom, 0)
                                    }
                                    Image(systemName: "photo.badge.plus")
                                        .font(.system(size: 30))
                                        .foregroundColor(styleManager.iconColor.opacity(proManager.isPro ? 1 : 0.5))
                                    if !isSimplifiedMode {
                                        Text(proManager.isPro ? "上传图片" : "上传图片")
                                            .foregroundColor(styleManager.iconColor.opacity(proManager.isPro ? 1 : 0.5))
                                            .font(.system(size: 16))
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(isSimplifiedMode ? Color.clear : Color.black.opacity(0.4))
                        }
                    }
                    .frame(width: totalWidth, height: centerAreaHeight)
                    .background(isSimplifiedMode ? Color.clear : Color.black.opacity(0.4))
                    .clipped()
                    
                    // 下区 - 拖拽区域，始终显示但根据模式调整样式
                    HStack {
                        Image("icon-star")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .foregroundColor(styleManager.iconColor.opacity(0.9))
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isSimplifiedMode.toggle()
                                    print("------------------------")
                                    print("[化妆视图] 切换显示模式")
                                    print("当前模式：\(isSimplifiedMode ? "简化" : "完整")")
                                    print("------------------------")
                                }
                            }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: bottomAreaHeight)
                    .background(isSimplifiedMode ? Color.clear : Color.black.opacity(0.15))
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .global)
                            .onChanged { value in
                                let translation = value.translation
                                let newX = position.x + translation.width - dragOffset.width
                                let newY = position.y + translation.height - dragOffset.height
                                
                                // 计算边界
                                let minX = totalWidth/2
                                let maxX = geometry.size.width - totalWidth/2
                                let minY = totalHeight/2
                                let maxY = geometry.size.height - totalHeight/2
                                
                                // 应用边界限制
                                position.x = min(max(newX, minX), maxX)
                                position.y = min(max(newY, minY), maxY)
                                
                                dragOffset = translation
                                
                                print("------------------------")
                                print("[化妆视图] 拖动中")
                                print("当前位置：x=\(position.x), y=\(position.y)")
                                print("------------------------")
                            }
                            .onEnded { _ in
                                dragOffset = .zero
                                
                                print("------------------------")
                                print("[化妆视图] 拖动结束")
                                print("最终位置：x=\(position.x), y=\(position.y)")
                                print("------------------------")
                            }
                    )
                    .zIndex(1)
                }
                .frame(width: totalWidth, height: totalHeight)
                .cornerRadius(12)
                .shadow(radius: isSimplifiedMode ? 0 : 10)  // 简化模式下移除阴影
                .background(isSimplifiedMode ? Color.clear : Color.black.opacity(0.15))  // 简化模式下移除背景
                .rotationEffect(orientationManager.getRotationAngle(orientationManager.validOrientation))
                .position(x: position.x, y: position.y)
                .customPopup(isPresented: $showImageEditor) {
                    if let original = originalImage {
                        ImageEditView(
                            sourceImage: original,
                            editedImage: $selectedImage,
                            editingKey: "makeup_edit_\(original.hashValue)",
                            isPresented: $showImageEditor,
                            cameraManager: cameraManager
                        )
                    }
                }
                
                // 添加视图位置标记点（不跟随旋转）
                Circle()
                    .fill(Color.red.opacity(0))
                    .frame(width: 6, height: 6)
                    .position(x: position.x, y: position.y)
            }
        }
        .sheet(isPresented: $showImagePicker) {
            PhotoPicker(
                selectedImage: $selectedImage,
                originalImage: $originalImage,
                imageUploadOrientation: $imageUploadOrientation
            )
        }
        .onChange(of: selectedImage) { _ in
            // 重置图片状态
            imageScale = 1.0
            lastImageScale = 1.0
            imageOffset = .zero
            lastImageOffset = .zero
            
            // 更新CaptureManager中的化妆图片
            if let _ = selectedImage {
                // 使用模拟图片替代实际选择的图片
                captureManager.makeupImage = generateSimulatedMakeupImage()
                captureManager.isMakeupViewActive = true
            } else {
                captureManager.makeupImage = nil
                captureManager.isMakeupViewActive = false
            }
        }
        .onChange(of: position) { newPosition in
            // 当视图位置改变时，更新模拟图片
            if captureManager.isMakeupViewActive {
                captureManager.makeupImage = generateSimulatedMakeupImage()
            }
        }
        .onChange(of: orientationManager.validOrientation) { newOrientation in
            // 当设备方向改变时，更新模拟图片
            if captureManager.isMakeupViewActive {
                captureManager.makeupImage = generateSimulatedMakeupImage()
                print("------------------------")
                print("[化妆视图] 设备方向变化")
                print("新方向：\(newOrientation.rawValue)")
                print("------------------------")
            }
        }
        .onChange(of: isVisible) { newValue in
            print("------------------------")
            print("[化妆视图] 状态变化")
            print("新状态：\(newValue ? "开启" : "关闭")")
            print("------------------------")
            
            if !newValue {
                // 当视图关闭时清理图片缓存
                cleanupImageCache()
                CaptureManager.shared.isMakeupViewActive = false
                CaptureManager.shared.makeupImage = nil
            } else {
                CaptureManager.shared.isMakeupViewActive = true
            }
        }
        .onAppear {
            // 注意：setupOrientationNotification 已在初始化时调用
            CaptureManager.shared.isMakeupViewActive = true
        }
        .onDisappear {
            // 清理旋转通知和图片缓存
            NotificationCenter.default.removeObserver(
                UIDevice.orientationDidChangeNotification
            )
            cleanupImageCache()
            CaptureManager.shared.isMakeupViewActive = false
            CaptureManager.shared.makeupImage = nil
        }
    }
    
    private func checkAndRequestPhotoAccess() {
        permissionManager.checkPhotoLibraryPermission { granted in
            if granted {
                showImagePicker = true
            }
        }
    }
    
    // 设置设备方向变化监听
    private func setupOrientationNotification() {
        // 不再需要自己处理设备方向变化，因为DeviceOrientationManager已经处理了
        if !UIDevice.current.isGeneratingDeviceOrientationNotifications {
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        }
    }
    
    // 添加清理图片缓存的方法
    private func cleanupImageCache() {
        print("------------------------")
        print("[化妆视图] 清理图片缓存")
        if selectedImage != nil {
            print("状态：清理选中的图片")
        } else {
            print("状态：无需清理（没有选中的图片）")
        }
        print("------------------------")
        
        // 清理选中的图片和原始图片
        selectedImage = nil
        originalImage = nil
        
        // 重置图片相关状态
        imageScale = 1.0
        lastImageScale = 1.0
        imageOffset = .zero
        lastImageOffset = .zero
        
        // 清除编辑状态
        if let original = originalImage {
            UserDefaults.standard.removeObject(forKey: "makeup_edit_\(original.hashValue)")
        }
    }
}

// 扩展 UIDeviceOrientation，添加判断有效界面方向的方法
extension UIDeviceOrientation {
    var isValidInterfaceOrientation: Bool {
        return self == .portrait || self == .portraitUpsideDown || 
               self == .landscapeLeft || self == .landscapeRight
    }
}

// 修改图片选择器结构体名称避免冲突
struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Binding var originalImage: UIImage?
    @Binding var imageUploadOrientation: UIDeviceOrientation  // 添加绑定属性
    @Environment(\.presentationMode) private var presentationMode
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker
        
        init(_ parent: PhotoPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.presentationMode.wrappedValue.dismiss()
            
            guard let provider = results.first?.itemProvider else {
                print("------------------------")
                print("[化妆视图] 图片选择失败")
                print("原因：未选择图片")
                print("------------------------")
                return
            }
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            print("------------------------")
                            print("[化妆视图] 图片加载失败")
                            print("错误信息：\(error.localizedDescription)")
                            print("------------------------")
                            return
                        }
                        
                        if let image = image as? UIImage {
                            print("------------------------")
                            print("[化妆视图] 图片上传成功")
                            print("图片尺寸：\(image.size.width) x \(image.size.height)")
                            print("图片比例：\(image.size.width / image.size.height)")
                            print("上传时设备方向：\(DeviceOrientationManager.shared.validOrientation.rawValue)")
                            print("------------------------")
                            
                            self.parent.selectedImage = image
                            self.parent.originalImage = image
                            // 记录上传时的设备方向，使用 orientationManager 的有效方向
                            self.parent.imageUploadOrientation = DeviceOrientationManager.shared.validOrientation
                        }
                    }
                }
            } else {
                print("------------------------")
                print("[化妆视图] 图片选择失败")
                print("原因：无法加载图片")
                print("------------------------")
            }
        }
    }
}

#Preview {
    DraggableMakeupView(isVisible: .constant(true), cameraManager: CameraManager())
        .background(Color.gray)
} 
