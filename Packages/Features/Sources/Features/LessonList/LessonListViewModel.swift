import UIKit
import Observation
import Networking

// ==========================================
// MVVM: ViewModel của màn danh sách bài học
// ==========================================
// View chỉ HIỂN THỊ (lessons, thumbnails, status) và gọi load().
// ViewModel giữ trạng thái + logic tải; việc gọi mạng giao cho LessonService (được truyền vào qua init).

@Observable
public final class LessonListViewModel {
    public private(set) var lessons: [Lesson] = []
    public private(set) var thumbnails: [String: UIImage] = [:] // id bài học -> ảnh đã tải xong
    public private(set) var status = "Đang tải danh sách..."

    // Dependency Injection qua init: ViewModel không biết đây là bản thật hay bản giả
    private let service: any LessonService

    public init(service: any LessonService) {
        self.service = service
    }

    public func load() async {
        print("🚀 Bắt đầu tải danh sách bài học")
        var doneCount = 0
        do {
            // 1. Tải JSON. await = "chờ ở đây", trong lúc chờ main thread vẫn RẢNH để vẽ và cuộn.
            lessons = try await service.fetchLessons()
            status = "Đang tải ảnh 0/\(lessons.count)..."

            // 2. TaskGroup: tạo 20 task con chạy SONG SONG.
            //    Task cha bị huỷ (rời màn) => mọi task con trong group cũng bị huỷ theo.
            let service = service
            try await withThrowingTaskGroup(of: (String, UIImage).self) { group in
                for lesson in lessons {
                    group.addTask { (lesson.id, try await service.fetchThumbnail(id: lesson.id)) }
                }
                // Nhận kết quả theo thứ tự task nào XONG TRƯỚC (không theo thứ tự thêm vào)
                for try await (id, image) in group {
                    thumbnails[id] = image
                    doneCount += 1
                    status = "Đang tải ảnh \(doneCount)/\(lessons.count)..."
                }
            }
            status = "Tải xong \(doneCount) ảnh"
            print("✅ Tải xong toàn bộ \(doneCount) ảnh")
        } catch {
            // Lỗi do bị huỷ (rời màn) khác với lỗi mạng thật => kiểm tra Task.isCancelled để phân biệt
            if Task.isCancelled {
                print("🛑 Rời màn => task bị huỷ, đã tải \(doneCount)/\(lessons.count) ảnh")
            } else {
                status = "Lỗi: \(error.localizedDescription)"
                print("❌ Lỗi tải: \(error)")
            }
        }
    }
}
