import SwiftUI

struct BorderStyle {
    // 主页边框样式
    static let normalColor = Color.gray.opacity(0.3)
    static var selectedColor = Color(red: 241/255, green: 235/255, blue: 223/255) {  // 白光色
        didSet {
            splitScreenSelectedColor = selectedColor
        }
    }
    static let normalWidth: CGFloat = 0
    static var selectedWidth: CGFloat = 40 {
        didSet {
            splitScreenSelectedWidth = selectedWidth
        }
    }
    
    // 分屏边框样式
    static let splitScreenNormalWidth: CGFloat = 0
    static var splitScreenSelectedWidth: CGFloat = 40
    static let splitScreenNormalColor = Color.gray.opacity(0.3)
    static var splitScreenSelectedColor = Color(red: 241/255, green: 235/255, blue: 223/255)  // 白光色
}

struct DragAnimationConfig {
    // 交互动画参数
    static let dragResponse: Double = 0.18
    static let dragDampingFraction: Double = 0.85
    static let dragBlendDuration: Double = 0.05
    
    // 结束动画参数
    static let endResponse: Double = 0.28
    static let endDampingFraction: Double = 0.82
    
    // 提示动画参数
    static let hintFadeDuration: Double = 0.2
    static let hintDisplayDuration: Double = 2.0
    
    // 拖拽阈值
    static let directionLockThreshold: CGFloat = 10.0
    static let dragThreshold: CGFloat = 20.0
}

struct ArrowLayoutConfig {
    static let arrowWidth: CGFloat = 50
    static let arrowHeight: CGFloat = 50
    static let arrowHalfWidth: CGFloat = arrowWidth / 2
    static let arrowPadding: CGFloat = -10  // 箭头到边缘的距离
}

struct CameraLayoutConfig {
    static let horizontalPadding: CGFloat = -150  // 修改为负值来增大宽度
    static let verticalPadding: CGFloat = 0   // 上下边距
    
    // 动态计算圆角半径
    static var cornerRadius: CGFloat {
        // 直接使用设备的物理圆角值
        return UIDevice.getCornerRadius()
    }
    
    // 所有视图使用相同的圆角值
    static var borderCornerRadius: CGFloat {
        return cornerRadius
    }
    
    static let bottomOffset: CGFloat = 0      // 底部偏移
    static let verticalOffset: CGFloat = 0   // 垂直偏移
} 
