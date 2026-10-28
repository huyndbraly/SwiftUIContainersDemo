// ==========================================
// DRAWING ENGINE: luật cập nhật bảng vẽ
// ==========================================
// Nhận 1 sự kiện => trả ra trạng thái mới. Không mạng, không giao diện => dễ test:
//   var board = BoardState(); board.apply(.clear); #expect(board.strokes.isEmpty)

// Những gì có thể xảy ra với bảng vẽ (tầng Networking dịch tin JSON của server ra các case này)
public enum BoardEvent: Sendable {
    case snapshot(strokes: [SharedStroke], live: [LiveStroke]) // vừa vào phòng: nhận toàn bộ tranh hiện tại
    case liveChunk(strokeId: String, author: String, colorIndex: Int, points: [Point2]) // nét đang vẽ dở dài thêm
    case strokeCommitted(SharedStroke) // server chốt 1 nét (có seq)
    case cancel(strokeId: String)      // bỏ nét đang vẽ dở (người vẽ rớt mạng)
    case clear                         // xoá bảng
}

// Trạng thái bảng vẽ: struct (kiểu giá trị) => ViewModel giữ 1 bản, mỗi lần apply là ra bản mới.
public struct BoardState: Sendable {
    public private(set) var strokes: [SharedStroke] = []   // nét đã chốt, luôn sắp theo seq
    public private(set) var liveStrokes: [LiveStroke] = [] // nét đang vẽ dở

    public init() {}

    public mutating func apply(_ event: BoardEvent) {
        switch event {
        case .snapshot(let all, let live):
            strokes = all.sorted { $0.seq < $1.seq }
            liveStrokes = live
        case .liveChunk(let id, let author, let colorIndex, let chunk):
            if let index = liveStrokes.firstIndex(where: { $0.strokeId == id }) {
                liveStrokes[index].points.append(contentsOf: chunk) // nét mọc dài thêm
            } else {
                liveStrokes.append(LiveStroke(strokeId: id, author: author, colorIndex: colorIndex, points: chunk))
            }
        case .strokeCommitted(let stroke):
            guard !strokes.contains(where: { $0.seq == stroke.seq }) else { return } // chống nhận trùng
            // Bỏ nét live + thêm nét chốt trong CÙNG 1 bước => không bị nháy
            liveStrokes.removeAll { $0.strokeId == stroke.strokeId }
            strokes.append(stroke)
            strokes.sort { $0.seq < $1.seq } // luôn theo seq của server, không theo thứ tự đến
        case .cancel(let id):
            liveStrokes.removeAll { $0.strokeId == id }
        case .clear:
            strokes.removeAll()
            liveStrokes.removeAll()
        }
    }

    // Con số để so 2 máy có cùng dãy nét không: giống nhau => tranh giống hệt
    public var checksum: Int {
        strokes.reduce(7) { ($0 &* 31 &+ $1.seq &* 17 &+ $1.points.count) % 1_000_003 }
    }
}
