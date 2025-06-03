import SwiftUI
import Foundation

// 添加模板存储键
private enum TemplateKeys {
    static let drawingTemplates = "drawingTemplates"
}

public class DrawingTemplateManager: ObservableObject {
    public static let shared = DrawingTemplateManager()
    
    @Published public var templates: [DrawingTemplate]
    
    private let maxTemplates = 6  // 修改为6个模板
    private let defaults = UserDefaults.standard
    
    private init() {
        // 尝试从 UserDefaults 加载模板
        if let data = UserDefaults.standard.data(forKey: TemplateKeys.drawingTemplates),
           let savedTemplates = try? JSONDecoder().decode([DrawingTemplate].self, from: data) {
            if savedTemplates.count == 6 {
                self.templates = savedTemplates
            } else {
                // 如果保存的模板数量不是6个，则扩展到6个
                var newTemplates = savedTemplates
                let currentCount = savedTemplates.count
                for i in currentCount..<6 {
                    newTemplates.append(DrawingTemplate(name: "模板\(i + 1)"))
                }
                self.templates = newTemplates
            }
            print("从存储加载模板成功：\(savedTemplates.count) 个模板")
        } else {
            // 初始化6个空模板
            self.templates = [
                DrawingTemplate(name: "模板1"),
                DrawingTemplate(name: "模板2"),
                DrawingTemplate(name: "模板3"),
                DrawingTemplate(name: "模板4"),
                DrawingTemplate(name: "模板5"),
                DrawingTemplate(name: "模板6")
            ]
            print("初始化空模板")
        }
    }
    
    // 检查是否有可用的模板槽位
    public var hasAvailableSlot: Bool {
        return templates.contains { $0.image == nil }
    }
    
    // 保存模板到指定位置
    public func saveTemplateAt(image: UIImage, index: Int) {
        guard index >= 0 && index < templates.count else { return }
        
        DispatchQueue.main.async {
            self.templates[index].image = image
            self.saveToUserDefaults()  // 保存到 UserDefaults
            print("保存模板成功 - 位置: \(index + 1)")
        }
    }
    
    // 删除指定位置的模板
    public func deleteTemplate(at index: Int) {
        guard index >= 0 && index < templates.count else { return }
        
        DispatchQueue.main.async {
            self.templates[index].image = nil
            self.saveToUserDefaults()  // 保存到 UserDefaults
            print("删除模板成功 - 位置: \(index + 1)")
        }
    }
    
    // 保存到 UserDefaults
    private func saveToUserDefaults() {
        if let encoded = try? JSONEncoder().encode(templates) {
            defaults.set(encoded, forKey: TemplateKeys.drawingTemplates)
            defaults.synchronize()
            print("模板数据已同步到存储")
        } else {
            print("模板数据编码失败")
        }
    }
} 