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
    
    // 添加输出控制属性
    var enableOriginalOutput: Bool = false
    var enableMirroredOutput: Bool = false
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // 修正视频方向
        connection.videoOrientation = .portrait
        connection.isVideoMirrored = true
        
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        
        // 根据控制属性决定是否输出
        if enableOriginalOutput {
            if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
                let normalImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
                DispatchQueue.main.async {
                    self.normalImageHandler?(normalImage)
                }
            }
        }
        
        if enableMirroredOutput {
            var mirroredImage = ciImage.transformed(by: CGAffineTransform(scaleX: -1, y: 1))
            let validOrientation = DeviceOrientationManager.shared.validOrientation
            
            if DeviceOrientationManager.shared.isAllowedOrientation(validOrientation) {
                if validOrientation == .landscapeLeft || validOrientation == .landscapeRight {
                    let rotationTransform = CGAffineTransform(translationX: ciImage.extent.width, y: ciImage.extent.height)
                        .rotated(by: .pi)
                    mirroredImage = mirroredImage.transformed(by: rotationTransform)
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
    lazy var context: CIContext = {
        // 使用 Metal 加速并保持最高质量
        let options = [
            CIContextOption.outputColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            CIContextOption.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            CIContextOption.useSoftwareRenderer: false,
            CIContextOption.highQualityDownsample: true
        ]
        return CIContext(options: options)
    }()
    
    var isMirrored: Bool = false
    private var previousOrientation: UIDeviceOrientation = .unknown
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
        connection.isVideoMirrored = false
        
        // 锁定缓冲区以防止数据竞争
        CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly) }
        
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        var processedImage = ciImage
        let validOrientation = DeviceOrientationManager.shared.validOrientation
        let currentTime = Date()
        
        // 只在有效方向变化时输出日志
        if validOrientation != previousOrientation && 
           currentTime.timeIntervalSince(lastLogTime) >= logInterval {
            print("------------------------")
            print("设备方向变化")
            print("当前模式：\(currentMode == .modeA ? "模式A" : "模式B")")
            print("当前方向：\(DeviceOrientationManager.shared.getOrientationDescription(validOrientation))")
            print("------------------------")
            previousOrientation = validOrientation
            lastLogTime = currentTime
        }
        
        // 根据当前模式处理图像
        switch currentMode {
        case .modeA:
            processedImage = processedImage.transformed(by: CGAffineTransform(scaleX: -1, y: 1))
            
        case .modeB:
            // 使用有效方向来决定旋转
            if validOrientation == .landscapeLeft || validOrientation == .landscapeRight {
                let rotationTransform = CGAffineTransform(translationX: ciImage.extent.width, y: ciImage.extent.height)
                    .rotated(by: .pi)
                processedImage = processedImage.transformed(by: rotationTransform)
            }
        }
        
        // 使用高质量渲染
        if let cgImage = context.createCGImage(processedImage, 
                                             from: processedImage.extent,
                                             format: .RGBA8,
                                             colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!) {
            let uiImage = UIImage(cgImage: cgImage, scale: UIScreen.main.scale, orientation: .up)
            DispatchQueue.main.async {
                self.imageHandler?(uiImage)
            }
        }
    }
} 