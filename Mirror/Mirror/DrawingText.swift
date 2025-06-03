import SwiftUI
import CoreText
import UIKit

// 文字渲染器
struct TextRenderer {
    // 将文本按照每行9个字重新分行
    private static func reformatText(_ text: String) -> String {
        let charsPerLine = 9
        var result: [String] = []
        
        // 先按原有的换行符分割
        let originalLines = text.components(separatedBy: "\n")
        
        for line in originalLines {
            if line.isEmpty {
                result.append("")
                continue
            }
            
            // 将每行按9个字符分割
            let characters = Array(line)
            var currentIndex = 0
            
            while currentIndex < characters.count {
                let endIndex = min(currentIndex + charsPerLine, characters.count)
                let subLine = String(characters[currentIndex..<endIndex])
                result.append(subLine)
                currentIndex += charsPerLine
            }
        }
        
        return result.joined(separator: "\n")
    }
    
    // 文本处理
    static func renderText(
        _ text: String,
        in rect: CGRect,
        with settings: BrushSettings,
        context: GraphicsContext,
        alignment: CustomTextAlignment = .center,
        scaleFactors: (x: CGFloat, y: CGFloat) = (x: 1.0, y: 1.0)
    ) {
        // 重新格式化文本
        let formattedText = reformatText(text)
        
        // 计算实际大小，考虑缩放因子
        let actualSize = CGSize(
            width: rect.size.width * scaleFactors.x,
            height: rect.size.height * scaleFactors.y
        )
        if let textImage = createTextImage(formattedText, size: actualSize, with: settings, alignment: alignment) {
            // 创建一个新的矩形，保持中心点不变但应用缩放因子
            let scaledRect = CGRect(
                x: rect.minX,
                y: rect.minY,
                width: rect.width * scaleFactors.x,
                height: rect.height * scaleFactors.y
            )
            context.draw(Image(uiImage: textImage), in: scaledRect)
        }
    }
    
    static func drawText(
        _ text: String,
        in rect: CGRect,
        with settings: BrushSettings,
        in context: CGContext,
        alignment: CustomTextAlignment = .center,
        scaleFactors: (x: CGFloat, y: CGFloat) = (x: 1.0, y: 1.0)
    ) {
        // 重新格式化文本
        let formattedText = reformatText(text)
        
        // 计算实际大小，考虑缩放因子
        let actualSize = CGSize(
            width: rect.size.width * scaleFactors.x,
            height: rect.size.height * scaleFactors.y
        )
        if let textImage = createTextImage(formattedText, size: actualSize, with: settings, alignment: alignment) {
            if let cgImage = textImage.cgImage {
                context.saveGState()
                // 翻转坐标系统
                context.translateBy(x: rect.minX, y: rect.maxY)
                context.scaleBy(x: 1.0, y: -1.0)
                // 绘制图片，使用考虑缩放因子的尺寸
                let drawRect = CGRect(
                    origin: .zero,
                    size: CGSize(
                        width: rect.width * scaleFactors.x,
                        height: rect.height * scaleFactors.y
                    )
                )
                context.draw(cgImage, in: drawRect)
                context.restoreGState()
            }
        }
    }
    
    private static func createTextImage(
        _ text: String,
        size: CGSize,
        with settings: BrushSettings,
        alignment: CustomTextAlignment
    ) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // 获取文本行数
            let lines = text.components(separatedBy: "\n")
            let lineCount = CGFloat(lines.count)
            
            // 动态计算字体大小，考虑行数
            let maxFontHeight = size.height / lineCount
            let fontSize = min(maxFontHeight * 0.8, size.width * 0.08)
            let font = UIFont.systemFont(ofSize: fontSize)
            
            // 计算行间距和总文本高度
            let lineSpacing: CGFloat = 2
            let totalLineSpacing = lineSpacing * (lineCount - 1)
            let lineHeight = font.lineHeight
            let totalTextHeight = lineHeight * lineCount + totalLineSpacing
            let startY = (size.height - totalTextHeight) / 2
            
            // 为每一行创建单独的文本
            for (index, line) in lines.enumerated() {
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = alignment.nsTextAlignment
                
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: UIColor(settings.color),
                    .paragraphStyle: paragraphStyle
                ]
                
                let attributedLine = NSAttributedString(string: line, attributes: attributes)
                let lineSize = attributedLine.size()
                
                // 根据对齐方式计算每行的 x 坐标
                var x: CGFloat
                switch alignment {
                case .left:
                    x = 5 // 左边留一点空间
                case .center:
                    x = (size.width - lineSize.width) / 2
                case .right:
                    x = size.width - lineSize.width - 5 // 右边留一点空间
                }
                
                // 计算当前行的 y 坐标
                let y = startY + CGFloat(index) * (lineHeight + lineSpacing)
                
                // 绘制当前行
                attributedLine.draw(at: CGPoint(x: x, y: y))
            }
        }
    }
}

// 文字形状类型
enum TextShapeType {
    case text(String)
} 