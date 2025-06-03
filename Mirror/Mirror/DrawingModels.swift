import SwiftUI
import Foundation

// 模板数据结构
public struct DrawingTemplate: Identifiable, Codable {
    public let id: UUID
    public var name: String
    private var imageData: Data?
    
    public var image: UIImage? {
        get {
            if let data = imageData {
                return UIImage(data: data)
            }
            return nil
        }
        set {
            imageData = newValue?.pngData()
        }
    }
    
    public init(name: String, image: UIImage? = nil) {
        self.id = UUID()
        self.name = name
        self.image = image
    }
    
    // 编码
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(imageData, forKey: .imageData)
    }
    
    // 解码
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        imageData = try container.decodeIfPresent(Data.self, forKey: .imageData)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, name, imageData
    }
} 