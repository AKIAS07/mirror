import SwiftUI
import AVFoundation

struct CircleButton: View {
    let imageName: String?
    let systemName: String?
    let title: String
    let action: () -> Void
    let deviceOrientation: UIDeviceOrientation
    var isDisabled: Bool = false
    var useCustomColor: Bool = false
    var customColor: Color = .white
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                if let imageName = imageName {
                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .apply(colorModifier: useCustomColor, color: customColor)
                } else if let systemName = systemName {
                    Image(systemName: systemName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                        .foregroundColor(useCustomColor ? customColor : .white)
                }
                
                if !title.isEmpty {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
            .opacity(isDisabled ? 0.5 : 1.0)
            .rotationEffect(getRotationAngle(deviceOrientation))
            .animation(.easeInOut(duration: 0.3), value: deviceOrientation)
        }
        .disabled(isDisabled)
    }
    
    private func getRotationAngle(_ orientation: UIDeviceOrientation) -> Angle {
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
}

// MARK: - View Extension
extension View {
    @ViewBuilder
    func apply(colorModifier shouldApply: Bool, color: Color) -> some View {
        if shouldApply {
            self.foregroundColor(color)
                .colorMultiply(color)
        } else {
            self
        }
    }
}

struct RestartCameraView: View {
    let action: () -> Void
    @ObservedObject private var styleManager = BorderLightStyleManager.shared
    @ObservedObject private var orientationManager = DeviceOrientationManager.shared
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Image(systemName: "camera.circle.fill")
                        .font(.system(size: 75))
                        .foregroundColor(styleManager.iconColor)
                        .rotationEffect(orientationManager.getRotationAngle(orientationManager.currentOrientation))
                        .animation(.easeInOut(duration: 0.3), value: orientationManager.currentOrientation)
                }
                .position(x: geometry.size.width/2, 
                         y: geometry.size.height/2 - geometry.safeAreaInsets.bottom/2)  // 考虑安全区域
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
    @State private var previousIsSelected: Bool = false
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    
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
        .onAppear {
            previousIsSelected = isSelected
            feedbackGenerator.prepare()
        }
        .onChange(of: isSelected) { newValue in
            if newValue != previousIsSelected {
                feedbackGenerator.impactOccurred()
                previousIsSelected = newValue
            }
        }
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
                    .foregroundColor(BorderLightStyleManager.shared.iconColor)
                Image(systemName: "chevron.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(BorderLightStyleManager.shared.iconColor)
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(BorderLightStyleManager.shared.iconColor)
            case .downAndRightLeft:
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(BorderLightStyleManager.shared.iconColor)
                Image(systemName: "chevron.down")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(BorderLightStyleManager.shared.iconColor)
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(BorderLightStyleManager.shared.iconColor)
            case .rightOnly:
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(BorderLightStyleManager.shared.iconColor)
            case .leftOnly:
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(BorderLightStyleManager.shared.iconColor)
            case .upOnly:
                Image(systemName: "chevron.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(BorderLightStyleManager.shared.iconColor)
            case .downOnly:
                Image(systemName: "chevron.down")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(BorderLightStyleManager.shared.iconColor)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .background(Color.black.opacity(0.35))
        .cornerRadius(15)
    }
}

struct CameraBorderView: View {
    let isSelected: Bool
    let isLighted: Bool
    @ObservedObject private var styleManager = BorderLightStyleManager.shared
    
    var body: some View {
        GeometryReader { geometry in
            let availableHeight = geometry.size.height
            let containerFrame = CGRect(
                x: CameraLayoutConfig.horizontalPadding,
                y: CameraLayoutConfig.verticalOffset,
                width: geometry.size.width - (CameraLayoutConfig.horizontalPadding * 2),
                height: availableHeight - CameraLayoutConfig.bottomOffset
            )
            
            BorderLightView(
                screenWidth: containerFrame.width,
                centerY: containerFrame.height,
                showOriginalHighlight: isSelected,
                showMirroredHighlight: isSelected
            )
            .position(x: geometry.size.width/2, y: geometry.size.height/2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
} 