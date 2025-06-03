import SwiftUI
import Foundation

// 模板选择视图
public struct DrawingTemplateView: View {
    @Binding var isPresented: Bool
    let onTemplateSelected: (DrawingTemplate) -> Void
    
    // 使用模板管理器
    @ObservedObject private var templateManager = DrawingTemplateManager.shared
    @State private var showDeleteAlert = false
    @State private var showApplyAlert = false
    @State private var templateToDelete: Int?
    @State private var selectedTemplate: DrawingTemplate?
    @State private var showEmptyTemplateAlert = false
    
    public init(isPresented: Binding<Bool>, onTemplateSelected: @escaping (DrawingTemplate) -> Void) {
        self._isPresented = isPresented
        self.onTemplateSelected = onTemplateSelected
    }
    
    public var body: some View {
        VStack(spacing: 15) {
            // 标题栏
            titleBar
            
            // 模板网格
            ScrollView {  // 添加滚动视图
                templateGrid
            }
            
            Spacer()
        }
        .frame(width: 300, height: 300)  // 增加高度以容纳更多模板
        .background(Color.black.opacity(0.7))
        .cornerRadius(15)
        .alert("删除模板", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                if let index = templateToDelete {
                    templateManager.deleteTemplate(at: index)
                }
            }
        } message: {
            Text("确定要删除这个模板吗？")
        }
        .alert("应用模板", isPresented: $showApplyAlert) {
            Button("取消", role: .cancel) { }
            Button("确定") {
                if let template = selectedTemplate {
                    onTemplateSelected(template)
                    isPresented = false
                }
            }
        } message: {
            Text("确定要应用此模板吗？")
        }
        .alert("提示", isPresented: $showEmptyTemplateAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("请先固定绘画作品后再保存哦")
        }
    }
    
    // 标题栏视图
    private var titleBar: some View {
        HStack {
            Text("选择模板")
                .font(.headline)
                .foregroundColor(.white)
            
            Spacer()
            
            Button(action: {
                isPresented = false
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal)
        .padding(.top, 15)
    }
    
    // 模板网格视图
    private var templateGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 15) {
            ForEach(Array(templateManager.templates.enumerated()), id: \.element.id) { index, template in
                templateItem(template: template, index: index)
            }
        }
        .padding()
    }
    
    // 单个模板项视图
    private func templateItem(template: DrawingTemplate, index: Int) -> some View {
        TemplateItemView(
            template: template,
            hasImage: template.image != nil,
            onTap: {
                if let _ = template.image {
                    selectedTemplate = template
                    showApplyAlert = true
                } else {
                    showEmptyTemplateAlert = true
                }
            },
            onDelete: {
                if template.image != nil {
                    templateToDelete = index
                    showDeleteAlert = true
                }
            }
        )
    }
}

// 模板项视图
struct TemplateItemView: View {
    let template: DrawingTemplate
    let hasImage: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                templateContent
                if hasImage {
                    deleteButton
                }
            }
        }
    }
    
    private var templateContent: some View {
        VStack {
            if let image = template.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
            } else {
                emptyTemplate
            }
            
            Text(template.name)
                .font(.caption)
                .foregroundColor(.white)
        }
    }
    
    private var emptyTemplate: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(Color.white.opacity(0.5), lineWidth: 2)
            .frame(width: 80, height: 80)
            .overlay(
                Text("无")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.5))
            )
    }
    
    private var deleteButton: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 20))
                }
                .offset(x: 10, y: -10)
            }
            Spacer()
        }
    }
}

struct DrawingTemplateView_Previews: PreviewProvider {
    static var previews: some View {
        DrawingTemplateView(
            isPresented: .constant(true),
            onTemplateSelected: { _ in }
        )
        .preferredColorScheme(.dark)
    }
} 