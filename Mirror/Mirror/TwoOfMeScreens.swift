import SwiftUI
import AVFoundation

// 定义屏幕ID
enum ScreenID {
    case original   // 原始画面
    case mirrored   // 镜像画面
}

struct TwoOfMeScreens: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var cameraManager = CameraManager()
    @State private var horizontalDragOffset = CGSize.zero
    @State private var originalScreenOffset: CGFloat = 0    // 原始画面偏移
    @State private var mirroredScreenOffset: CGFloat = 0    // 镜像画面偏移
    @State private var isScreensSwapped = false
    @State private var isDragging = false
    @State private var isLongPressed = false
    @State private var originalImage: UIImage?     // 原始画面
    @State private var mirroredImage: UIImage?     // 镜像画面
    
    // 定义拖拽阈值和边缘区域宽度
    private let dismissThreshold: CGFloat = 100.0
    private let swapThreshold: CGFloat = 150.0
    private let longPressDelay = 1.0
    private let edgeWidth: CGFloat = 30
    
    // 震动反馈生成器
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
    
    // 添加新的视图容器组件
    struct ScreenContainer: View {
        let screenID: ScreenID
        let content: AnyView  // 使用 AnyView 来支持不同类型的内容
        let offset: CGFloat
        let isSwapped: Bool
        let isLongPressed: Bool
        let longPressAction: (Bool) -> Void
        let dragAction: (DragGesture.Value) -> Void
        let dragEndAction: (DragGesture.Value) -> Void
        
        var body: some View {
            content
                .frame(height: UIScreen.main.bounds.height / 2)
                .overlay(
                    Rectangle()
                        .stroke(isLongPressed ? Color.yellow : Color.green, 
                              lineWidth: isLongPressed ? 20 : 1)
                )
                .offset(y: offset)
                .onLongPressGesture(minimumDuration: 1.0, maximumDistance: 50) {
                    print("\(screenID == .original ? "原始" : "镜像")屏长按结束")
                    longPressAction(false)
                } onPressingChanged: { isPressing in
                    if isPressing {
                        print("\(screenID == .original ? "原始" : "镜像")屏开始长按")
                        longPressAction(true)
                    }
                }
                .gesture(
                    DragGesture()
                        .onChanged { gesture in
                            dragAction(gesture)
                        }
                        .onEnded { gesture in
                            dragEndAction(gesture)
                        }
                )
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let safeArea = geometry.safeAreaInsets
            let screenBounds = UIScreen.main.bounds
            let screenHeight = screenBounds.height
            let screenWidth = screenBounds.width
            let centerY = screenHeight / 2
            
            ZStack {
                // 背景
                Color.black.edgesIgnoringSafeArea(.all)
                
                // 上下分屏布局
                VStack(spacing: 0) {
                    // 原始画面屏幕（初始在上方）
                    ScreenContainer(
                        screenID: .original,
                        content: AnyView(
                            ZStack {
                                if !isScreensSwapped {
                                    if let image = originalImage {
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: screenWidth, height: centerY)
                                            .clipped()
                                    }
                                } else {
                                    if let image = mirroredImage {
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: screenWidth, height: centerY)
                                            .clipped()
                                    }
                                }
                            }
                        ),
                        offset: originalScreenOffset,
                        isSwapped: isScreensSwapped,
                        isLongPressed: isLongPressed,
                        longPressAction: { isPressing in
                            isLongPressed = isPressing
                            if isPressing {
                                feedbackGenerator.impactOccurred(intensity: 1.0)
                            }
                        },
                        dragAction: { gesture in
                            if isLongPressed {
                                isDragging = true
                                originalScreenOffset = gesture.translation.height
                                mirroredScreenOffset = -gesture.translation.height
                            }
                        },
                        dragEndAction: { gesture in
                            handleDragEnd(gesture)
                        }
                    )
                    
                    // 分割线
                    Rectangle()
                        .fill(Color.gray)
                        .frame(height: 1)
                    
                    // 镜像画面屏幕（初始在下方）
                    ScreenContainer(
                        screenID: .mirrored,
                        content: AnyView(
                            ZStack {
                                if isScreensSwapped {
                                    if let image = originalImage {
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: screenWidth, height: centerY)
                                            .clipped()
                                    }
                                } else {
                                    if let image = mirroredImage {
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: screenWidth, height: centerY)
                                            .clipped()
                                    }
                                }
                            }
                        ),
                        offset: mirroredScreenOffset,
                        isSwapped: isScreensSwapped,
                        isLongPressed: isLongPressed,
                        longPressAction: { isPressing in
                            isLongPressed = isPressing
                            if isPressing {
                                feedbackGenerator.impactOccurred(intensity: 1.0)
                            }
                        },
                        dragAction: { gesture in
                            if isLongPressed {
                                isDragging = true
                                mirroredScreenOffset = gesture.translation.height
                                originalScreenOffset = -gesture.translation.height
                            }
                        },
                        dragEndAction: { gesture in
                            handleDragEnd(gesture)
                        }
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .edgesIgnoringSafeArea(.all)
                .offset(x: horizontalDragOffset.width)
                
                // 长按提示
                if isLongPressed {
                    VStack {
                        Image(systemName: "arrow.up.arrow.down.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.8))
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .position(x: screenWidth/2, y: centerY)
                }
                
                // 左边缘拖拽区域
                Color.clear
                    .frame(width: edgeWidth, height: screenHeight)
                    .contentShape(Rectangle())
                    .position(x: edgeWidth/2, y: screenHeight/2)
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                if !isLongPressed {
                                    horizontalDragOffset = CGSize(width: gesture.translation.width, height: 0)
                                    print("左边缘拖拽距离: \(gesture.translation.width)")
                                }
                            }
                            .onEnded { gesture in
                                if !isLongPressed {
                                    if gesture.translation.width > dismissThreshold {
                                        print("左边缘达到退出阈值，关闭页面")
                                        presentationMode.wrappedValue.dismiss()
                                    } else {
                                        print("从左边缘未达到退出阈值，回弹")
                                        withAnimation(.spring()) {
                                            horizontalDragOffset = .zero
                                        }
                                    }
                                }
                            }
                    )
                
                // 右边缘拖拽区域
                Color.clear
                    .frame(width: edgeWidth, height: screenHeight)
                    .contentShape(Rectangle())
                    .position(x: screenWidth - edgeWidth/2, y: screenHeight/2)
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                if !isLongPressed {
                                    horizontalDragOffset = CGSize(width: gesture.translation.width, height: 0)
                                    print("右边拖拽距离: \(gesture.translation.width)")
                                }
                            }
                            .onEnded { gesture in
                                if !isLongPressed {
                                    if gesture.translation.width < -dismissThreshold {
                                        print("从右边缘达到退出阈值，关闭页面")
                                        presentationMode.wrappedValue.dismiss()
                                    } else {
                                        print("从右边缘未达到退出阈值，回弹")
                                        withAnimation(.spring()) {
                                            horizontalDragOffset = .zero
                                        }
                                    }
                                }
                            }
                    )
            }
            .onAppear {
                setupVideoProcessing()
                print("------------------------")
                print("视图加载完成")
                print("设备名称: \(UIDevice.current.name)")
                print("系统版本: \(UIDevice.current.systemVersion)")
                print("设备屏幕尺寸: \(screenBounds)")
                print("安全区域: \(safeArea)")
                print("边缘拖拽区域宽度: \(edgeWidth)")
                print("------------------------")
                // 预准备震动反馈
                feedbackGenerator.prepare()
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
    
    // 抽取拖拽结束处理逻辑
    private func handleDragEnd(_ gesture: DragGesture.Value) {
        if isLongPressed {
            isDragging = false
            if abs(gesture.translation.height) > swapThreshold {
                withAnimation(.spring()) {
                    isScreensSwapped.toggle()
                    originalScreenOffset = 0
                    mirroredScreenOffset = 0
                }
                feedbackGenerator.impactOccurred(intensity: 1.0)
            } else {
                withAnimation(.spring()) {
                    originalScreenOffset = 0
                    mirroredScreenOffset = 0
                }
            }
            isLongPressed = false
        }
    }
}

// 添加 VideoProcessor 类
class VideoProcessor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    var normalImageHandler: ((UIImage) -> Void)?  // 正常画面处理器
    var flippedImageHandler: ((UIImage) -> Void)?  // 翻转画面处理器
    let context = CIContext()
    
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
        
        // 生成水平翻转画面
        let flippedImage = ciImage.transformed(by: CGAffineTransform(scaleX: -1, y: 1))
        if let cgImage = context.createCGImage(flippedImage, from: flippedImage.extent) {
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