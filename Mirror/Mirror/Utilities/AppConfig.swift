import Foundation

// 应用程序配置
struct AppConfig {
    // 动画时间配置
    struct AnimationConfig {
        // 通用动画持续时间
        static let defaultDuration: TimeInterval = 0.3
        
        // 闪光动画配置
        struct Flash {
            static let fadeInDuration: TimeInterval = 0.1
            static let displayDuration: TimeInterval = 0.5
            static let fadeOutDuration: TimeInterval = 0.2
        }
        
        // 截图延迟配置
        struct Capture {
            static let delay: TimeInterval = 0.5
        }
        
        // 提示显示时间
        struct Toast {
            static let duration: TimeInterval = 1.0
        }
        
        // 分屏定格配置
        struct TwoOfMe {
            static let captureDelay: TimeInterval = 0.5  // 与主页保持一致
            static let flashDuration: TimeInterval = Flash.displayDuration  // 使用与主页相同的闪光持续时间
        }
    }
    
    // 防抖配置
    struct Debounce {
        static let screenshot: TimeInterval = 0.5
    }
} 