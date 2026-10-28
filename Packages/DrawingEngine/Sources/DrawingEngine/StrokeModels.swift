// ==========================================
// DRAWING ENGINE: dữ liệu nét vẽ
// ==========================================
// Thuần Swift: KHÔNG import SwiftUI/UIKit, KHÔNG biết gì về mạng.
// => dùng lại được cho app khác, viết unit test được mà không cần simulator hay server.
// `public`: code ngoài package (Networking, Features) mới nhìn thấy. Không ghi public => chỉ dùng được trong package này.

// 1 điểm. Toạ độ chuẩn hoá 0...1 (không phải pixel) để máy kích thước nào cũng vẽ đúng chỗ.
public struct Point2: Codable, Hashable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

// 1 nét ĐÃ CHỐT: server gán seq, quyết định thứ tự vẽ ở mọi máy.
public struct SharedStroke: Codable, Identifiable, Sendable {
    public let seq: Int
    public let strokeId: String? // mã do máy vẽ tự sinh lúc bắt đầu kéo, để nối nét live với nét chốt
    public let author: String
    public let colorIndex: Int   // chỉ số trong bảng màu
    public let points: [Point2]
    public var id: Int { seq }
}

// 1 nét ĐANG VẼ DỞ (của người khác), chưa có seq.
public struct LiveStroke: Codable, Identifiable, Sendable {
    public let strokeId: String
    public let author: String
    public let colorIndex: Int
    public var points: [Point2]
    public var id: String { strokeId }
}
