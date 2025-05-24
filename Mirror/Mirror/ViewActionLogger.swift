import Foundation
import SwiftUI

// 定义工具栏操作类型
enum ToolbarAction {
    case live       // Live 模式切换
    case flash      // 闪光灯控制
    case light      // 灯光控制
    case capture    // 拍照
    case zoom       // 缩放控制
    case color      // 颜色控制
    case camera     // 摄像头切换
    
    var description: String {
        switch self {
        case .live: return "Live模式切换"
        case .flash: return "闪光灯控制"
        case .light: return "灯光控制"
        case .capture: return "拍照"
        case .zoom: return "缩放控制"
        case .color: return "颜色控制"
        case .camera: return "摄像头切换"
        }
    }
}

// 定义工具按钮操作类型
enum UtilityAction {
    case add        // 添加
    case reference  // 参考图
    case brush      // 画笔
    case drag       // 拖拽
    case close      // 关闭
    
    var description: String {
        switch self {
        case .add: return "添加"
        case .reference: return "参考图"
        case .brush: return "画笔"
        case .drag: return "拖拽"
        case .close: return "关闭"
        }
    }
}

// 定义手势操作类型
enum GestureAction {
    case tap           // 点击
    case doubleTap     // 双击
    case drag          // 拖拽
    case pinch         // 缩放
    
    var description: String {
        switch self {
        case .tap: return "点击"
        case .doubleTap: return "双击"
        case .drag: return "拖拽"
        case .pinch: return "缩放"
        }
    }
}

// 定义视图操作类型
enum ViewAction {
    case toolbarAction(ToolbarAction)      // 工具栏操作
    case utilityAction(UtilityAction)      // 工具按钮操作
    case gestureAction(GestureAction)      // 手势操作
    
    var description: String {
        switch self {
        case .toolbarAction(let action):
            return "工具栏操作: \(action.description)"
        case .utilityAction(let action):
            return "工具按钮操作: \(action.description)"
        case .gestureAction(let action):
            return "手势操作: \(action.description)"
        }
    }
}

// 视图操作日志管理器
class ViewActionLogger {
    static let shared = ViewActionLogger()
    
    private init() {}
    
    // 记录操作
    func logAction(_ action: ViewAction, additionalInfo: [String: Any] = [:]) {
        let timestamp = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"
        
        print("------------------------")
        print("[视图操作] \(dateFormatter.string(from: timestamp))")
        print("操作类型：\(action.description)")
        
        if !additionalInfo.isEmpty {
            print("附加信息：")
            additionalInfo.forEach { key, value in
                print("- \(key): \(value)")
            }
        }
        
        print("------------------------")
    }
    
    // 记录工具栏位置变化
    func logToolbarPositionChange(from oldPosition: ToolbarPosition, to newPosition: ToolbarPosition) {
        let timestamp = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"
        
        print("------------------------")
        print("[工具栏位置] \(dateFormatter.string(from: timestamp))")
        print("位置变化：\(oldPosition.rawValue) -> \(newPosition.rawValue)")
        print("------------------------")
    }
    
    // 记录缩放操作
    func logZoomAction(scale: CGFloat, isGesture: Bool = true) {
        let timestamp = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"
        
        print("------------------------")
        print("[\(isGesture ? "手势" : "按钮")缩放] \(dateFormatter.string(from: timestamp))")
        print("缩放比例：\(Int(scale * 100))%")
        print("------------------------")
    }
    
    // 记录拍照操作
    func logCaptureAction(isLivePhoto: Bool) {
        let timestamp = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"
        
        print("------------------------")
        print("[拍照操作] \(dateFormatter.string(from: timestamp))")
        print("类型：\(isLivePhoto ? "Live Photo" : "普通照片")")
        print("------------------------")
    }
    
    // 记录模式切换
    func logModeSwitch(toModeA: Bool) {
        let timestamp = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"
        
        print("------------------------")
        print("[模式切换] \(dateFormatter.string(from: timestamp))")
        print("切换到：模式\(toModeA ? "A" : "B")")
        print("------------------------")
    }
} 