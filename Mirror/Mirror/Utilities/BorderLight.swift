import SwiftUI
import UIKit

// 边框灯管理器
class BorderLightManager: ObservableObject {
    @Published var showOriginalHighlight = false
    @Published var showMirroredHighlight = false
    
    // 添加亮度控制相关属性
    private var originalBrightness: CGFloat = UIScreen.main.brightness
    private var isControllingBrightness = false
    
    init() {
        // 保存当前亮度
        originalBrightness = UIScreen.main.brightness
    }
    
    // 切换边框灯状态
    func toggleBorderLight(for screenID: ScreenID) {
        switch screenID {
        case .original:
            showOriginalHighlight.toggle()
            handleBrightnessChange(isOn: showOriginalHighlight)
            // 添加震动反馈（开启和关闭时都触发）
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
            print("------------------------")
            print("Original屏幕被点击")
            print(showOriginalHighlight ? "边框灯已开启" : "边框灯已关闭")
            print("------------------------")
            
        case .mirrored:
            showMirroredHighlight.toggle()
            handleBrightnessChange(isOn: showMirroredHighlight)
            // 添加震动反馈（开启和关闭时都触发）
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
            print("------------------------")
            print("Mirrored屏幕被点击")
            print(showMirroredHighlight ? "边框灯已开启" : "边框灯已关闭")
            print("------------------------")
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
        showOriginalHighlight = false
        showMirroredHighlight = false
        
        // 添加震动反馈
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        
        // 恢复原始亮度
        if isControllingBrightness {
            UIScreen.main.brightness = originalBrightness
            isControllingBrightness = false
            print("设备亮度已恢复")
        }
    }
}

// 边框灯视图
struct BorderLightView: View {
    let screenWidth: CGFloat
    let centerY: CGFloat
    let showOriginalHighlight: Bool
    let showMirroredHighlight: Bool
    
    var body: some View {
        let isHighlighted = showOriginalHighlight || showMirroredHighlight
        
        GeometryReader { geometry in
            // 计算实际的边框尺寸
            let frameWidth = screenWidth
            let frameHeight = centerY
            
            ZStack {
                // 发光边框
                RoundedRectangle(cornerRadius: CameraLayoutConfig.borderCornerRadius)
                    .stroke(
                        isHighlighted ? BorderStyle.splitScreenSelectedColor : BorderStyle.splitScreenNormalColor,
                        lineWidth: isHighlighted ? BorderStyle.splitScreenSelectedWidth : BorderStyle.splitScreenNormalWidth
                    )
                    .frame(width: frameWidth, height: frameHeight)
                    .position(
                        x: frameWidth/2,
                        y: frameHeight/2
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: CameraLayoutConfig.borderCornerRadius)
                            .stroke(BorderStyle.splitScreenNormalColor.opacity(isHighlighted ? 0.3 : 1), lineWidth: BorderStyle.splitScreenNormalWidth)
                            .frame(width: frameWidth, height: frameHeight)
                            .position(
                                x: frameWidth/2,
                                y: frameHeight/2
                            )
                    )
                    .animation(.easeInOut(duration: 0.2), value: isHighlighted)
            }
            .mask(
                // 遮罩，只显示绿色框线内的部分
                RoundedRectangle(cornerRadius: CameraLayoutConfig.borderCornerRadius)
                    .frame(width: frameWidth - BorderStyle.splitScreenNormalWidth, height: frameHeight - BorderStyle.splitScreenNormalWidth)
                    .position(
                        x: frameWidth/2,
                        y: frameHeight/2
                    )
            )
            .clipped()
        }
    }
} 
