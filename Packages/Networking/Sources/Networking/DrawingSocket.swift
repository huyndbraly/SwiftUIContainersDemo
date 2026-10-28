import Foundation
import DrawingEngine

// ==========================================
// NETWORKING: kết nối WebSocket tới server vẽ chung
// ==========================================
// Dữ liệu từ server được NHẬN VÀ GIẢI MÃ Ở LUỒNG NỀN (receiveAll), rồi đẩy vào 1 AsyncStream.
// ViewModel (luồng chính) chỉ cần: for await event in socket.events() { ... }
//
//   luồng nền:   ws.receive() → giải mã JSON → continuation.yield(event) ─┐
//                                                                         │ AsyncStream (ống nối an toàn giữa các luồng)
//   luồng chính: for await event in socket.events() ◄─────────────────────┘

// Sự kiện socket báo cho ViewModel.
// Sendable: được phép đi qua ranh giới giữa các luồng (chỉ chứa dữ liệu kiểu giá trị, không ai sửa chung được).
public enum SocketEvent: Sendable {
    case connected(Bool)  // có / mất kết nối
    case board(BoardEvent) // server báo 1 thay đổi của bảng vẽ
}

// Hợp đồng: ViewModel chỉ biết những hàm này, không biết bên trong là URLSession.
// @MainActor: gọi từ luồng chính (ViewModel), nên gửi tin đi luôn đúng thứ tự.
@MainActor
public protocol DrawingSocket: AnyObject, Sendable {
    // Mở kết nối và trả về dòng sự kiện. Vòng for-await bên ngoài dừng (bị huỷ) => socket tự ngắt.
    func events() -> AsyncStream<SocketEvent>
    func sendLive(strokeId: String, author: String, colorIndex: Int, points: [Point2])
    func sendEnd(strokeId: String)
    func sendClear()
}

// Bản thật: URLSessionWebSocketTask nối tới Server/drawing_server.py
@MainActor
public final class WebSocketDrawingSocket: DrawingSocket {
    private let url: URL
    private var current: URLSessionWebSocketTask? // kết nối đang mở, dùng để gửi tin

    // 127.0.0.1 (không phải "localhost") để khỏi vướng App Transport Security với ws:// không mã hoá
    public init(url: URL = URL(string: "ws://127.0.0.1:8765")!) {
        self.url = url
    }

    public func events() -> AsyncStream<SocketEvent> {
        // makeStream: tạo 1 cái ống. `stream` là đầu ra (ViewModel đọc), `continuation` là đầu vào (ta đẩy sự kiện vào).
        let (stream, continuation) = AsyncStream.makeStream(of: SocketEvent.self)
        print("🔌 Socket: bắt đầu kết nối \(url)")

        // Vòng kết nối lại: chạy trên MainActor (vì class là @MainActor), nhưng phần chờ/nhận tin nằm ở receiveAll (luồng nền)
        let loop = Task { [weak self, url] in
            while !Task.isCancelled {
                let ws = URLSession.shared.webSocketTask(with: url)
                self?.current = ws
                ws.resume()
                await Self.receiveAll(from: ws, into: continuation) // chỉ trả về khi kết nối hỏng hoặc bị huỷ
                continuation.yield(.connected(false))
                try? await Task.sleep(for: .seconds(1)) // mất kết nối thì thử lại sau 1 giây
            }
            continuation.finish()
        }

        // Bên đọc ngừng đọc (ViewModel huỷ vòng for-await) => dọn dẹp: dừng vòng lặp + đóng kết nối
        continuation.onTermination = { [weak self] _ in
            print("🔌 Socket: đã ngắt kết nối")
            loop.cancel()
            Task { @MainActor in
                self?.current?.cancel(with: .goingAway, reason: nil) // làm receive() đang chờ ném lỗi để thoát
                self?.current = nil
            }
        }
        return stream
    }

    // @concurrent + nonisolated: chạy ở LUỒNG NỀN. Chờ tin và giải mã JSON ở đây, không chiếm luồng chính.
    // Chỉ đụng tới dữ liệu Sendable (ws, continuation, sự kiện đã giải mã) => compiler chứng minh được không có data race.
    @concurrent
    nonisolated private static func receiveAll(from ws: URLSessionWebSocketTask,
                                               into continuation: AsyncStream<SocketEvent>.Continuation) async {
        do {
            while true {
                let message = try await ws.receive() // chờ server gửi gì đó
                if case .string(let text) = message,
                   let decoded = try? JSONDecoder().decode(ServerMessage.self, from: Data(text.utf8)),
                   let event = decoded.boardEvent {
                    continuation.yield(.board(event)) // yield gọi an toàn từ bất kỳ luồng nào
                }
            }
        } catch {
            // lỗi (server tắt, bị cancel...) => thoát, vòng ngoài sẽ thử lại
        }
    }

    public func sendLive(strokeId: String, author: String, colorIndex: Int, points: [Point2]) {
        send(ClientMessage(type: "live", strokeId: strokeId, author: author, colorIndex: colorIndex, points: points))
    }

    public func sendEnd(strokeId: String) {
        send(ClientMessage(type: "end", strokeId: strokeId))
    }

    public func sendClear() {
        send(ClientMessage(type: "clear"))
    }

    private func send(_ message: ClientMessage) {
        guard let data = try? JSONEncoder().encode(message), let text = String(data: data, encoding: .utf8) else { return }
        current?.send(.string(text)) { _ in }
    }
}

// MARK: - Định dạng JSON trên đường truyền (chỉ package này cần biết => không public)

// Server → máy: "snapshot", "live", "stroke", "cancel", "clear"
struct ServerMessage: Codable {
    let type: String
    var stroke: SharedStroke?
    var strokes: [SharedStroke]?
    var live: [LiveStroke]?
    var strokeId: String?
    var author: String?
    var colorIndex: Int?
    var points: [Point2]?

    // Dịch "bì thư" JSON thành sự kiện của DrawingEngine
    var boardEvent: BoardEvent? {
        switch type {
        case "snapshot":
            return .snapshot(strokes: strokes ?? [], live: live ?? [])
        case "live":
            guard let strokeId, let points else { return nil }
            return .liveChunk(strokeId: strokeId, author: author ?? "?", colorIndex: colorIndex ?? 0, points: points)
        case "stroke":
            guard let stroke else { return nil }
            return .strokeCommitted(stroke)
        case "cancel":
            guard let strokeId else { return nil }
            return .cancel(strokeId: strokeId)
        case "clear":
            return .clear
        default:
            return nil
        }
    }
}

// Máy → server: "live" (đoạn điểm mới của nét đang kéo), "end" (nhấc tay), "clear"
struct ClientMessage: Codable {
    let type: String
    var strokeId: String?
    var author: String?
    var colorIndex: Int?
    var points: [Point2]?
}
