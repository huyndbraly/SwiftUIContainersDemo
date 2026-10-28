import SwiftUI
import UIKit

// ==========================================
// UIBezierPath: làm mượt nét vẽ (Smoothing)
// ==========================================
// Màn hình chỉ báo vị trí ngón tay ~60-120 lần/giây => ta nhận được các ĐIỂM RỜI RẠC.
// Vẽ nhanh => 2 điểm liền nhau cách xa => nối thẳng sẽ ra các góc gãy.
// 2 bảng dưới dùng CHUNG 1 mảng điểm, chỉ khác cách nối:
//   - Bảng trên: addLine (nối thẳng)          => gãy khúc
//   - Bảng dưới: addQuadCurve (quadratic midpoint) => cong mượt

public struct SmoothStrokeView: View {
    @State private var strokes: [[CGPoint]] = []
    @State private var current: [CGPoint] = []

    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            board(title: "Nối thẳng (addLine)", smooth: false)
            board(title: "Làm mượt Bezier (addQuadCurve)", smooth: true)
            Button("Xoá bảng", role: .destructive) { strokes = [] }
                .buttonStyle(.bordered)
        }
        .padding()
        .navigationTitle("Làm mượt nét vẽ")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func board(title: String, smooth: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline.bold())
            Canvas { context, _ in
                for points in strokes + [current] where points.count > 1 {
                    let bezier = smooth ? StrokePath.smooth(points) : StrokePath.straight(points)
                    // UIBezierPath (UIKit) -> Path (SwiftUI) để vẽ trên Canvas
                    context.stroke(Path(bezier.cgPath), with: .color(.blue),
                                   style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    // Chấm xám = điểm chạm thật mà màn hình báo về
                    for p in points {
                        context.fill(Path(ellipseIn: CGRect(x: p.x - 2, y: p.y - 2, width: 4, height: 4)), with: .color(.gray))
                    }
                }
            }
            .background(Color(UIColor.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { current.append($0.location) }
                    .onEnded { _ in
                        if current.count > 1 { strokes.append(current) }
                        current = []
                    }
            )
        }
    }
}

// Dựng UIBezierPath từ mảng điểm theo 2 cách
enum StrokePath {
    // Cách 1: nối thẳng từng cặp điểm
    static func straight(_ points: [CGPoint]) -> UIBezierPath {
        let path = UIBezierPath()
        path.move(to: points[0])
        for p in points.dropFirst() {
            path.addLine(to: p)
        }
        return path
    }

    // Cách 2: quadratic midpoint
    // Đường cong đi qua TRUNG ĐIỂM của 2 điểm liền nhau, còn điểm chạm thật làm ĐIỂM KÉO (control point).
    // Tại mỗi trung điểm, 2 đoạn cong nối nhau có cùng hướng => không còn góc gãy.
    //
    //     p1 (điểm kéo)
    //    /  \
    //  m0 ⌒ m1      m0 = trung điểm(p0, p1), m1 = trung điểm(p1, p2)
    static func smooth(_ points: [CGPoint]) -> UIBezierPath {
        let path = UIBezierPath()
        path.move(to: points[0])
        guard points.count > 2 else {
            path.addLine(to: points[1])
            return path
        }
        path.addLine(to: mid(points[0], points[1])) // đoạn thẳng ngắn từ điểm đầu tới trung điểm đầu tiên
        for i in 1..<points.count - 1 {
            path.addQuadCurve(to: mid(points[i], points[i + 1]), controlPoint: points[i])
        }
        path.addLine(to: points[points.count - 1]) // đoạn thẳng ngắn tới điểm cuối
        return path
    }

    private static func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }
}
