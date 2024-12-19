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
    @State private var isSelected = false  // 添加选中状态
    @State private var originalImage: UIImage?     // 原始画面
    @State private var mirroredImage: UIImage?     // 镜像画面
    @State private var previousBrightness: CGFloat = UIScreen.main.brightness  // 添加原始亮度状态
    @State private var showAlert = false
    @State private var showSwapIcon = false  // 添加交换图标显示状态
    
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
        let isSelected: Bool  // 修改为选中状态
        let toggleSelection: () -> Void  // 添加切换选中状态的回调
        let dragAction: (DragGesture.Value) -> Void
        let dragEndAction: (DragGesture.Value) -> Void
        
        var body: some View {
            content
                .frame(height: UIScreen.main.bounds.height / 2)
                .overlay(
                    Rectangle()
                        .stroke(isSelected ? Color.white : Color.green, 
                              lineWidth: isSelected ? 50 : 1)
                )
                .offset(y: offset)
                .onTapGesture {
                    toggleSelection()
                }
                .gesture(
                    DragGesture()
                        .onChanged { gesture in
                            if isSelected {  // 只在选中状态下允许拖动
                                dragAction(gesture)
                            }
                        }
                        .onEnded { gesture in
                            if isSelected {
                                dragEndAction(gesture)
                            }
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
                        isSelected: isSelected,
                        toggleSelection: {
                            toggleSelection()
                        },
                        dragAction: { gesture in
                            isDragging = true
                            originalScreenOffset = gesture.translation.height
                            mirroredScreenOffset = -gesture.translation.height
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
                        isSelected: isSelected,
                        toggleSelection: {
                            toggleSelection()
                        },
                        dragAction: { gesture in
                            isDragging = true
                            mirroredScreenOffset = gesture.translation.height
                            originalScreenOffset = -gesture.translation.height
                        },
                        dragEndAction: { gesture in
                            handleDragEnd(gesture)
                        }
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .edgesIgnoringSafeArea(.all)
                .offset(x: horizontalDragOffset.width)
                .transition(.move(edge: .trailing))
                .animation(.easeInOut(duration: 0.3), value: horizontalDragOffset)
                
                // 交换提示图标（只在选中状态下显示，且2秒后自动消失）
                if isSelected && showSwapIcon {
                    VStack {
                        Image(systemName: "arrow.up.arrow.down.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.8))
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .position(x: geometry.size.width/2, y: geometry.size.height/2)
                }
                
                // 左边缘拖拽区域
                Color.clear
                    .frame(width: edgeWidth, height: screenHeight)
                    .contentShape(Rectangle())
                    .position(x: edgeWidth/2, y: screenHeight/2)
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                if !isSelected {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        horizontalDragOffset = CGSize(width: gesture.translation.width, height: 0)
                                    }
                                    if abs(gesture.translation.width) > dismissThreshold * 0.8 &&
                                       abs(horizontalDragOffset.width) <= dismissThreshold * 0.8 {
                                        print("开始向左拖拽退出")
                                    }
                                } else if !showAlert {
                                    if gesture.translation.width > 20 {
                                        showAlert = true
                                        print("显示提示：请先取消打光功能")
                                    }
                                }
                            }
                            .onEnded { gesture in
                                if !isSelected {
                                    if gesture.translation.width > dismissThreshold {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            horizontalDragOffset = CGSize(width: UIScreen.main.bounds.width, height: 0)
                                        }
                                        print("达到左侧退出阈值")
                                        print("关闭页面")
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            presentationMode.wrappedValue.dismiss()
                                        }
                                    } else {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
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
                                if !isSelected {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        horizontalDragOffset = CGSize(width: gesture.translation.width, height: 0)
                                    }
                                    if abs(gesture.translation.width) > dismissThreshold * 0.8 &&
                                       abs(horizontalDragOffset.width) <= dismissThreshold * 0.8 {
                                        print("开始向右拖拽退出")
                                    }
                                } else if !showAlert {
                                    if gesture.translation.width < -20 {
                                        showAlert = true
                                        print("显示提示：请先取消打光功能")
                                    }
                                }
                            }
                            .onEnded { gesture in
                                if !isSelected {
                                    if gesture.translation.width < -dismissThreshold {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            horizontalDragOffset = CGSize(width: -UIScreen.main.bounds.width, height: 0)
                                        }
                                        print("达到右侧退出阈值")
                                        print("关闭页面")
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            presentationMode.wrappedValue.dismiss()
                                        }
                                    } else {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            horizontalDragOffset = .zero
                                        }
                                    }
                                }
                            }
                    )
                
                // 添加提示视图
                if showAlert {
                    VStack {
                        Text("请先取消打光功能再退出此页面")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(10)
                    }
                    .position(x: screenWidth/2, y: screenHeight/2)
                    .onAppear {
                        // 2秒后自动隐藏提示
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                showAlert = false
                            }
                        }
                    }
                }
            }
            .onAppear {
                setupVideoProcessing()
                print("------------------------")
                print("Two of Me 模式初始化")
                print("屏幕尺寸: \(UIScreen.main.bounds.width) x \(UIScreen.main.bounds.height)")
                print("------------------------")
                // 准备震动反馈
                feedbackGenerator.prepare()
            }
        }
        .ignoresSafeArea(.all)
        .onDisappear {
            // 确保在视图消失时恢复原始亮度
            if isSelected {
                UIScreen.main.brightness = previousBrightness
                print("TwoOfMe视图消失 - 恢复原始亮度：\(previousBrightness)")
            }
        }
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
        if isSelected {  // 修改断条件
            isDragging = false
            if abs(gesture.translation.height) > swapThreshold {
                withAnimation(.spring()) {
                    isScreensSwapped.toggle()
                    originalScreenOffset = 0
                    mirroredScreenOffset = 0
                }
                feedbackGenerator.impactOccurred(intensity: 1.0)
                print("画面位置已交换")
            } else {
                withAnimation(.spring()) {
                    originalScreenOffset = 0
                    mirroredScreenOffset = 0
                }
            }
            // 不再重置 isSelected，让用户手动取消选中状态
        }
    }
    
    // 修改选中状态切换函数
    private func toggleSelection() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isSelected.toggle()
            
            if isSelected {
                // 保存当前亮度并设置为最大
                previousBrightness = UIScreen.main.brightness
                UIScreen.main.brightness = 1.0
                print("分屏选中 - 提高亮度至最大")
                print("原始亮度：\(previousBrightness)")
                
                // 显示交换图标并设置2秒后消失
                showSwapIcon = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    withAnimation {
                        showSwapIcon = false
                    }
                }
                
                feedbackGenerator.impactOccurred(intensity: 1.0)
            } else {
                // 恢复原始亮度
                UIScreen.main.brightness = previousBrightness
                print("分屏取消选中 - 恢复原始亮度：\(previousBrightness)")
                showSwapIcon = false  // 立即隐藏交换图标
            }
        }
        print("分屏选中状态：\(isSelected)")
    }
}

// 添加 VideoProcessor 类
class VideoProcessor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    var normalImageHandler: ((UIImage) -> Void)?
    var flippedImageHandler: ((UIImage) -> Void)?
    let context = CIContext()
    private var lastLogTime: Date = Date()
    private let logInterval: TimeInterval = 1.0  // 每秒最多输出一次日志
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
        
        // 生成镜像画面（根据设备方向处理）
        var mirroredImage = ciImage.transformed(by: CGAffineTransform(scaleX: -1, y: 1))
        
        // 根据设备方向旋转镜像画面
        let deviceOrientation = UIDevice.current.orientation
        if deviceOrientation == .landscapeLeft || deviceOrientation == .landscapeRight {
            let rotationTransform = CGAffineTransform(translationX: ciImage.extent.width, y: ciImage.extent.height)
                .rotated(by: .pi)
            mirroredImage = mirroredImage.transformed(by: rotationTransform)
            
            // 只在方向改变时输出一次日志
            if deviceOrientation != lastOrientation {
                print("镜像画面根据设备方向(\(deviceOrientation == .landscapeLeft ? "向左" : "向右"))调整")
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