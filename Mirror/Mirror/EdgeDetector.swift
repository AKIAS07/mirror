import SwiftUI

// 边缘检测管理器
class EdgeDetector: ObservableObject {
    @Published var showTopBorder = false
    @Published var showBottomBorder = false
    @Published var showLeftBorder = false
    @Published var showRightBorder = false
    
    // 添加计时器
    private var hideTimer: Timer?
    
    // 重置所有边框状态
    func resetBorders() {
        showTopBorder = false
        showBottomBorder = false
        showLeftBorder = false
        showRightBorder = false
    }
    
    // 边缘检测方法
    func detectEdges(
        offset: CGSize,
        maxOffset: CGSize,
        orientation: UIDeviceOrientation
    ) -> (left: Bool, right: Bool, top: Bool, bottom: Bool) {
        let threshold: CGFloat = 5.0
        
        // 计算基本边缘检测（竖屏状态）
        let baseDetection = (
            left: abs(offset.width - maxOffset.width) < threshold,
            right: abs(offset.width + maxOffset.width) < threshold,
            top: abs(offset.height - maxOffset.height) < threshold,
            bottom: abs(offset.height + maxOffset.height) < threshold
        )
        
        // 根据设备方向返回对应的边缘状态
        switch orientation {
        case .landscapeLeft:
            return (
                left: baseDetection.bottom,   // 上边变左边
                right: baseDetection.top,     // 下边变右边
                top: baseDetection.left,      // 右边变上边
                bottom: baseDetection.right   // 左边变下边
            )
        case .landscapeRight:
            return (
                left: baseDetection.top,      // 下边变左边
                right: baseDetection.bottom,  // 上边变右边
                top: baseDetection.right,     // 左边变上边
                bottom: baseDetection.left    // 右边变下边
            )
        case .portraitUpsideDown:
            return (
                left: baseDetection.right,    // 左右相反
                right: baseDetection.left,    // 左右相反
                top: baseDetection.bottom,    // 上下相反
                bottom: baseDetection.top     // 上下相反
            )
        default:
            return baseDetection
        }
    }
    
    // 更新边框状态
    func updateBorders(edges: (left: Bool, right: Bool, top: Bool, bottom: Bool)) {
        // 取消现有的计时器
        hideTimer?.invalidate()
        
        withAnimation {
            showLeftBorder = edges.left
            showRightBorder = edges.right
            showTopBorder = edges.top
            showBottomBorder = edges.bottom
        }
        
        // 打印调试信息
        printEdgeDetectionStatus(edges: edges)
        
        // 设置新的计时器，0.5秒后隐藏边框
        hideTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            withAnimation {
                self?.resetBorders()
            }
        }
    }
    
    // 打印边缘检测状态
    private func printEdgeDetectionStatus(edges: (left: Bool, right: Bool, top: Bool, bottom: Bool)) {
        print("------------------------")
        print("边缘检测状态")
        if edges.left { print("  左边缘重合") }
        if edges.right { print("  右边缘重合") }
        if edges.top { print("  上边缘重合") }
        if edges.bottom { print("  下边缘重合") }
        print("------------------------")
    }
}

// 边框容器视图
struct EdgeBorderContainer: View {
    let screenWidth: CGFloat
    let centerY: CGFloat
    @ObservedObject var edgeDetector: EdgeDetector
    
    var body: some View {
        Group {
            // 上边框
            Rectangle()
                .fill(Color.white)
                .opacity(edgeDetector.showTopBorder ? 1.0 : 0.0)
                .frame(width: screenWidth, height: 20)
                .position(x: screenWidth/2, y: 10)
            
            // 下边框
            Rectangle()
                .fill(Color.white)
                .opacity(edgeDetector.showBottomBorder ? 1.0 : 0.0)
                .frame(width: screenWidth, height: 20)
                .position(x: screenWidth/2, y: centerY - 10)
            
            // 左边框
            Rectangle()
                .fill(Color.white)
                .opacity(edgeDetector.showLeftBorder ? 1.0 : 0.0)
                .frame(width: 20, height: centerY)
                .position(x: 10, y: centerY/2)
            
            // 右边框
            Rectangle()
                .fill(Color.white)
                .opacity(edgeDetector.showRightBorder ? 1.0 : 0.0)
                .frame(width: 20, height: centerY)
                .position(x: screenWidth - 10, y: centerY/2)
        }
        .zIndex(2)
        .animation(.easeInOut(duration: 0.3), value: edgeDetector.showTopBorder)
        .animation(.easeInOut(duration: 0.3), value: edgeDetector.showBottomBorder)
        .animation(.easeInOut(duration: 0.3), value: edgeDetector.showLeftBorder)
        .animation(.easeInOut(duration: 0.3), value: edgeDetector.showRightBorder)
    }
} 