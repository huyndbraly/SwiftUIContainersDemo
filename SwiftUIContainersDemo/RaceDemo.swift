import Foundation
import DrawingEngine

// ==========================================
// DEMO DATA RACE: 2 nơi cùng ghi vào 1 bộ đệm nét
// ==========================================
// Nguồn 1 "socket": luồng nền ghi 2000 nét
// Nguồn 2 "main":   luồng chính ghi 2000 nét, CÙNG LÚC với nguồn 1
//   xcrun simctl openurl <UDID> "artmate://race?mode=class" => bộ đệm là class thường  => data race
//   xcrun simctl openurl <UDID> "artmate://race?mode=actor" => actor StrokeBuffer thật  => an toàn
// Chạy bản build bật Thread Sanitizer để TSan in báo cáo "WARNING: ThreadSanitizer: data race".
// Lưu ý: app mặc định mọi thứ là @MainActor => phải ghi `nonisolated` / `@concurrent` thì code mới chạy ở luồng nền.

// Y hệt StrokeBuffer nhưng là class thay vì actor.
// @unchecked Sendable = tự nhận "tôi lo an toàn rồi" => compiler thôi kiểm tra => race lọt tới lúc chạy.
// Bỏ @unchecked: chuyền qua Task.detached thì build báo lỗi, nhưng kiểu Task { await hàm @concurrent } ở dưới
// thì Swift 6.2.4 vẫn build qua => compiler không bắt hết, phải có Thread Sanitizer.
nonisolated final class UnsafeStrokeBuffer: @unchecked Sendable {
    private var state = BoardState()

    func apply(_ event: BoardEvent) -> BoardState {
        state.apply(event)
        return state
    }
}

enum RaceDemo {
    nonisolated static let perSource = 2000
    nonisolated(unsafe) static var startTime = Date() // chỉ để in mốc thời gian
    nonisolated static func ms() -> Int { Int(Date().timeIntervalSince(startTime) * 1000) }

    // Mỗi nét 1 strokeId khác nhau => mỗi lần apply thêm đúng 1 phần tử vào liveStrokes
    nonisolated static func event(_ source: String, _ i: Int) -> BoardEvent {
        .liveChunk(strokeId: "\(source)-\(i)", author: source, colorIndex: 0, points: [Point2(x: 0, y: 0)])
    }

    // Nguồn "socket": @concurrent => chạy ở luồng nền, giống receiveAll trong DrawingSocket
    @concurrent nonisolated static func writeFromSocket(_ buffer: UnsafeStrokeBuffer) async {
        print("   socket (luồng chính? \(pthread_main_np() != 0)) bắt đầu ở ms \(ms())")
        for i in 0..<perSource { _ = buffer.apply(event("socket", i)) } // ghi thẳng, không xếp hàng
        print("   socket xong ở ms \(ms())")
    }

    @concurrent nonisolated static func writeFromSocket(_ buffer: StrokeBuffer) async {
        print("   socket (luồng chính? \(pthread_main_np() != 0)) bắt đầu ở ms \(ms())")
        for i in 0..<perSource { _ = await buffer.apply(event("socket", i)) } // await => xếp hàng vào actor
        print("   socket xong ở ms \(ms())")
    }

    // Chạy trên MainActor (luồng chính)
    static func run(mode: String) async {
        print("🏁 [Race] mode=\(mode): 2 nguồn cùng ghi, mỗi nguồn \(perSource) nét")
        startTime = Date()
        let total: Int
        if mode == "actor" {
            let buffer = StrokeBuffer()
            let socket = Task { await writeFromSocket(buffer) }
            await Task.yield() // nhường luồng chính 1 nhịp để Task trên kịp chuyển sang luồng nền
            print("   main (luồng chính? \(pthread_main_np() != 0)) bắt đầu ở ms \(ms())")
            for i in 0..<perSource { _ = await buffer.apply(event("main", i)) }
            print("   main xong ở ms \(ms())")
            await socket.value
            total = await buffer.apply(.cancel(strokeId: "-")).liveStrokes.count // đọc kết quả qua actor
        } else {
            let buffer = UnsafeStrokeBuffer()
            let socket = Task { await writeFromSocket(buffer) }
            await Task.yield()
            print("   main (luồng chính? \(pthread_main_np() != 0)) bắt đầu ở ms \(ms())")
            for i in 0..<perSource { _ = buffer.apply(event("main", i)) } // ghi thẳng, không chờ ai
            print("   main xong ở ms \(ms())")
            await socket.value
            total = buffer.apply(.cancel(strokeId: "-")).liveStrokes.count
        }
        let expected = perSource * 2
        if total == expected {
            print("📊 [Race] mode=\(mode): kỳ vọng \(expected) nét, thực tế \(total) => đủ")
        } else {
            print("📊 [Race] mode=\(mode): kỳ vọng \(expected) nét, thực tế \(total) => MẤT \(expected - total) nét")
        }
    }
}
