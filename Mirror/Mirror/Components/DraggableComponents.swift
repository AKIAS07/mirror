import SwiftUI

enum DragHintState {
    case upAndRightLeft  // 显示上箭头和右箭头左箭头
    case downAndRightLeft  // 显示下箭头和右箭头左箭头
    case rightOnly   // 只显示右箭头
    case leftOnly    // 只显示左箭头
    case upOnly      // 只显示上箭头
    case downOnly    // 只显示下箭头
}

struct DraggableArrow: View {
    let isExpanded: Bool
    let isLighted: Bool
    let screenWidth: CGFloat
    @Binding var isControlPanelVisible: Bool
    @Binding var showDragHint: Bool
    @Binding var dragHintState: DragHintState
    @Binding var dragOffset: CGFloat
    @Binding var dragVerticalOffset: CGFloat
    @Binding var containerOffset: CGFloat
    
    // 添加状态变量来跟踪拖拽方向
    @State private var dragDirection: DragDirection = .none
    // 添加状态变量来锁定方向判定
    @State private var isDirectionLocked = false
    @State private var lastDragTranslation: CGFloat = 0
    
    // 添加拖拽方向枚举
    private enum DragDirection {
        case none
        case vertical
        case horizontal
    }
    
    // 添加垂直拖动相关常量
    private let verticalDestination: CGFloat = 120.0  // 向上拖拽的目标位置
    private let verticalDragThreshold: CGFloat = 20.0  // 垂直拖拽的触发阈值
    
    // 处理垂直拖动
    private func handleVerticalDrag(value: DragGesture.Value) {
        if isControlPanelVisible {
            withAnimation(.interactiveSpring(
                response: DragAnimationConfig.dragResponse,
                dampingFraction: DragAnimationConfig.dragDampingFraction,
                blendDuration: DragAnimationConfig.dragBlendDuration
            )) {
                // 计算translation的增量
                let translationDelta = value.translation.height - lastDragTranslation
                
                // 更新位置 = 当前位置 + 增量
                dragVerticalOffset = min(0, max(-verticalDestination, dragVerticalOffset + translationDelta))
                
                // 根据拖拽方向来决定箭头方向，而不是根据位置
                if translationDelta < 0 {
                    // 向上拖动
                    dragHintState = .upOnly
                } else {
                    // 向下拖动
                    dragHintState = .downOnly
                }
                
                // 更新上一次的translation
                lastDragTranslation = value.translation.height
            }
            
            // 显示拖动提示（避免重复触发动画）
            if !showDragHint {
                withAnimation(.easeInOut(duration: DragAnimationConfig.hintFadeDuration)) {
                    showDragHint = true
                }
            }
        }
    }
    
    // 处理垂直拖动结束
    private func handleVerticalDragEnd(value: DragGesture.Value) {
        if isControlPanelVisible {
            let translation = value.translation.height
            let currentPosition = dragVerticalOffset
            let moveDistance = abs(translation)
            
            withAnimation(.spring(
                response: DragAnimationConfig.endResponse,
                dampingFraction: DragAnimationConfig.endDampingFraction
            )) {
                if moveDistance > DragAnimationConfig.dragThreshold {
                    // 移动距离超过阈值，根据移动方向决定最终位置
                    dragVerticalOffset = translation < 0 ? -verticalDestination : 0
                } else {
                    // 移动距离不足，回到最近的位置
                    dragVerticalOffset = currentPosition < -verticalDestination / 2 ? 
                        -verticalDestination : 0
                }
            }
        }
    }
    
    // 处理水平拖动
    private func handleHorizontalDrag(value: DragGesture.Value, velocity: CGFloat) {
        let translation = value.translation.width
        
        withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.8, blendDuration: 0.05)) {
            if isControlPanelVisible {
                // 容器当前显示，允许自由拖动
                dragOffset = translation
                containerOffset = translation
                dragHintState = translation > 0 ? .rightOnly : .leftOnly
            } else {
                // 容器当前隐藏，根据位置处理拖动
                if containerOffset < 0 {
                    // 从左侧隐藏状态拖动，使用相对于当前位置的偏移
                    dragOffset = -screenWidth + 60 + translation
                    containerOffset = -screenWidth + translation
                    dragHintState = .rightOnly
                } else {
                    // 从右侧隐藏状态拖动
                    dragOffset = max(0, min(screenWidth - 60, translation + screenWidth - 60))
                    containerOffset = max(0, min(screenWidth, translation + screenWidth))
                    dragHintState = .leftOnly
                }
            }
        }
    }
    
    // 处理水平拖动结束
    private func handleHorizontalDragEnd(value: DragGesture.Value) {
        let velocity = value.velocity.width
        let translation = value.translation.width
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if isControlPanelVisible {
                if abs(velocity) > 500 {  // 快速滑动
                    if velocity < 0 && translation < 0 {  // 向左滑动且位移为负
                        dragOffset = -(screenWidth - 60)
                        containerOffset = -screenWidth
                        isControlPanelVisible = false
                        print("快速向左滑动 - 隐藏到左侧")
                    } else if velocity > 0 && translation > 0 {  // 向右滑动且位移为正
                        dragOffset = screenWidth - 60
                        containerOffset = screenWidth
                        isControlPanelVisible = false
                        print("快速向右滑动 - 隐藏到右侧")
                    } else {
                        // 如果方向不一致，回到原位
                        dragOffset = 0
                        containerOffset = 0
                        print("方向不一致 - 回到中间")
                    }
                } else {  // 缓慢滑动
                    if abs(dragOffset) > screenWidth * 0.2 {  // 超过20%触发
                        if dragOffset < 0 {
                            dragOffset = -(screenWidth - 60)
                            containerOffset = -screenWidth
                            print("向左滑动足够 - 隐藏到左侧")
                        } else {
                            dragOffset = screenWidth - 60
                            containerOffset = screenWidth
                            print("向右滑动足够 - 隐藏到右侧")
                        }
                        isControlPanelVisible = false
                    } else {
                        dragOffset = 0
                        containerOffset = 0
                        print("滑动不足 - 回到中间")
                    }
                }
            } else {
                handleHiddenPanelDragEnd(value: value)
            }
        }
    }
    
    // 处理隐藏状态下的拖动结束
    private func handleHiddenPanelDragEnd(value: DragGesture.Value) {
        let velocity = value.velocity.width
        let translation = value.translation.width
        
        if containerOffset < 0 {  // 当前在左侧
            if velocity > 500 || translation > screenWidth * 0.2 {  // 快速向右滑或滑动距离足够
                dragOffset = 0
                containerOffset = 0
                isControlPanelVisible = true
                print("从左侧显示到中间 - 速度:\(velocity), 距离:\(translation)")
            } else {
                dragOffset = -(screenWidth - 60)
                containerOffset = -screenWidth
                print("保持在左侧隐藏 - 速度:\(velocity), 距离:\(translation)")
            }
        } else {  // 当前在右侧
            if velocity < -500 || -translation > screenWidth * 0.2 {  // 快速向左滑或滑动距离足够
                dragOffset = 0
                containerOffset = 0
                isControlPanelVisible = true
                print("从右侧显示到中间 - 速度:\(velocity), 距离:\(translation)")
            } else {
                dragOffset = screenWidth - 60
                containerOffset = screenWidth
                print("保持在右侧隐藏 - 速度:\(velocity), 距离:\(translation)")
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 黄色半透明背景
                Rectangle()
                    .fill(isExpanded ? Color.clear : Color.white.opacity(0.0))
                    .frame(width: geometry.size.width, height: 50)
                    .allowsHitTesting(false)
                
                // 箭头图标容器
                HStack {
                    // 箭头图标
                    Image(isExpanded ? "icon-bf-white" : "icon-star")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: isExpanded ? 40 : 30)  // icon-star 保持30，icon-bf-white 放大到45
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: ArrowLayoutConfig.arrowWidth, height: ArrowLayoutConfig.arrowHeight)
                        .contentShape(Rectangle())
                        .padding(.leading, isControlPanelVisible ? 
                             geometry.size.width/2 - ArrowLayoutConfig.arrowHalfWidth : 
                             (containerOffset < 0 ? geometry.size.width - ArrowLayoutConfig.arrowWidth - ArrowLayoutConfig.arrowPadding : ArrowLayoutConfig.arrowPadding))
                        .onAppear {
                            let arrowWidth: CGFloat = ArrowLayoutConfig.arrowWidth
                            let arrowHeight: CGFloat = ArrowLayoutConfig.arrowHeight
                            let screenHeight = UIScreen.main.bounds.height
                            let containerHeight: CGFloat = 120
                            
                            // 计算箭头的中心坐标
                            let centerX = isControlPanelVisible ? 
                                geometry.size.width/2 : 
                                (containerOffset < 0 ? geometry.size.width - ArrowLayoutConfig.arrowHalfWidth - ArrowLayoutConfig.arrowPadding : ArrowLayoutConfig.arrowHalfWidth + ArrowLayoutConfig.arrowPadding)
                            let centerY = screenHeight - containerHeight - arrowHeight/2
                            
                            print("------------------------")
                            print("白色箭头初始位置")
                            print("箭头尺寸：\(arrowWidth) x \(arrowHeight)")
                            print("箭头中心坐标：(\(centerX), \(centerY))")
                            print("相对位置：\(isControlPanelVisible ? "居中" : (containerOffset < 0 ? "靠右" : "靠左"))")
                            print("------------------------")
                        }
                        .onTapGesture {
                            // 根据垂直位置和显示状态决定提示类型
                            if dragVerticalOffset == 0 {
                                // 容器在底部
                                dragHintState = isControlPanelVisible ? .upAndRightLeft :
                                    (containerOffset < 0 ? .rightOnly : .leftOnly)
                            } else if dragVerticalOffset == -verticalDestination {
                                // 容器在上方
                                dragHintState = isControlPanelVisible ? .downAndRightLeft :
                                    (containerOffset < 0 ? .rightOnly : .leftOnly)
                            }
                            
                            withAnimation(.easeInOut(duration: DragAnimationConfig.hintFadeDuration)) {
                                showDragHint = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + DragAnimationConfig.hintDisplayDuration) {
                                withAnimation(.easeInOut(duration: DragAnimationConfig.hintFadeDuration)) {
                                    showDragHint = false
                                }
                            }
                        }
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    if !isDirectionLocked {
                                        let horizontalAmount = abs(value.translation.width)
                                        let verticalAmount = abs(value.translation.height)
                                        
                                        if horizontalAmount > 10 || verticalAmount > 10 {
                                            dragDirection = horizontalAmount > verticalAmount ? .horizontal : .vertical
                                            isDirectionLocked = true
                                            print("锁定方向: \(dragDirection)")
                                        }
                                    }
                                    
                                    if isDirectionLocked {
                                        switch dragDirection {
                                        case .horizontal:
                                            handleHorizontalDrag(value: value, velocity: value.velocity.width)
                                            
                                            // 显示拖动提示
                                            if !showDragHint {
                                                withAnimation {
                                                    showDragHint = true
                                                }
                                            }
                                            
                                        case .vertical:
                                            handleVerticalDrag(value: value)
                                            
                                        case .none:
                                            break
                                        }
                                    }
                                }
                                .onEnded { value in
                                    print("------------------------")
                                    print("手势结束")
                                    print("最终移动 - 垂直: \(value.translation.height), 水平: \(value.translation.width)")
                                    print("当前方向: \(dragDirection)")
                                    
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showDragHint = false
                                    }
                                    
                                    if isDirectionLocked {
                                        switch dragDirection {
                                        case .horizontal:
                                            handleHorizontalDragEnd(value: value)
                                        case .vertical:
                                            handleVerticalDragEnd(value: value)
                                        case .none:
                                            break
                                        }
                                    }
                                    
                                    // 重置状态
                                    dragDirection = .none
                                    isDirectionLocked = false
                                    lastDragTranslation = 0
                                }
                        )
                    
                    Spacer()
                        .allowsHitTesting(false)
                }
                .offset(y: 25)  // 将整个 HStack 向下移动
            }
            .onChange(of: isControlPanelVisible) { _ in
                showDragHint = false
            }
        }
        .frame(height: 50)
    }
} 