import SwiftUI

// ==========================================
// @OBSERVABLE MACRO (iOS 17+): GIAO DIỆN TỰ VẼ LẠI KHI DỮ LIỆU TỪ "SERVER" VỀ
// ==========================================
// Kịch bản: Server báo "có nét vẽ mới từ bạn A" => model thêm nét vào mảng => Canvas tự vẽ nét đó, không ai gọi lệnh vẽ lại.
// Ở đây server được giả lập bằng Timer: cứ 0,5 giây thêm 1 nét ngẫu nhiên.

struct LiveDrawingRoute: Hashable {} // "vé vào cửa" cho NavigationPath, giống RoomListRoute

// 1 nét vẽ: danh sách điểm + màu + người vẽ.
// Toạ độ chuẩn hoá 0...1 (không phải pixel) để máy nào, kích thước Canvas nào cũng vẽ đúng chỗ => khi vẽ nhân với size của Canvas.
// Identifiable để ForEach/Canvas phân biệt được từng nét.
struct Stroke: Identifiable {
    let id = UUID()
    let author: String
    let color: Color
    let points: [CGPoint]
}

// --- MODEL ---
// @Observable (macro): Swift tự viết lại class này, mỗi stored property được bọc thêm bộ ghi nhận "ai đã ĐỌC" và "ai đã GHI".
// => SwiftUI biết CHÍNH XÁC view nào đọc property nào, và chỉ vẽ lại view đó khi property đó đổi.
// So với ObservableObject cũ (iOS 13+): chỉ cần @Published đổi là MỌI view dùng object đều bị tính lại body, kể cả view không đọc property đó.
// Là class (reference type) vì cần 1 đối tượng DUY NHẤT dùng chung giữa nhiều view; struct bị copy mỗi lần truyền.
// @MainActor: Timer chạy trên main thread, và mọi thay đổi ảnh hưởng UI phải ở main thread.
@MainActor
@Observable
final class DrawingBoard {
    var strokes: [Stroke] = []
    var isRunning = false

    // @ObservationIgnored: property này KHÔNG cần theo dõi (không view nào hiển thị Timer), tránh macro bọc thừa.
    @ObservationIgnored private var timer: Timer?

    private let authors = ["Bạn A", "Bạn B", "Bạn C"]
    private let colors: [Color] = [.red, .orange, .green, .blue, .purple, .pink]

    func start() {
        guard timer == nil else { return } // đang chạy rồi thì thôi, tránh tạo 2 timer
        isRunning = true
        // Timer gọi closure mỗi 0,5s trên run loop của main thread.
        // [weak self]: Timer giữ closure, closure giữ self => nếu không weak thì board không bao giờ được giải phóng (retain cycle).
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            // Closure của Timer không được compiler biết là ở MainActor => xác nhận "đang ở main" để gọi hàm @MainActor.
            MainActor.assumeIsolated { self?.receiveStrokeFromServer() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    func clear() {
        strokes.removeAll()
    }

    // Đây là chỗ "server báo về". App thật sẽ gọi hàm này trong callback WebSocket, ở đây dữ liệu được sinh ngẫu nhiên.
    private func receiveStrokeFromServer() {
        var point = CGPoint(x: .random(in: 0.1...0.9), y: .random(in: 0.1...0.9))
        var points = [point]
        for _ in 0..<12 { // đi bộ ngẫu nhiên 12 bước để ra nét cong
            point.x = min(max(point.x + .random(in: -0.08...0.08), 0), 1)
            point.y = min(max(point.y + .random(in: -0.08...0.08), 0), 1)
            points.append(point)
        }
        // Ghi vào strokes => SwiftUI biết ngay property này vừa đổi => các view ĐỌC strokes sẽ được tính lại body.
        strokes.append(Stroke(author: authors.randomElement()!, color: colors.randomElement()!, points: points))
    }
}

// --- MÀN HÌNH CHA ---
struct LiveDrawingView: View {
    // @State giữ board sống suốt vòng đời màn hình (iOS 17+ dùng @State cho cả class @Observable, thay cho @StateObject cũ).
    // Nếu khai báo `let board = DrawingBoard()` thì mỗi lần body cha chạy lại sẽ tạo board MỚI, mất hết nét.
    @State private var board = DrawingBoard()

    var body: some View {
        // In ra console MỖI LẦN body của view này được tính lại, kèm lý do (property nào đổi).
        // Chỉ dùng khi debug. `let _ =` để thoả quy tắc ViewBuilder (không cho gọi hàm trả Void trực tiếp trong body).
        let _ = Self._printChanges()

        // Cha CHỈ truyền board xuống, KHÔNG đọc strokes hay isRunning => body của cha không bao giờ chạy lại khi nét mới về.
        VStack(spacing: 16) {
            StrokeCounterView(board: board)
            StrokeCanvasView(board: board)
            ServerControlView(board: board)
        }
        .padding()
        .navigationTitle("Vẽ chung realtime")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { board.start() }
        .onDisappear { board.stop() } // rời màn hình thì tắt timer, nếu không timer vẫn chạy ngầm (như socket ngắt khi background)
    }
}

// --- VIEW 1: ĐỌC strokes.count / strokes.last => vẽ lại mỗi khi có nét mới ---
struct StrokeCounterView: View {
    let board: DrawingBoard // không cần @Bindable/@ObservedObject: chỉ ĐỌC, Observation tự theo dõi

    var body: some View {
        let _ = Self._printChanges()
        HStack {
            Text("Số nét: \(board.strokes.count)")
                .font(.headline)
            Spacer()
            if let last = board.strokes.last {
                Text("Mới nhất: \(last.author)")
                    .font(.subheadline)
                    .foregroundColor(last.color)
            }
        }
    }
}

// --- VIEW 2: CANVAS, ĐỌC toàn bộ strokes => vẽ lại mỗi khi có nét mới ---
struct StrokeCanvasView: View {
    let board: DrawingBoard

    var body: some View {
        let _ = Self._printChanges()
        // Đọc strokes NGAY TRONG body (không đọc bên trong closure của Canvas) để chắc chắn SwiftUI ghi nhận sự phụ thuộc.
        let strokes = board.strokes

        // Canvas: vẽ kiểu immediate-mode bằng GraphicsContext, nhanh hơn nhiều so với tạo hàng trăm view con (ForEach { Path }).
        Canvas { context, size in
            for stroke in strokes {
                var path = Path()
                // Đổi toạ độ chuẩn hoá 0...1 thành pixel thật theo kích thước Canvas
                path.addLines(stroke.points.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) })
                context.stroke(path, with: .color(stroke.color),
                               style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            }
        }
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
    }
}

// --- VIEW 3: CHỈ ĐỌC isRunning => KHÔNG vẽ lại khi nét mới về (đây là điểm chứng minh) ---
struct ServerControlView: View {
    let board: DrawingBoard

    var body: some View {
        let _ = Self._printChanges()
        HStack(spacing: 12) {
            Button(board.isRunning ? "Ngắt server giả" : "Bật server giả") {
                board.isRunning ? board.stop() : board.start()
            }
            .buttonStyle(.borderedProminent)

            Button("Xoá bảng", role: .destructive) { board.clear() }
                .buttonStyle(.bordered)
        }
    }
}

//Giả sử viết theo cách cũ:

//class DrawingBoard: ObservableObject {
//    @Published var strokes: [Stroke] = []
//    @Published var isRunning = false
//}
//
//struct ServerControlView: View {
//    @ObservedObject var board: DrawingBoard
//    ...
//}
//
//Mỗi lần strokes đổi, board phát thông báo chung "có gì đó vừa đổi". Mọi view đang @ObservedObject board, kể cả ServerControlView, đều bị gọi lại body. SwiftUI không biết view đó chỉ quan tâm isRunning.
//
//Sau khi gọi lại body, SwiftUI so kết quả mới với kết quả cũ. Hai nút vẫn y hệt, nên trên màn hình không có gì đổi. Cái tốn là công tính lại body (tạo lại các view con, chạy lại code trong body), chứ không phải vẽ lại thật. Với hai nút thì chẳng đáng kể, nhưng với view phức tạp mà bị gọi lại 2 lần mỗi giây thì lãng phí.

#Preview {
    NavigationStack {
        LiveDrawingView()
    }
}

//Board có hai thông tin: strokes (danh sách nét) và isRunning (server đang chạy hay không). Có 3 view cùng nhìn vào board:
//
//┌───────────────────┬────────────┐
//│       View        │ Đọc cái gì │
//├───────────────────┼────────────┤
//│ StrokeCounterView │ strokes    │
//├───────────────────┼────────────┤
//│ StrokeCanvasView  │ strokes    │
//├───────────────────┼────────────┤
//│ ServerControlView │ isRunning  │
//└───────────────────┴────────────┘
//
//Mỗi 0,5 giây timer thêm một nét, tức là strokes đổi. Lúc đó:
//
//- StrokeCounterView đọc strokes, nên số nét phải cập nhật. Body chạy lại.
//- StrokeCanvasView đọc strokes, nên phải vẽ thêm nét. Body chạy lại.
//- ServerControlView không đọc strokes. Nút "Bật/Ngắt server giả" không có gì thay đổi để hiển thị, nên body không chạy lại.
