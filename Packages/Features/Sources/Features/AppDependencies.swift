import SwiftUI
import Networking

// ==========================================
// DEPENDENCY INJECTION: "hộp đồ nghề" của app
// ==========================================
// View và ViewModel KHÔNG tự tạo URLSession hay Socket. Chúng nhận service từ bên ngoài:
//   - qua @Environment: app bỏ hộp đồ nghề vào môi trường 1 lần ở gốc, màn nào cần thì lấy ra
//   - qua init: View truyền service vào ViewModel(service:)
// => Đổi bản thật sang bản giả (Preview, test) chỉ cần đổi 1 chỗ, không sửa code màn hình.

nonisolated public struct AppDependencies: Sendable {
    public var lessonService: any LessonService
    // Mỗi lần vào phòng vẽ cần 1 socket MỚI => giữ "cách tạo socket" (closure) thay vì 1 socket dùng chung
    public var makeDrawingSocket: @Sendable @MainActor () -> any DrawingSocket

    public init(lessonService: any LessonService,
                makeDrawingSocket: @escaping @Sendable @MainActor () -> any DrawingSocket) {
        self.lessonService = lessonService
        self.makeDrawingSocket = makeDrawingSocket
    }

    // Bản thật: gọi mạng thật
    public static let live = AppDependencies(
        lessonService: LiveLessonService(),
        makeDrawingSocket: { WebSocketDrawingSocket() }
    )
}

extension EnvironmentValues {
    // Khoá môi trường mới. Mặc định là bản thật; Preview/test có thể .environment(\.dependencies, bảnGiả)
    @Entry public var dependencies: AppDependencies = .live
}
