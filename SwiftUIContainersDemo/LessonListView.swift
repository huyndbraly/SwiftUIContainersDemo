import SwiftUI

// ==========================================
// SWIFT CONCURRENCY CƠ BẢN: async/await, Task, TaskGroup, huỷ Task
// ==========================================
// Màn này tải 1 file JSON (danh sách 20 bài học), rồi tải 20 ảnh thumbnail SONG SONG bằng TaskGroup.
// .task { } tự huỷ khi rời màn => các ảnh đang tải dở bị huỷ theo, log 🛑 xác nhận.
// Test: for i in $(seq 1 3); do xcrun simctl openurl <UDID> artmate://lessons; sleep 1.5; xcrun simctl openurl <UDID> artmate://room; sleep 1; done

struct LessonListRoute: Hashable {} // "vé vào cửa" cho NavigationPath, giống RoomListRoute

// 1 phần tử trong JSON của picsum.photos: {"id":"0","author":"Alejandro Escamilla", ...}
// Decodable: JSONDecoder tự đổi JSON thành struct, chỉ lấy các field khai báo ở đây.
// nonisolated: không gắn với main thread => giải mã JSON được ở luồng nền.
nonisolated struct Lesson: Decodable, Identifiable {
    let id: String
    let author: String
}

// --- CÁC HÀM GỌI MẠNG ---
// Cách CŨ (completion handler):
//   URLSession.shared.dataTask(with: url) { data, response, error in ... }.resume()
//   => kết quả trả về trong closure, gọi nối tiếp thì lồng nhiều tầng, phải nhớ [weak self], không tự huỷ theo màn hình.
// Cách MỚI (async/await):
//   let (data, response) = try await URLSession.shared.data(from: url)
//   => đọc từ trên xuống như code thường, lỗi đi qua try/catch, task bị huỷ thì URLSession tự huỷ request.
enum LessonAPI {
    // @concurrent: hàm chạy ở LUỒNG NỀN, không chiếm main thread => giao diện không bị treo trong lúc tải/giải mã.
    @concurrent
    nonisolated static func fetchLessons() async throws -> [Lesson] {
        let url = URL(string: "https://picsum.photos/v2/list?limit=20")!
        let (data, _) = try await URLSession.shared.data(from: url) // await: chờ mạng, luồng không bị chặn
        return try JSONDecoder().decode([Lesson].self, from: data)
    }

    @concurrent
    nonisolated static func fetchThumbnail(id: String) async throws -> (String, UIImage) {
        print("⬇️ Ảnh #\(id) bắt đầu tải")
        do {
            // Giả lập mạng chậm 1-4 giây để kịp thoát màn giữa chừng. Task.sleep cũng tự dừng (ném lỗi) khi task bị huỷ.
            try await Task.sleep(for: .seconds(.random(in: 1...4)))
            let url = URL(string: "https://picsum.photos/id/\(id)/300/200")!
            let (data, _) = try await URLSession.shared.data(from: url)
            // Giải mã ảnh ngay ở luồng nền => lúc hiện lên màn hình main thread không phải giải mã nữa => cuộn không giật
            guard let image = UIImage(data: data)?.preparingForDisplay() else {
                throw URLError(.cannotDecodeContentData)
            }
            print("✅ Ảnh #\(id) xong")
            return (id, image)
        } catch {
            if Task.isCancelled { print("🛑 Ảnh #\(id) bị huỷ") }
            throw error // ném tiếp lên TaskGroup
        }
    }
}

// --- MÀN DANH SÁCH BÀI HỌC ---
struct LessonListView: View {
    @State private var lessons: [Lesson] = []
    @State private var thumbnails: [String: UIImage] = [:] // id bài học -> ảnh đã tải xong
    @State private var status = "Đang tải danh sách..."

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            Text(status)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.top, 8)

            // LazyVGrid: chỉ dựng ô sắp hiện trên màn => cuộn mượt
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(lessons) { lesson in
                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.systemGray5))
                            .frame(height: 110)
                            .overlay {
                                if let image = thumbnails[lesson.id] {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    ProgressView() // chưa tải xong thì hiện vòng xoay
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        Text("Bài #\(lesson.id) · \(lesson.author)")
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal)
        }
        .navigationTitle("Bài học (async)")
        .navigationBarTitleDisplayMode(.inline)
        // .task: chạy hàm async khi màn hiện ra, và TỰ HUỶ khi màn biến mất.
        // => không cần tự tạo Task {} rồi nhớ gọi cancel() trong onDisappear.
        .task { await loadAll() }
    }

    private func loadAll() async {
        print("🚀 Bắt đầu tải danh sách bài học")
        var doneCount = 0
        do {
            // 1. Tải JSON. await = "chờ ở đây", trong lúc chờ main thread vẫn RẢNH để vẽ và cuộn.
            lessons = try await LessonAPI.fetchLessons()
            status = "Đang tải ảnh 0/\(lessons.count)..."

            // 2. TaskGroup: tạo 20 task con chạy SONG SONG.
            //    Task cha bị huỷ (rời màn) => mọi task con trong group cũng bị huỷ theo.
            try await withThrowingTaskGroup(of: (String, UIImage).self) { group in
                for lesson in lessons {
                    group.addTask { try await LessonAPI.fetchThumbnail(id: lesson.id) }
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

#Preview {
    NavigationStack {
        ContentView()
    }
}
