import SwiftUI

// 设备方向管理器
class DeviceOrientationManager: ObservableObject {
    static let shared = DeviceOrientationManager()
    
    @Published private(set) var currentOrientation: UIDeviceOrientation = .portrait
    private var lastValidOrientation: UIDeviceOrientation = .portrait
    @Published private(set) var isOrientationLocked: Bool = false  // 添加方向锁定状态
    
    private let allowedOrientations: [UIDeviceOrientation] = [
        .portrait,
        .portraitUpsideDown,
        .landscapeLeft,
        .landscapeRight
    ]
    
    private init() {
        startOrientationMonitoring()
    }
    
    private func startOrientationMonitoring() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOrientationChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func handleOrientationChange() {
        // 如果方向被锁定，不处理方向变化
        if isOrientationLocked {
            return
        }
        
        let newOrientation = UIDevice.current.orientation
        
        // 只处理允许的方向，否则保持最后一个有效方向
        if allowedOrientations.contains(newOrientation) {
            lastValidOrientation = newOrientation
            currentOrientation = newOrientation
            print("------------------------")
            print("设备方向改变")
            print("当前方向：\(getOrientationDescription(newOrientation))")
            print("------------------------")
        }
        // 不再在这里更新 currentOrientation
    }
    
    // 获取当前有效方向
    var validOrientation: UIDeviceOrientation {
        return currentOrientation
    }
    
    // 判断是否是允许的方向
    func isAllowedOrientation(_ orientation: UIDeviceOrientation) -> Bool {
        return allowedOrientations.contains(orientation)
    }
    
    // 获取方向描述
    func getOrientationDescription(_ orientation: UIDeviceOrientation) -> String {
        switch orientation {
        case .portrait:
            return "竖直"
        case .portraitUpsideDown:
            return "倒置竖屏"
        case .landscapeLeft:
            return "向左横屏"
        case .landscapeRight:
            return "向右横屏"
        default:
            return "其他"
        }
    }
    
    // 获取旋转角度
    func getRotationAngle(_ orientation: UIDeviceOrientation) -> Angle {
        switch orientation {
        case .landscapeLeft:
            return .degrees(90)
        case .landscapeRight:
            return .degrees(-90)
        case .portraitUpsideDown:
            return .degrees(180)
        default:
            return .degrees(0)
        }
    }
    
    // 添加新方法来获取最后的有效方向
    var lastValidDeviceOrientation: UIDeviceOrientation {
        return lastValidOrientation
    }
    
    // 添加锁定/解锁方向的方法
    func lockOrientation() {
        isOrientationLocked = true
        print("------------------------")
        print("[设备方向] 已锁定")
        print("当前方向：\(getOrientationDescription(currentOrientation))")
        print("------------------------")
    }
    
    func unlockOrientation() {
        isOrientationLocked = false
        print("------------------------")
        print("[设备方向] 已解锁")
        print("当前方向：\(getOrientationDescription(currentOrientation))")
        print("------------------------")
    }
    
    deinit {
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.removeObserver(self)
    }
} 