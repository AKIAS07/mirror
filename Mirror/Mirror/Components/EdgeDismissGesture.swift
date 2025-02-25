import SwiftUI

struct EdgeDismissGesture: View {
    let screenWidth: CGFloat
    let screenHeight: CGFloat
    let onDismiss: () -> Void
    @Binding var pageOffset: CGFloat
    @Binding var dragScale: CGFloat
    @Binding var isOverlayActive: Bool
    @Binding var touchZonePosition: TouchZonePosition
    @State private var previousPosition: TouchZonePosition = .center
    
    // 添加状态变量来跟踪拖动状态
    @State private var isDragging = false
    @State private var dragStartLocation: CGFloat = 0
    
    // 添加设备方向判断
    private var isLandscape: Bool {
        let orientation = UIDevice.current.orientation
        return orientation.isLandscape
    }
    
    @ObservedObject private var orientationManager = DeviceOrientationManager.shared  // 添加方向管理器
    
    var body: some View {
        HStack(spacing: 0) {
            // 左边缘触控区 - 减小宽度并移到最边缘
            Color.clear
                .frame(width: isLandscape ? 10 : 10)
                .background(Color.clear)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isDragging {
                                isDragging = true
                                dragStartLocation = value.startLocation.x
                                isOverlayActive = true
                                orientationManager.lockOrientation()  // 锁定方向
                                
                                // 记录当前位置并移动到中心
                                if touchZonePosition != .center {
                                    previousPosition = touchZonePosition
                                    touchZonePosition = .center
                                }
                            }
                            
                            // 计算水平拖动距离
                            let horizontalDrag = value.location.x - dragStartLocation
                            
                            // 应用水平偏移
                            pageOffset = max(0, horizontalDrag)
                            
                            // 计算拖拽缩放比例
                            let progress = min(pageOffset / screenWidth, 1.0)
                            dragScale = 1.0 + progress * 3.0  // 从1.0到6.0
                            
                            print("------------------------")
                            print("[边缘手势] 左侧拖动中")
                            print("起始位置：\(Int(dragStartLocation))pt")
                            print("当前位置：\(Int(value.location.x))pt")
                            print("水平偏移：\(Int(pageOffset))pt")
                            print("------------------------")
                        }
                        .onEnded { value in
                            isDragging = false
                            isOverlayActive = false
                            orientationManager.unlockOrientation()  // 解锁方向
                            
                            // 如果拖动超过阈值则退出
                            if pageOffset > screenWidth * 0.3 {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    pageOffset = screenWidth
                                    dragScale = 4.0
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    onDismiss()
                                }
                            } else {
                                // 否则回弹并恢复原始位置
                                withAnimation(.easeOut(duration: 0.2)) {
                                    pageOffset = 0
                                    dragScale = 1.0
                                    touchZonePosition = previousPosition  // 恢复到之前的位置
                                }
                            }
                            
                            print("------------------------")
                            print("[边缘手势] 左侧拖动结束")
                            print("最终偏移：\(Int(pageOffset))pt")
                            print("------------------------")
                        }
                )
            
            Spacer()
            
            // 右边缘触控区 - 减小宽度并移到最边缘
            Color.clear
                .frame(width: isLandscape ? 43 : 10)
                .background(Color.clear)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isDragging {
                                isDragging = true
                                dragStartLocation = value.startLocation.x
                                isOverlayActive = true
                                orientationManager.lockOrientation()  // 锁定方向
                                
                                // 记录当前位置并移动到中心
                                if touchZonePosition != .center {
                                    previousPosition = touchZonePosition
                                    touchZonePosition = .center
                                }
                            }
                            
                            // 计算水平拖动距离
                            let horizontalDrag = dragStartLocation - value.location.x
                            
                            // 应用水平偏移(负值)
                            pageOffset = min(0, -horizontalDrag)
                            
                            // 计算拖拽缩放比例 (使用绝对值确保向右拖动也能正确缩放)
                            let progress = min(abs(pageOffset) / screenWidth, 1.0)
                            dragScale = 1.0 + progress * 3.0  // 从1.0到10.0
                            
                            print("------------------------")
                            print("[边缘手势] 右侧拖动中")
                            print("起始位置：\(Int(dragStartLocation))pt")
                            print("当前位置：\(Int(value.location.x))pt") 
                            print("水平偏移：\(Int(pageOffset))pt")
                            print("------------------------")
                        }
                        .onEnded { value in
                            isDragging = false
                            isOverlayActive = false
                            orientationManager.unlockOrientation()  // 解锁方向
                            
                            // 如果拖动超过阈值则退出
                            if abs(pageOffset) > screenWidth * 0.3 {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    pageOffset = -screenWidth
                                    dragScale = 4.0
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    onDismiss()
                                }
                            } else {
                                // 否则回弹并恢复原始位置
                                withAnimation(.easeOut(duration: 0.2)) {
                                    pageOffset = 0
                                    dragScale = 1.0
                                    touchZonePosition = previousPosition  // 恢复到之前的位置
                                }
                            }
                            
                            print("------------------------")
                            print("[边缘手势] 右侧拖动结束")
                            print("最终偏移：\(Int(pageOffset))pt")
                            print("------------------------")
                        }
                )
        }
        .frame(maxHeight: .infinity)
    }
}

#Preview {
    EdgeDismissGesture(
        screenWidth: UIScreen.main.bounds.width,
        screenHeight: UIScreen.main.bounds.height,
        onDismiss: {},
        pageOffset: .constant(0),
        dragScale: .constant(1.0),
        isOverlayActive: .constant(false),
        touchZonePosition: .constant(.center)  // 添加预览参数
    )
} 