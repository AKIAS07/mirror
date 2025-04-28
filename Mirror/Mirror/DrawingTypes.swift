import SwiftUI
import Foundation
import UIKit

// 绘图工具类型
enum ImageSelectionTool: String, Codable {
    case brush      // 画笔
    case smudge     // 涂抹笔
    case rectangle  // 矩形
    case circle     // 圆形
    case mouth      // 嘴巴轮廓
    case eyebrow    // 眉毛轮廓
}

// 绘图路径
struct DrawingPath: Identifiable, Equatable, Codable {
    let id: UUID
    var points: [CGPoint]
    var tool: ImageSelectionTool
    var offset: CGPoint = .zero      // 路径的位置偏移
    var isSelected: Bool = false     // 是否被选中
    
    // 实现Equatable协议
    static func == (lhs: DrawingPath, rhs: DrawingPath) -> Bool {
        guard lhs.points.count == rhs.points.count else { return false }
        for (i, point) in lhs.points.enumerated() {
            if point.x != rhs.points[i].x || point.y != rhs.points[i].y {
                return false
            }
        }
        return lhs.tool == rhs.tool && lhs.id == rhs.id &&
               lhs.offset == rhs.offset && lhs.isSelected == rhs.isSelected
    }
    
    // 编码
    enum CodingKeys: String, CodingKey {
        case id, points, tool, offset, isSelected
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(tool, forKey: .tool)
        try container.encode(offset, forKey: .offset)
        try container.encode(isSelected, forKey: .isSelected)
        
        // 编码点数组
        var pointsContainer = container.nestedUnkeyedContainer(forKey: .points)
        for point in points {
            try pointsContainer.encode(point.x)
            try pointsContainer.encode(point.y)
        }
    }
    
    // 解码
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        tool = try container.decode(ImageSelectionTool.self, forKey: .tool)
        offset = try container.decodeIfPresent(CGPoint.self, forKey: .offset) ?? .zero
        isSelected = try container.decodeIfPresent(Bool.self, forKey: .isSelected) ?? false
        
        // 解码点数组
        var points: [CGPoint] = []
        var pointsContainer = try container.nestedUnkeyedContainer(forKey: .points)
        while !pointsContainer.isAtEnd {
            let x = try pointsContainer.decode(CGFloat.self)
            let y = try pointsContainer.decode(CGFloat.self)
            points.append(CGPoint(x: x, y: y))
        }
        self.points = points
    }
    
    // 默认初始化器
    init(id: UUID = UUID(), points: [CGPoint], tool: ImageSelectionTool) {
        self.id = id
        self.points = points
        self.tool = tool
        self.offset = .zero
        self.isSelected = false
    }
    
    // 获取路径的边界框
    func getBoundingBox() -> CGRect {
        guard !points.isEmpty else { return .zero }
        
        let offsetPoints = points.map { CGPoint(x: $0.x + offset.x, y: $0.y + offset.y) }
        let xs = offsetPoints.map { $0.x }
        let ys = offsetPoints.map { $0.y }
        
        let minX = xs.min() ?? 0
        let maxX = xs.max() ?? 0
        let minY = ys.min() ?? 0
        let maxY = ys.max() ?? 0
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    // 检查点是否在路径内
    func contains(_ point: CGPoint) -> Bool {
        let boundingBox = getBoundingBox()
        return boundingBox.contains(point)
    }
} 