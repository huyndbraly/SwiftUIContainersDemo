import SwiftUI
import DrawingEngine
import Networking

// ==========================================
// MVVM: View của phòng vẽ chung
// ==========================================
// View KHÔNG gọi Socket. Nó đọc dữ liệu từ ViewModel, gửi Action, và báo vòng đời (onAppear/onDisappear/scenePhase).

// Bảng màu dùng chung: server chỉ gửi chỉ số, mỗi máy tra ra màu giống nhau
private let boardPalette: [Color] = [.red, .orange, .green, .blue, .purple, .pink]

public struct SharedBoardView: View {
    @State private var viewModel: SharedBoardViewModel

    // Trạng thái vòng đời app (active / inactive / background), SwiftUI tự cập nhật. Chỉ đọc, không gán được.
    @Environment(\.scenePhase) private var scenePhase

    // Dependency Injection qua init: ai mở phòng vẽ thì đưa socket vào
    public init(socket: any DrawingSocket) {
        _viewModel = State(initialValue: SharedBoardViewModel(socket: socket))
    }

    public var body: some View {
        VStack(spacing: 12) {
            SharedStatusView(viewModel: viewModel)
            SharedCanvasView(viewModel: viewModel)
            Button("Xoá bảng (cả 2 máy)", role: .destructive) {
                viewModel.dispatch(.clear) // chỉ gửi Action, không tự xoá
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .navigationTitle("Vẽ chung 2 máy")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { // vào phòng => kết nối
            print("🔄 [Lifecycle] Phòng vẽ: onAppear")
            viewModel.connect()
        }
        .onDisappear { // rời phòng (bấm Back) => ngắt
            print("🔄 [Lifecycle] Phòng vẽ: onDisappear")
            viewModel.disconnect()
        }
        // Bấm Home KHÔNG gọi onDisappear (màn vẫn còn trong NavigationStack, chỉ là app xuống nền)
        // => phải tự nghe scenePhase để ngắt/nối lại socket.
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background: // bấm Home / chuyển app khác => ngắt để đỡ hao pin, đỡ tốn mạng
                print("🌙 [Lifecycle] Phòng vẽ: scenePhase = background => ngắt socket")
                viewModel.disconnect()
            case .active: // mở lại app => nối lại. Màn vẫn là phòng vẽ vì NavigationStack giữ nguyên path
                print("☀️ [Lifecycle] Phòng vẽ: scenePhase = active => kết nối lại socket")
                viewModel.connect()
            case .inactive: // có cuộc gọi đến, kéo Control Center... thường chỉ thoáng qua => giữ kết nối
                print("🟡 [Lifecycle] Phòng vẽ: scenePhase = inactive => giữ kết nối")
            @unknown default:
                break
            }
        }
    }
}

// Thanh trạng thái: so sánh "Checksum" giữa 2 simulator, giống nhau nghĩa là tranh giống hệt
struct SharedStatusView: View {
    let viewModel: SharedBoardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.isConnected ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                Text(viewModel.isConnected ? "Đã kết nối server" : "Chưa kết nối (chạy Server/drawing_server.py?)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            HStack {
                Text("\(viewModel.myName)")
                    .fontWeight(.semibold)
                    .foregroundColor(boardPalette[viewModel.myColorIndex])
                Spacer()
                Text("Nét: \(viewModel.board.strokes.count) · seq cuối: \(viewModel.board.strokes.last?.seq ?? 0) · checksum: \(viewModel.board.checksum)")
                    .font(.caption.monospacedDigit())
            }
            .font(.subheadline)
        }
    }
}

struct SharedCanvasView: View {
    let viewModel: SharedBoardViewModel

    // Nét đang kéo dở của CHÍNH MÌNH: bản nháp hiển thị tức thì trên máy này, chưa phải dữ liệu chung.
    // Điểm vẽ ra được gửi đi từng đoạn nhỏ (live) để máy kia thấy nét mọc dần; dữ liệu chung chỉ đổi khi server chốt nét.
    @State private var draft: [Point2] = []
    @State private var draftID: String?
    @State private var unsent: [Point2] = []     // các điểm chưa gửi, gom lại rồi gửi 1 lần để đỡ spam mạng
    @State private var lastFlush = Date.distantPast
    @State private var draftSubmitted = false    // đã nhấc tay, đang chờ server chốt nét

    var body: some View {
        let strokes = viewModel.board.strokes
        let liveStrokes = viewModel.board.liveStrokes
        let currentDraft = draft
        let myColor = boardPalette[viewModel.myColorIndex]

        // Bảng luôn VUÔNG (aspectRatio 1): nếu 2 máy có tỉ lệ bảng khác nhau thì toạ độ 0...1 bị kéo giãn khác nhau => tranh lệch.
        GeometryReader { geo in
            Canvas { context, size in
                func path(for points: [Point2]) -> Path {
                    var p = Path()
                    p.addLines(points.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) })
                    return p
                }
                let style = StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                for stroke in strokes { // đã sắp theo seq => thứ tự chồng lớp giống nhau ở mọi máy
                    context.stroke(path(for: stroke.points), with: .color(boardPalette[stroke.colorIndex % boardPalette.count]), style: style)
                }
                for live in liveStrokes where live.points.count > 1 { // nét của bạn đang vẽ dở, hiện realtime
                    context.stroke(path(for: live.points), with: .color(boardPalette[live.colorIndex % boardPalette.count]), style: style)
                }
                if currentDraft.count > 1 {
                    context.stroke(path(for: currentDraft), with: .color(myColor.opacity(0.5)), style: style)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard viewModel.isConnected else { return } // chưa có server thì không cho vẽ (nét sẽ không đi đâu)
                        if draftSubmitted { resetDraft() }
                        if draftID == nil { draftID = UUID().uuidString } // mã nối nét live với nét chốt
                        let point = Point2(x: min(max(value.location.x / geo.size.width, 0), 1),
                                           y: min(max(value.location.y / geo.size.height, 0), 1))
                        draft.append(point)
                        unsent.append(point)
                        if Date().timeIntervalSince(lastFlush) > 0.03 { flush() } // tối đa ~30 lần/giây
                    }
                    .onEnded { _ in
                        flush() // gửi nốt các điểm còn lại
                        guard let id = draftID else { return }
                        viewModel.dispatch(.strokeEnded(strokeId: id)) // xin server chốt nét, KHÔNG append vào strokes
                        if draft.count > 1 {
                            draftSubmitted = true // giữ bản nháp tới khi nét chốt từ server về để khỏi bị nháy mất nét
                        } else {
                            resetDraft()
                        }
                    }
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
        .onChange(of: viewModel.board.strokes.count) {
            // nét chốt CỦA MÌNH (khớp strokeId) đã về => bỏ bản nháp
            if draftSubmitted, let id = draftID, viewModel.board.strokes.contains(where: { $0.strokeId == id }) {
                resetDraft()
            }
        }
    }

    private func flush() {
        guard let id = draftID, !unsent.isEmpty else { return }
        viewModel.dispatch(.strokeProgress(strokeId: id, points: unsent))
        unsent = []
        lastFlush = Date()
    }

    private func resetDraft() {
        draft = []
        draftID = nil
        unsent = []
        draftSubmitted = false
    }
}
