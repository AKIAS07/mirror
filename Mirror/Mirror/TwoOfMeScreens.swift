import SwiftUI
import AVFoundation

// 定义屏幕ID
enum ScreenID {
    case original
    case mirrored
    
    var debugColor: Color {
        switch self {
        case .original:
            return Color.yellow.opacity(0.3)
        case .mirrored:
            return Color.red.opacity(0.3)
        }
    }
    
    var debugName: String {
        switch self {
        case .original:
            return "Original"
        case .mirrored:
            return "Mirrored"
        }
    }
}

struct ScreenContainer: View {
    let screenID: ScreenID
    let content: AnyView
    
    var body: some View {
        ZStack {
            // 底层：相机内容
            content
                .frame(height: UIScreen.main.bounds.height / 2)
            
            // 调试颜色层
            Rectangle()
                .fill(screenID.debugColor)
                .frame(height: UIScreen.main.bounds.height / 2)
        }
    }
}

struct ButtonContainer: View {
    let width: CGFloat
    let onSwapTapped: () -> Void
    
    var body: some View {
        // 黑色容器
        ZStack {
            // 背景
            Rectangle()
                .fill(Color.black)
                .frame(width: width, height: 60)
            
            // 交换图标按钮（扩大点击区域）
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 24, weight: .bold))  // 加大图标
                .foregroundColor(.white)
                .frame(width: 60, height: 60)  // 扩大框架
                .contentShape(Rectangle())  // 扩大点击区域
                .onTapGesture {
                    print("------------------------")
                    print("交换按钮被点击")
                    print("点击区域：60x60pt")
                    print("------------------------")
                    onSwapTapped()
                }
                .background(
                    // 可选：添加一个微弱的发光效果
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 40, height: 40)
                        .blur(radius: 5)
                )
        }
    }
}

struct TwoOfMeScreens: View {
    @StateObject private var cameraManager = CameraManager()
    @State private var originalImage: UIImage?
    @State private var mirroredImage: UIImage?
    @State private var containerWidth: CGFloat = 0
    @State private var showContainer = false
    @State private var isScreensSwapped = false
    @State private var isOriginalPaused = false  // Original画面定格状态
    @State private var isMirroredPaused = false  // Mirrored画面定格状态
    @State private var pausedOriginalImage: UIImage?  // 存储Original定格画面
    @State private var pausedMirroredImage: UIImage?  // 存储Mirrored定格画面
    
    // 触控区域可点击状态
    @State private var isZone1Enabled = true
    @State private var isZone2Enabled = true
    @State private var isZone3Enabled = true
    
    // 添加计算属性来获取当前布局状态描述
    private var layoutDescription: String {
        if !isScreensSwapped {
            return "Original在上，Mirrored在下"
        } else {
            return "Mirrored在上，Original在下"
        }
    }
    
    // Original 屏幕的状态
    @State private var originalScale: CGFloat = 1.0
    @State private var currentScale: CGFloat = 1.0  // 保持原来的名字
    
    // Mirrored 屏幕的状态
    @State private var mirroredScale: CGFloat = 1.0
    @State private var currentMirroredScale: CGFloat = 1.0
    
    @State private var lastScale: CGFloat = 1.0  // 添加记录上次缩放值的状态
    @State private var lastOutputTime: Date = Date()  // 添加上次输出时间记录
    private let outputInterval: TimeInterval = 0.2  // 设置输出时间间隔（秒）
    
    // 添加缩放限制常量
    private let minScale: CGFloat = 1.0     // 最小100%
    private let maxScale: CGFloat = 10.0    // 最大1000%
    
    @State private var showScaleLimitMessage = false  // 添加限制提示状态
    @State private var scaleLimitMessage = ""  // 添加限制提示信息
    
    // 封装缩放处理方法
    private func handlePinchGesture(
        scale: CGFloat,
        screenID: ScreenID,
        baseScale: CGFloat,
        currentScale: inout CGFloat  // 使用 inout 参数来修改当前缩放值
    ) {
        let newScale = baseScale * scale
        
        // 检查缩放限制
        if newScale >= maxScale && scale > 1.0 {
            currentScale = maxScale
            if !showScaleLimitMessage {
                print("------------------------")
                print("已放大至最大尺寸")
                print("------------------------")
                showScaleLimitMessage = true
                scaleLimitMessage = "已放大至最大尺寸"
            }
        } else if newScale <= minScale && scale < 1.0 {
            currentScale = minScale
            if !showScaleLimitMessage {
                print("------------------------")
                print("已缩小至最小尺寸")
                print("------------------------")
                showScaleLimitMessage = true
                scaleLimitMessage = "已缩小至最小尺寸"
            }
        } else {
            currentScale = min(max(newScale, minScale), maxScale)
            showScaleLimitMessage = false
            
            let now = Date()
            if now.timeIntervalSince(lastOutputTime) >= outputInterval {
                print("------------------------")
                print("触控区\(screenID == .original ? "2" : "3")双指手势：\(scale > 1.0 ? "拉开" : "靠近")")
                print("画面比例：\(Int(currentScale * 100))%")
                print("------------------------")
                lastOutputTime = now
            }
        }
    }
    
    // 封装手势结束处理方法
    private func handlePinchEnd(
        screenID: ScreenID,
        currentScale: CGFloat,
        baseScale: inout CGFloat  // 使用 inout 参数来修改基准缩放值
    ) {
        baseScale = currentScale
        showScaleLimitMessage = false
        print("------------------------")
        print("触控区\(screenID == .original ? "2" : "3")双指手势结束")
        print("最终画面比例：\(Int(baseScale * 100))%")
        print("------------------------")
    }
    
    var body: some View {
        GeometryReader { geometry in
            let screenBounds = UIScreen.main.bounds
            let screenHeight = screenBounds.height
            let screenWidth = screenBounds.width
            let centerY = screenHeight / 2
            
            ZStack {
                // 背景
                Color.black.edgesIgnoringSafeArea(.all)
                
                // 上下分屏布局
                VStack(spacing: 0) {
                    // 根据交换状态决定显示哪个屏幕
                    if !isScreensSwapped {
                        // Original 屏幕在上
                        ScreenContainer(
                            screenID: .original,
                            content: AnyView(
                                ZStack {
                                    if let image = isOriginalPaused ? pausedOriginalImage : originalImage {
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: screenWidth, height: centerY)
                                            .scaleEffect(isOriginalPaused ? currentScale : 1.0)  // 使用 currentScale
                                            .clipped()
                                    }
                                }
                            )
                        )
                        
                        Rectangle()
                            .fill(Color.gray)
                            .frame(height: 1)
                        
                        // Mirrored 屏幕在下
                        ScreenContainer(
                            screenID: .mirrored,
                            content: AnyView(
                                ZStack {
                                    if let image = isMirroredPaused ? pausedMirroredImage : mirroredImage {
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: screenWidth, height: centerY)
                                            .scaleEffect(isMirroredPaused ? currentMirroredScale : 1.0)
                                            .clipped()
                                    }
                                }
                            )
                        )
                    } else {
                        // Mirrored 屏幕在上
                        ScreenContainer(
                            screenID: .mirrored,
                            content: AnyView(
                                ZStack {
                                    if let image = isMirroredPaused ? pausedMirroredImage : mirroredImage {
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: screenWidth, height: centerY)
                                            .scaleEffect(isMirroredPaused ? currentMirroredScale : 1.0)  // 添加缩放效果
                                            .clipped()
                                    }
                                }
                            )
                        )
                        
                        Rectangle()
                            .fill(Color.gray)
                            .frame(height: 1)
                        
                        // Original 屏幕在下
                        ScreenContainer(
                            screenID: .original,
                            content: AnyView(
                                ZStack {
                                    if let image = isOriginalPaused ? pausedOriginalImage : originalImage {
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: screenWidth, height: centerY)
                                            .scaleEffect(isOriginalPaused ? currentScale : 1.0)  // 使用 currentScale
                                            .clipped()
                                    }
                                }
                            )
                        )
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: isScreensSwapped)  // 添加交换动画
                
                // 触控区域
                ZStack {
                    // Original屏的触控区2
                    VStack {
                        Color.clear
                            .contentShape(Rectangle())
                            .frame(height: (screenHeight - 20) / 2)
                            .gesture(
                                TapGesture(count: 2)
                                    .onEnded {
                                        if isZone2Enabled {
                                            print("------------------------")
                                            print("触控区2被双击")
                                            print("区域：Original屏幕")
                                            print("位置：\(isScreensSwapped ? "下部" : "上部")")
                                            
                                            togglePauseState(for: .original)
                                            
                                            print("当前布局：\(layoutDescription)")
                                            print("------------------------")
                                        }
                                    }
                                    .exclusively(before: 
                                        LongPressGesture(minimumDuration: 0.5)
                                            .onEnded { _ in
                                                if isZone2Enabled && !isOriginalPaused {  // 只在非定格状态响应长按
                                                    print("------------------------")
                                                    print("触控区2被长按")
                                                    print("区域：Original屏幕")
                                                    print("位置：\(isScreensSwapped ? "下部" : "上部")")
                                                    print("当前布局：\(layoutDescription)")
                                                    print("画面状态：\(isOriginalPaused ? "已定格" : "实时中")")
                                                    print("------------------------")
                                                }
                                            }
                                            .exclusively(before: DragGesture(minimumDistance: 0)
                                                .onEnded { gesture in
                                                    if isZone2Enabled && !isOriginalPaused {  // 只在非定格状态响应单击
                                                        print("------------------------")
                                                        print("触控区2被单击")
                                                        print("区域：Original屏幕")
                                                        print("位置：\(isScreensSwapped ? "下部" : "上部")")
                                                        print("点击位置：(x=\(Int(gesture.location.x)), y=\(Int(gesture.location.y)))pt")
                                                        print("当前布局：\(layoutDescription)")
                                                        print("可点击状态：已启用")
                                                        
                                                        if showContainer {
                                                            print("黑色容器已隐藏")
                                                            withAnimation(.linear(duration: 0.5)) {
                                                                containerWidth = 0
                                                            }
                                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                                                showContainer = false
                                                            }
                                                        }
                                                        
                                                        print("------------------------")
                                                    }
                                                }
                                            )
                                    )
                            )
                            .simultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { scale in
                                        if isZone2Enabled && isOriginalPaused {
                                            handlePinchGesture(
                                                scale: scale,
                                                screenID: .original,
                                                baseScale: originalScale,
                                                currentScale: &currentScale
                                            )
                                        }
                                    }
                                    .onEnded { scale in
                                        if isZone2Enabled && isOriginalPaused {
                                            handlePinchEnd(
                                                screenID: .original,
                                                currentScale: currentScale,
                                                baseScale: &originalScale
                                            )
                                        }
                                    }
                            )
                        Spacer()
                    }
                    .frame(height: screenHeight / 2)
                    .position(x: screenWidth/2, y: isScreensSwapped ? screenHeight*3/4 : screenHeight/4)
                    
                    // Mirrored屏的触控区3
                    VStack {
                        Spacer()
                        Color.clear
                            .contentShape(Rectangle())
                            .frame(height: (screenHeight - 20) / 2)
                            .gesture(
                                TapGesture(count: 2)
                                    .onEnded {
                                        if isZone3Enabled {
                                            print("------------------------")
                                            print("触控区3被双击")
                                            print("区域：Mirrored屏幕")
                                            print("位置：\(isScreensSwapped ? "上部" : "下部")")
                                            
                                            togglePauseState(for: .mirrored)
                                            
                                            print("当前布局：\(layoutDescription)")
                                            print("------------------------")
                                        }
                                    }
                                    .exclusively(before: 
                                        LongPressGesture(minimumDuration: 0.5)
                                            .onEnded { _ in
                                                if isZone3Enabled && !isMirroredPaused {  // 只在非定格状态响应长按
                                                    print("------------------------")
                                                    print("触控区3被长按")
                                                    print("区域：Mirrored屏幕")
                                                    print("位置：\(isScreensSwapped ? "上部" : "下部")")
                                                    print("当前布局：\(layoutDescription)")
                                                    print("画面状态：\(isMirroredPaused ? "已定格" : "实时中")")
                                                    print("------------------------")
                                                }
                                            }
                                            .exclusively(before: DragGesture(minimumDistance: 0)
                                                .onEnded { gesture in
                                                    if isZone3Enabled && !isMirroredPaused {  // 只在非定格状态响应单击
                                                        print("------------------------")
                                                        print("触控区3被单击")
                                                        print("区域：Mirrored屏幕")
                                                        print("位置：\(isScreensSwapped ? "上部" : "下部")")
                                                        print("点击位置：(x=\(Int(gesture.location.x)), y=\(Int(gesture.location.y)))pt")
                                                        print("当前布局：\(layoutDescription)")
                                                        print("可点击状态：已启用")
                                                        
                                                        if showContainer {
                                                            print("黑色容器已隐藏")
                                                            withAnimation(.linear(duration: 0.5)) {
                                                                containerWidth = 0
                                                            }
                                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                                                showContainer = false
                                                            }
                                                        }
                                                        
                                                        print("------------------------")
                                                    }
                                                }
                                            )
                                    )
                            )
                            .simultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { scale in
                                        if isZone3Enabled && isMirroredPaused {
                                            handlePinchGesture(
                                                scale: scale,
                                                screenID: .mirrored,
                                                baseScale: mirroredScale,
                                                currentScale: &currentMirroredScale
                                            )
                                        }
                                    }
                                    .onEnded { scale in
                                        if isZone3Enabled && isMirroredPaused {
                                            handlePinchEnd(
                                                screenID: .mirrored,
                                                currentScale: currentMirroredScale,
                                                baseScale: &mirroredScale
                                            )
                                        }
                                    }
                            )
                    }
                    .frame(height: screenHeight / 2)
                    .position(x: screenWidth/2, y: isScreensSwapped ? screenHeight/4 : screenHeight*3/4)
                    
                    // 触控区1（透明矩形）
                    ZStack {
                        Color.clear
                            .contentShape(Rectangle())
                            .frame(width: screenWidth, height: 20)
                        
                        // 按钮容器
                        if showContainer {
                            ButtonContainer(width: containerWidth) {
                                // 理交换按钮点击
                                print("------------------------")
                                print("执行交换操作")
                                print("当前布局：\(layoutDescription)")
                                
                                // 执行交换
                                withAnimation {
                                    isScreensSwapped.toggle()
                                }
                                
                                // 延迟打印交换后状态，确保状���已更新
                                DispatchQueue.main.async {
                                    print("交换完成")
                                    print("新布局：\(layoutDescription)")
                                    print("------------------------")
                                }
                            }
                            .animation(.linear(duration: 0.5), value: containerWidth)
                        }
                    }
                    .position(x: screenWidth/2, y: screenHeight/2)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { gesture in
                                if isZone1Enabled {
                                    print("------------------------")
                                    print("触控区1被点击")
                                    print("区域：中央透明矩形")
                                    print("点击位置：(x=\(Int(gesture.location.x)), y=\(Int(gesture.location.y)))pt")
                                    print("可点击状态：已启用")
                                    print("------------------------")
                                    
                                    // 显示容器并执行动画
                                    showContainer = true
                                    withAnimation(.linear(duration: 0.5)) {
                                        containerWidth = screenWidth
                                    }
                                } else {
                                    print("------------------------")
                                    print("触控区1已禁用")
                                    print("------------------------")
                                }
                            }
                    )
                }
            }
            .onAppear {
                setupVideoProcessing()
                print("------------------------")
                print("视图初始化")
                print("触控区2：永远对应Original屏幕（双击可定格/恢复画面）")
                print("触控区3：永远对应Mirrored屏幕（双击可定格/恢复画面）")
                print("初始布局：\(layoutDescription)")
                print("------------------------")
            }
        }
        .ignoresSafeArea(.all)
    }
    
    private func setupVideoProcessing() {
        let processor = VideoProcessor()
        
        // 设置原始画面处理器
        processor.normalImageHandler = { image in
            DispatchQueue.main.async {
                self.originalImage = image
            }
        }
        
        // 设置镜像画面处理器
        processor.flippedImageHandler = { image in
            DispatchQueue.main.async {
                self.mirroredImage = image
            }
        }
        
        cameraManager.videoOutputDelegate = processor
        cameraManager.checkPermission()
    }
    
    // 添加布局变化监听
    private func onLayoutChanged() {
        print("------------------------")
        print("布局发生变化")
        print("当前布局：\(layoutDescription)")
        print("------------------------")
    }
    
    private func togglePauseState(for screenID: ScreenID) {
        switch screenID {
        case .original:
            if isOriginalPaused {
                isOriginalPaused = false
                pausedOriginalImage = nil
                originalScale = 1.0
                currentScale = 1.0  // 使用 currentScale
                print("Original画面已恢复")
            } else {
                isOriginalPaused = true
                pausedOriginalImage = originalImage
                originalScale = 1.0
                currentScale = 1.0  // 使用 currentScale
                print("Original画面已定格")
            }
        case .mirrored:
            if isMirroredPaused {
                isMirroredPaused = false
                pausedMirroredImage = nil
                mirroredScale = 1.0
                currentMirroredScale = 1.0
                print("Mirrored画面已恢复")
            } else {
                isMirroredPaused = true
                pausedMirroredImage = mirroredImage
                mirroredScale = 1.0
                currentMirroredScale = 1.0
                print("Mirrored画面已定格")
            }
        }
    }
}

// 添加 VideoProcessor 类
class VideoProcessor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    var normalImageHandler: ((UIImage) -> Void)?
    var flippedImageHandler: ((UIImage) -> Void)?
    let context = CIContext()
    private var lastLogTime: Date = Date()
    private let logInterval: TimeInterval = 1.0  // 秒最多输出一次日志
    private var lastOrientation: UIDeviceOrientation = .unknown
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // 修正视频方向
        connection.videoOrientation = .portrait
        connection.isVideoMirrored = true
        
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        
        // 生成正常画面
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            let normalImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
            DispatchQueue.main.async {
                self.normalImageHandler?(normalImage)
            }
        }
        
        // 生成镜像画面（据设备方向处理）
        var mirroredImage = ciImage.transformed(by: CGAffineTransform(scaleX: -1, y: 1))
        
        // 根据设备方向旋转镜像画面
        let deviceOrientation = UIDevice.current.orientation
        if deviceOrientation == .landscapeLeft || deviceOrientation == .landscapeRight {
            let rotationTransform = CGAffineTransform(translationX: ciImage.extent.width, y: ciImage.extent.height)
                .rotated(by: .pi)
            mirroredImage = mirroredImage.transformed(by: rotationTransform)
            
            // 只在向改变时输出一次日志
            if deviceOrientation != lastOrientation {
                print("镜像画面根据设备方向(\(deviceOrientation == .landscapeLeft ? "向左" : "向右"))整")
                lastOrientation = deviceOrientation
            }
        }
        
        if let cgImage = context.createCGImage(mirroredImage, from: mirroredImage.extent) {
            let flippedUIImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
            DispatchQueue.main.async {
                self.flippedImageHandler?(flippedUIImage)
            }
        }
    }
}

#Preview {
    TwoOfMeScreens()
} 