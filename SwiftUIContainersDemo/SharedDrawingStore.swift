import SwiftUI

// ==========================================
// SINGLE SOURCE OF TRUTH + LUỒNG DỮ LIỆU MỘT CHIỀU:  Action → Store → View
// ==========================================
//
//   VIEW ──Action──► STORE (nguồn sự thật DUY NHẤT) ──state mới──► VIEW vẽ lại
//                      ▲
//                      └── Action "server báo có nét mới" (nét của mình lẫn nét của bạn đều vào đây)
//
// Quy tắc:
//  1. View KHÔNG tự sửa dữ liệu chung. Muốn thay đổi chỉ được gửi 1 Action vào store (store.dispatch).
//  2. `strokes` là private(set): bên ngoài chỉ đọc được, không gán được => chỉ store sửa.
//  3. Nét ĐÃ CHỐT của mình KHÔNG được thêm thẳng vào mảng. Nó đi lên server, server gán số thứ tự `seq` rồi phát lại cho mọi máy
//     (kể cả máy vừa vẽ). Mình chỉ thấy nét chốt của mình khi nó quay về qua đúng đường mà nét của bạn cũng đi.
//  4. REALTIME: khi đang kéo, từng đoạn điểm được gửi ngay ("live") để máy kia thấy nét mọc dần. Nét live chỉ là tạm thời, chưa có seq;
//     khi nhấc tay server chốt nét (gán seq) và máy nào cũng đổi nét live → nét chốt trong cùng 1 bước (không bị nháy).
//  => Mọi máy nhận cùng 1 dãy nét theo cùng thứ tự seq => tranh giống hệt nhau.
//
// Nếu mỗi máy tự append nét của mình ngay lập tức: máy A có [A, B], máy B có [B, A] => nét chồng nhau bị lệch thứ tự ("trống đánh xuôi, kèn thổi ngược").

// MARK: - Dữ liệu truyền qua mạng (JSON)

struct Point2: Codable, Hashable {
    let x: Double // toạ độ chuẩn hoá 0...1 để máy kích thước nào cũng vẽ đúng chỗ // => Toạ độ 0 đến 1 là gì? Giả sử bảng vẽ rộng 392 pixel. Ngón tay chạm ở pixel (196, 98) thì lưu x = 196/392 = 0.5 và y = 98/392 = 0.25. Máy khác có bảng rộng 300 pixel thì vẽ ở 0.5×300 = 150, vẫn đúng vị trí tương đối.
    let y: Double
}

struct SharedStroke: Codable, Identifiable {
    let seq: Int          // do SERVER gán, quyết định thứ tự vẽ
    let strokeId: String? // mã do máy vẽ tự sinh từ lúc bắt đầu kéo, để nối nét live với nét chốt
    let author: String
    let colorIndex: Int   // chỉ số trong bảng màu của view
    let points: [Point2]
    var id: Int { seq }
}

// Nét đang được vẽ dở (của người khác), chưa có seq
struct LiveStroke: Codable, Identifiable {
    let strokeId: String
    let author: String
    let colorIndex: Int
    var points: [Point2]
    var id: String { strokeId }
}

// Server → máy:
//  "snapshot" (nét đã chốt + nét đang vẽ dở khi mới kết nối), "live" (thêm đoạn điểm vào nét đang vẽ),
//  "stroke" (1 nét đã chốt, có seq), "cancel" (bỏ nét live), "clear" (xoá bảng)
struct ServerMessage: Codable {
    let type: String
    var stroke: SharedStroke?
    var strokes: [SharedStroke]?
    var live: [LiveStroke]?
    var strokeId: String?
    var author: String?
    var colorIndex: Int?
    var points: [Point2]?
}

// Máy → server: "live" (đoạn điểm mới của nét đang kéo), "end" (nhấc tay), "clear"
struct ClientMessage: Codable {
    let type: String
    var strokeId: String?
    var author: String?
    var colorIndex: Int?
    var points: [Point2]?
}

// MARK: - Action: danh sách đầy đủ những việc có thể làm thay đổi dữ liệu chung

enum DrawingAction {
    case strokeProgress(strokeId: String, points: [Point2]) // từ View: đang kéo, có thêm đoạn điểm mới
    case strokeEnded(strokeId: String)                      // từ View: nhấc tay, xin server chốt nét
    case clear                         // từ View: bấm xoá bảng
    case received(ServerMessage)       // từ mạng: server báo về
    case connectionChanged(Bool)       // từ mạng: mất/có kết nối
}

// MARK: - Store

@MainActor
@Observable
final class SharedDrawingStore {
    private(set) var strokes: [SharedStroke] = []        // nét đã chốt, theo thứ tự seq
    private(set) var liveStrokes: [LiveStroke] = []       // nét của người khác đang vẽ dở (tạm thời)
    private(set) var isConnected = false

    let myName = "Máy " + String(UUID().uuidString.prefix(4))
    let myColorIndex = Int.random(in: 0..<6)

    @ObservationIgnored private var socket: URLSessionWebSocketTask?
    @ObservationIgnored private var loop: Task<Void, Never>?
    // 127.0.0.1 (không phải "localhost") để khỏi vướng App Transport Security khi dùng ws:// không mã hoá. Simulator dùng chung mạng với Mac.
    @ObservationIgnored private let serverURL = URL(string: "ws://127.0.0.1:8765")!

    // CỬA DUY NHẤT để thay đổi trạng thái
    func dispatch(_ action: DrawingAction) {
        switch action {
        case .strokeProgress(let strokeId, let points):
            // Chỉ gửi lên server. Máy gửi tự hiển thị bản nháp của chính nó, không cần server phát ngược lại.
            send(ClientMessage(type: "live", strokeId: strokeId, author: myName, colorIndex: myColorIndex, points: points))

        case .strokeEnded(let strokeId):
            // KHÔNG sửa strokes ở đây. strokes chỉ đổi khi server chốt nét và phát lại (case .received "stroke").
            send(ClientMessage(type: "end", strokeId: strokeId))

        case .clear:
            send(ClientMessage(type: "clear"))

        case .received(let message):
            isConnected = true // nhận được gì đó từ server tức là đang thông (server luôn gửi snapshot ngay khi kết nối)
            switch message.type {
            case "snapshot":
                strokes = (message.strokes ?? []).sorted { $0.seq < $1.seq }
                liveStrokes = message.live ?? []
            case "live":
                guard let id = message.strokeId, let chunk = message.points else { break }
                if let index = liveStrokes.firstIndex(where: { $0.strokeId == id }) {
                    liveStrokes[index].points.append(contentsOf: chunk) // nét mọc dài thêm
                } else {
                    liveStrokes.append(LiveStroke(strokeId: id, author: message.author ?? "?",
                                                  colorIndex: message.colorIndex ?? 0, points: chunk))
                }
            case "cancel":
                liveStrokes.removeAll { $0.strokeId == message.strokeId }
            case "stroke":
                if let stroke = message.stroke, !strokes.contains(where: { $0.seq == stroke.seq }) { // chống nhận trùng
                    // Bỏ nét live và thêm nét chốt trong CÙNG 1 lần dispatch => SwiftUI chỉ vẽ 1 lần, nét không nháy mất.
                    liveStrokes.removeAll { $0.strokeId == stroke.strokeId }
                    strokes.append(stroke)
                    strokes.sort { $0.seq < $1.seq } // luôn sắp theo seq của server, không theo thứ tự đến của máy này
                }
            case "clear":
                strokes.removeAll()
                liveStrokes.removeAll()
            default:
                break
            }

        case .connectionChanged(let connected):
            isConnected = connected
        }
    }

    // Số kiểm tra phụ thuộc thứ tự: 2 máy có cùng số này nghĩa là cùng dãy nét, cùng thứ tự.
    // (Không dùng hashValue của Swift vì nó bị ngẫu nhiên hoá mỗi lần chạy app.)
    var checksum: Int {
        strokes.reduce(7) { ($0 &* 31 &+ $1.seq &* 17 &+ $1.points.count) % 1_000_003 }
    }

    // MARK: Mạng

    func connect() {
        guard loop == nil else { return }
        print("🔌 Socket: bắt đầu kết nối \(serverURL)")
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.runConnection()
                self.dispatch(.connectionChanged(false))
                try? await Task.sleep(for: .seconds(1)) // mất kết nối thì thử lại sau 1 giây
            }
        }
    }

    func disconnect() {
        guard loop != nil else { return } // chưa kết nối thì thôi, tránh in log thừa
        print("🔌 Socket: đã ngắt kết nối")
        loop?.cancel()
        loop = nil
        socket?.cancel(with: .goingAway, reason: nil) // làm receive() đang chờ bị ném lỗi để vòng lặp thoát
        socket = nil
        isConnected = false
    }

    private func runConnection() async {
        let task = URLSession.shared.webSocketTask(with: serverURL)
        socket = task
        task.resume()
        do {
            while true {
                let message = try await task.receive() // chờ server gửi gì đó
                if case .string(let text) = message,
                   let decoded = try? JSONDecoder().decode(ServerMessage.self, from: Data(text.utf8)) {
                    dispatch(.received(decoded))
                }
            }
        } catch {
            // lỗi (server tắt, bị cancel...) => thoát, connect() sẽ thử lại
        }
    }

    private func send(_ message: ClientMessage) {
        guard let data = try? JSONEncoder().encode(message), let text = String(data: data, encoding: .utf8) else { return }
        socket?.send(.string(text)) { _ in }
    }
}


//File này không có giao diện. Nó làm hai việc: giữ dữ liệu bảng vẽ, và nói chuyện với server. File gồm 4 phần.
//
//Phần A. Các "mẫu dữ liệu" (dòng 24 đến 68)
//
//Đây là các khuôn để đựng thông tin.
//
//┌─────────────────────────┬──────────────────────────────┬──────────────────────────────────────────────────┐
//│           Tên           │            Là gì             │                     Chứa gì                      │
//├─────────────────────────┼──────────────────────────────┼──────────────────────────────────────────────────┤
//│ Point2 (dòng 24)        │ Một điểm                     │ x, y từ 0 đến 1                                  │
//├─────────────────────────┼──────────────────────────────┼──────────────────────────────────────────────────┤
//│ SharedStroke (dòng 29)  │ Một nét đã chốt              │ seq, strokeId, author, colorIndex, points        │
//├─────────────────────────┼──────────────────────────────┼──────────────────────────────────────────────────┤
//│ LiveStroke (dòng 39)    │ Một nét đang vẽ dở (của bạn) │ giống trên nhưng không có seq                    │
//├─────────────────────────┼──────────────────────────────┼──────────────────────────────────────────────────┤
//│ ServerMessage (dòng 50) │ "Bì thư" server gửi cho máy  │ type cho biết loại tin, các trường khác tuỳ loại │
//├─────────────────────────┼──────────────────────────────┼──────────────────────────────────────────────────┤
//│ ClientMessage (dòng 62) │ "Bì thư" máy gửi cho server  │ type + vài trường                                │
//└─────────────────────────┴──────────────────────────────┴──────────────────────────────────────────────────┘
//
//Điểm cần nhớ:
//- x, y từ 0 đến 1 là vị trí theo tỉ lệ, không phải pixel. x = 0.5 luôn là giữa bảng, dù bảng to hay nhỏ.
//- strokeId là mã nhận diện nét, sinh ra ngay khi bắt đầu kéo. Nhờ nó, máy biết "nét đang vẽ dở này chính là nét chốt kia".
//- Codable ở cuối khai báo nghĩa là struct này đổi qua lại được với chữ JSON để gửi qua mạng.
//
//Ví dụ một "bì thư" server gửi khi có nét chốt:
//{"type":"stroke","stroke":{"seq":3,"strokeId":"S1","author":"Máy 0118","colorIndex":3,"points":[{"x":0.1,"y":0.2}, ...]}}
//
//Phần B. DrawingAction (dòng 72 đến 78): danh sách "yêu cầu"
//
//Đây là tất cả những việc có thể làm đổi dữ liệu, không có việc nào khác.
//
//┌───────────────────┬────────┬─────────────────────────────────────┐
//│      Action       │ Ai gửi │                Nghĩa                │
//├───────────────────┼────────┼─────────────────────────────────────┤
//│ strokeProgress    │ View   │ "Tôi đang kéo, đây là vài điểm mới" │
//├───────────────────┼────────┼─────────────────────────────────────┤
//│ strokeEnded       │ View   │ "Tôi nhấc tay rồi, chốt nét giúp"   │
//├───────────────────┼────────┼─────────────────────────────────────┤
//│ clear             │ View   │ "Xoá bảng"                          │
//├───────────────────┼────────┼─────────────────────────────────────┤
//│ received          │ Mạng   │ "Server vừa báo về một tin"         │
//├───────────────────┼────────┼─────────────────────────────────────┤
//│ connectionChanged │ Mạng   │ "Mất hoặc có kết nối"               │
//└───────────────────┴────────┴─────────────────────────────────────┘
//
//Phần C. SharedDrawingStore: kho dữ liệu (dòng 82 đến 150)
//
//Các biến (dòng 85 đến 95):
//
//┌─────────────────────────┬────────────────────────────────────────────────────────────────────────────────────┐
//│          Biến           │                                      Ý nghĩa                                       │
//├─────────────────────────┼────────────────────────────────────────────────────────────────────────────────────┤
//│ strokes                 │ Các nét đã chốt, theo thứ tự seq                                                   │
//├─────────────────────────┼────────────────────────────────────────────────────────────────────────────────────┤
//│ liveStrokes             │ Các nét của bạn đang vẽ dở                                                         │
//├─────────────────────────┼────────────────────────────────────────────────────────────────────────────────────┤
//│ isConnected             │ Đã nối được server chưa                                                            │
//├─────────────────────────┼────────────────────────────────────────────────────────────────────────────────────┤
//│ myName, myColorIndex    │ Tên và màu của máy mình (ngẫu nhiên lúc mở)                                        │
//├─────────────────────────┼────────────────────────────────────────────────────────────────────────────────────┤
//│ socket, loop, serverURL │ Đồ dùng nội bộ để nối mạng (có @ObservationIgnored vì màn hình không cần theo dõi) │
//└─────────────────────────┴────────────────────────────────────────────────────────────────────────────────────┘
//
//- private(set) nghĩa là bên ngoài chỉ đọc được, không gán được. Chỉ chính kho này mới sửa được dữ liệu.
//- @Observable nghĩa là khi các biến này đổi, màn hình nào đang đọc nó sẽ tự vẽ lại.
//
//Hàm dispatch (dòng 98): cửa duy nhất để thay đổi. Có 5 nhánh, chia 2 nhóm:
//
//Nhóm gửi đi (3 nhánh, chỉ gửi, không sửa dữ liệu):
//- strokeProgress → gửi tin "live" lên server (dòng 102).
//- strokeEnded → gửi tin "end" (dòng 106).
//- clear → gửi tin "clear" (dòng 109).
//
//Nhóm nhận về (nhánh .received, chỗ duy nhất sửa dữ liệu), chia theo type của tin server:
//
//┌───────────────┬─────────────────────────────────────────────────────────────────────────────────┐
//│ Tin từ server │                                    Việc làm                                     │
//├───────────────┼─────────────────────────────────────────────────────────────────────────────────┤
//│ snapshot      │ Máy vừa vào: lấy toàn bộ nét đã chốt và nét đang vẽ dở                          │
//├───────────────┼─────────────────────────────────────────────────────────────────────────────────┤
//│ live          │ Nối thêm điểm vào nét đang vẽ dở của bạn (chưa có thì tạo mới)                  │
//├───────────────┼─────────────────────────────────────────────────────────────────────────────────┤
//│ cancel        │ Bỏ nét đang vẽ dở (người vẽ rớt mạng)                                           │
//├───────────────┼─────────────────────────────────────────────────────────────────────────────────┤
//│ stroke        │ Nét đã chốt: bỏ nét live và thêm nét chốt trong cùng một bước, rồi sắp theo seq │
//├───────────────┼─────────────────────────────────────────────────────────────────────────────────┤
//│ clear         │ Xoá hết cả hai danh sách                                                        │
//└───────────────┴─────────────────────────────────────────────────────────────────────────────────┘
//
//Dòng 128 chống nhận trùng: nét có seq đã tồn tại thì bỏ qua.
//
//checksum (dòng 148): con số dùng để so hai máy có cùng dãy nét hay không.
//
//Phần D. Nối mạng (dòng 154 đến 194)
//
//┌─────────────────┬──────────────────────────────────────────────────────────────────────────┐
//│       Hàm       │                                 Việc làm                                 │
//├─────────────────┼──────────────────────────────────────────────────────────────────────────┤
//│ connect()       │ Mở đường dây tới server. Nếu rớt thì chờ 1 giây rồi nối lại, lặp mãi     │
//├─────────────────┼──────────────────────────────────────────────────────────────────────────┤
//│ disconnect()    │ Cắt đường dây, dừng vòng lặp                                             │
//├─────────────────┼──────────────────────────────────────────────────────────────────────────┤
//│ runConnection() │ Ngồi nghe: có tin từ server là đổi sang Action.received rồi gọi dispatch │
//├─────────────────┼──────────────────────────────────────────────────────────────────────────┤
//│ send()          │ Đóng gói tin thành chữ JSON rồi gửi lên server                           │
//└─────────────────┴──────────────────────────────────────────────────────────────────────────┘
