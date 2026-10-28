import Foundation
import Observation
import DrawingEngine
import Networking

// ==========================================
// MVVM: ViewModel của phòng vẽ chung (trước đây là SharedDrawingStore)
// ==========================================
// Luồng 1 chiều vẫn giữ nguyên:
//   View ──Action──► ViewModel ──gửi──► Socket ──► server
//   server ──► Socket (luồng nền) ──AsyncStream──► ViewModel ──► StrokeBuffer (actor) ──bản sao──► board (luồng chính) ──► View vẽ lại
// Ai được ghi gì:
//   - mảng nét gốc: CHỈ actor StrokeBuffer (mỗi lúc 1 việc)
//   - board hiển thị: CHỈ ViewModel trên MainActor (luồng chính)
// => không có chỗ nào 2 luồng cùng ghi 1 dữ liệu => không data race.

// Những việc View được phép yêu cầu
public enum DrawingAction {
    case strokeProgress(strokeId: String, points: [Point2]) // đang kéo, có thêm đoạn điểm mới
    case strokeEnded(strokeId: String)                      // nhấc tay, xin server chốt nét
    case clear                                              // bấm xoá bảng
}

@Observable
public final class SharedBoardViewModel {
    public private(set) var board = BoardState() // trạng thái bảng vẽ (DrawingEngine)
    public private(set) var isConnected = false

    public let myName = "Máy " + String(UUID().uuidString.prefix(4))
    public let myColorIndex = Int.random(in: 0..<6)

    @ObservationIgnored private let socket: any DrawingSocket
    @ObservationIgnored private let buffer = StrokeBuffer() // actor giữ bộ đệm nét gốc
    @ObservationIgnored private var listenTask: Task<Void, Never>? // vòng for-await đọc sự kiện socket

    public init(socket: any DrawingSocket) {
        self.socket = socket
    }

    // CỬA DUY NHẤT để View yêu cầu thay đổi. Chỉ gửi lên server, KHÔNG tự sửa board:
    // nét của mình cũng phải đợi server chốt rồi quay về như nét của bạn.
    public func dispatch(_ action: DrawingAction) {
        switch action {
        case .strokeProgress(let strokeId, let points):
            socket.sendLive(strokeId: strokeId, author: myName, colorIndex: myColorIndex, points: points)
        case .strokeEnded(let strokeId):
            socket.sendEnd(strokeId: strokeId)
        case .clear:
            socket.sendClear()
        }
    }

    public func connect() {
        guard listenTask == nil else { return } // đang nghe rồi thì thôi
        // Task {} tạo trong class @MainActor => thân Task chạy trên MainActor (luồng chính).
        // [weak self]: ViewModel giữ listenTask => Task không được giữ chặt ViewModel (tránh retain cycle).
        listenTask = Task { [weak self, socket, buffer] in
            // for await: mỗi khi socket đẩy 1 sự kiện vào stream (từ luồng nền), vòng lặp chạy 1 lượt ở đây (luồng chính)
            for await event in socket.events() {
                switch event {
                case .connected(let connected):
                    self?.isConnected = connected
                case .board(let boardEvent):
                    // await: sang actor ghi bộ đệm (xếp hàng nếu actor đang bận), nhận lại BẢN SAO
                    let snapshot = await buffer.apply(boardEvent)
                    // Quay lại luồng chính => gán dữ liệu hiển thị an toàn, View tự vẽ lại
                    self?.isConnected = true // nhận được gì đó từ server tức là đang thông
                    self?.board = snapshot
                }
            }
        }
    }

    public func disconnect() {
        // Huỷ vòng for-await => stream kết thúc => socket tự dọn (onTermination: dừng vòng lặp, đóng kết nối)
        listenTask?.cancel()
        listenTask = nil
        isConnected = false
    }
}
