import SwiftUI

// Pro 标签组件
public struct ProLabel: View {
    let text: String
    @StateObject private var proManager = ProManager.shared
    
    public var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(Color(red: 0.8, green: 0.6, blue: 0.0))  // 金色
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(red: 1.0, green: 0.95, blue: 0.7).opacity(0.3))  // 浅金色背景
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(red: 0.8, green: 0.6, blue: 0.0).opacity(0.5), lineWidth: 1)  // 金色边框
                    )
                    .frame(width: 35, height: 15)
            )
            // 只在非 Pro 用户时添加点击事件
            .onTapGesture(perform: proManager.isPro ? {} : {
                proManager.showProUpgrade()
            })
            // 只在非 Pro 用户时显示弹窗
            .sheet(isPresented: $proManager.showProUpgradeSheet, content: {
                if !proManager.isPro {
                    ProUpgradeView(dismiss: { proManager.showProUpgradeSheet = false })
                }
            })
    }
}

// Free 标签组件
public struct FreeLabel: View {
    let text: String
    
    public var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(Color(red: 0, green: 0.2, blue: 0.6).opacity(0.3)) 
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(red: 0, green: 0.2, blue: 0.7).opacity(0.1))  
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(red: 0, green: 0.2, blue: 0.6).opacity(0.3), lineWidth: 1) 
                    )
                    .frame(width: 35, height: 15)
            )
    }
}
