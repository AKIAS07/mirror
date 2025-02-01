import SwiftUI

struct EdgeDismissGesture: View {
    let screenWidth: CGFloat
    let screenHeight: CGFloat
    let onDismiss: () -> Void
    @Binding var pageOffset: CGFloat  // 添加页面偏移绑定
    
    // 状态变量
    @State private var isDragging = false
    
    // 常量
    private let edgeWidth: CGFloat = 20  // 边缘触控区宽度
    private let dismissThreshold: CGFloat = 100  // 触发退出的阈值
    private let dampingFactor: CGFloat = 0.5  // 拖动阻尼系数
    
    var body: some View {
        HStack(spacing: 0) {
            // 左侧触控区
            Color.clear
                .frame(width: edgeWidth, height: screenHeight)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            handleDrag(value: value, fromLeft: true)
                        }
                        .onEnded { value in
                            handleDragEnd(value: value, fromLeft: true)
                        }
                )
            
            Spacer()
            
            // 右侧触控区
            Color.clear
                .frame(width: edgeWidth, height: screenHeight)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            handleDrag(value: value, fromLeft: false)
                        }
                        .onEnded { value in
                            handleDragEnd(value: value, fromLeft: false)
                        }
                )
        }
        .frame(maxWidth: .infinity)
    }
    
    // 处理拖动
    private func handleDrag(value: DragGesture.Value, fromLeft: Bool) {
        if !isDragging {
            isDragging = true
            print("------------------------")
            print("触控区E被触发")
            print("位置：\(fromLeft ? "左" : "右")侧边缘")
            print("------------------------")
        }
        
        let translation = value.translation.width
        let adjustedTranslation = fromLeft ? translation : -abs(translation)
        
        // 应用阻尼效果并更新页面偏移
        withAnimation(.interactiveSpring()) {
            pageOffset = adjustedTranslation * dampingFactor
        }
        
        // 打印拖动状态
        print("------------------------")
        print("触控区E拖动中")
        print("原始偏移：\(Int(translation))pt")
        print("阻尼后偏移：\(Int(pageOffset))pt")
        print("------------------------")
    }
    
    // 处理拖动结束
    private func handleDragEnd(value: DragGesture.Value, fromLeft: Bool) {
        let translation = value.translation.width
        let adjustedTranslation = fromLeft ? translation : -abs(translation)
        
        if abs(adjustedTranslation) >= dismissThreshold {
            print("------------------------")
            print("触控区E触发退出")
            print("最终偏移：\(Int(adjustedTranslation))pt")
            print("------------------------")
            
            // 触发退出动画
            withAnimation(.easeInOut(duration: 0.3)) {
                pageOffset = fromLeft ? screenWidth : -screenWidth
            }
            
            // 延迟执行实际退出
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onDismiss()
            }
        } else {
            print("------------------------")
            print("触控区E拖动取消")
            print("最终偏移：\(Int(adjustedTranslation))pt")
            print("未达到退出阈值：\(dismissThreshold)pt")
            print("------------------------")
            
            // 恢复原位
            withAnimation(.easeOut(duration: 0.2)) {
                pageOffset = 0
            }
        }
        
        isDragging = false
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