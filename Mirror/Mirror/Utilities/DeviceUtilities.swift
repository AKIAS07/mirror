import UIKit

extension UIDevice {
    static let modelName: String = {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        
        // 返回设备标识符
        return identifier
    }()
    
    // 获取设备圆角值
    static func getCornerRadius() -> CGFloat {
        let model = modelName
        
        // 获取设备原始圆角值
        let originalCornerRadius: CGFloat
        switch model {
        // iPhone 14 Pro Max, 14 Pro
        case "iPhone15,3", "iPhone15,2":
            originalCornerRadius = 55
        // iPhone 14 Plus, 14
        case "iPhone14,8", "iPhone14,7":
            originalCornerRadius = 47.33
        // iPhone 13 Pro Max, 12 Pro Max
        case "iPhone14,3", "iPhone13,4":
            originalCornerRadius = 53.33
        // iPhone 13 Pro, 12 Pro
        case "iPhone14,2", "iPhone13,3":
            originalCornerRadius = 47.33
        // iPhone 13, 12
        case "iPhone14,5", "iPhone13,2":
            originalCornerRadius = 47.33
        // iPhone 13 mini, 12 mini
        case "iPhone14,4", "iPhone13,1":
            originalCornerRadius = 44.0
        // iPhone 11 Pro Max
        case "iPhone12,5":
            originalCornerRadius = 39.0
        // iPhone 11 Pro
        case "iPhone12,3":
            originalCornerRadius = 39.0
        // iPhone 11
        case "iPhone12,1":
            originalCornerRadius = 41.5
        default:
            originalCornerRadius = 39.0
        }
        
        // 直接返回原始圆角值
        return originalCornerRadius
    }
} 