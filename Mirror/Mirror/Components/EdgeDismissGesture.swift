import SwiftUI

struct EdgeDismissGesture: View {
    let screenWidth: CGFloat
    let screenHeight: CGFloat
    let onDismiss: () -> Void
    @Binding var pageOffset: CGFloat
    
    // 添加状态变量来跟踪拖动状态
    @State private var isDragging = false
    @State private var dragStartLocation: CGFloat = 0
    
    // 添加设备方向判断
    private var isLandscape: Bool {
        let orientation = UIDevice.current.orientation
        return orientation.isLandscape
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // 左边缘触控区 - 减小宽度并移到最边缘
            Color.clear
                .frame(width: isLandscape ? 7 : 7)
                .background(Color.red)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isDragging {
                                isDragging = true
                                dragStartLocation = value.startLocation.x
                            }
                            
                            // 计算水平拖动距离
                            let horizontalDrag = value.location.x - dragStartLocation
                            
                            // 应用水平偏移
                            pageOffset = max(0, horizontalDrag)
                            
                            print("------------------------")
                            print("[边缘手势] 左侧拖动中")
                            print("起始位置：\(Int(dragStartLocation))pt")
                            print("当前位置：\(Int(value.location.x))pt")
                            print("水平偏移：\(Int(pageOffset))pt")
                            print("------------------------")
                        }
                        .onEnded { value in
                            isDragging = false
                            
                            // 如果拖动超过阈值则退出
                            if pageOffset > screenWidth * 0.3 {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    pageOffset = screenWidth
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    onDismiss()
                                }
                            } else {
                                // 否则回弹
                                withAnimation(.easeOut(duration: 0.2)) {
                                    pageOffset = 0
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
                .frame(width: isLandscape ? 40 : 7)
                .background(Color.blue)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isDragging {
                                isDragging = true
                                dragStartLocation = value.startLocation.x
                            }
                            
                            // 计算水平拖动距离
                            let horizontalDrag = dragStartLocation - value.location.x
                            
                            // 应用水平偏移(负值)
                            pageOffset = min(0, -horizontalDrag)
                            
                            print("------------------------")
                            print("[边缘手势] 右侧拖动中")
                            print("起始位置：\(Int(dragStartLocation))pt")
                            print("当前位置：\(Int(value.location.x))pt") 
                            print("水平偏移：\(Int(pageOffset))pt")
                            print("------------------------")
                        }
                        .onEnded { value in
                            isDragging = false
                            
                            // 如果拖动超过阈值则退出
                            if abs(pageOffset) > screenWidth * 0.3 {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    pageOffset = -screenWidth
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    onDismiss()
                                }
                            } else {
                                // 否则回弹
                                withAnimation(.easeOut(duration: 0.2)) {
                                    pageOffset = 0
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
        pageOffset: .constant(0)  // 预览时使用常量绑定
    )
} 