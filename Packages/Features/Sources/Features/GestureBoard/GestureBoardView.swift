import SwiftUI

// ==========================================
// GESTURE COMPOSABILITY: 1 ngón vẽ, 2 ngón zoom trên CÙNG 1 bảng
// ==========================================
// Vấn đề: ngón 1 chạm xuống TRƯỚC ngón 2 một chút => Drag đã bắt đầu vẽ rồi mới thấy 2 ngón => zoom để lại 1 nét thừa.
// Cách giải:
//   1. SimultaneousGesture(Drag, Magnify): cả 2 cùng nhận chạm, 1 chỗ duy nhất quyết định vẽ hay zoom.
//   2. Thấy ngón thứ 2 => bỏ nét đang vẽ dở, khoá vẽ tới khi nhấc HẾT tay.
//   3. Nét chỉ được lưu lúc nhấc tay (onEnded), trước đó chỉ là nét nháp.
// MagnificationGesture đã deprecated từ iOS 17 => dùng MagnifyGesture.

public struct GestureBoardView: View {
    @State private var strokes: [[CGPoint]] = [] // các nét đã lưu
    @State private var current: [CGPoint] = []   // nét đang vẽ dở (nháp)
    @State private var isZooming = false         // lượt chạm này là zoom => không vẽ

    @State private var scale: CGFloat = 1     // độ zoom đang hiển thị
    @State private var lastScale: CGFloat = 1 // độ zoom đã chốt sau lần pinch trước

    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            Canvas { context, _ in
                for points in strokes + [current] where points.count > 1 {
                    var path = Path()
                    path.addLines(points)
                    context.stroke(path, with: .color(.blue), lineWidth: 3)
                }
            }
            .background(Color(UIColor.systemGray6))
            .contentShape(Rectangle())
            // Gắn gesture TRƯỚC scaleEffect => toạ độ chạm đã là toạ độ của tranh (SwiftUI tự chia cho scale),
            // vẽ lúc đang zoom vẫn ra đúng dưới ngón tay
            .gesture(drawAndZoom)
            .scaleEffect(scale)
            .clipped()

            Text("Nét: \(strokes.count) · Zoom: \(String(format: "%.1f", scale))x")
            Button("Xoá bảng") { strokes = []; scale = 1; lastScale = 1 }
        }
        .padding()
        .navigationTitle("1 ngón vẽ · 2 ngón zoom")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var drawAndZoom: some Gesture {
        SimultaneousGesture(DragGesture(minimumDistance: 0), MagnifyGesture())
            .onChanged { value in
                // value.second có giá trị => đang có 2 ngón => ZOOM
                if let zoom = value.second {
                    isZooming = true
                    current = [] // bỏ mấy điểm ngón 1 lỡ vẽ trước khi ngón 2 chạm xuống
                    scale = lastScale * zoom.magnification
                    return
                }
                // 1 ngón => VẼ (trừ khi lượt này đã là zoom, vd nhấc 1 ngón ra trước)
                if !isZooming, let drag = value.first {
                    current.append(drag.location)
                }
            }
            .onEnded { _ in // nhấc HẾT tay
                if !isZooming, current.count > 1 { strokes.append(current) }
                current = []
                isZooming = false
                lastScale = scale
            }
    }
}
