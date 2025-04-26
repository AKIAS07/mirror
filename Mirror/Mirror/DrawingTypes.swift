import SwiftUI
import Foundation
import UIKit

// 绘图工具类型
enum ImageSelectionTool: String, Codable {
    case brush
    case rectangle
    case circle
}

// 绘图路径
struct DrawingPath: Identifiable, Equatable, Codable {
    let id: UUID
    var points: [CGPoint]
    var tool: ImageSelectionTool
    
    // 实现Equatable协议
    static func == (lhs: DrawingPath, rhs: DrawingPath) -> Bool {
        guard lhs.points.count == rhs.points.count else { return false }
        for (i, point) in lhs.points.enumerated() {
            if point.x != rhs.points[i].x || point.y != rhs.points[i].y {
                return false
            }
        }
        return lhs.tool == rhs.tool && lhs.id == rhs.id
    }
    
    // 编码
    enum CodingKeys: String, CodingKey {
        case id, points, tool
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(tool, forKey: .tool)
        
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
    }
} 