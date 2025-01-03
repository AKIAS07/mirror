import SwiftUI
import AVFoundation

struct CameraView: UIViewRepresentable {
    @Binding var session: AVCaptureSession
    @Binding var isMirrored: Bool
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        
        // 确保在设置镜像之前关闭自动调整
        if let connection = previewLayer.connection {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = isMirrored
            
            // 添加日志输出
            print("CameraView - 设置镜像状态：\(isMirrored)")
        }
        
        view.layer.addSublayer(previewLayer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer,
           let connection = previewLayer.connection {
            // 同样确保在更新时也先关闭自动调整
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = isMirrored
            
            // 添加日志输出
            print("CameraView - 更新镜像状态：\(isMirrored)")
        }
    }
} 