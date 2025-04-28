import SwiftUI

struct CustomPopupView<Content: View>: View {
    @Binding var isPresented: Bool
    let content: Content
    
    init(isPresented: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self._isPresented = isPresented
        self.content = content()
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 半透明黑色背景
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        withAnimation {
                            isPresented = false
                        }
                    }
                
                // 内容视图
                content
                    .frame(width: geometry.size.width * 0.9, height: geometry.size.height * 0.8)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(radius: 10)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }
    }
}

// 为View添加自定义弹窗修饰器
extension View {
    func customPopup<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        ZStack {
            self
            
            if isPresented.wrappedValue {
                CustomPopupView(isPresented: isPresented, content: content)
                    .transition(.opacity)
            }
        }
    }
} 