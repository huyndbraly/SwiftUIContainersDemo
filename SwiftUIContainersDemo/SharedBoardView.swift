import SwiftUI

// Màn hình vẽ chung nhiều máy. Xem SharedDrawingStore.swift để hiểu luồng Action → Store → View.

struct SharedBoardRoute: Hashable {} // "vé vào cửa" cho NavigationPath, giống LiveDrawingRoute

// Bảng màu dùng chung: server chỉ gửi chỉ số, mỗi máy tra ra màu giống nhau
private let boardPalette: [Color] = [.red, .orange, .green, .blue, .purple, .pink]

struct SharedBoardView: View {
    @State private var store = SharedDrawingStore()

    // Trạng thái vòng đời app (active / inactive / background), SwiftUI tự cập nhật. Chỉ đọc, không gán được.
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let _ = Self._printChanges()
        VStack(spacing: 12) {
            SharedStatusView(store: store)
            SharedCanvasView(store: store)
            Button("Xoá bảng (cả 2 máy)", role: .destructive) {
                store.dispatch(.clear) // chỉ gửi Action, không tự xoá
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .navigationTitle("Vẽ chung 2 máy")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store.connect() }       // vào phòng => kết nối
        .onDisappear { store.disconnect() } // rời phòng (bấm Back) => ngắt
        // Bấm Home KHÔNG gọi onDisappear (màn vẫn còn trong NavigationStack, chỉ là app xuống nền)
        // => phải tự nghe scenePhase để ngắt/nối lại socket.
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background: // bấm Home / chuyển app khác => ngắt để đỡ hao pin, đỡ tốn mạng
                print("🌙 [Phòng vẽ] App xuống nền => ngắt socket")
                store.disconnect()
            case .active: // mở lại app => nối lại. Màn vẫn là phòng vẽ vì NavigationStack giữ nguyên path
                print("☀️ [Phòng vẽ] App mở lại => kết nối lại socket")
                store.connect()
            case .inactive: // có cuộc gọi đến, kéo Control Center... thường chỉ thoáng qua => giữ kết nối
                print("🟡 [Phòng vẽ] App tạm thời không tương tác (inactive) => giữ kết nối")
            @unknown default:
                break
            }
        }
    }
}

// Thanh trạng thái: so sánh "Checksum" giữa 2 simulator, giống nhau nghĩa là tranh giống hệt
struct SharedStatusView: View {
    let store: SharedDrawingStore

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Circle()
                    .fill(store.isConnected ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                Text(store.isConnected ? "Đã kết nối server" : "Chưa kết nối (chạy Server/drawing_server.py?)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            HStack {
                Text("\(store.myName)")
                    .fontWeight(.semibold)
                    .foregroundColor(boardPalette[store.myColorIndex])
                Spacer()
                Text("Nét: \(store.strokes.count) · seq cuối: \(store.strokes.last?.seq ?? 0) · checksum: \(store.checksum)")
                    .font(.caption.monospacedDigit())
            }
            .font(.subheadline)
        }
    }
}

struct SharedCanvasView: View {
    let store: SharedDrawingStore

    // Nét đang kéo dở của CHÍNH MÌNH: bản nháp hiển thị tức thì trên máy này, chưa phải dữ liệu chung.
    // Điểm vẽ ra được gửi đi từng đoạn nhỏ (live) để máy kia thấy nét mọc dần; dữ liệu chung chỉ đổi khi server chốt nét.
    @State private var draft: [Point2] = []
    @State private var draftID: String?
    @State private var unsent: [Point2] = []     // các điểm chưa gửi, gom lại rồi gửi 1 lần để đỡ spam mạng
    @State private var lastFlush = Date.distantPast
    @State private var draftSubmitted = false    // đã nhấc tay, đang chờ server chốt nét

    var body: some View {
        let _ = Self._printChanges()
        let strokes = store.strokes
        let liveStrokes = store.liveStrokes
        let currentDraft = draft
        let myColor = boardPalette[store.myColorIndex]

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
                        guard store.isConnected else { return } // chưa có server thì không cho vẽ (nét sẽ không đi đâu)
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
                        store.dispatch(.strokeEnded(strokeId: id)) // xin server chốt nét, KHÔNG append vào strokes
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
        .onChange(of: store.strokes.count) {
            // nét chốt CỦA MÌNH (khớp strokeId) đã về => bỏ bản nháp
            if draftSubmitted, let id = draftID, store.strokes.contains(where: { $0.strokeId == id }) {
                resetDraft()
            }
        }
    }

    private func flush() {
        guard let id = draftID, !unsent.isEmpty else { return }
        store.dispatch(.strokeProgress(strokeId: id, points: unsent))
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

#Preview {
    NavigationStack {
        SharedBoardView()
    }
}


//File này là giao diện, gồm 3 view. Nguyên tắc: các view chỉ đọc dữ liệu từ kho và gửi yêu cầu, không tự sửa dữ liệu chung.
//
//Hai thứ khai báo ở đầu:
//- SharedBoardRoute (dòng 5): "vé vào cửa" để điều hướng tới màn này.
//- boardPalette (dòng 8): bảng 6 màu. Server chỉ gửi số 0 đến 5, mỗi máy tự tra ra màu giống nhau.
//
//View 1: SharedBoardView, màn hình cha (dòng 10 đến 29)
//
//- @State private var store = SharedDrawingStore(): tạo một kho duy nhất cho cả màn hình.
//- Xếp dọc 3 thứ: dòng trạng thái, bảng vẽ, nút xoá.
//- Nút xoá chỉ gọi store.dispatch(.clear), không tự xoá nét nào.
//- .onAppear { store.connect() }: vào màn hình thì nối server.
//- .onDisappear { store.disconnect() }: rời màn hình thì ngắt.
//- View cha đưa store xuống hai view con, không đọc dữ liệu nên ít phải vẽ lại.
//
//View 2: SharedStatusView, dòng trạng thái (dòng 32 đến 56)
//
//Chỉ đọc để hiển thị:
//- Chấm tròn xanh là đã nối server, đỏ là chưa (isConnected).
//- Tên máy, tô theo màu của máy (myName, myColorIndex).
//- Nét: N · seq cuối: M · checksum: K, đọc từ strokes và checksum.
//
//Đây là chỗ bạn so hai simulator: checksum giống nhau là hai tranh giống nhau.
//
//View 3: SharedCanvasView, bảng vẽ (dòng 58 đến 143)
//
//Đây là view quan trọng nhất.
//
//5 biến @State (dòng 63 đến 67): bản nháp riêng của máy mình, không phải dữ liệu chung.
//
//┌────────────────┬─────────────────────────────────────────────────────────────┐
//│      Biến      │                           Ý nghĩa                           │
//├────────────────┼─────────────────────────────────────────────────────────────┤
//│ draft          │ Các điểm của nét mình đang kéo, để hiện ngay không chờ mạng │
//├────────────────┼─────────────────────────────────────────────────────────────┤
//│ draftID        │ Mã strokeId của nét đang kéo                                │
//├────────────────┼─────────────────────────────────────────────────────────────┤
//│ unsent         │ Hàng đợi các điểm chưa gửi                                  │
//├────────────────┼─────────────────────────────────────────────────────────────┤
//│ lastFlush      │ Lần gửi gần nhất lúc nào                                    │
//├────────────────┼─────────────────────────────────────────────────────────────┤
//│ draftSubmitted │ Đã nhấc tay, đang chờ server chốt                           │
//└────────────────┴─────────────────────────────────────────────────────────────┘
//
//Phần vẽ (dòng 78 đến 94): Canvas vẽ 3 lớp, lớp sau nằm trên lớp trước:
//1. Các nét đã chốt (strokes), đã sắp theo seq nên hai máy chồng nét giống nhau.
//2. Các nét đang vẽ dở của bạn (liveStrokes): chính là chỗ bạn thấy nét mọc dần.
//3. Bản nháp của mình (draft), tô nhạt 50%.
//
//Hàm path(for:) (dòng 79) đổi toạ độ 0 đến 1 thành pixel thật bằng cách nhân với kích thước Canvas.
//
//Khi ngón tay kéo, .onChanged (dòng 97), theo thứ tự:
//1. Chưa nối server thì không cho vẽ (dòng 98).
//2. Nếu nét trước còn bản nháp chờ chốt thì xoá bản nháp đó (dòng 99).
//3. Chưa có mã nét thì sinh một mã mới (dòng 100).
//4. Đổi vị trí ngón tay thành toạ độ 0 đến 1 và thêm vào draft và unsent (dòng 101 đến 104).
//5. Nếu đã quá 0,03 giây từ lần gửi trước thì gọi flush() để gửi (dòng 105).
//
//Khi nhấc tay, .onEnded (dòng 107):
//1. flush() gửi nốt các điểm còn lại.
//2. Gửi strokeEnded để xin server chốt nét.
//3. Nếu nét có hơn 1 điểm: đặt draftSubmitted = true và giữ bản nháp trên màn hình đến khi nét chốt về (tránh bị nháy mất nét). Nếu chỉ là một cú chạm thì xoá bản nháp luôn.
//
//Hai hàm phụ:
//- flush() (dòng 130): gửi các điểm trong unsent qua strokeProgress, rồi làm trống hàng đợi.
//- resetDraft() (dòng 137): xoá sạch bản nháp, chuẩn bị cho nét mới.
//
//.onChange(of: store.strokes.count) (dòng 122): mỗi khi có nét chốt mới về, nếu đó đúng là nét của mình (khớp strokeId) thì xoá bản nháp, vì giờ đã có nét chốt thật vẽ thay.
//
//Vì sao .aspectRatio(1) (dòng 119): bảng luôn hình vuông ở mọi máy. Nếu bảng ở máy này dẹt và máy kia vuông thì toạ độ 0 đến 1 bị kéo giãn khác nhau, tranh sẽ lệch.
