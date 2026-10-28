import SwiftUI

// ==========================================
// CANVAS API: vẽ 1.000+ nét mà vẫn mượt
// ==========================================
// View thường: mỗi nét là 1 View => 1.000 nét = 1.000 View. Mỗi lần ngón tay nhích, SwiftUI phải so sánh lại cả 1.000 View.
// Canvas: cả bảng chỉ là 1 View. Bên trong ta tự ra lệnh vẽ lên GraphicsContext, không tạo View nào.
//
// 3 mẹo để giữ ≥ 55 FPS:
//   1. Gom nét CÙNG MÀU vào 1 Path lớn => 1.000 nét chỉ còn ~6 lệnh stroke (6 màu), thay vì 1.000 lệnh.
//   2. Tách 2 lớp: lớp nét CŨ (to, ít đổi) và lớp nét ĐANG VẼ (nhỏ, đổi liên tục).
//   3. Lớp nét cũ dùng .equatable(): đang vẽ thì lớp này không vẽ lại, chỉ vẽ lại khi có nét mới được lưu.

private let palette: [Color] = [.red, .orange, .green, .blue, .purple, .pink] // giả lập 6 người vẽ chung
private let lineStyle = StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)

public struct CanvasPerfView: View {
    @State private var strokes: [[CGPoint]] = []    // dữ liệu gốc (dùng cho chế độ View thường)
    @State private var batches: [Int: Path] = [:]   // mẹo 1: màu -> 1 Path gộp mọi nét màu đó
    @State private var version = 0                  // tăng mỗi khi lớp nét cũ đổi
    @State private var current: [CGPoint] = []     // nét đang vẽ
    @State private var boardSize: CGSize = .zero
    @State private var useViews = false             // bật để so sánh với cách dùng View thường
    @State private var fps = FPSMeter()

    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            Toggle("So sánh: dùng View thường", isOn: $useViews)

            ZStack {
                if useViews {
                    // CÁCH CHẬM: 1 nét = 1 View
                    ForEach(strokes.indices, id: \.self) { i in
                        Path { $0.addLines(strokes[i]) }
                            .stroke(palette[i % palette.count], style: lineStyle)
                    }
                } else {
                    // CÁCH NHANH: 1 Canvas, mọi nét cũ vẽ trong ~6 lệnh
                    FinishedLayer(batches: batches, version: version)
                        .equatable() // mẹo 3
                }
                // Lớp nét đang vẽ: Canvas nhỏ, chỉ có 1 nét => vẽ lại mỗi khung hình cũng nhẹ
                Canvas { context, _ in
                    var path = Path()
                    path.addLines(current)
                    context.stroke(path, with: .color(.black), style: lineStyle)
                }
            }
            .background(Color(UIColor.systemGray6))
            .clipped()
            .contentShape(Rectangle())
            .onGeometryChange(for: CGSize.self) { $0.size } action: { boardSize = $0 }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { current.append($0.location) }
                    .onEnded { _ in
                        if current.count > 1 { add([current]) }
                        current = []
                    }
            )

            Text("FPS: \(fps.value) · Nét: \(strokes.count)")
                .font(.headline.monospacedDigit())
                .foregroundColor(fps.value >= 55 ? .green : .red)

            HStack {
                Button("+1.000 nét") { add(randomStrokes(1000)) }
                Button("Xoá bảng", role: .destructive) {
                    strokes = []
                    batches = [:]
                    version += 1
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .navigationTitle("Canvas 1.000 nét")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { fps.start() }
        .onDisappear { fps.stop() } // không stop => CADisplayLink giữ FPSMeter sống mãi (retain cycle)
    }

    // Thêm nét: lưu dữ liệu gốc + gộp ngay vào Path của màu tương ứng (gộp 1 lần lúc thêm, không gộp lại mỗi khung hình)
    private func add(_ newStrokes: [[CGPoint]]) {
        for points in newStrokes {
            let color = strokes.count % palette.count
            batches[color, default: Path()].addLines(points)
            strokes.append(points)
        }
        version += 1
    }

    // Sinh nét ngẫu nhiên: mỗi nét ~20 điểm, đi lượn như tay người vẽ
    private func randomStrokes(_ count: Int) -> [[CGPoint]] {
        let w = max(boardSize.width, 1), h = max(boardSize.height, 1)
        return (0..<count).map { _ in
            var p = CGPoint(x: .random(in: 0...w), y: .random(in: 0...h))
            var angle = Double.random(in: 0...(2 * .pi))
            return (0..<20).map { _ in
                angle += .random(in: -0.5...0.5)
                p.x += cos(angle) * 6
                p.y += sin(angle) * 6
                return p
            }
        }
    }
}

// Lớp nét cũ. Equatable chỉ so `version` => SwiftUI bỏ qua việc vẽ lại lớp này khi chỉ có `current` đổi.
struct FinishedLayer: View, Equatable {
    let batches: [Int: Path]
    let version: Int

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.version == rhs.version }

    var body: some View {
        Canvas { context, _ in
            for (color, path) in batches {
                context.stroke(path, with: .color(palette[color]), style: lineStyle)
            }
        }
    }
}
