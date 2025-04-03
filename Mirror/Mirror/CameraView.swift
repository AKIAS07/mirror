import SwiftUI
import AVFoundation

struct CameraView: UIViewRepresentable {
    @Binding var session: AVCaptureSession
    @Binding var isMirrored: Bool
    
    class PreviewView: UIView {
        override class var layerClass: AnyClass {
            return AVCaptureVideoPreviewLayer.self
        }
        
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            return layer as! AVCaptureVideoPreviewLayer
        }
    }
    
    func makeUIView(context: Context) -> PreviewView {
        print("------------------------")
        print("[CameraView] 创建预览视图")
        print("------------------------")
        
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        
        // 配置预览层
        if let connection = view.videoPreviewLayer.connection {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = isMirrored
            connection.videoOrientation = .portrait
            
            print("------------------------")
            print("[CameraView] 预览层配置")
            print("镜像状态：\(isMirrored)")
            print("方向：竖屏")
            print("------------------------")
        }
        
        return view
    }
    
    func updateUIView(_ uiView: PreviewView, context: Context) {
        print("------------------------")
        print("[CameraView] 更新预览视图")
        print("------------------------")
        
        uiView.videoPreviewLayer.session = session
        
        if let connection = uiView.videoPreviewLayer.connection {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = isMirrored
            connection.videoOrientation = .portrait
            
            print("------------------------")
            print("[CameraView] 预览层更新")
            print("镜像状态：\(isMirrored)")
            print("方向：竖屏")
            print("------------------------")
        }
        
        // 移除这里的会话启动逻辑，因为它可能与配置过程冲突
        print("------------------------")
        print("[CameraView] 预览层更新完成")
        print("------------------------")
    }
} 