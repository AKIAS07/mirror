import SwiftUI

// 设备方向管理器
class DeviceOrientationManager: ObservableObject {
    static let shared = DeviceOrientationManager()
    
    @Published private(set) var currentOrientation: UIDeviceOrientation = .portrait
    private var lastValidOrientation: UIDeviceOrientation = .portrait
    @Published private(set) var isOrientationLocked: Bool = false  // 添加方向锁定状态
    
    // 添加对 ProManager 的引用
    private let proManager = ProManager.shared
    
    private let allowedOrientations: [UIDeviceOrientation] = [
        .portrait,
        .portraitUpsideDown,
        .landscapeLeft,
        .landscapeRight
    ]
    
    private init() {
        // 确保在开始监听之前就开始生成设备方向通知
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        
        // 立即获取初始方向
        if let initialOrientation = getCurrentValidOrientation() {
            self.currentOrientation = initialOrientation
            self.lastValidOrientation = initialOrientation
            print("------------------------")
            print("[设备方向] 初始化")
            print("初始方向：\(getOrientationDescription(initialOrientation))")
            print("------------------------")
        }
        
        // 监听 ProManager 的 isPro 变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleProStatusChange),
            name: NSNotification.Name("ProStatusDidChange"),
            object: nil
        )
        
        startOrientationMonitoring()
        
        // 每次应用进入前台时更新方向
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleApplicationWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    @objc private func handleProStatusChange() {
        if !proManager.isPro {
            // 如果不是 Pro 用户，强制恢复到竖屏
            forcePortraitOrientation()
        }
    }
    
    private func forcePortraitOrientation() {
        currentOrientation = .portrait
        lastValidOrientation = .portrait
        print("------------------------")
        print("[设备方向] 强制竖屏 (非Pro用户)")
        print("------------------------")
    }
    
    private func getCurrentValidOrientation() -> UIDeviceOrientation? {
        let orientation = UIDevice.current.orientation
        return allowedOrientations.contains(orientation) ? orientation : nil
    }
    
    private func startOrientationMonitoring() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOrientationChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
        
        print("------------------------")
        print("[设备方向] 开始监测")
        print("当前方向：\(getOrientationDescription(currentOrientation))")
        print("------------------------")
    }
    
    @objc private func handleOrientationChange() {
        // 如果不是 Pro 用户或方向被锁定，不处理方向变化
        if !proManager.isPro || isOrientationLocked {
            return
        }
        
        let newOrientation = UIDevice.current.orientation
        
        // 只处理允许的方向，否则保持最后一个有效方向
        if allowedOrientations.contains(newOrientation) {
            updateOrientation(to: newOrientation)
        }
    }
    
    @objc private func handleApplicationWillEnterForeground() {
        if let currentValidOrientation = getCurrentValidOrientation() {
            updateOrientation(to: currentValidOrientation)
        }
    }
    
    private func updateOrientation(to newOrientation: UIDeviceOrientation) {
        if !isOrientationLocked && proManager.isPro && allowedOrientations.contains(newOrientation) {
            lastValidOrientation = newOrientation
            currentOrientation = newOrientation
            print("------------------------")
            print("[设备方向] 更新")
            print("新方向：\(getOrientationDescription(newOrientation))")
            print("------------------------")
            
            // 发送方向更新通知
            NotificationCenter.default.post(
                name: NSNotification.Name("DeviceOrientationDidChange"),
                object: nil,
                userInfo: ["orientation": newOrientation]
            )
        }
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