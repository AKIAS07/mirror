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
import AVKit

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var captureState = CaptureState()
    @StateObject private var restartManager = ContentRestartManager.shared
    @StateObject private var captureManager = CaptureManager.shared
    @State private var showingTwoOfMe = false
    @State private var isCameraActive = true
    @State private var showRestartHint = false
    @State private var deviceOrientation = UIDevice.current.orientation
    @State private var ModeASelected = false
    @State private var previousBrightness: CGFloat = {
        let brightness = UIScreen.main.brightness
        print("记录初始屏幕亮度：\(brightness)")
        return brightness
    }()
    @State private var ModeBSelected = false
    @State private var isLighted = false
    @State private var isControlsVisible = true  // 统一的控制可见性状态
    
    @State private var isUserAdjustingBrightness = false
    
    @State private var currentScale: CGFloat = 1.0
    @State private var baseScale: CGFloat = 1.0
    @State private var showScaleLimitMessage = false
    @State private var scaleLimitMessage = ""
    @State private var showScaleIndicator = false
    @State private var currentIndicatorScale: CGFloat = 1.0
    @State private var isControlPanelVisible: Bool = true
    @State private var dragOffset: CGFloat = 0
    @State private var dragVerticalOffset: CGFloat = 0
    @State private var shouldIgnoreScale: Bool = false  // 添加新的状态变量
    
    private let minScale: CGFloat = 0.6
    private let maxScale: CGFloat = 10.0
    private let verticalDestination: CGFloat = 120.0
    private let verticalDragThreshold: CGFloat = 20.0
    
    // 添加震动反馈生成器
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyFeedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let lightFeedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    
    @State private var showArrowHint = false
    @State private var dragHintState: DragHintState = .upAndRightLeft
    
    @State private var containerOffset: CGFloat = 0
    
    @State private var showSettings = false
    
    @State private var showHelp = false
    
    @State private var isControlAreaVisible = true
    
    @State private var lastScreenshotTime: Date = Date()
    private let screenshotDebounceInterval: TimeInterval = AppConfig.Debounce.screenshot
    
    @State private var photoLibraryAuthorizationStatus: PHAuthorizationStatus = .notDetermined
    
    // 为每个按钮添加独立的动画状态
    @State private var showLeftIconAnimation = false
    @State private var showMiddleIconAnimation = false
    @State private var showRightIconAnimation = false
    @State private var leftAnimationPosition: CGPoint = .zero
    @State private var middleAnimationPosition: CGPoint = .zero
    @State private var rightAnimationPosition: CGPoint = .zero

    // 添加设备方向状态
    @StateObject private var orientationManager = DeviceOrientationManager.shared
    
    @State private var isToolbarVisible = true
    
    @StateObject private var permissionManager = PermissionManager.shared
    
    @StateObject private var proManager = ProManager.shared
    @StateObject private var dayNightManager = DayNightManager.shared  // 添加昼夜模式管理器
    @StateObject private var realModeController = RealModeController.shared  // 添加真实模式控制器
    
    @State private var showLiveAlert = false
    @State private var liveAlertMessage = ""
    
    // 添加化妆视图状态
    @State private var showMakeupView = false
    
    // 添加参考格纹图显示状态
    @State private var showReferenceGrid = false
    // 添加网格参数状态
    @State private var gridSpacing: CGFloat = UserSettingsManager.shared.loadGridSettings().spacing
    @State private var gridLineColor: Color = UserSettingsManager.shared.loadGridSettings().color
    @State private var gridLineOpacity: Double = UserSettingsManager.shared.loadGridSettings().opacity

    @State private var isZoomExpanded = false  // 添加放缩状态变量
    @State private var isDayMode = true  // 添加昼夜模式状态变量，默认为白天模式
    @State private var isRCircleEnabled = false  // 添加 r.circle.fill 按钮状态
    
    @ObservedObject private var styleManager = BorderLightStyleManager.shared
    
    var body: some View {
        GeometryReader { geometry in
            
            ZStack {
                if permissionManager.cameraPermissionGranted {
                    if cameraManager.isMirrored {
                        // 模式A视图
                        CameraContainer(
                            session: cameraManager.session,
                            isMirrored: cameraManager.isMirrored,
                            isActive: restartManager.isCameraActive,
                            deviceOrientation: orientationManager.currentOrientation,
                            restartAction: { restartManager.restartCamera(cameraManager: cameraManager) },
                            cameraManager: cameraManager,
                            previousBrightness: previousBrightness,
                            isSelected: $ModeASelected,
                            isLighted: $isLighted,
                            isControlAreaVisible: $isControlAreaVisible,
                            currentScale: $currentScale,
                            showScaleIndicator: $showScaleIndicator,
                            currentIndicatorScale: $currentIndicatorScale,
                            onPinchChanged: handlePinchGesture,
                            onPinchEnded: handlePinchEnd,
                            minScale: minScale,
                            captureState: captureState
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .edgesIgnoringSafeArea(.all)
                        
                        // 添加独立的边框视图
                        CameraBorderView(isSelected: ModeASelected, isLighted: isLighted)
                            .zIndex(3)
                    } else {
                        // 模式B视图
                        CameraContainer(
                            session: cameraManager.session,
                            isMirrored: cameraManager.isMirrored,
                            isActive: restartManager.isCameraActive,
                            deviceOrientation: orientationManager.currentOrientation,
                            restartAction: { restartManager.restartCamera(cameraManager: cameraManager) },
                            cameraManager: cameraManager,
                            previousBrightness: previousBrightness,
                            isSelected: $ModeBSelected,
                            isLighted: $isLighted,
                            isControlAreaVisible: $isControlAreaVisible,
                            currentScale: $currentScale,
                            showScaleIndicator: $showScaleIndicator,
                            currentIndicatorScale: $currentIndicatorScale,
                            onPinchChanged: handlePinchGesture,
                            onPinchEnded: handlePinchEnd,
                            minScale: minScale,
                            captureState: captureState
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .edgesIgnoringSafeArea(.all)
                        
                        // 添加独立的边框视图
                        CameraBorderView(isSelected: ModeBSelected, isLighted: isLighted)
                            .zIndex(3)
                    }
                    
                    // 三个动画视图（放在背景和控制面板之间）
                    Group {
                        if showLeftIconAnimation {
                            Image("icon-bf-black")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 75, height: 75)
                                .opacity(0.3)
                                .transition(.opacity)
                                .rotationEffect(getRotationAngle(orientationManager.currentOrientation))
                                .position(leftAnimationPosition)
                        }
                        
                        if showMiddleIconAnimation {
                            Image("icon-bf-white")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 75, height: 75)
                                .opacity(0.3)
                                .transition(.opacity)
                                .rotationEffect(getRotationAngle(orientationManager.currentOrientation))
                                .position(middleAnimationPosition)
                        }
                        
                        if showRightIconAnimation {
                            Image("icon-bf-black")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 75, height: 75)
                                .opacity(0.3)
                                .transition(.opacity)
                                .rotationEffect(getRotationAngle(orientationManager.currentOrientation))
                                .position(rightAnimationPosition)
                        }
                    }
                    .zIndex(2)
                    
                    // 控制面板
                    if isControlsVisible {
                        ZStack {
                            // 黑色容器和黄色容器组
                            ZStack {
                                // 第一个容器
                                VStack(spacing: 0) {
                                    Rectangle()
                                        .fill(Color.black.opacity(0.15))
                                        .frame(width: isLighted ? geometry.size.width : geometry.size.width, height: 120)
                                        .animation(.easeInOut(duration: 0.3), value: isLighted)
                                        .overlay(
                                            ZStack {
                                                // 按钮布局
                                                HStack(spacing: 40) {
                                                    createLeftButton(geometry: geometry)
                                                    createMiddleButton(geometry: geometry)
                                                    createRightButton(geometry: geometry)
                                                }
                                                .onAppear {
                                                    let iconColor = BorderLightStyleManager.shared.iconColor
                                                    print("------------------------")
                                                    print("第一个容器按钮颜色：\(getColorDetails(iconColor))")
                                                    print("容器背景透明度：0.35")
                                                }
                                            }
                                        )
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                                .offset(x: containerOffset, y: dragVerticalOffset)
                                .ignoresSafeArea(.all)
                                .zIndex(1)  // 黑色容器层级

                                // 第二个容器
                                VStack(spacing: 0) {
                                    Rectangle()
                                        .fill(Color.black.opacity(0.15))
                                        .frame(width: isLighted ? geometry.size.width : geometry.size.width, height: 120)
                                        .overlay(
                                            ZStack {
                                                // 顶部长条
                                                Rectangle()
                                                    .fill(BorderLightStyleManager.shared.iconColor.opacity(0.3))
                                                    .frame(width: 150, height: 2)
                                                    .cornerRadius(4)
                                                    .padding(.top, -60)
                                                
                                                HStack(spacing: 60) {
                                                    Spacer()
                                                    
                                                    // 使用创建函数替换直接创建
                                                    createSettingsButton(geometry: geometry)
                                                        .onAppear {
                                                            let iconColor = BorderLightStyleManager.shared.iconColor
                                                            print("设置按钮颜色：\(getColorDetails(iconColor))")
                                                            print("容器背景透明度：0.35")
                                                        }
                                                    
                                                    createHelpButton(geometry: geometry)
                                                        .onAppear {
                                                            let iconColor = BorderLightStyleManager.shared.iconColor
                                                            print("帮助按钮颜色：\(getColorDetails(iconColor))")
                                                            print("容器背景透明度：0.35")
                                                        }
                                                    
                                                    Spacer()
                                                }
                                            }
                                        )
                                }
                                .frame(maxHeight: .infinity, alignment: .bottom)
                                .offset(x: containerOffset, y: dragVerticalOffset + 120)
                                .animation(.easeInOut(duration: 0.3), value: isLighted)
                                .ignoresSafeArea(.all)
                                .zIndex(0)  // 黄色容器层级
                            }
                            .zIndex(0)  // 容器组层级

                            // 箭头放置在最上层
                            VStack {
                                Spacer()
                                DraggableArrow(isExpanded: !isControlPanelVisible, 
                                             isLighted: isLighted,
                                             screenWidth: geometry.size.width,
                                             deviceOrientation: orientationManager.currentOrientation,
                                             isControlPanelVisible: $isControlPanelVisible,
                                             showDragHint: $showArrowHint,
                                             dragHintState: $dragHintState,
                                             dragOffset: $dragOffset,
                                             dragVerticalOffset: $dragVerticalOffset,
                                             containerOffset: $containerOffset)
                                    .padding(.bottom, 120)
                            }
                            .offset(x: dragOffset, y: dragVerticalOffset)
                            .zIndex(2)  // 箭头容器层级
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .ignoresSafeArea(.all, edges: .bottom)
                        .zIndex(4)
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
                        
                    // 添加独立的边框视图，放在最上层
                    if cameraManager.isMirrored {
                        CameraBorderView(isSelected: ModeASelected, isLighted: isLighted)
                            .zIndex(5)  // 提高边框视图的层级
                    } else {
                        CameraBorderView(isSelected: ModeBSelected, isLighted: isLighted)
                            .zIndex(5)  // 提高边框视图的层级
                    }
                    
                    // 修改参考格纹图视图的调用和层级
                    if showReferenceGrid {
                        ReferenceGridView(
                            gridSpacing: gridSpacing,
                            lineColor: gridLineColor,
                            lineOpacity: gridLineOpacity
                        )
                        .zIndex(3)  // 调整层级到工具栏下方
                    }
                    
                    // 添加左下角和右下角的按钮
                    VStack {
                        Spacer()
                        HStack {
                            // 左下角放缩按钮
                            VStack(spacing: 10) {
                                // r.circle.fill 按钮
                                Button(action: {
                                    // 触发震动反馈
                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                    generator.impactOccurred()
                                    
                                    // 使用 RealModeController 切换状态
                                    realModeController.toggleRealMode()
                                }) {
                                    Image(systemName: realModeController.isRealModeEnabled ? "r.circle.fill" : "r.circle")
                                        .font(.system(size: 20))
                                        .foregroundColor(styleManager.iconColor)
                                        .frame(width: 44, height: 44)
                                        .background(Color.black.opacity(0.15))
                                        .clipShape(Circle())
                                }
                                
                                // 放缩按钮
                                Button(action: {
                                    // 根据当前缩放状态执行相应操作
                                    if abs(currentScale - minScale) < 0.01 {
                                        // 当前是全景模式，点击后放大到100%
                                        currentScale = 1.0
                                        baseScale = 1.0
                                        isZoomExpanded = true
                                        showScaleIndicator = true
                                        currentIndicatorScale = 1.0
                                        
                                        // 延迟隐藏缩放提示
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                            showScaleIndicator = false
                                        }
                                        
                                        // 记录缩放操作
                                        ViewActionLogger.shared.logZoomAction(scale: 1.0)
                                    } else {
                                        // 当前是100%或更大，点击后缩小到全景模式
                                        currentScale = minScale
                                        baseScale = minScale
                                        isZoomExpanded = false
                                        showScaleIndicator = true
                                        currentIndicatorScale = minScale
                                        
                                        // 延迟隐藏缩放提示
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                            showScaleIndicator = false
                                        }
                                        
                                        // 记录缩放操作
                                        ViewActionLogger.shared.logZoomAction(scale: minScale)
                                    }
                                    
                                    // 触发震动反馈
                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                    generator.impactOccurred()
                                }) {
                                    Image(systemName: abs(currentScale - minScale) < 0.01 ? 
                                        "arrow.down.left.and.arrow.up.right" : 
                                        "arrow.down.forward.and.arrow.up.backward")
                                        .font(.system(size: 20))
                                        .foregroundColor(styleManager.iconColor)
                                        .frame(width: 44, height: 44)
                                        .background(Color.black.opacity(0.15))
                                        .clipShape(Circle())
                                }
                            }
                            .padding(.leading, 20)
                            .padding(.bottom, 140)
                            
                            Spacer()
                            
                            // 右下角昼夜切换按钮
                            VStack(spacing: 10) {
                                // 白天模式按钮
                                Button(action: {
                                    // 触发震动反馈
                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                    generator.impactOccurred()
                                    
                                    // 切换到白天模式
                                    dayNightManager.switchToDayMode()
                                }) {
                                    Image(systemName: "sun.min.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(dayNightManager.isDayMode ? styleManager.iconColor : styleManager.iconColor.opacity(0.5))
                                        .frame(width: 44, height: 44)
                                        .background(Color.black.opacity(0.15))
                                        .clipShape(Circle())
                                }
                                
                                // 夜晚模式按钮
                                Button(action: {
                                    // 触发震动反馈
                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                    generator.impactOccurred()
                                    
                                    // 切换到夜晚模式
                                    dayNightManager.switchToNightMode()
                                }) {
                                    Image(systemName: "moon.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(!dayNightManager.isDayMode ? styleManager.iconColor : styleManager.iconColor.opacity(0.5))
                                        .frame(width: 44, height: 44)
                                        .background(Color.black.opacity(0.15))
                                        .clipShape(Circle())
                                }
                            }
                            .padding(.trailing, 20)
                            .padding(.bottom, 140)
                        }
                    }
                    .zIndex(5)
                } else {
                    CameraPermissionView()
                }
                
                // 添加工具栏到最顶层
                if isControlsVisible {
                    DraggableToolbar(
                        captureState: captureState,
                        isVisible: $isControlsVisible,
                        showMakeupView: $showMakeupView,
                        containerSelected: cameraManager.isMirrored ? $ModeASelected : $ModeBSelected,
                        isLighted: $isLighted,
                        previousBrightness: previousBrightness,
                        currentScale: $currentScale,
                        baseScale: $baseScale,
                        cameraManager: cameraManager,
                        showReferenceGrid: $showReferenceGrid
                    )
                    .zIndex(6)  // 保持工具栏在较高层级
                }
                
                // 添加截图操作视图
                if captureManager.isPreviewVisible {
                    CaptureActionsView(
                        captureManager: captureManager,
                        cameraManager: cameraManager,
                        onDismiss: {
                            // 截图操作完成后显示所有控制界面
                            withAnimation {
                                isControlsVisible = true
                                isControlAreaVisible = true
                            }
                        }
                    )
                    .zIndex(7)
                }
                
                // 添加提示视图到最顶层
                if showArrowHint {
                    DragHintView(hintState: dragHintState)
                        .position(x: geometry.size.width/2, y: {
                            switch dragHintState {
                            case .upAndRightLeft, .upOnly:
                                // 当箭头在底部时，提示显示在上方
                                return geometry.size.height/2 + 240
                            case .downAndRightLeft, .downOnly:
                                // 当箭头在顶部时，提示显示在下方
                                return geometry.size.height/2 + 120
                            case .rightOnly:
                                // 当箭头在左侧时，提示显示在右侧
                                return geometry.size.height/2 + 240
                            case .leftOnly:
                                // 当箭头在右侧时，提示显示在左侧
                                return geometry.size.height/2 + 240
                            }
                        }())
                        .offset(x: {
                            switch dragHintState {
                            case .rightOnly:
                                // 当箭头在左侧时，提示向右偏移
                                return -150
                            case .leftOnly:
                                // 当箭头在右侧时，提示向左偏移
                                return 150
                            default:
                                return 0
                            }
                        }())
                        .transition(.opacity)
                        .zIndex(4)
                }
                
                // 将化妆视图移到弹窗之前
                if showMakeupView {
                    DraggableMakeupView(isVisible: $showMakeupView, cameraManager: cameraManager)
                        .zIndex(6)  // 降低层级
                }
                
                // 添加设置面板
                if showSettings {
                    SettingsPanel(isPresented: $showSettings)
                        .zIndex(8)  // 提高层级
                }
                
                // 添加帮助面板
                if showHelp {
                    HelpPanel(isPresented: $showHelp)
                        .zIndex(8)  // 提高层级
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                permissionManager.checkInitialCameraPermission()
                
                // 检查并加载保存的配置
                let settings = UserSettingsManager.shared
                if settings.hasUserConfig() {
                    print("检测到保存的用户配置，开始加载...")
                    settings.applySettings()
                }
                
                // 添加屏幕亮度变化通知监听
                NotificationCenter.default.addObserver(
                    forName: UIScreen.brightnessDidChangeNotification,
                    object: nil,
                    queue: .main) { _ in
                        let currentBrightness = UIScreen.main.brightness
                        
                        if !ModeASelected && !ModeBSelected {
                            previousBrightness = currentBrightness
                            print("用户调整了屏幕亮度，更新初始亮度：\(currentBrightness)")
                        }
                    }
                
                // 添加按钮颜色更新通知监听
                NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("UpdateButtonColors"),
                    object: nil,
                    queue: .main) { _ in
                        // 强制视图刷新
                        withAnimation {
                            isControlAreaVisible.toggle()
                            isControlAreaVisible.toggle()
                        }
                    }
                
                // 添加网格设置更新通知监听
                NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("UpdateGridSettings"),
                    object: nil,
                    queue: .main) { notification in
                        if let userInfo = notification.userInfo,
                           let spacing = userInfo["spacing"] as? CGFloat,
                           let color = userInfo["color"] as? Color,
                           let opacity = userInfo["opacity"] as? Double {
                            // 直接更新预览，不保存设置
                            gridSpacing = spacing
                            gridLineColor = color
                            gridLineOpacity = opacity
                            
                            print("------------------------")
                            print("[网格设置] 更新预览")
                            print("- 网格间距：\(spacing)")
                            print("- 线条颜色：\(color)")
                            print("- 线条透明度：\(opacity)")
                            print("------------------------")
                        }
                    }
                
                // 添加自动进入全景模式的通知监听
                NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("AutoEnterPanoramaMode"),
                    object: nil,
                    queue: .main
                ) { _ in
                    print("------------------------")
                    print("[夜晚模式] 自动切换到全景模式")
                    print("当前缩放比例：\(currentScale)")
                    print("目标缩放比例：\(minScale)")
                    print("------------------------")
                    
                    // 自动切换到全景模式
                    currentScale = minScale
                    baseScale = minScale
                    isZoomExpanded = false
                    showScaleIndicator = true
                    currentIndicatorScale = minScale
                    
                    // 延迟隐藏缩放提示
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showScaleIndicator = false
                    }
                    
                    // 记录缩放操作
                    ViewActionLogger.shared.logZoomAction(scale: minScale)
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
                    queue: .main
                ) { _ in
                    restartManager.handleAppWillResignActive(cameraManager: cameraManager)
                }
                
                NotificationCenter.default.addObserver(
                    forName: UIApplication.didBecomeActiveNotification,
                    object: nil,
                    queue: .main
                ) { _ in
                    restartManager.handleAppDidBecomeActive()
                }
                
                // 添加分屏退出通知监听
                NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("DismissTwoOfMeView"),
                    object: nil,
                    queue: .main) { _ in
                        print("接收到分屏退出通知")
                        withAnimation {
                            showingTwoOfMe = false
                        }
                    }
                
                // 预准备震动反馈
                feedbackGenerator.prepare()
                
                permissionManager.updatePermissionState()
                
                // 检查是否需要自动进入双屏
                if ProManager.shared.isPro && UserSettingsManager.shared.loadAutoEnterTwoOfMe() {
                    print("------------------------")
                    print("[自动进入] 双屏模式")
                    print("------------------------")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        handleEnterTwoOfMe()
                    }
                }
            }
            .onDisappear {
                // 移除所有通知监听
                NotificationCenter.default.removeObserver(self)
                UIDevice.current.endGeneratingDeviceOrientationNotifications()
                
                print("主页面退出")
                print("------------------------")
            }
            // 添加 Live 模式切换提示弹窗
            .alert(isPresented: $showLiveAlert) {
                Alert(
                    title: Text("提示"),
                    message: Text(liveAlertMessage),
                    primaryButton: .default(Text("关闭实况")) {
                        // 关闭 Live 模式
                        cameraManager.toggleSystemCamera()
                        print("------------------------")
                        print("用户确认关闭 Live 模式")
                        print("------------------------")
                    },
                    secondaryButton: .cancel(Text("取消"))
                )
            }
            .fullScreenCover(isPresented: $showingTwoOfMe) {
                handleTwoOfMeDismiss()
            } content: {
                TwoOfMeScreens()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .opacity.combined(with: .move(edge: .leading))
                    ))
                    .animation(.easeInOut(duration: 0.3), value: showingTwoOfMe)
            }
            .sheet(isPresented: $proManager.showProUpgradeSheet) {
                ProUpgradeView(
                    dismiss: { proManager.showProUpgradeSheet = false },
                    onDismiss: {
                        if proManager.isFromMiddleButton {
                            handleEnterTwoOfMe()
                        }
                    }
                )
            }
            // 添加权限管理视图作为 overlay
            .overlay(
                PermissionManagerView()
                    .zIndex(1000)
            )
        }
        // 在最外层添加权限管理视图
        .overlay(
            PermissionManagerView()
                .zIndex(1000)
        )
    }
    
    private func handleTwoOfMeDismiss() {
        print("------------------------")
        print("处理分屏页面退出")
        print("------------------------")
        
        // 先停止相机会话
        cameraManager.safelyStopSession()
        
        // 设置相机模式
        cameraManager.isMirrored = false
        
        // 显示重启提示，等待用户点击
        restartManager.isCameraActive = false
        restartManager.showRestartHint = true
    }
    
    // 修改缩放处理函数
    private func handlePinchGesture(scale: CGFloat) {
        // 如果应该忽略缩放，直接返回
        if shouldIgnoreScale {
            return
        }
        
        let newScale = baseScale * scale
        
        // 更新缩放提示
        currentIndicatorScale = currentScale
        showScaleIndicator = true
        
        // 特殊处理100%和60%之间的缩放
        if abs(currentScale - 1.0) < 0.01 && scale < 1.0 {
            // 从100%缩小时，直接跳到60%
            currentScale = minScale
            baseScale = minScale
            currentIndicatorScale = minScale  // 确保提示显示正确的比例
            
            print("------------------------")
            print("从100%直接缩小到4:3比例")
            print("------------------------")
            
            // 记录缩放操作
            ViewActionLogger.shared.logZoomAction(scale: currentScale)
            return
        } else if abs(currentScale - minScale) < 0.01 && scale > 1.0 {
            // 从60%放大时，直接跳到100%并结束当前手势
            currentScale = 1.0
            baseScale = 1.0
            currentIndicatorScale = 1.0  // 确保提示显示正确的比例
            shouldIgnoreScale = true  // 设置忽略标志
            
            print("------------------------")
            print("从4:3比例直接放大到100%")
            print("------------------------")
            
            // 记录缩放操作
            ViewActionLogger.shared.logZoomAction(scale: currentScale)
            return
        }
        
        // 处理其他缩放情况
        if newScale >= maxScale && scale > 1.0 {
            currentScale = maxScale
            if !showScaleLimitMessage {
                print("------------------------")
                print("已放大至最大尺寸")
                print("------------------------")
                showScaleLimitMessage = true
                scaleLimitMessage = "已放大至最大尺寸"
                
                // 记录缩放限制
                ViewActionLogger.shared.logAction(
                    .gestureAction(.pinch),
                    additionalInfo: ["状态": "达到最大缩放限制"]
                )
            }
        } else if newScale <= minScale && scale < 1.0 {
            currentScale = minScale
            if !showScaleLimitMessage {
                print("------------------------")
                print("已缩小至4:3比例")
                print("------------------------")
                showScaleLimitMessage = true
                scaleLimitMessage = "已缩小至4:3比例"
                
                // 记录缩放限制
                ViewActionLogger.shared.logAction(
                    .gestureAction(.pinch),
                    additionalInfo: ["状态": "达到4:3比例"]
                )
            }
        } else if currentScale >= 1.0 {
            // 在100%以上时允许自由缩放
            currentScale = min(newScale, maxScale)
            showScaleLimitMessage = false
        }
        
        // 更新提示比例
        currentIndicatorScale = currentScale
        
        // 记录缩放操作
        ViewActionLogger.shared.logZoomAction(scale: currentScale)
        
        // 打印日志
        let scaleDescription = abs(currentScale - minScale) < 0.01 ? "小尺寸模式" : "\(Int(currentScale * 100))%"
        print("------------------------")
        print("双指缩放")
        print("当前比例：\(scaleDescription)")
        print("------------------------")
    }
    
    private func handlePinchEnd(scale: CGFloat) {
        shouldIgnoreScale = false  // 重置忽略标志
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
    
    // 修改获取旋转角度的方法
    private func getRotationAngle(_ orientation: UIDeviceOrientation) -> Angle {
        return orientationManager.getRotationAngle(orientation)
    }
    
    // 修改方向描述辅助方法
    private func getOrientationDescription(_ orientation: UIDeviceOrientation) -> String {
        return orientationManager.getOrientationDescription(orientation)
    }
    
    // 添加颜色比较辅助方法
    private func compareColors(_ color1: Color, _ color2: Color) -> Bool {
        let uiColor1 = UIColor(color1)
        let uiColor2 = UIColor(color2)
        var red1: CGFloat = 0, green1: CGFloat = 0, blue1: CGFloat = 0, alpha1: CGFloat = 0
        var red2: CGFloat = 0, green2: CGFloat = 0, blue2: CGFloat = 0, alpha2: CGFloat = 0
        
        uiColor1.getRed(&red1, green: &green1, blue: &blue1, alpha: &alpha1)
        uiColor2.getRed(&red2, green: &green2, blue: &blue2, alpha: &alpha2)
        
        let tolerance: CGFloat = 0.01
        return abs(red1 - red2) < tolerance && 
               abs(green1 - green2) < tolerance && 
               abs(blue1 - blue2) < tolerance
    }
    
    // 添加颜色调试辅助函数
    private func getColorDetails(_ color: Color) -> String {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(format: "RGB(%.3f, %.3f, %.3f) Alpha: %.3f", red, green, blue, alpha)
    }
    
    // 更新左按钮创建函数
    private func createLeftButton(geometry: GeometryProxy) -> some View {
        let styleManager = BorderLightStyleManager.shared
        return CircleButton(
            imageName: "icon-bf-white-left",
            systemName: nil,
            title: "",
            action: {
                // 触发震动反馈
                feedbackGenerator.impactOccurred()
                
                // 检查是否处于Live模式
                if cameraManager.isUsingSystemCamera {
                    // 显示提示弹窗
                    showLiveModeSwitchAlert(mode: "A")
                    return
                }
                
                // 记录模式切换
                ViewActionLogger.shared.logModeSwitch(toModeA: true)
                
                // 更新动画逻辑
                leftAnimationPosition = CGPoint(x: geometry.size.width/2 - 80, y: geometry.size.height - 25 + dragVerticalOffset)
                withAnimation {
                    showLeftIconAnimation = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                    withAnimation {
                        showLeftIconAnimation = false
                    }
                }
                
                print("------------------------")
                print("点击左按钮 - 切换到模式A")
                print("当前状态: 模式A选中=\(ModeASelected), 模式B选中=\(ModeBSelected), 高亮=\(isLighted)")
                
                ModeASelected = ModeBSelected
                isLighted = ModeBSelected
                
                if ModeBSelected {
                    UIScreen.main.brightness = 1.0
                    print("切换到模式A - 保持最大亮度")
                } else {
                    UIScreen.main.brightness = previousBrightness
                    print("切换到模式A - 保持原始亮度：\(previousBrightness)")
                }
                
                if let processor = cameraManager.videoOutputDelegate as? MainVideoProcessor {
                    processor.setMode(.modeA)
                }
                cameraManager.isMirrored = true
                ModeBSelected = false
                
                print("切换后状态: 模式A选中=\(ModeASelected), 模式B选中=\(ModeBSelected), 高亮=\(isLighted)")
                print("------------------------")
            },
            deviceOrientation: orientationManager.currentOrientation,
            isDisabled: cameraManager.isMirrored,
            useCustomColor: true,
            customColor: styleManager.iconColor
        )
    }
    
    // 修改中间按钮创建函数
    private func createMiddleButton(geometry: GeometryProxy) -> some View {
        let styleManager = BorderLightStyleManager.shared
        let iconName = styleManager.splitScreenIconImage
        
        return CircleButton(
            imageName: iconName,
            systemName: nil,
            title: "",
            action: {
                // 触发震动反馈
                heavyFeedbackGenerator.impactOccurred()
                
                // 设置动画位置
                middleAnimationPosition = CGPoint(
                    x: geometry.size.width/2, 
                    y: geometry.size.height - 25 + dragVerticalOffset  // 向上移动200pt
                )

                if ProManager.shared.isPro {
                    // Pro 用户直接进入 TwoOfMe 页面
                    handleEnterTwoOfMe()
                } else {
                    // 非 Pro 用户显示升级弹窗
                    ProManager.shared.showProUpgrade(isFromMiddleButton: true)
                }
            },
            deviceOrientation: orientationManager.currentOrientation,
            useCustomColor: !iconName.hasPrefix("color") && iconName != "icon-bf-color-1",
            customColor: styleManager.splitScreenIconColor
        )
    }
    
    // 修改辅助函数，添加括号
    private func handleEnterTwoOfMe() {  // 添加括号
        withAnimation {
            showMiddleIconAnimation = true
        }
        
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
        
        UIScreen.main.brightness = previousBrightness
        print("进入 Two of Me 前 - 强制恢复原始亮度：\(previousBrightness)")
        
        // 立即停止相机并显示重启提示
        cameraManager.safelyStopSession()
        restartManager.isCameraActive = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            withAnimation {
                showMiddleIconAnimation = false
                print("进入 Two of Me 模式")
                showingTwoOfMe = true
            }
        }
    }
    
    // 更新右按钮创建函数
    private func createRightButton(geometry: GeometryProxy) -> some View {
        let styleManager = BorderLightStyleManager.shared
        return CircleButton(
            imageName: "icon-bf-white-right",
            systemName: nil,
            title: "",
            action: {
                // 触发震动反馈
                feedbackGenerator.impactOccurred()
                
                // 检查是否处于Live模式
                if cameraManager.isUsingSystemCamera {
                    // 显示提示弹窗
                    showLiveModeSwitchAlert(mode: "B")
                    return
                }
                
                // 记录模式切换
                ViewActionLogger.shared.logModeSwitch(toModeA: false)
                
                // 更新动画逻辑
                rightAnimationPosition = CGPoint(x: geometry.size.width/2 + 80, y: geometry.size.height - 25 + dragVerticalOffset)
                withAnimation {
                    showRightIconAnimation = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                    withAnimation {
                        showRightIconAnimation = false
                    }
                }
                
                print("------------------------")
                print("点击右按钮 - 切换到模式B")
                print("当前状态: 模式A选中=\(ModeASelected), 模式B选中=\(ModeBSelected), 高亮=\(isLighted)")
                
                ModeBSelected = ModeASelected
                isLighted = ModeASelected
                
                if ModeASelected {
                    UIScreen.main.brightness = 1.0
                    print("切换到模式B - 保持最大亮度")
                } else {
                    UIScreen.main.brightness = previousBrightness
                    print("切换到模式B - 保持原始亮度：\(previousBrightness)")
                }
                
                if let processor = cameraManager.videoOutputDelegate as? MainVideoProcessor {
                    processor.setMode(.modeB)
                }
                cameraManager.isMirrored = false
                ModeASelected = false
                
                print("切换后状态: 模式A选中=\(ModeASelected), 模式B选中=\(ModeBSelected), 高亮=\(isLighted)")
                print("------------------------")
            },
            deviceOrientation: orientationManager.currentOrientation,
            isDisabled: !cameraManager.isMirrored,
            useCustomColor: true,
            customColor: styleManager.iconColor
        )
    }
    
    // 更新设置按钮创建函数
    private func createSettingsButton(geometry: GeometryProxy) -> some View {
        let styleManager = BorderLightStyleManager.shared
        return CircleButton(
            imageName: nil,
            systemName: "gearshape.fill",
            title: "",
            action: {
                // 触发震动反馈
                lightFeedbackGenerator.impactOccurred()
                
                withAnimation(.easeInOut(duration: 0.2)) {
                    showSettings = true
                }
            },
            deviceOrientation: orientationManager.currentOrientation,
            isDisabled: false,
            useCustomColor: true,
            customColor: styleManager.iconColor
        )
    }
    
    // 更新帮助按钮创建函数
    private func createHelpButton(geometry: GeometryProxy) -> some View {
        let styleManager = BorderLightStyleManager.shared
        return CircleButton(
            imageName: nil,
            systemName: "questionmark.circle.fill",
            title: "",
            action: {
                // 触发震动反馈
                lightFeedbackGenerator.impactOccurred()
                
                withAnimation(.easeInOut(duration: 0.2)) {
                    showHelp = true
                }
            },
            deviceOrientation: orientationManager.currentOrientation,
            isDisabled: false,
            useCustomColor: true,
            customColor: styleManager.iconColor
        )
    }
    
    // 修改显示Live模式切换提示弹窗的函数
    private func showLiveModeSwitchAlert(mode: String) {
        print("------------------------")
        print("Live模式下尝试切换到模式\(mode)")
        print("显示提示弹窗")
        print("------------------------")
        
        liveAlertMessage = "切换将关闭实况功能"
        showLiveAlert = true
    }
}

#Preview {
    ContentView()
        .environmentObject(CameraManager())
        .environmentObject(CaptureState())
}
