import SwiftUI
import AVFoundation

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