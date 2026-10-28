import UIKit

// ==========================================
// NETWORKING: tải danh sách bài học + ảnh thumbnail
// ==========================================
// Protocol = "hợp đồng". ViewModel chỉ biết "có ai đó tải được bài học", KHÔNG biết bên trong dùng URLSession.
// => Lúc chạy thật dùng LiveLessonService; lúc Preview/test thay bằng bản giả, không cần mạng.

public struct Lesson: Decodable, Identifiable, Sendable {
    public let id: String
    public let author: String

    public init(id: String, author: String) {
        self.id = id
        self.author = author
    }
}

public protocol LessonService: Sendable {
    func fetchLessons() async throws -> [Lesson]
    func fetchThumbnail(id: String) async throws -> UIImage
}

// Bản thật: gọi picsum.photos bằng URLSession.
// Package này không gắn MainActor => các hàm async ở đây chạy ở LUỒNG NỀN, không chiếm main thread.
public struct LiveLessonService: LessonService {
    public init() {}

    public func fetchLessons() async throws -> [Lesson] {
        let url = URL(string: "https://picsum.photos/v2/list?limit=20")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([Lesson].self, from: data)
    }

    public func fetchThumbnail(id: String) async throws -> UIImage {
        print("⬇️ Ảnh #\(id) bắt đầu tải")
        do {
            // Giả lập mạng chậm 1-4 giây để kịp thoát màn giữa chừng. Task.sleep cũng tự dừng (ném lỗi) khi task bị huỷ.
            try await Task.sleep(for: .seconds(.random(in: 1...4)))
            let url = URL(string: "https://picsum.photos/id/\(id)/300/200")!
            let (data, _) = try await URLSession.shared.data(from: url)
            // Giải mã ảnh ngay ở luồng nền => lúc hiện lên màn hình không phải giải mã nữa => cuộn không giật
            guard let image = UIImage(data: data)?.preparingForDisplay() else {
                throw URLError(.cannotDecodeContentData)
            }
            print("✅ Ảnh #\(id) xong")
            return image
        } catch {
            if Task.isCancelled { print("🛑 Ảnh #\(id) bị huỷ") }
            throw error
        }
    }
}
