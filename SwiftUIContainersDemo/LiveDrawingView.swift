import SwiftUI

// ==========================================
// @OBSERVABLE MACRO (iOS 17+): GIAO DIỆN TỰ VẼ LẠI KHI DỮ LIỆU TỪ "SERVER" VỀ
// ==========================================
// Kịch bản: Server báo "có nét vẽ mới từ bạn A" => model thêm nét vào mảng => Canvas tự vẽ nét đó, không ai gọi lệnh vẽ lại.
// Ở đây server được giả lập bằng Timer: cứ 0,5 giây thêm 1 nét ngẫu nhiên.
//
// ==========================================
// DEMO ARC: strong / [weak self] / [unowned self]
// ==========================================
// Closure của Timer đóng vai "callback nhận dữ liệu từ Socket": được LƯU LẠI và gọi đi gọi lại liên tục.
// Chọn cách closure bắt self bằng deep link, rồi vào/thoát màn nhiều lần và đọc log:
//   artmate://draw?mode=strong   artmate://draw?mode=weak   artmate://draw?mode=unowned
//   (có ?mode => KHÔNG gọi stop() khi rời màn, để thấy riêng tác dụng của cách bắt self)
//   artmate://draw (không có mode) => chạy bình thường: weak + gọi stop() khi rời màn

struct LiveDrawingRoute: Hashable {} // "vé vào cửa" cho NavigationPath, giống RoomListRoute

// 3 cách closure bắt self
enum CaptureMode: String {
    case strong, weak, unowned
}

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

    // Cài đặt cho demo ARC, deep link artmate://draw?mode=... gán vào (static: dùng chung cho mọi board)
    static var captureMode: CaptureMode = .weak
    static var stopOnExit = true
    // Đếm số board đang nằm trong RAM: init +1, deinit -1. Thoát màn mà số này không giảm => leak.
    static var aliveCount = 0
    private static var lastID = 0

    let id: Int // số thứ tự board (#1, #2...) để log phân biệt board cũ (đã thoát màn) với board mới

    private let authors = ["Bạn A", "Bạn B", "Bạn C"]
    private let colors: [Color] = [.red, .orange, .green, .blue, .purple, .pink]

    init() {
        Self.lastID += 1
        id = Self.lastID
        Self.aliveCount += 1
    }

    // isolated deinit: deinit chạy trên MainActor => đọc/ghi được id, aliveCount.
    // Chỉ chạy khi KHÔNG còn ai giữ board (bộ đếm tham chiếu mạnh về 0). Thoát màn mà không thấy log này => board bị leak.
    isolated deinit {
        Self.aliveCount -= 1
        print("🗑 Board #\(id) deinit | còn \(Self.aliveCount) board trong RAM")
    }

    func start() {
        guard timer == nil else { return } // đang chạy rồi thì thôi, tránh tạo 2 timer
        isRunning = true
        print("▶️ Board #\(id) start, closure bắt self kiểu \(Self.captureMode) | đang có \(Self.aliveCount) board trong RAM")

        // Timer gọi closure mỗi 0,5s trên run loop của main thread. RunLoop GIỮ Timer, Timer GIỮ closure.
        // Closure của Timer không được compiler biết là ở MainActor => MainActor.assumeIsolated xác nhận "đang ở main" để gọi hàm @MainActor.
        switch Self.captureMode {
        case .strong:
            // ❌ Không có capture list => closure GIỮ CHẶT self.
            // Vòng: board ──timer──► Timer ──► closure ──self──► board => thoát màn board vẫn sống mãi (LEAK).
            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                MainActor.assumeIsolated { self.receiveStrokeFromServer() }
            }
        case .weak:
            // ✅ [weak self]: closure không giữ board => board chết thì self tự thành nil.
            // Board chết nhưng RunLoop vẫn giữ Timer => tự tắt timer, nếu không timer chạy mãi với self = nil.
            let boardID = id // copy số Int ra ngoài, để vẫn in được id khi board đã chết
            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
                MainActor.assumeIsolated {
                    guard let self else {
                        print("⏹ Timer của board #\(boardID) tự tắt vì board đã được giải phóng (self == nil)")
                        timer.invalidate()
                        return
                    }
                    self.receiveStrokeFromServer()
                }
            }
        case .unowned:
            // ⚠️ [unowned self]: closure không giữ board, nhưng KHÔNG tự thành nil.
            // Board chết rồi mà timer vẫn gọi => "Attempted to read an unowned reference but object was already deallocated" => CRASH.
            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [unowned self] _ in
                MainActor.assumeIsolated { self.receiveStrokeFromServer() }
            }
        }
    }
    
    
//    ## Retain cycle trong demo là gì
//
//    Hãy nhìn xem **ai đang giữ ai** khi bạn ở trong màn vẽ, chế độ `strong`:
//
//    ```
//    LiveDrawingView ──giữ──► board ──giữ (biến timer)──► Timer ──giữ──► closure
//                               ▲                                          │
//                               └────────────── giữ (self) ────────────────┘
//    ```
//
//    - `LiveDrawingView` giữ board qua `@State private var board`.
//    - Board giữ Timer qua biến `timer`.
//    - Timer giữ closure, vì nó cần closure để chạy mỗi 0,5 giây.
//    - Closure giữ board, vì bên trong có dùng `self`.
//
//    Ba mũi tên cuối **quay về chính board**, tạo thành **một vòng tròn**. Đó là **retain cycle**: các object giữ lẫn nhau thành vòng.
//
//    ### Khi bạn thoát màn
//
//    `LiveDrawingView` biến mất, nên mũi tên đầu tiên bị cắt:
//
//    ```
//                             board ──giữ──► Timer ──giữ──► closure
//                               ▲                              │
//                               └─────────── giữ ──────────────┘
//    ```
//
//    - Board vẫn còn **1 người giữ**: closure.
//    - Closure còn người giữ: Timer.
//    - Timer còn người giữ: board (và cả RunLoop của hệ thống).
//
//    Không object nào có bộ đếm về 0, nên **không object nào bị xoá**. Cả cụm trôi nổi trong RAM: không màn nào hiển thị nó, không ai dùng tới nó, nhưng nó vẫn chạy và vẫn thêm nét mỗi 0,5 giây. Đó là **memory leak**.
//
//    Log chế độ `strong` cho thấy đúng điều đó:
//    ```
//    ▶️ Board #1 start … | đang có 1 board trong RAM
//    ▶️ Board #2 start … | đang có 2 board trong RAM   ← board #1 vẫn còn
//    ▶️ Board #3 start … | đang có 3 board trong RAM   ← board #1, #2 vẫn còn
//    ```
//
//    ## `[weak self]` giải quyết được gì
//
//    `weak` biến mũi tên **closure → board** thành "chỉ nhớ, không giữ" (vẽ bằng nét đứt):
//
//    ```
//    LiveDrawingView ──giữ──► board ──giữ──► Timer ──giữ──► closure
//                               ▲                              ┆
//                               └┄┄┄┄┄┄┄ nhớ (weak) ┄┄┄┄┄┄┄┄┄┄┄┘
//    ```
//
//    **Vòng tròn bị cắt.** Khi thoát màn, mọi thứ được dọn theo thứ tự sau:
//
//    | Bước | Chuyện gì xảy ra |
//    |---|---|
//    | 1 | `LiveDrawingView` bỏ board. Closure chỉ "nhớ" chứ không giữ, nên board còn **0 người giữ** |
//    | 2 | Board bị xoá, console in `🗑 Board #1 deinit`. Board bị xoá thì biến `timer` của nó cũng mất |
//    | 3 | Timer vẫn còn RunLoop giữ, nên 0,5 giây sau nó gọi closure. `guard let self` thấy `nil` |
//    | 4 | Closure gọi `timer.invalidate()`, nên RunLoop bỏ Timer. Timer và closure cũng bị xoá, console in `⏹ Timer … tự tắt` |
//
//    Kết quả là cả cụm được dọn sạch:
//    ```
//    🗑 Board #1 deinit | còn 0 board trong RAM
//    ⏹ Timer của board #1 tự tắt vì board đã được giải phóng (self == nil)
//    ```
 

    func stop() {
        timer?.invalidate() // RunLoop bỏ Timer, Timer thả closure => vòng bị cắt dù closure bắt strong
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
        // rời màn hình thì tắt timer, nếu không timer vẫn chạy ngầm (như socket ngắt khi background).
        // Demo ARC (artmate://draw?mode=...) tắt bước này để thấy riêng tác dụng của strong / weak / unowned.
        .onDisappear {
            if DrawingBoard.stopOnExit { board.stop() }
        }
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
