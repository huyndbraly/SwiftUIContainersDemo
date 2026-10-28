import SwiftUI
import Networking

// ==========================================
// MVVM: View của màn danh sách bài học
// ==========================================
// View KHÔNG gọi URLSession. Nó chỉ đọc dữ liệu từ ViewModel và gọi viewModel.load().

public struct LessonListView: View {
    // @State giữ ViewModel sống suốt vòng đời màn hình (giống @State private var board = DrawingBoard())
    @State private var viewModel: LessonListViewModel

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    // Dependency Injection qua init: ai mở màn này thì đưa service vào
    public init(service: any LessonService) {
        _viewModel = State(initialValue: LessonListViewModel(service: service))
    }

    public var body: some View {
        ScrollView {
            Text(viewModel.status)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.top, 8)

            // LazyVGrid: chỉ dựng ô sắp hiện trên màn => cuộn mượt
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(viewModel.lessons) { lesson in
                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.systemGray5))
                            .frame(height: 110)
                            .overlay {
                                if let image = viewModel.thumbnails[lesson.id] {
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
        .task {
            print("🔄 [Lifecycle] Bài học: .task bắt đầu")
            await viewModel.load()
        }
        .onAppear { print("🔄 [Lifecycle] Bài học: onAppear") }
        .onDisappear { print("🔄 [Lifecycle] Bài học: onDisappear") }
    }
}

// Bản GIẢ cho Preview: không cần mạng, trả dữ liệu ngay => thấy lợi ích của việc dùng protocol
private struct PreviewLessonService: LessonService {
    func fetchLessons() async throws -> [Lesson] {
        (0..<6).map { Lesson(id: "\($0)", author: "Tác giả \($0)") }
    }

    func fetchThumbnail(id: String) async throws -> UIImage {
        UIImage(systemName: "photo.artframe")!
    }
}

#Preview {
    NavigationStack {
        LessonListView(service: PreviewLessonService())
    }
}
