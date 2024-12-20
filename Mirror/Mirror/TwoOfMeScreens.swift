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
                .frame(width: width, height: 20)
            
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
    @State private var isScreensSwapped = false  // 添加交换状态
    
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
                                    if let image = originalImage {
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: screenWidth, height: centerY)
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
                                    if let image = mirroredImage {
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: screenWidth, height: centerY)
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
                                    if let image = mirroredImage {
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: screenWidth, height: centerY)
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
                                    if let image = originalImage {
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: screenWidth, height: centerY)
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
                    // Original屏的触控区2（永远对应Original）
                    VStack {
                        Color.clear
                            .contentShape(Rectangle())
                            .frame(height: (screenHeight - 20) / 2)
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onEnded { gesture in
                                        if isZone2Enabled {
                                            print("------------------------")
                                            print("触控区2被点击")
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
                        Spacer()
                    }
                    .frame(height: screenHeight / 2)
                    .position(x: screenWidth/2, y: isScreensSwapped ? screenHeight*3/4 : screenHeight/4)
                    
                    // Mirrored屏的触控区3（永远对应Mirrored）
                    VStack {
                        Spacer()
                        Color.clear
                            .contentShape(Rectangle())
                            .frame(height: (screenHeight - 20) / 2)
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onEnded { gesture in
                                        if isZone3Enabled {
                                            print("------------------------")
                                            print("触控区3被点击")
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
                                // 处理交换按钮点击
                                print("------------------------")
                                print("执行交换操作")
                                print("当前布局：\(layoutDescription)")
                                
                                // 执行交换
                                withAnimation {
                                    isScreensSwapped.toggle()
                                }
                                
                                // 延迟打印交换后状态，确保状态已更新
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
                print("触控区2：永远对应Original屏幕")
                print("触控区3：永远对应Mirrored屏幕")
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
            
            // 只在方向改变时输出一次日志
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