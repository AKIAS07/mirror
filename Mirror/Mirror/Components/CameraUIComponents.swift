import SwiftUI
import AVFoundation

struct CircleButton: View {
    let systemName: String
    let imageName: String
    let title: String
    let action: () -> Void
    let deviceOrientation: UIDeviceOrientation
    let isDisabled: Bool
    
    init(systemName: String = "", 
         imageName: String = "",
         title: String, 
         action: @escaping () -> Void, 
         deviceOrientation: UIDeviceOrientation,
         isDisabled: Bool = false) {
        self.systemName = systemName
        self.imageName = imageName
        self.title = title
        self.action = action
        self.deviceOrientation = deviceOrientation
        self.isDisabled = isDisabled
    }
    
    var body: some View {
        Button(action: action) {
            if !title.isEmpty {
                // 只显示文字，用于焦距按钮
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
            } else if !imageName.isEmpty {
                // 显示自定义图片
                Image(imageName)
                    .resizable()
                    .renderingMode(.original)  // 使用原始渲染模式
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)  // 增加图标尺寸
                    .opacity(isDisabled ? 0.3 : 1.0)
                    .rotationEffect(getIconRotationAngle(deviceOrientation))
                    .frame(width: 60, height: 60)
            } else {
                // 显示系统图标
                Image(systemName: systemName)
                    .font(.system(size: 30))  // 增加系统图标尺寸
                    .foregroundColor(isDisabled ? .gray : .white)
                    .rotationEffect(getIconRotationAngle(deviceOrientation))
                    .frame(width: 60, height: 60)
            }
        }
        .disabled(isDisabled)
    }
    
    // 获取图标旋转角度
    private func getIconRotationAngle(_ orientation: UIDeviceOrientation) -> Angle {
        switch orientation {
        case .landscapeLeft:
            return .degrees(90)
        case .landscapeRight:
            return .degrees(-90)
        default:
            return .degrees(0)
        }
    }
}

struct RestartCameraView: View {
    let action: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("摄像头已关闭")
                        .foregroundColor(.white)
                        .font(.title2)
                    
                    Image(systemName: "camera.circle")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                }
                .position(x: geometry.size.width/2, y: geometry.size.height/2)
            }
            .onTapGesture {
                action()
            }
        }
    }
}

struct BackgroundMaskView: View {
    let isSelected: Bool
    let isLighted: Bool
    
    var body: some View {
        GeometryReader { geometry in
            let availableHeight = geometry.size.height
            
            ZStack {
                Color.white.opacity(0.0)
                    .edgesIgnoringSafeArea(.all)
                
                Path { path in
                    path.addRect(CGRect(x: 0, y: 0, width: geometry.size.width, height: geometry.size.height))
                    
                    let holeWidth = geometry.size.width - (CameraLayoutConfig.horizontalPadding * 2)
                    let holeHeight = availableHeight - CameraLayoutConfig.bottomOffset
                    let holeX = CameraLayoutConfig.horizontalPadding
                    let holeY = (availableHeight - holeHeight) / 2 + CameraLayoutConfig.verticalOffset
                    
                    let bezierPath = UIBezierPath(roundedRect: CGRect(x: holeX,
                                                                     y: holeY,
                                                                     width: holeWidth,
                                                                     height: holeHeight),
                                                cornerRadius: CameraLayoutConfig.cornerRadius)
                    path.addPath(Path(bezierPath.cgPath))
                }
                .fill(style: FillStyle(eoFill: true))
                .foregroundColor(isLighted ? Color.white.opacity(1.0) : Color.black.opacity(1.0))
                
                Rectangle()
                    .fill(.yellow.opacity(0.0))
                    .frame(width: geometry.size.width - (CameraLayoutConfig.horizontalPadding * 2),
                           height: availableHeight - CameraLayoutConfig.bottomOffset)
                    .clipShape(RoundedRectangle(cornerRadius: CameraLayoutConfig.cornerRadius))
                    .offset(y: CameraLayoutConfig.verticalOffset)
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
}

struct DragHintView: View {
    let hintState: DragHintState
    
    var body: some View {
        HStack(spacing: 40) {
            switch hintState {
            case .upAndRightLeft:
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Image(systemName: "chevron.up")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
            case .downAndRightLeft:
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Image(systemName: "chevron.down")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
            case .rightOnly:
                Image(systemName: "chevron.right")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            case .leftOnly:
                Image(systemName: "chevron.left")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            case .upOnly:
                Image(systemName: "chevron.up")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            case .downOnly:
                Image(systemName: "chevron.down")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 15)
        .background(Color.black.opacity(0.7))
        .cornerRadius(15)
    }
}

struct CameraBorderView: View {
    let isSelected: Bool
    let isLighted: Bool
    
    var body: some View {
        GeometryReader { geometry in
            let availableHeight = geometry.size.height
            let containerFrame = CGRect(
                x: CameraLayoutConfig.horizontalPadding,
                y: CameraLayoutConfig.verticalOffset,
                width: geometry.size.width - (CameraLayoutConfig.horizontalPadding * 2),
                height: availableHeight - CameraLayoutConfig.bottomOffset
            )
            
            RoundedRectangle(cornerRadius: CameraLayoutConfig.cornerRadius)
                .trim(from: 0, to: 1)
                .stroke(
                    isSelected ? BorderStyle.selectedColor : BorderStyle.normalColor,
                    style: StrokeStyle(
                        lineWidth: isSelected ? BorderStyle.selectedWidth : BorderStyle.normalWidth,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .frame(width: containerFrame.width, height: containerFrame.height)
                .position(x: geometry.size.width/2, y: geometry.size.height/2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
} 