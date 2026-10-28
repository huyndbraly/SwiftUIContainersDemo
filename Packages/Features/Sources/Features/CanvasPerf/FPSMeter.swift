import UIKit
import Observation

// ==========================================
// FPS overlay tự làm bằng CADisplayLink
// ==========================================
// CADisplayLink gọi tick() mỗi lần màn hình làm mới (60 hoặc 120 lần/giây).
// Nếu luồng chính bận vẽ quá lâu, tick() bị lỡ nhịp => đếm được ít lần hơn => FPS tụt.
// Đây là số đo gần đúng; số chuẩn thì đo bằng Instruments (template "Animation Hitches") trên máy thật.
@Observable
final class FPSMeter: NSObject {
    private(set) var value = 0

    @ObservationIgnored private var link: CADisplayLink?
    @ObservationIgnored private var frames = 0
    @ObservationIgnored private var lastReport: CFTimeInterval = 0

    func start() {
        guard link == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick)) // link giữ strong self
        link.add(to: .main, forMode: .common) // .common: vẫn chạy khi đang kéo/cuộn
        self.link = link
    }

    func stop() {
        link?.invalidate() // bắt buộc gọi để link thả self ra
        link = nil
    }

    @objc private func tick(_ link: CADisplayLink) {
        frames += 1
        if lastReport == 0 { lastReport = link.timestamp }
        let elapsed = link.timestamp - lastReport
        if elapsed >= 0.5 { // cập nhật số 2 lần/giây cho dễ đọc
            value = Int((Double(frames) / elapsed).rounded())
            frames = 0
            lastReport = link.timestamp
        }
    }
}
