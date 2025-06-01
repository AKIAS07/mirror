import SwiftUI

class RealModeController: ObservableObject {
    static let shared = RealModeController()
    
    @Published var isRealModeEnabled = false
    
    // 添加对网格显示状态的引用
    private var showReferenceGrid: Binding<Bool>?
    
    private init() {}
    
    // 添加设置网格显示状态的方法
    func setReferenceGridBinding(_ binding: Binding<Bool>) {
        self.showReferenceGrid = binding
    }
    
    func toggleRealMode() {
        if !isRealModeEnabled {
            showSystemAlert()
        } else {
            isRealModeEnabled = false
        }
    }
    
    // 获取网格图片的方法
    public func getReferenceGridImage() -> UIImage? {
        // 从文档目录获取网格图片
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let gridImageURL = documentsPath.appendingPathComponent("gridsource.png")
        
        guard let originalImage = UIImage(contentsOfFile: gridImageURL.path) else {
            return nil
        }
        
        // 目标宽高比 (3024:4032 ≈ 0.75)
        let targetAspectRatio: CGFloat = 3024.0 / 4032.0
        
        // 计算裁剪区域
        let originalWidth = originalImage.size.width
        let originalHeight = originalImage.size.height
        
        // 保持原始宽度，计算对应的高度
        let cropHeight = originalWidth / targetAspectRatio
        
        // 确保裁剪高度不超过原始高度
        guard cropHeight <= originalHeight else {
            return originalImage
        }
        
        // 计算裁剪区域（居中）
        let y = (originalHeight - cropHeight) / 2
        let cropRect = CGRect(x: 0, y: y, width: originalWidth, height: cropHeight)
        
        // 使用 Core Graphics 进行裁剪
        return autoreleasepool {
            let format = UIGraphicsImageRendererFormat()
            format.scale = originalImage.scale
            format.opaque = true
            
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: originalWidth, height: cropHeight), format: format)
            let croppedImage = renderer.image { context in
                // 将原始图片绘制到裁剪区域
                originalImage.draw(at: CGPoint(x: 0, y: -y))
            }
            
            return croppedImage
        }
    }
    
    // 显示系统确认弹窗
    private func showSystemAlert() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            
            let alertController = UIAlertController(
                title: "切换到真实模式",
                message: "将有以下改动：\n• 开启参考网格\n• xxx\n• xxx",
                preferredStyle: .alert
            )
            
            alertController.addAction(UIAlertAction(title: "确认", style: .default) { [weak self] _ in
                self?.isRealModeEnabled = true
                
                // 检查并开启网格功能
                if let showReferenceGrid = self?.showReferenceGrid {
                    if !showReferenceGrid.wrappedValue {
                        print("------------------------")
                        print("[真实模式] 自动开启参考网格")
                        print("------------------------")
                        showReferenceGrid.wrappedValue = true
                    }
                }
            })
            
            alertController.addAction(UIAlertAction(title: "取消", style: .cancel))
            
            rootViewController.present(alertController, animated: true)
        }
    }
} 