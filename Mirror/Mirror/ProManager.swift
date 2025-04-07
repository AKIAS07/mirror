import SwiftUI
import StoreKit

class ProManager: ObservableObject {
    @Published var showProUpgradeSheet = false {
        didSet {
            // 当弹窗显示时，发送应用即将进入后台的通知
            if showProUpgradeSheet {
                print("------------------------")
                print("[Pro升级弹窗] 显示")
                print("应用即将进入后台")
                print("------------------------")
                
                // 发送应用即将进入后台的通知
                NotificationCenter.default.post(
                    name: UIApplication.willResignActiveNotification,
                    object: nil
                )
            }
        }
    }
    @Published var isFromMiddleButton = false // 添加标记来源
    @Published var isPro: Bool = false {  // 添加会员状态控制
        didSet {
            // 当 isPro 状态改变时，保存到 UserDefaults
            UserDefaults.standard.set(isPro, forKey: "isPro")
            UserDefaults.standard.synchronize()
        }
    }
    
    static let shared = ProManager()
    private let appStoreId = "6743115750" // 替换为您的 App Store ID
    
    private init() {
        // 从 UserDefaults 读取 Pro 状态
        isPro = UserDefaults.standard.bool(forKey: "isPro")
        
        // 开发阶段可添加测试代码
        #if DEBUG
        isPro = true // 强制开启付费功能
        #endif
    }
    
    func showProUpgrade(isFromMiddleButton: Bool = false) {
        self.isFromMiddleButton = isFromMiddleButton
        showProUpgradeSheet = true
    }
    
    func openAppStore() {
        if let url = URL(string: "itms-apps://apple.com/app/id\(appStoreId)") {
            UIApplication.shared.open(url)
        }
    }
    
    // 添加检查是否为免费功能的方法
    func isFreeSetting(_ settingType: SettingType) -> Bool {
        if isPro { return true }  // 如果是会员，所有功能都可用
        
        switch settingType {
        case .light, .theme:
            return true  // 免费功能
        case .flash, .gesture, .companion, .system:  // 添加 system
            return false  // Pro 功能
        }
    }
    
    // 添加遮罩视图组件
    func proFeatureOverlay(_ type: SettingType) -> some View {
        Group {
            if !isPro && !isFreeSetting(type) {
                Rectangle()
                    .fill(Color.clear) // 透明填充
                    .contentShape(Rectangle()) // 保持点击区域
                    .onTapGesture {
                        self.showProUpgrade() // 添加 self 前缀
                    }
            }
        }
    }
    
    // 添加触控区1功能控制
    var isTouchZone1Enabled: Bool {
        return isPro
    }
    
    // 添加触控区1功能检查方法
    func checkTouchZone1Access(completion: @escaping () -> Void) {
        if isTouchZone1Enabled {
            completion()
        } else {
            showProUpgrade()
            print("------------------------")
            print("[触控区1] 功能已禁用")
            print("原因：需要Pro版本")
            print("------------------------")
        }
    }
    
    // 添加处理 TwoOfMe 页面的方法
    func handleTwoOfMeProCheck(cameraManager: CameraManager) {
        if !isPro {
            // 停止相机会话
            cameraManager.safelyStopSession()
            
            // 发送通知以显示重启提示
            NotificationCenter.default.post(
                name: NSNotification.Name("ForceTwoOfMeRestart"),
                object: nil
            )
            
            // 显示升级弹窗
            showProUpgrade()
            
            print("------------------------")
            print("[Two of Me] 进入后台")
            print("原因：需要Pro版本")
            print("------------------------")
        }
    }
}

// 添加设置类型枚举
enum SettingType {
    case light     // 灯光设置
    case flash     // 闪光设置
    case gesture   // 手势设置
    case theme     // 主题设置
    case companion // 陪伴设置
    case system    // 系统设置
}

struct ProUpgradeView: View {
    let dismiss: () -> Void
    @StateObject private var proManager = ProManager.shared
    
    var onDismiss: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.yellow)
                .padding(.top, 50)
            
            Text("下载Pro版本，解锁全部功能")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            Spacer()
            
            HStack(spacing: 16) {
                Button(action: {
                    dismiss()
                    // 只有当是从中间按钮点击时，才执行 onDismiss
                    if proManager.isFromMiddleButton {
                        onDismiss?()
                    }
                }) {
                    Text("取消")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                }
                
                Button(action: {
                    // 如果有可用的商品，直接发起购买
                    if let product = IAPManager.shared.products.first {
                        IAPManager.shared.purchase(product: product)
                    }
                    dismiss()
                }) {
                    Text("去购买")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
        .padding()
    }
}

// 预览
struct ProUpgradeView_Previews: PreviewProvider {
    static var previews: some View {
        ProUpgradeView(dismiss: {})
    }
} 