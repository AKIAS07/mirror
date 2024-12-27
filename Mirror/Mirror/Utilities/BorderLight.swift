import SwiftUI
import UIKit

// 边框灯管理器
class BorderLightManager: ObservableObject {
    @Published var showOriginalHighlight = false
    @Published var showMirroredHighlight = false
    
    // 添加亮度控制相关属性
    private var originalBrightness: CGFloat = UIScreen.main.brightness
    private var isControllingBrightness = false
    
    // 切换边框灯状态
    func toggleBorderLight(for screenID: ScreenID) {
        withAnimation(.easeInOut(duration: 0.3)) {
            switch screenID {
            case .original:
                showOriginalHighlight.toggle()
                handleBrightnessChange(isOn: showOriginalHighlight)
                print("------------------------")
                print("Original屏幕被点击")
                print(showOriginalHighlight ? "边框灯已开启" : "边框灯已关闭")
                print("------------------------")
                
            case .mirrored:
                showMirroredHighlight.toggle()
                handleBrightnessChange(isOn: showMirroredHighlight)
                print("------------------------")
                print("Mirrored屏幕被点击")
                print(showMirroredHighlight ? "边框灯已开启" : "边框灯已关闭")
                print("------------------------")
            }
        }
    }
    
    // 处理亮度变化
    private func handleBrightnessChange(isOn: Bool) {
        if isOn && !isControllingBrightness {
            // 保存当前亮度并设置为最大
            isControllingBrightness = true
            originalBrightness = UIScreen.main.brightness
            UIScreen.main.brightness = 1.0
            print("设备亮度已调至最大")
        } else if !showOriginalHighlight && !showMirroredHighlight {
            // 当所有边框灯都关闭时，恢复原始亮度
            if isControllingBrightness {
                UIScreen.main.brightness = originalBrightness
                isControllingBrightness = false
                print("设备亮度已恢复")
            }
        }
    }
    
    // 关闭所有边框灯
    func turnOffAllLights() {
        withAnimation(.easeOut(duration: 0.3)) {
            showOriginalHighlight = false
            showMirroredHighlight = false
            
            // 恢复原始亮度
            if isControllingBrightness {
                UIScreen.main.brightness = originalBrightness
                isControllingBrightness = false
                print("设备亮度已恢复")
            }
        }
    }
    
    // 在初始化时保存当前亮度
    init() {
        originalBrightness = UIScreen.main.brightness
    }
}

// 边框灯视图
struct BorderLightView: View {
    let screenWidth: CGFloat
    let centerY: CGFloat
    private let borderWidth: CGFloat = 50  // 修改边框宽度为50
    
    var body: some View {
        ZStack {
            // 上边框
            Rectangle()
                .fill(Color.white)
                .frame(width: screenWidth, height: borderWidth)  // 使用新的宽度
                .position(x: screenWidth/2, y: borderWidth/2)  // 调整位置
            
            // 下边框
            Rectangle()
                .fill(Color.white)
                .frame(width: screenWidth, height: borderWidth)  // 使用新的宽度
                .position(x: screenWidth/2, y: centerY - borderWidth/2)  // 调整位置
            
            // 左边框
            Rectangle()
                .fill(Color.white)
                .frame(width: borderWidth, height: centerY)  // 使用新的宽度
                .position(x: borderWidth/2, y: centerY/2)  // 调整位置
            
            // 右边框
            Rectangle()
                .fill(Color.white)
                .frame(width: borderWidth, height: centerY)  // 使用新的宽度
                .position(x: screenWidth - borderWidth/2, y: centerY/2)  // 调整位置
        }
        .transition(.opacity)
    }
} 