import SwiftUI
import AVFoundation

struct TwoOfMeScreens: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var horizontalDragOffset = CGSize.zero
    @State private var topScreenOffset: CGFloat = 0
    @State private var bottomScreenOffset: CGFloat = 0
    @State private var isScreensSwapped = false
    @State private var isDragging = false
    @State private var isLongPressed = false
    
    // 定义拖拽阈值和边缘区域宽度
    private let dismissThreshold: CGFloat = 100.0
    private let swapThreshold: CGFloat = 150.0
    private let longPressDelay = 1.0
    private let edgeWidth: CGFloat = 30
    
    // 震动反馈生成器
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
    
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
                    // 上半部分
                    Rectangle()
                        .fill(isScreensSwapped ? Color.black : Color.white)
                        .frame(height: centerY)
                        .overlay(
                            Rectangle()
                                .stroke(isLongPressed ? Color.yellow : Color.green, 
                                      lineWidth: isLongPressed ? 20 : 1)
                        )
                        .offset(y: topScreenOffset)
                        .onLongPressGesture(minimumDuration: longPressDelay, maximumDistance: 50) {
                            print("长按结束")
                            isLongPressed = false
                        } onPressingChanged: { isPressing in
                            if isPressing {
                                print("开始长按")
                                isLongPressed = true
                                feedbackGenerator.impactOccurred(intensity: 1.0)
                            }
                        }
                        .gesture(
                            DragGesture()
                                .onChanged { gesture in
                                    if isLongPressed {
                                        isDragging = true
                                        topScreenOffset = gesture.translation.height
                                        bottomScreenOffset = -gesture.translation.height
                                    }
                                }
                                .onEnded { gesture in
                                    if isLongPressed {
                                        isDragging = false
                                        if abs(gesture.translation.height) > swapThreshold {
                                            withAnimation(.spring()) {
                                                isScreensSwapped.toggle()
                                                topScreenOffset = 0
                                                bottomScreenOffset = 0
                                            }
                                            feedbackGenerator.impactOccurred(intensity: 1.0)
                                        } else {
                                            withAnimation(.spring()) {
                                                topScreenOffset = 0
                                                bottomScreenOffset = 0
                                            }
                                        }
                                        isLongPressed = false
                                    }
                                }
                        )
                    
                    // 分割线
                    Rectangle()
                        .fill(Color.gray)
                        .frame(height: 1)
                    
                    // 下半部分
                    Rectangle()
                        .fill(isScreensSwapped ? Color.white : Color.black)
                        .frame(height: centerY)
                        .overlay(
                            Rectangle()
                                .stroke(isLongPressed ? Color.yellow : Color.green, 
                                      lineWidth: isLongPressed ? 20 : 1)
                        )
                        .offset(y: bottomScreenOffset)
                        .onLongPressGesture(minimumDuration: longPressDelay, maximumDistance: 50) {
                            print("长按结束")
                            isLongPressed = false
                        } onPressingChanged: { isPressing in
                            if isPressing {
                                print("开始长按")
                                isLongPressed = true
                                feedbackGenerator.impactOccurred(intensity: 1.0)
                            }
                        }
                        .gesture(
                            DragGesture()
                                .onChanged { gesture in
                                    if isLongPressed {
                                        isDragging = true
                                        bottomScreenOffset = gesture.translation.height
                                        topScreenOffset = -gesture.translation.height
                                    }
                                }
                                .onEnded { gesture in
                                    if isLongPressed {
                                        isDragging = false
                                        if abs(gesture.translation.height) > swapThreshold {
                                            withAnimation(.spring()) {
                                                isScreensSwapped.toggle()
                                                topScreenOffset = 0
                                                bottomScreenOffset = 0
                                            }
                                            feedbackGenerator.impactOccurred(intensity: 1.0)
                                        } else {
                                            withAnimation(.spring()) {
                                                topScreenOffset = 0
                                                bottomScreenOffset = 0
                                            }
                                        }
                                        isLongPressed = false
                                    }
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
}

#Preview {
    TwoOfMeScreens()
} 