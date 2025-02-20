import SwiftUI

// 手势管理器
class TwoOfMeGestureManager {
    // 创建双击和单击手势
    static func createTapGestures(
        for screenID: ScreenID,
        isZone2Enabled: Bool,
        isZone3Enabled: Bool,
        isDefaultGesture: Bool,
        isScreensSwapped: Bool,
        layoutDescription: String,
        currentImageScale: Binding<CGFloat>,
        originalImageScale: Binding<CGFloat>,
        currentMirroredImageScale: Binding<CGFloat>,
        mirroredImageScale: Binding<CGFloat>,
        togglePauseState: @escaping (ScreenID) -> Void,
        handleSingleTap: @escaping (ScreenID) -> Void,
        imageUploader: ImageUploader
    ) -> some Gesture {
        let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
        feedbackGenerator.prepare()
        
        return ExclusiveGesture(
            TapGesture(count: 2)
                .onEnded {
                    // 检查当前分屏的手电筒状态
                    if imageUploader.isFlashlightActive(for: screenID) {
                        print("------------------------")
                        print("[手势] 被禁用")
                        print("区域：\(screenID == .original ? "Original" : "Mirrored")屏幕")
                        print("原因：该分屏手电筒已激活")
                        print("------------------------")
                        return
                    }
                    
                    if screenID == .original ? isZone2Enabled : isZone3Enabled {
                        // 触发震动反馈
                        feedbackGenerator.impactOccurred()
                        
                        if isDefaultGesture {
                            print("------------------------")
                            print("触控区\(screenID == .original ? "2" : "3")被双击")
                            print("区域：\(screenID.debugName)屏幕")
                            print("位置：\(isScreensSwapped ? (screenID == .original ? "下部" : "上部") : (screenID == .original ? "上部" : "下部"))")
                            print("进入触控区\(screenID == .original ? "2a" : "3a")")
                            
                            togglePauseState(screenID)
                            
                            // 在Original屏幕被定格时，自动将画面缩放比例重置为100%
                            if screenID == .original {
                                currentImageScale.wrappedValue = 1.0
                                originalImageScale.wrappedValue = 1.0
                                
                                print("------------------------")
                                print("[Original屏幕自动缩放]")
                                print("定格后自动重置缩放比例为100%")
                                print("------------------------")
                            }
                                                        
                            // 在Mirrored屏幕被定格时，自动将画面缩放比例重置为100%
                            if screenID == .mirrored {
                                currentMirroredImageScale.wrappedValue = 1.0
                                mirroredImageScale.wrappedValue = 1.0
                                
                                print("------------------------")
                                print("[Mirrored屏幕自动缩放]")
                                print("定格后自动重置缩放比例为100%")
                                print("------------------------")
                            }
                            print("当前布局：\(layoutDescription)")
                            print("------------------------")
                        } else {
                            handleSingleTap(screenID)
                        }
                    }
                },
            TapGesture(count: 1)
                .onEnded {
                    // 检查当前分屏的手电筒状态
                    if imageUploader.isFlashlightActive(for: screenID) {
                        print("------------------------")
                        print("[手势] 被禁用")
                        print("区域：\(screenID == .original ? "Original" : "Mirrored")屏幕")
                        print("原因：该分屏手电筒已激活")
                        print("------------------------")
                        return
                    }
                    
                    if screenID == .original ? isZone2Enabled : isZone3Enabled {
                        // 触发震动反馈
                        feedbackGenerator.impactOccurred()
                        
                        if isDefaultGesture {
                            handleSingleTap(screenID)
                        } else {
                            togglePauseState(screenID)
                        }
                    }
                }
        )
    }
    
    // 创建缩放手势
    static func createPinchGesture(
        for screenID: ScreenID,
        isZone2Enabled: Bool,
        isZone3Enabled: Bool,
        isOriginalPaused: Bool,
        isMirroredPaused: Bool,
        // Original 画面的缩放参数
        originalCameraScale: Binding<CGFloat>,
        originalImageScale: Binding<CGFloat>,
        currentCameraScale: Binding<CGFloat>,
        currentImageScale: Binding<CGFloat>,
        // Mirrored 画面的缩放参数
        mirroredCameraScale: Binding<CGFloat>,
        mirroredImageScale: Binding<CGFloat>,
        currentMirroredCameraScale: Binding<CGFloat>,
        currentMirroredImageScale: Binding<CGFloat>,
        minScale: CGFloat,
        maxScale: CGFloat,
        currentIndicatorScale: Binding<CGFloat>,
        activeScalingScreen: Binding<ScreenID?>,
        showScaleIndicator: Binding<Bool>,
        originalOffset: CGSize,
        mirroredOffset: CGSize,
        isImageOutOfBounds: @escaping (CGFloat, CGSize, CGFloat, CGFloat) -> Bool,
        centerImage: @escaping (CGFloat) -> Void,
        centerMirroredImage: @escaping (CGFloat) -> Void
    ) -> some Gesture {
        MagnificationGesture()
            .onChanged { scale in
                if screenID == .original ? isZone2Enabled : isZone3Enabled {
                    if screenID == .original {
                        if isOriginalPaused {
                            let dampedScale = 1.0 + (scale - 1.0) * 0.1
                            let newScale = originalImageScale.wrappedValue * dampedScale
                            currentImageScale.wrappedValue = min(max(newScale, minScale), maxScale)
                            
                            print("------------------------")
                            print("[Original屏幕缩放]")
                            print("1. 摄像头比例")
                            print("   - 基准比例: \(Int(originalCameraScale.wrappedValue * 100))%")
                            print("2. 定格图片比例")
                            print("   - 基准比例: \(Int(originalImageScale.wrappedValue * 100))%")
                            print("   - 手势缩放: \(Int(dampedScale * 100))%")
                            print("   - 最终比例: \(Int(currentImageScale.wrappedValue * 100))%")
                            print("------------------------")
                        } else {
                            let newScale = originalCameraScale.wrappedValue * scale
                            currentCameraScale.wrappedValue = min(max(newScale, minScale), maxScale)
                            
                            print("------------------------")
                            print("[Original屏幕缩放]")
                            print("1. 摄像头比例")
                            print("   - 基准比例: \(Int(originalCameraScale.wrappedValue * 100))%")
                            print("   - 手势缩放: \(Int(scale * 100))%")
                            print("   - 最终比例: \(Int(currentCameraScale.wrappedValue * 100))%")
                            print("2. 定格图片比例")
                            print("   - 未定格")
                            print("------------------------")
                        }
                        
                        // 更新缩放指示器
                        currentIndicatorScale.wrappedValue = isOriginalPaused ? 
                            currentImageScale.wrappedValue : currentCameraScale.wrappedValue
                        activeScalingScreen.wrappedValue = .original
                        showScaleIndicator.wrappedValue = true
                        
                    } else {
                        if isMirroredPaused {
                            let dampedScale = 1.0 + (scale - 1.0) * 0.1
                            let newScale = mirroredImageScale.wrappedValue * dampedScale
                            currentMirroredImageScale.wrappedValue = min(max(newScale, minScale), maxScale)
                            
                            print("------------------------")
                            print("[Mirrored屏幕缩放]")
                            print("1. 摄像头比例")
                            print("   - 基准比例: \(Int(mirroredCameraScale.wrappedValue * 100))%")
                            print("2. 定格图片比例")
                            print("   - 基准比例: \(Int(mirroredImageScale.wrappedValue * 100))%")
                            print("   - 手势缩放: \(Int(dampedScale * 100))%")
                            print("   - 最终比例: \(Int(currentMirroredImageScale.wrappedValue * 100))%")
                            print("------------------------")
                        } else {
                            let newScale = mirroredCameraScale.wrappedValue * scale
                            currentMirroredCameraScale.wrappedValue = min(max(newScale, minScale), maxScale)
                            
                            print("------------------------")
                            print("[Mirrored屏幕缩放]")
                            print("1. 摄像头比例")
                            print("   - 基准比例: \(Int(mirroredCameraScale.wrappedValue * 100))%")
                            print("   - 手势缩放: \(Int(scale * 100))%")
                            print("   - 最终比例: \(Int(currentMirroredCameraScale.wrappedValue * 100))%")
                            print("2. 定格图片比例")
                            print("   - 未定格")
                            print("------------------------")
                        }
                        
                        // 更新缩放指示器
                        currentIndicatorScale.wrappedValue = isMirroredPaused ? 
                            currentMirroredImageScale.wrappedValue : currentMirroredCameraScale.wrappedValue
                        activeScalingScreen.wrappedValue = .mirrored
                        showScaleIndicator.wrappedValue = true
                    }
                }
            }
            .onEnded { endScale in
                // 移除动画
                if screenID == .original {
                    if isOriginalPaused {
                        originalImageScale.wrappedValue = currentImageScale.wrappedValue
                        
                        // 只在缩小时检查边界并居中
                        if endScale < 1.0 && isImageOutOfBounds(currentImageScale.wrappedValue, originalOffset, minScale, maxScale) {
                            centerImage(currentImageScale.wrappedValue)
                        }
                    } else {
                        originalCameraScale.wrappedValue = currentCameraScale.wrappedValue
                    }
                } else {
                    if isMirroredPaused {
                        mirroredImageScale.wrappedValue = currentMirroredImageScale.wrappedValue
                        
                        // 只在缩小时检查边界并居中
                        if endScale < 1.0 && isImageOutOfBounds(currentMirroredImageScale.wrappedValue, mirroredOffset, minScale, maxScale) {
                            centerMirroredImage(currentMirroredImageScale.wrappedValue)
                        }
                    } else {
                        mirroredCameraScale.wrappedValue = currentMirroredCameraScale.wrappedValue
                    }
                }
                
                // 延迟隐藏缩放提示
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showScaleIndicator.wrappedValue = false
                    activeScalingScreen.wrappedValue = nil
                }
            }
    }
    
    // 创建长按手势
    static func createLongPressGesture(
        for screenID: ScreenID,
        isZone2Enabled: Bool,
        isZone3Enabled: Bool,
        isScreensSwapped: Bool,
        isOriginalPaused: Bool,
        isMirroredPaused: Bool,
        imageUploader: ImageUploader
    ) -> some Gesture {
        let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
        feedbackGenerator.prepare()
        
        return LongPressGesture(minimumDuration: 0.8)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                // 检查是否有全屏灯激活
                if imageUploader.isFlashlightActive(for: screenID) {
                    return
                }
                
                switch value {
                case .second(true, _):
                    if screenID == .original ? isZone2Enabled : isZone3Enabled {
                        // 触发震动反馈
                        feedbackGenerator.impactOccurred()
                        
                        print("------------------------")
                        print("触控区\(screenID == .original ? "2" : "3")被长按")
                        print("区域：\(screenID.debugName)屏幕")
                        print("位置：\(isScreensSwapped ? (screenID == .original ? "下部" : "上部") : (screenID == .original ? "上部" : "下部"))")
                        print("------------------------")
                        
                        if screenID == .original {
                            if isOriginalPaused {
                                imageUploader.showDownloadOverlay(for: .original)
                            } else {
                                imageUploader.showRectangle(for: .original)
                            }
                        } else {
                            if isMirroredPaused {
                                imageUploader.showDownloadOverlay(for: .mirrored)
                            } else {
                                imageUploader.showRectangle(for: .mirrored)
                            }
                        }
                    }
                default:
                    break
                }
            }
    }
    
    // 创建拖动手势
    static func createDragGesture(
        for screenID: ScreenID,
        isZone2Enabled: Bool,
        isZone3Enabled: Bool,
        isOriginalPaused: Bool,
        isMirroredPaused: Bool,
        currentScale: CGFloat,
        currentMirroredScale: CGFloat,
        originalOffset: CGSize,
        mirroredOffset: CGSize,
        imageUploader: ImageUploader,
        isImageOutOfBounds: @escaping (CGFloat, CGSize, CGFloat, CGFloat) -> Bool,
        centerImage: @escaping (CGFloat) -> Void,
        centerMirroredImage: @escaping (CGFloat) -> Void,
        handleDragGesture: @escaping (DragGesture.Value, CGFloat, CGFloat, CGFloat, CGSize) -> Void,
        handleMirroredDragGesture: @escaping (DragGesture.Value, CGFloat, CGFloat, CGFloat, CGSize) -> Void,
        handleDragEnd: @escaping () -> Void,
        handleMirroredDragEnd: @escaping () -> Void
    ) -> some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                if imageUploader.isFlashlightActive(for: screenID) {
                    return
                }
                
                if screenID == .original ? isZone2Enabled : isZone3Enabled {
                    if screenID == .original {
                        if isOriginalPaused && currentScale > 1.0 {
                            // 使用 DeviceOrientationManager 的当前有效方向
                            let orientation = DeviceOrientationManager.shared.validOrientation
                            let dampedTranslation = getRotatedTranslation(
                                CGSize(
                                    width: value.translation.width * 0.7,
                                    height: value.translation.height * 0.7
                                ),
                                for: orientation
                            )
                            
                            handleDragGesture(
                                value,
                                UIScreen.main.bounds.width,
                                UIScreen.main.bounds.height,
                                UIScreen.main.bounds.height / 2,
                                dampedTranslation
                            )
                        }
                    } else {
                        if isMirroredPaused && currentMirroredScale > 1.0 {
                            // 使用 DeviceOrientationManager 的当前有效方向
                            let orientation = DeviceOrientationManager.shared.validOrientation
                            let dampedTranslation = getRotatedTranslation(
                                CGSize(
                                    width: value.translation.width * 0.7,
                                    height: value.translation.height * 0.7
                                ),
                                for: orientation
                            )
                            
                            handleMirroredDragGesture(
                                value,
                                UIScreen.main.bounds.width,
                                UIScreen.main.bounds.height,
                                UIScreen.main.bounds.height / 2,
                                dampedTranslation
                            )
                        }
                    }
                }
            }
            .onEnded { _ in
                // 检查当前分屏的手电筒状态
                if imageUploader.isFlashlightActive(for: screenID) {
                    return
                }
                
                if screenID == .original ? isZone2Enabled : isZone3Enabled {
                    if screenID == .original {
                        if isOriginalPaused && currentScale > 1.0 {
                            handleDragEnd()
                            
                            // 检查是否需要中心校准
                            if isImageOutOfBounds(
                                currentScale,
                                originalOffset,
                                UIScreen.main.bounds.width,
                                UIScreen.main.bounds.height
                            ) {
                                print("拖动结束，图片超出边界，执行中心位置矫正")
                                centerImage(currentScale)
                            }
                        }
                    } else {
                        if isMirroredPaused && currentMirroredScale > 1.0 {
                            handleMirroredDragEnd()
                            
                            // 检查是否需要中心校准
                            if isImageOutOfBounds(
                                currentMirroredScale,
                                mirroredOffset,
                                UIScreen.main.bounds.width,
                                UIScreen.main.bounds.height
                            ) {
                                print("拖动结束，图片超出边界，执行中心位置矫正")
                                centerMirroredImage(currentMirroredScale)
                            }
                        }
                    }
                }
            }
    }
    
    // 添加获取旋转后偏移的辅助方法
    private static func getRotatedTranslation(_ translation: CGSize, for orientation: UIDeviceOrientation) -> CGSize {
        // 只处理允许的方向
        if DeviceOrientationManager.shared.isAllowedOrientation(orientation) {
            switch orientation {
            case .landscapeLeft:
                return CGSize(
                    width: translation.height,
                    height: -translation.width
                )
            case .landscapeRight:
                return CGSize(
                    width: -translation.height,
                    height: translation.width
                )
            case .portraitUpsideDown:
                return CGSize(
                    width: -translation.width,
                    height: -translation.height
                )
            default:
                return translation
            }
        } else {
            // 如果不是允许的方向，使用最后一个有效方向
            let lastValidOrientation = DeviceOrientationManager.shared.validOrientation
            return getRotatedTranslation(translation, for: lastValidOrientation)
        }
    }
    
    // 创建组合手势
    static func createCombinedGestures(
        for screenID: ScreenID,
        isZone2Enabled: Bool,
        isZone3Enabled: Bool,
        isOriginalPaused: Bool,
        isMirroredPaused: Bool,
        originalScale: Binding<CGFloat>,
        mirroredScale: Binding<CGFloat>,
        currentScale: Binding<CGFloat>,
        currentMirroredScale: Binding<CGFloat>,
        minScale: CGFloat,
        maxScale: CGFloat,
        currentIndicatorScale: Binding<CGFloat>,
        activeScalingScreen: Binding<ScreenID?>,
        showScaleIndicator: Binding<Bool>,
        originalOffset: CGSize,
        mirroredOffset: CGSize,
        imageUploader: ImageUploader,
        isImageOutOfBounds: @escaping (CGFloat, CGSize, CGFloat, CGFloat) -> Bool,
        centerImage: @escaping (CGFloat) -> Void,
        centerMirroredImage: @escaping (CGFloat) -> Void,
        handleDragGesture: @escaping (DragGesture.Value, CGFloat, CGFloat, CGFloat, CGSize) -> Void,
        handleMirroredDragGesture: @escaping (DragGesture.Value, CGFloat, CGFloat, CGFloat, CGSize) -> Void,
        handleDragEnd: @escaping () -> Void,
        handleMirroredDragEnd: @escaping () -> Void
    ) -> some Gesture {
        SimultaneousGesture(
            createLongPressGesture(
                for: screenID,
                isZone2Enabled: isZone2Enabled,
                isZone3Enabled: isZone3Enabled,
                isScreensSwapped: false,
                isOriginalPaused: isOriginalPaused,
                isMirroredPaused: isMirroredPaused,
                imageUploader: imageUploader
            ),
            SimultaneousGesture(
                createPinchGesture(
                    for: screenID,
                    isZone2Enabled: isZone2Enabled,
                    isZone3Enabled: isZone3Enabled,
                    isOriginalPaused: isOriginalPaused,
                    isMirroredPaused: isMirroredPaused,
                    // Original 画面的缩放参数
                    originalCameraScale: originalScale,
                    originalImageScale: currentScale,
                    currentCameraScale: currentScale,
                    currentImageScale: currentScale,
                    // Mirrored 画面的缩放参数
                    mirroredCameraScale: mirroredScale,
                    mirroredImageScale: currentMirroredScale,
                    currentMirroredCameraScale: currentMirroredScale,
                    currentMirroredImageScale: currentMirroredScale,
                    minScale: minScale,
                    maxScale: maxScale,
                    currentIndicatorScale: currentIndicatorScale,
                    activeScalingScreen: activeScalingScreen,
                    showScaleIndicator: showScaleIndicator,
                    originalOffset: originalOffset,
                    mirroredOffset: mirroredOffset,
                    isImageOutOfBounds: isImageOutOfBounds,
                    centerImage: centerImage,
                    centerMirroredImage: centerMirroredImage
                ),
                createDragGesture(
                    for: screenID,
                    isZone2Enabled: isZone2Enabled,
                    isZone3Enabled: isZone3Enabled,
                    isOriginalPaused: isOriginalPaused,
                    isMirroredPaused: isMirroredPaused,
                    currentScale: currentScale.wrappedValue,
                    currentMirroredScale: currentMirroredScale.wrappedValue,
                    originalOffset: originalOffset,
                    mirroredOffset: mirroredOffset,
                    imageUploader: imageUploader,
                    isImageOutOfBounds: isImageOutOfBounds,
                    centerImage: centerImage,
                    centerMirroredImage: centerMirroredImage,
                    handleDragGesture: handleDragGesture,
                    handleMirroredDragGesture: handleMirroredDragGesture,
                    handleDragEnd: handleDragEnd,
                    handleMirroredDragEnd: handleMirroredDragEnd
                )
            )
        )
    }
} 