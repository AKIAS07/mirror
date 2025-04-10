import SwiftUI
import PhotosUI

struct DraggableMakeupView: View {
    @Binding var isVisible: Bool
    @State private var position = CGPoint(x: UIScreen.main.bounds.width / 2, y: 200)
    @State private var dragOffset = CGSize.zero
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @StateObject private var permissionManager = PermissionManager.shared
    
    // 添加图片缩放和位置状态
    @State private var imageScale: CGFloat = 1.0
    @State private var lastImageScale: CGFloat = 1.0
    @State private var imageOffset: CGSize = .zero
    @State private var lastImageOffset: CGSize = .zero
    
    // 定义视图尺寸
    private let totalWidth: CGFloat = 240
    private let totalHeight: CGFloat = 240
    
    // 定义缩放限制
    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 10.0
    
    // 计算各区域高度
    private var topAreaHeight: CGFloat { totalHeight / 8 }
    private var bottomAreaHeight: CGFloat { totalHeight / 8 }
    private var centerAreaHeight: CGFloat { totalHeight / 8 * 6 }
    
    // 计算视图宽高比
    private var viewAspectRatio: CGFloat { totalWidth / centerAreaHeight }
    
    // 计算图片初始尺寸
    private func calculateInitialImageSize(_ image: UIImage) -> (width: CGFloat, height: CGFloat) {
        let imageAspectRatio = image.size.width / image.size.height
        
        if imageAspectRatio > viewAspectRatio {
            // 图片较宽，高度匹配
            let height = centerAreaHeight
            let width = height * imageAspectRatio
            return (width, height)
        } else {
            // 图片较高，宽度匹配
            let width = totalWidth
            let height = width / imageAspectRatio
            return (width, height)
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // 上区 - 关闭按钮
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isVisible = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }
                    .frame(width: 40, height: topAreaHeight)
                    .contentShape(Rectangle())
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .frame(height: topAreaHeight)
                .background(Color.black.opacity(0.3))
                .zIndex(2)
                
                // 中央区 - 显示选择的图片或上传按钮
                ZStack {
                    if let image = selectedImage {
                        let imageSize = calculateInitialImageSize(image)
                        GeometryReader { imageGeometry in
                            ZStack {
                                // 触控区层
                                Color.black.opacity(0.01)
                                    .frame(width: totalWidth, height: centerAreaHeight)
                                    .background(Color.clear) // 添加背景色以便于调试
                                    .contentShape(Rectangle()) // 确保整个区域都能响应手势
                                    .onAppear {
                                        print("------------------------")
                                        print("[触控区] 初始化")
                                        print("触控区大小：\(totalWidth) x \(centerAreaHeight)")
                                        print("触控区位置：x=\(totalWidth/2), y=\(centerAreaHeight/2)")
                                        print("------------------------")
                                    }
                                    .gesture(
                                        DragGesture()
                                            .onChanged { value in
                                                print("------------------------")
                                                print("[触控区] 拖拽手势开始")
                                                print("触控区大小：\(totalWidth) x \(centerAreaHeight)")
                                                print("触摸位置：\(value.location)")
                                                print("------------------------")
                                                
                                                let translation = value.translation
                                                // 计算边界限制
                                                let scaledWidth = imageSize.width * imageScale
                                                let scaledHeight = imageSize.height * imageScale
                                                let maxOffsetX = max(0, (scaledWidth - totalWidth) / 2)
                                                let maxOffsetY = max(0, (scaledHeight - centerAreaHeight) / 2)
                                                
                                                let proposedX = lastImageOffset.width + translation.width
                                                let proposedY = lastImageOffset.height + translation.height
                                                
                                                imageOffset = CGSize(
                                                    width: max(-maxOffsetX, min(maxOffsetX, proposedX)),
                                                    height: max(-maxOffsetY, min(maxOffsetY, proposedY))
                                                )
                                                
                                                print("图片偏移：\(imageOffset)")
                                                print("------------------------")
                                            }
                                            .onEnded { _ in
                                                lastImageOffset = imageOffset
                                                print("------------------------")
                                                print("[触控区] 拖拽手势结束")
                                                print("最终偏移：\(imageOffset)")
                                                print("------------------------")
                                            }
                                    )
                                    .simultaneousGesture(
                                        MagnificationGesture()
                                            .onChanged { value in
                                                print("------------------------")
                                                print("[触控区] 缩放手势变化")
                                                print("当前缩放值：\(value.magnitude)")
                                                print("------------------------")
                                                
                                                let proposedScale = value.magnitude * lastImageScale
                                                imageScale = min(max(proposedScale, minScale), maxScale)
                                                
                                                // 在缩放改变时重新计算位置边界
                                                let scaledWidth = imageSize.width * imageScale
                                                let scaledHeight = imageSize.height * imageScale
                                                let maxOffsetX = max(0, (scaledWidth - totalWidth) / 2)
                                                let maxOffsetY = max(0, (scaledHeight - centerAreaHeight) / 2)
                                                
                                                imageOffset = CGSize(
                                                    width: max(-maxOffsetX, min(maxOffsetX, imageOffset.width)),
                                                    height: max(-maxOffsetY, min(maxOffsetY, imageOffset.height))
                                                )
                                                
                                                print("图片缩放比例：\(imageScale)")
                                                print("边界限制：X=±\(maxOffsetX), Y=±\(maxOffsetY)")
                                                print("------------------------")
                                            }
                                            .onEnded { value in
                                                lastImageScale = imageScale
                                                print("------------------------")
                                                print("[触控区] 缩放手势结束")
                                                print("最终缩放比例：\(imageScale)")
                                                print("------------------------")
                                            }
                                    )
                                    .zIndex(10) // 提高触控区的层级
                                
                                // 图片层
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: imageSize.width, height: imageSize.height)
                                    .scaleEffect(imageScale)
                                    .offset(x: imageOffset.width, y: imageOffset.height)
                                    .clipped()
                                    .allowsHitTesting(false) // 让图片层穿透手势事件
                                    .onAppear {
                                        print("------------------------")
                                        print("[图片层] 初始化")
                                        print("图片大小：\(imageSize.width) x \(imageSize.height)")
                                        print("当前缩放：\(imageScale)")
                                        print("当前偏移：\(imageOffset)")
                                        print("------------------------")
                                    }
                            }
                            .position(x: totalWidth/2, y: centerAreaHeight/2)
                        }
                        .frame(width: totalWidth, height: centerAreaHeight)
                        .clipped() // 确保内容被裁剪在边界内
                    } else {
                        Button(action: {
                            checkAndRequestPhotoAccess()
                        }) {
                            VStack(spacing: 10) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 30))
                                    .foregroundColor(.white)
                                Text("上传图片")
                                    .foregroundColor(.white)
                                    .font(.system(size: 16))
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.4))
                    }
                }
                .frame(width: totalWidth, height: centerAreaHeight)
                .background(Color.black.opacity(0.4))
                .clipped()
                
                // 下区 - 拖拽区域
                HStack {
                    Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .frame(height: bottomAreaHeight)
                .background(Color.black.opacity(0.3))
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .global)
                        .onChanged { value in
                            let translation = value.translation
                            let newX = position.x + translation.width - dragOffset.width
                            let newY = position.y + translation.height - dragOffset.height
                            
                            // 计算边界
                            let minX = totalWidth/2
                            let maxX = geometry.size.width - totalWidth/2
                            let minY = totalHeight/2
                            let maxY = geometry.size.height - totalHeight/2
                            
                            // 应用边界限制
                            position.x = min(max(newX, minX), maxX)
                            position.y = min(max(newY, minY), maxY)
                            
                            dragOffset = translation
                        }
                        .onEnded { _ in
                            dragOffset = .zero
                        }
                )
                .zIndex(1)
            }
            .frame(width: totalWidth, height: totalHeight)
            .cornerRadius(12)
            .shadow(radius: 10)
            .position(x: position.x, y: position.y)
        }
        .sheet(isPresented: $showImagePicker) {
            PhotoPicker(selectedImage: $selectedImage)
        }
        .onChange(of: selectedImage) { _ in
            // 重置图片状态
            imageScale = 1.0
            lastImageScale = 1.0
            imageOffset = .zero
            lastImageOffset = .zero
        }
    }
    
    private func checkAndRequestPhotoAccess() {
        permissionManager.checkPhotoLibraryPermission { granted in
            if granted {
                showImagePicker = true
            }
        }
    }
}

// 修改图片选择器结构体名称避免冲突
struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) private var presentationMode
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker
        
        init(_ parent: PhotoPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.presentationMode.wrappedValue.dismiss()
            
            guard let provider = results.first?.itemProvider else { return }
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, _ in
                    DispatchQueue.main.async {
                        self.parent.selectedImage = image as? UIImage
                    }
                }
            }
        }
    }
}

#Preview {
    DraggableMakeupView(isVisible: .constant(true))
        .background(Color.gray)
} 