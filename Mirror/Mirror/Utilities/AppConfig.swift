import Foundation

// 应用程序配置
struct AppConfig {
    // 动画时间配置
    struct AnimationConfig {
        // 通用动画持续时间
        static let defaultDuration: TimeInterval = 0.7
        
        // 闪光动画配置
        struct Flash {
            private static var _isEnabled = false
            static var isEnabled: Bool {
                get { return _isEnabled }
                set { _isEnabled = newValue }
            }
            
            // 添加闪光强度配置
            enum Intensity: Double, CaseIterable {
                case weak = 0.3
                case medium = 0.6
                case strong = 0.9
                
                var description: String {
                    switch self {
                    case .weak: return "弱"
                    case .medium: return "中"
                    case .strong: return "强"
                    }
                }
            }
            private static var _intensity: Intensity = .medium
            static var intensity: Intensity {
                get { return _intensity }
                set { _intensity = newValue }
            }
            
            static let fadeInDuration: Double = 0.2
            static let fadeOutDuration: Double = 0.2
            static let displayDuration: Double = 2.0
        }
        
        // 截图延迟配置
        struct Capture {
            static var delay: TimeInterval {
                return Flash.isEnabled ? 0.5 : 0.0
            }
        }
        
        // 提示显示时间
        struct Toast {
            static let duration: TimeInterval = 2.0
        }
        
        // 分屏定格配置
        struct TwoOfMe {
            static var captureDelay: TimeInterval {
                return Flash.isEnabled ? 0.5 : 0.0
            }
            static let flashDuration: TimeInterval = 0.5
        }
    }
    
    // 防抖配置
    struct Debounce {
        static let screenshot: TimeInterval = 0.5
    }
} 