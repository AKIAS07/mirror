//
//  ContentView.swift
//  Mirror
//
//  Created by 林喵 on 2024/12/16.
//

import SwiftUI
import AVFoundation
import UIKit
import Photos

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @State private var showingTwoOfMe = false
    @State private var isCameraActive = true
    @State private var showRestartHint = false
    @State private var deviceOrientation = UIDevice.current.orientation
    @State private var ModeASelected = false
    // 在初始化时就记录初始亮度
    @State private var previousBrightness: CGFloat = {
        let brightness = UIScreen.main.brightness
        print("记录初始屏幕亮度：\(brightness)")
        return brightness
    }()
    @State private var ModeBSelected = false
    @State private var isLighted = false
    
    // 添加一个变量来追踪是否是用户手动调整的亮度
    @State private var isUserAdjustingBrightness = false
    
    // 添加放缩相关的状态变量
    @State private var currentScale: CGFloat = 1.0
    @State private var baseScale: CGFloat = 1.0
    @State private var showScaleLimitMessage = false
    @State private var scaleLimitMessage = ""
    @State private var showScaleIndicator = false
    @State private var currentIndicatorScale: CGFloat = 1.0
    @State private var isControlPanelVisible: Bool = true
    @State private var dragOffset: CGFloat = 0
    @State private var dragVerticalOffset: CGFloat = 0  // 添加垂直偏移量
    
    // 添加放缩限制常量
    private let minScale: CGFloat = 1.0     // 最小100%
    private let maxScale: CGFloat = 10.0    // 最大1000%
    private let verticalDestination: CGFloat = 120.0  // 向上拖拽的目标位置
    private let verticalDragThreshold: CGFloat = 20.0  // 垂直拖拽的触发阈值
    
    // 添加震动反馈生成器
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
    
    // 添加新的状态变量
    @State private var showArrowHint = false
    @State private var dragHintState: DragHintState = .upAndRightLeft
    
    // 添加黑色容器的独立偏移值
    @State private var containerOffset: CGFloat = 0
    
    // 添加设置面板状态
    @State private var showSettings = false
    
    // 添加帮助面板状态
    @State private var showHelp = false
    
    // 添加控制面板可见性状态
    @State private var isControlAreaVisible = true
    
    // 添加截图处理相关的状态
    @State private var lastScreenshotTime: Date = Date()
    private let screenshotDebounceInterval: TimeInterval = 0.5
    
    // 添加照片库权限状态
    @State private var photoLibraryAuthorizationStatus: PHAuthorizationStatus = .notDetermined
    
    var body: some View {
        GeometryReader { geometry in
            
            ZStack {
                if cameraManager.permissionGranted {
                    if cameraManager.isMirrored {
                        // 模式A视图
                        GeometryReader { geometry in
                            CameraContainer(
                                session: cameraManager.session,
                                isMirrored: cameraManager.isMirrored,
                                isActive: isCameraActive,
                                deviceOrientation: deviceOrientation,
                                restartAction: restartCamera,
                                cameraManager: cameraManager,
                                previousBrightness: previousBrightness,
                                isSelected: $ModeASelected,
                                isLighted: $isLighted,
                                isControlAreaVisible: $isControlAreaVisible,
                                currentScale: $currentScale,
                                showScaleIndicator: $showScaleIndicator,
                                currentIndicatorScale: $currentIndicatorScale,
                                onPinchChanged: handlePinchGesture,
                                onPinchEnded: handlePinchEnd
                            )
                        }
                        
                        // 添加独立的边框视图
                        CameraBorderView(isSelected: ModeASelected, isLighted: isLighted)
                            .zIndex(3)
                    } else {
                        // 模式B视图
                        GeometryReader { geometry in
                            CameraContainer(
                                session: cameraManager.session,
                                isMirrored: cameraManager.isMirrored,
                                isActive: isCameraActive,
                                deviceOrientation: deviceOrientation,
                                restartAction: restartCamera,
                                cameraManager: cameraManager,
                                previousBrightness: previousBrightness,
                                isSelected: $ModeBSelected,
                                isLighted: $isLighted,
                                isControlAreaVisible: $isControlAreaVisible,
                                currentScale: $currentScale,
                                showScaleIndicator: $showScaleIndicator,
                                currentIndicatorScale: $currentIndicatorScale,
                                onPinchChanged: handlePinchGesture,
                                onPinchEnded: handlePinchEnd
                            )
                        }
                        
                        // 添加独立的边框视图
                        CameraBorderView(isSelected: ModeBSelected, isLighted: isLighted)
                            .zIndex(3)
                    }
                    
                    // 控制面板
                    if isControlAreaVisible {
                        ZStack {
                            // 黑色容器
                            VStack(spacing: 0) {
                                Rectangle()
                                    .fill(Color.black.opacity(0.5))
                                    .frame(width: isLighted ? geometry.size.width - 20 : geometry.size.width, height: 120)
                                    .animation(.easeInOut(duration: 0.3), value: isLighted)
                                    .overlay(
                                        HStack(spacing: 40) {
                                            // 左按钮 - 模式A
                                            CircleButton(
                                                systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right",
                                                title: "",
                                                action: {
                                                    // 直接传递选中状态和亮度状态
                                                    ModeASelected = ModeBSelected
                                                    isLighted = ModeBSelected
                                                    
                                                    // 根据选中状态设置亮度
                                                    if ModeBSelected {
                                                        // 如果之前是选中状态，保持最大亮度
                                                        UIScreen.main.brightness = 1.0
                                                        print("切换到模式A - 保持最大亮度")
                                                    } else {
                                                        // 如果之前是未选中状态，保持原始亮度
                                                        UIScreen.main.brightness = previousBrightness
                                                        print("切换到模式A - 保持原始亮度：\(previousBrightness)")
                                                    }
                                                    
                                                    // 设置为模式A
                                                    if let processor = cameraManager.videoOutputDelegate as? MainVideoProcessor {
                                                        processor.setMode(.modeA)
                                                    }
                                                    cameraManager.isMirrored = true
                                                    
                                                    // 重置模式B的状态（移到最后）
                                                    ModeBSelected = false
                                                },
                                                deviceOrientation: deviceOrientation,
                                                isDisabled: cameraManager.isMirrored
                                            )
                                            
                                            // 中间按钮 - Two of Me
                                            CircleButton(
                                                systemName: "rectangle.split.2x1",
                                                title: "",
                                                action: {
                                                    // 在进入 Two of Me 模式前，确保恢复原始亮度
                                                    if cameraManager.isMirrored {
                                                        if ModeASelected {
                                                            UIScreen.main.brightness = previousBrightness
                                                            print("进入 Two of Me 前 - 模式A恢复原始亮度：\(previousBrightness)")
                                                            ModeASelected = false
                                                        }
                                                    } else {
                                                        if ModeBSelected {
                                                            UIScreen.main.brightness = previousBrightness
                                                            print("进入 Two of Me 前 - 模式B恢复原始亮度：\(previousBrightness)")
                                                            ModeBSelected = false
                                                        }
                                                    }
                                                    
                                                    // 确保在显示 TwoOfMe 页面前恢复原始亮度
                                                    UIScreen.main.brightness = previousBrightness
                                                    print("进入 Two of Me 前 - 强制恢复原始亮度：\(previousBrightness)")
                                                    
                                                    print("进入 Two of Me 模式")
                                                    showingTwoOfMe = true
                                                },
                                                deviceOrientation: deviceOrientation
                                            )
                                            
                                            // 右按钮 - 模式B
                                            CircleButton(
                                                systemName: "camera",
                                                title: "",
                                                action: {
                                                    // 直接传递选中状态和亮度状态
                                                    ModeBSelected = ModeASelected
                                                    isLighted = ModeASelected
                                                    
                                                    // 根据选中状态设置亮度
                                                    if ModeASelected {
                                                        // 如果之前是选中状态，保持最大亮度
                                                        UIScreen.main.brightness = 1.0
                                                        print("切换到模式B - 保持最大亮度")
                                                    } else {
                                                        // 如果之前是未选中状态，保持原始亮度
                                                        UIScreen.main.brightness = previousBrightness
                                                        print("切换到模式B - 保持原始亮度：\(previousBrightness)")
                                                    }
                                                    
                                                    // 设置为模式B
                                                    if let processor = cameraManager.videoOutputDelegate as? MainVideoProcessor {
                                                        processor.setMode(.modeB)
                                                    }
                                                    cameraManager.isMirrored = false
                                                    
                                                    // 重置模式A的状态（移到最后）
                                                    ModeASelected = false
                                                },
                                                deviceOrientation: deviceOrientation,
                                                isDisabled: !cameraManager.isMirrored
                                            )
                                        }
                                    )
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                            .offset(x: containerOffset, y: dragVerticalOffset)
                            .ignoresSafeArea(.all)
                            .zIndex(1)  // 确保黑色容器在上层

                            // 黄色容器
                            VStack(spacing: 0) {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.5))
                                    .frame(width: isLighted ? geometry.size.width - 20 : geometry.size.width, height: 120)
                                    .overlay(
                                        HStack(spacing: 40) {
                                            Spacer()
                                            
                                            // 设置按钮
                                            CircleButton(
                                                systemName: "gearshape.fill",
                                                title: "",
                                                action: {
                                                    withAnimation(.easeInOut(duration: 0.2)) {
                                                        showSettings = true
                                                    }
                                                },
                                                deviceOrientation: deviceOrientation
                                            )
                                            
                                            // 帮助按钮
                                            CircleButton(
                                                systemName: "questionmark.circle.fill",
                                                title: "",
                                                action: {
                                                    withAnimation(.easeInOut(duration: 0.2)) {
                                                        showHelp = true
                                                    }
                                                },
                                                deviceOrientation: deviceOrientation
                                            )
                                            
                                            Spacer()
                                        }
                                    )
                            }
                            .frame(maxHeight: .infinity, alignment: .bottom)
                            .offset(x: containerOffset, y: dragVerticalOffset + 120)  // 保持在黑色容器下方
                            .animation(.easeInOut(duration: 0.3), value: isLighted)
                            .ignoresSafeArea(.all)
                            .zIndex(0)  // 确保黄色容器在下层

                            // 箭头放置在黑色容器上方
                            VStack {
                                Spacer()
                                DraggableArrow(isExpanded: !isControlPanelVisible, 
                                             isLighted: isLighted,
                                             screenWidth: geometry.size.width,
                                             isControlPanelVisible: $isControlPanelVisible,
                                             showDragHint: $showArrowHint,
                                             dragHintState: $dragHintState,
                                             dragOffset: $dragOffset,
                                             dragVerticalOffset: $dragVerticalOffset,
                                             containerOffset: $containerOffset)
                                    .padding(.bottom, 120)
                            }
                            .offset(x: dragOffset, y: dragVerticalOffset)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .ignoresSafeArea(.all, edges: .bottom)
                        .zIndex(1)
                        .animation(.easeInOut(duration: 0.3), value: isControlAreaVisible)
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)),
                                removal: .opacity.combined(with: .move(edge: .bottom))
                            )
                        )
                    }
                    
                    // 更新背景遮罩视图，确保正确传递选中状态
                    BackgroundMaskView(isSelected: cameraManager.isMirrored ? ModeASelected : ModeBSelected, isLighted: isLighted)
                        .allowsHitTesting(false)
                        .onChange(of: ModeASelected) { _ in
                            print("遮罩状态更新 - 模式A选中状态：\(ModeASelected)")
                        }
                        .onChange(of: ModeBSelected) { _ in
                            print("遮罩状态更新 - 模式B选中状态：\(ModeBSelected)")
                        }
                        .zIndex(2)
                } else {
                    // 权限请求视图
                    ZStack {
                        Color.black.edgesIgnoringSafeArea(.all)
                        
                        VStack {
                            Image(systemName: "camera.fill")
                                .foregroundColor(.white)
                                .font(.largeTitle)
                            Text("使用此APP需要您开启相机权限")
                                .foregroundColor(.white)
                                .padding()
                            Button(action: {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                Text("授权相机")
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.yellow)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                
                // 添加提示视图到最顶层
                if showArrowHint {
                    DragHintView(hintState: dragHintState)
                        .position(x: geometry.size.width/2, y: geometry.size.height/2)
                        .transition(.opacity)
                        .zIndex(4)
                }
                
                // 添加设置面板
                if showSettings {
                    SettingsPanel(isPresented: $showSettings)
                        .zIndex(4)  // 确保设置面板显示在最上层
                }
                
                // 添加帮助面板
                if showHelp {
                    HelpPanel(isPresented: $showHelp)
                        .zIndex(4)  // 确保帮助面板显示在最上层
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                // 添加屏幕亮度变化通知监听
                NotificationCenter.default.addObserver(
                    forName: UIScreen.brightnessDidChangeNotification,
                    object: nil,
                    queue: .main) { _ in
                        let currentBrightness = UIScreen.main.brightness
                        
                        // 只有在非选中状态下才更新初始亮度
                        if !ModeASelected && !ModeBSelected {
                            previousBrightness = currentBrightness
                            print("用户调整了屏幕亮度，更新初始亮度：\(currentBrightness)")
                        }
                    }
                
                NotificationCenter.default.addObserver(
                    forName: UIDevice.orientationDidChangeNotification,
                    object: nil,
                    queue: .main) { _ in
                        let newOrientation = UIDevice.current.orientation
                        deviceOrientation = newOrientation
                        print("设备方向化：\(newOrientation.rawValue)")
                        
                        if !cameraManager.isMirrored && newOrientation == .landscapeLeft {
                            print("正常模式下向左横屏，旋转摄像头画面180度")
                        }
                    }
                
                UIDevice.current.beginGeneratingDeviceOrientationNotifications()
                
                print("主页面加载")
                print("屏幕尺寸：width=\(geometry.size.width), height=\(geometry.size.height)")
                print("------------------------")
                cameraManager.checkPermission()
                
                // 添加应用程序生命周期通知监听
                NotificationCenter.default.addObserver(
                    forName: UIApplication.willResignActiveNotification,
                    object: nil,
                    queue: .main) { _ in
                        print("应用进后台")
                        handleAppBackground()
                    }
                
                NotificationCenter.default.addObserver(
                    forName: UIApplication.didBecomeActiveNotification,
                    object: nil,
                    queue: .main) { _ in
                        print("应用回到前台")
                        handleAppForeground()
                    }
                
                
                // 预准备震动反馈
                feedbackGenerator.prepare()

            }
            .onDisappear {
                // 移除所有通知监听
                NotificationCenter.default.removeObserver(self)
                UIDevice.current.endGeneratingDeviceOrientationNotifications()
                
                print("主页面退出")
                print("------------------------")
            }
            // 添加应用程序生命周期通知监听
            .onChange(of: UIApplication.shared.applicationState) { newState in
                if newState == .active {
                    // 应用回到前台时，检查是否需要恢复最大亮度
                    if cameraManager.isMirrored {
                        if ModeASelected {
                            UIScreen.main.brightness = 1.0
                            print("应用回到前台 - 镜像模式恢复最大亮度")
                        }
                    } else {
                        if ModeBSelected {
                            UIScreen.main.brightness = 1.0
                            print("应用回到前台 - 正常模式恢复最大亮度")
                        }
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingTwoOfMe) {
            handleTwoOfMeDismiss()
        } content: {
            TwoOfMeScreens()
                .transition(.move(edge: .trailing))  // 从右边进入
        }
    }
    
    // 处理应用进入后台
    private func handleAppBackground() {
        if cameraManager.permissionGranted {
            cameraManager.safelyStopSession()
            isCameraActive = false
            print("相机会话已停止")
        }
    }
    
    // 处理应用回到前台
    private func handleAppForeground() {
        // 不需要在这里重新检查权限，因为CameraManager会自动处理
        if !isCameraActive && cameraManager.permissionGranted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.restartCamera()
            }
        } else if !cameraManager.permissionGranted {
            print("相机权限未授权，显示权限请求界面")
            isCameraActive = false
            showRestartHint = false
        } else {
            print("显示重启相机提示")
            showRestartHint = true
        }
    }
    
    private func handleTwoOfMeDismiss() {
        if cameraManager.permissionGranted {
            cameraManager.safelyStopSession()
            cameraManager.isMirrored = false
            isCameraActive = false
            showRestartHint = true
        }
    }
    
    private func restartCamera() {
        if !cameraManager.permissionGranted {
            print("无相机权限，无法重启相机")
            return
        }
        
        print("重启相机会话")
        DispatchQueue.global(qos: .userInitiated).async {
            self.cameraManager.session.startRunning()
            DispatchQueue.main.async {
                self.isCameraActive = true
                self.showRestartHint = false
                print("相机会话已重启")
            }
        }
    }
    
    // 添加放缩处理函数
    private func handlePinchGesture(scale: CGFloat) {
        let newScale = baseScale * scale
        
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
            
            // 更新缩放提示
            currentIndicatorScale = currentScale
            showScaleIndicator = true
            
            // 打印日志
            let currentPercentage = Int(currentScale * 100)
            print("------------------------")
            print("双指缩放")
            print("当前比例：\(currentPercentage)%")
            print("------------------------")
        }
    }
    
    private func handlePinchEnd(scale: CGFloat) {
        baseScale = currentScale
        showScaleLimitMessage = false
        
        // 延迟隐藏缩放提示
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showScaleIndicator = false
        }
        
        print("------------------------")
        print("双指手势结束")
        print("最终画面比例：\(Int(baseScale * 100))%")
        print("------------------------")
    }
    
    
}

#Preview {
    ContentView()
}
