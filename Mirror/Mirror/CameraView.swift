import SwiftUI
import AVFoundation

struct CameraView: UIViewRepresentable {
    var session: AVCaptureSession
    var isMirrored: Bool
    var isSystemCamera: Bool = false  // 新增参数
    var isBackCamera: Bool = false    // 新增参数
    
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
            
            // 特殊情况处理：在镜像模式(A)下使用系统相机的后置摄像头
            if isSystemCamera && isBackCamera && isMirrored {
                // 在这种情况下需要旋转180度
                connection.videoOrientation = .portraitUpsideDown
                print("[CameraView] 特殊情况：系统相机后置镜像模式，应用180度旋转")
            } else {
                connection.videoOrientation = .portrait
            }
            
            connection.isVideoMirrored = isMirrored
            
            print("------------------------")
            print("[CameraView] 预览层配置")
            print("镜像状态：\(isMirrored)")
            print("系统相机：\(isSystemCamera)")
            print("后置摄像头：\(isBackCamera)")
            print("方向：\(connection.videoOrientation == .portraitUpsideDown ? "倒置竖屏" : "竖屏")")
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
            
            // 特殊情况处理：在镜像模式(A)下使用系统相机的后置摄像头
            if isSystemCamera && isBackCamera && isMirrored {
                // 在这种情况下需要旋转180度
                connection.videoOrientation = .portraitUpsideDown
                print("[CameraView] 特殊情况：系统相机后置镜像模式，应用180度旋转")
            } else {
                connection.videoOrientation = .portrait
            }
            
            connection.isVideoMirrored = isMirrored
            
            print("------------------------")
            print("[CameraView] 预览层更新")
            print("镜像状态：\(isMirrored)")
            print("系统相机：\(isSystemCamera)")
            print("后置摄像头：\(isBackCamera)")
            print("方向：\(connection.videoOrientation == .portraitUpsideDown ? "倒置竖屏" : "竖屏")")
            print("------------------------")
        }
        
        print("------------------------")
        print("[CameraView] 预览层更新完成")
        print("------------------------")
    }
} 