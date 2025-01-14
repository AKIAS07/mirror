import AVFoundation
import UIKit

// 视频处理器
class VideoProcessor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    var normalImageHandler: ((UIImage) -> Void)?
    var flippedImageHandler: ((UIImage) -> Void)?
    let context = CIContext()
    private var lastLogTime: Date = Date()
    private let logInterval: TimeInterval = 1.0  // 最多输出一次日志
    private var lastOrientation: UIDeviceOrientation = .unknown
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // 修正视频方向
        connection.videoOrientation = .portrait
        connection.isVideoMirrored = true
        
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        
        // 生成正常画面
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            let normalImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
            DispatchQueue.main.async {
                self.normalImageHandler?(normalImage)
            }
        }
        
        // 生成镜像画面（根据方向处理）
        var mirroredImage = ciImage.transformed(by: CGAffineTransform(scaleX: -1, y: 1))
        
        // 根据设备方向旋转镜像画面
        let deviceOrientation = UIDevice.current.orientation
        if deviceOrientation == .landscapeLeft || deviceOrientation == .landscapeRight {
            let rotationTransform = CGAffineTransform(translationX: ciImage.extent.width, y: ciImage.extent.height)
                .rotated(by: .pi)
            mirroredImage = mirroredImage.transformed(by: rotationTransform)
            
            // 只在方向改变时输出一次日志
            if deviceOrientation != lastOrientation {
                print("镜像画面根据设备方向(\(deviceOrientation == .landscapeLeft ? "向左" : "向右"))调整")
                lastOrientation = deviceOrientation
            }
        }
        
        if let cgImage = context.createCGImage(mirroredImage, from: mirroredImage.extent) {
            let flippedUIImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
            DispatchQueue.main.async {
                self.flippedImageHandler?(flippedUIImage)
            }
        }
    }
}

// 图片旋转扩展
extension UIImage {
    func rotate(degrees: CGFloat) -> UIImage {
        let radians = degrees * .pi / 180.0
        let rotatedSize = CGSize(
            width: size.width * abs(cos(radians)) + size.height * abs(sin(radians)),
            height: size.height * abs(cos(radians)) + size.width * abs(sin(radians))
        )
        
        UIGraphicsBeginImageContext(rotatedSize)
        let context = UIGraphicsGetCurrentContext()!
        
        context.translateBy(x: rotatedSize.width/2, y: rotatedSize.height/2)
        context.rotate(by: radians)
        draw(in: CGRect(
            x: -size.width/2,
            y: -size.height/2,
            width: size.width,
            height: size.height
        ))
        
        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return rotatedImage
    }
}

// 相机观察者
class CameraObserver: NSObject {
    let processor: MainVideoProcessor
    private var lastLogTime: Date = Date()
    private let logInterval: TimeInterval = 1.0
    private var previousMirrorState: Bool = false
    
    init(processor: MainVideoProcessor) {
        self.processor = processor
        super.init()
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "videoMirrored",
           let connection = object as? AVCaptureConnection {
            let currentTime = Date()
            
            // 在状态真正发生变化且超过时间间隔时输出日志
            if connection.isVideoMirrored != previousMirrorState && 
               currentTime.timeIntervalSince(lastLogTime) >= logInterval {
                print("镜像状态更新：\(connection.isVideoMirrored)")
                lastLogTime = currentTime
                previousMirrorState = connection.isVideoMirrored
                
                // 更新处理器的模式
                processor.setMode(connection.isVideoMirrored ? .modeA : .modeB)
            }
            
            // 更新处理器状态
            processor.isMirrored = connection.isVideoMirrored
        }
    }
}

// 主视频处理器
class MainVideoProcessor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    var imageHandler: ((UIImage) -> Void)?
    let context = CIContext()
    var isMirrored: Bool = false
    private var previousOrientation: UIDeviceOrientation = .unknown
    private var previousMirrorState: Bool = false
    private var lastLogTime: Date = Date()
    private let logInterval: TimeInterval = 1.0
    private var currentMode: CameraMode = .modeB
    
    enum CameraMode {
        case modeA
        case modeB
    }
    
    // 添加设置模式的方法
    func setMode(_ mode: CameraMode) {
        let previousMode = currentMode
        currentMode = mode
        
        // 记录模式变化
        if previousMode != currentMode {
            let currentTime = Date()
            if currentTime.timeIntervalSince(lastLogTime) >= logInterval {
                print("------------------------")
                print("模式切换")
                print("当前模式：\(currentMode == .modeA ? "模式A" : "模式B")")
                print("------------------------")
                lastLogTime = currentTime
            }
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        connection.videoOrientation = .portrait
        connection.isVideoMirrored = false  // 确保连接不自动镜像
        
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        var processedImage = ciImage
        let deviceOrientation = UIDevice.current.orientation
        let currentTime = Date()
        
        // 设备方向变化日志
        if deviceOrientation != previousOrientation && 
           currentTime.timeIntervalSince(lastLogTime) >= logInterval {
            print("------------------------")
            print("设备方向变化")
            print("当前模式：\(currentMode == .modeA ? "模式A" : "模式B")")
            switch deviceOrientation {
            case .portrait:
                print("方向：竖屏(1)")
            case .portraitUpsideDown:
                print("方向：倒置竖屏(2)")
            case .landscapeRight:
                print("方向：向右横屏(3)")
            case .landscapeLeft:
                print("方向：向左横屏(4)")
            default:
                print("方向：其他")
            }
            print("------------------------")
            previousOrientation = deviceOrientation
            lastLogTime = currentTime
        }
        
        // 根据当前模式处理图像
        switch currentMode {
        case .modeA:
            // 模式A：应用水平翻转（镜像效果）
            processedImage = processedImage.transformed(by: CGAffineTransform(scaleX: -1, y: 1))
            
        case .modeB:
            // 模式B：在设备方向为3或4时进行180度旋转
            if deviceOrientation == .landscapeLeft || deviceOrientation == .landscapeRight {
                let rotationTransform = CGAffineTransform(translationX: ciImage.extent.width, y: ciImage.extent.height)
                    .rotated(by: .pi)
                processedImage = processedImage.transformed(by: rotationTransform)
            }
        }
        
        if let cgImage = context.createCGImage(processedImage, from: processedImage.extent) {
            let uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
            DispatchQueue.main.async {
                self.imageHandler?(uiImage)
            }
        }
    }
} 