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
        isImageOutOfBounds: @escaping (CGFloat, CGSize, CGFloat, CGFloat) -> Bool,
        centerImage: @escaping (CGFloat) -> Void,
        centerMirroredImage: @escaping (CGFloat) -> Void
    ) -> some Gesture {
        MagnificationGesture()
            .onChanged { scale in
                if screenID == .original ? isZone2Enabled : isZone3Enabled {
                    if screenID == .original {
                        let newScale = originalScale.wrappedValue * scale
                        currentScale.wrappedValue = min(max(newScale, minScale), maxScale)
                        
                        // 添加缩放提示
                        currentIndicatorScale.wrappedValue = currentScale.wrappedValue
                        activeScalingScreen.wrappedValue = .original
                        showScaleIndicator.wrappedValue = true
                        
                        print("------------------------")
                        print("触控区2a双指手势：\(scale > 1.0 ? "拉开" : "靠近")")
                        print("画面比例：\(Int(currentScale.wrappedValue * 100))%")
                        print("------------------------")
                    } else {
                        let newScale = mirroredScale.wrappedValue * scale
                        currentMirroredScale.wrappedValue = min(max(newScale, minScale), maxScale)
                        
                        // 添加缩放提示
                        currentIndicatorScale.wrappedValue = currentMirroredScale.wrappedValue
                        activeScalingScreen.wrappedValue = .mirrored
                        showScaleIndicator.wrappedValue = true
                        
                        print("------------------------")
                        print("触控区3a双指手势：\(scale > 1.0 ? "拉开" : "靠近")")
                        print("画面比例：\(Int(currentMirroredScale.wrappedValue * 100))%")
                        print("------------------------")
                    }
                }
            }
            .onEnded { scale in
                if screenID == .original ? isZone2Enabled : isZone3Enabled {
                    if screenID == .original {
                        // 更新基准缩放值
                        originalScale.wrappedValue = currentScale.wrappedValue
                        
                        // 延迟隐藏缩放提示
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showScaleIndicator.wrappedValue = false
                            activeScalingScreen.wrappedValue = nil
                        }
                        
                        print("------------------------")
                        print("触控区2a双指手势结束")
                        print("最终画面比例：\(Int(currentScale.wrappedValue * 100))%")
                        
                        // 只在缩小操作且图片超出边界时进行中心位置矫正
                        if scale < 1.0 && isImageOutOfBounds(
                            currentScale.wrappedValue,
                            originalOffset,
                            UIScreen.main.bounds.width,
                            UIScreen.main.bounds.height
                        ) {
                            print("图片超出边界，执行缩小后的中心位置矫正")
                            centerImage(currentScale.wrappedValue)
                        } else {
                            print("图片在边界内，保持当前位置")
                        }
                        
                        print("------------------------")
                    } else {
                        // 更新基准缩放值
                        mirroredScale.wrappedValue = currentMirroredScale.wrappedValue
                        
                        // 延迟隐藏缩放提示
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showScaleIndicator.wrappedValue = false
                            activeScalingScreen.wrappedValue = nil
                        }
                        
                        print("------------------------")
                        print("触控区3a双指手势结束")
                        print("最终画面比例：\(Int(currentMirroredScale.wrappedValue * 100))%")
                        
                        // 添加缩小操作的边界检查和中心矫正
                        if scale < 1.0 && isImageOutOfBounds(
                            currentMirroredScale.wrappedValue,
                            mirroredOffset,
                            UIScreen.main.bounds.width,
                            UIScreen.main.bounds.height
                        ) {
                            print("图片超出边界，执行缩小后的中心位置矫正")
                            centerMirroredImage(currentMirroredScale.wrappedValue)
                        } else {
                            print("图片在边界内，保持当前位置")
                        }
                        
                        print("------------------------")
                    }
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
        imageUploader: ImageUploader,
        handleDragGesture: @escaping (DragGesture.Value, CGFloat, CGFloat, CGFloat) -> Void,
        handleMirroredDragGesture: @escaping (DragGesture.Value, CGFloat, CGFloat, CGFloat) -> Void,
        handleDragEnd: @escaping () -> Void,
        handleMirroredDragEnd: @escaping () -> Void
    ) -> some Gesture {
        DragGesture()
            .onChanged { value in
                // 检查当前分屏的手电筒状态
                if imageUploader.isFlashlightActive(for: screenID) {
                    return
                }
                
                if screenID == .original ? isZone2Enabled : isZone3Enabled {
                    if screenID == .original {
                        if isOriginalPaused && currentScale > 1.0 {
                            handleDragGesture(
                                value,
                                UIScreen.main.bounds.width,
                                UIScreen.main.bounds.height,
                                UIScreen.main.bounds.height / 2
                            )
                        }
                    } else {
                        if isMirroredPaused && currentMirroredScale > 1.0 {
                            handleMirroredDragGesture(
                                value,
                                UIScreen.main.bounds.width,
                                UIScreen.main.bounds.height,
                                UIScreen.main.bounds.height / 2
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
                        }
                    } else {
                        if isMirroredPaused && currentMirroredScale > 1.0 {
                            handleMirroredDragEnd()
                        }
                    }
                }
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
        handleDragGesture: @escaping (DragGesture.Value, CGFloat, CGFloat, CGFloat) -> Void,
        handleMirroredDragGesture: @escaping (DragGesture.Value, CGFloat, CGFloat, CGFloat) -> Void,
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
                    originalScale: originalScale,
                    mirroredScale: mirroredScale,
                    currentScale: currentScale,
                    currentMirroredScale: currentMirroredScale,
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
                    imageUploader: imageUploader,
                    handleDragGesture: handleDragGesture,
                    handleMirroredDragGesture: handleMirroredDragGesture,
                    handleDragEnd: handleDragEnd,
                    handleMirroredDragEnd: handleMirroredDragEnd
                )
            )
        )
    }
} 