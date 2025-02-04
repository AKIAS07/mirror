import SwiftUI

// 颜色配置结构
struct ColorOption: Identifiable, Hashable {
    let id = UUID()
    let color: Color
    let image: String
    let background: Color?
    let useOriginalColor: Bool
    
    init(color: Color, image: String, background: Color? = nil, useOriginalColor: Bool = false) {
        self.color = color
        self.image = image
        self.background = background
        self.useOriginalColor = useOriginalColor
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ColorOption, rhs: ColorOption) -> Bool {
        lhs.id == rhs.id
    }
}

// 主屏蝴蝶颜色选项
let mainScreenColors: [ColorOption] = [
    ColorOption(color: .white, image: "icon-bf-white", background: Color.gray.opacity(0.5), useOriginalColor: false),
    ColorOption(color: Color(red: 190/255, green: 152/255, blue: 170/255), image: "icon-bf-white", background: nil, useOriginalColor: false),
    ColorOption(color: Color(red: 200/255, green: 183/255, blue: 166/255), image: "icon-bf-white", background: nil, useOriginalColor: false),
    ColorOption(color: Color(red: 240/255, green: 234/255, blue: 218/255), image: "icon-bf-white", background: Color.gray.opacity(0.5), useOriginalColor: false)
]

// 分屏蝴蝶颜色选项
let splitScreenColors: [ColorOption] = [
    ColorOption(color: .purple, image: "icon-bf-color-1", background: nil, useOriginalColor: true),
    ColorOption(color: Color(red: 62/255, green: 63/255, blue: 76/255), image: "icon-bf-white", background: nil, useOriginalColor: false),
    ColorOption(color: Color(red: 159/255, green: 137/255, blue: 158/255), image: "icon-bf-white", background: nil, useOriginalColor: false),
    ColorOption(color: Color(red: 93/255, green: 165/255, blue: 177/255), image: "icon-bf-white", background: nil, useOriginalColor: false),
    ColorOption(color: Color(red: 150/255, green: 194/255, blue: 78/255), image: "icon-bf-white", background: nil, useOriginalColor: false),
    ColorOption(color: Color(red: 251/255, green: 210/255, blue: 106/255), image: "icon-bf-white", background: nil, useOriginalColor: false),
    ColorOption(color: Color(red: 178/255, green: 104/255, blue: 111/255), image: "icon-bf-white", background: nil, useOriginalColor: false)
   
] 