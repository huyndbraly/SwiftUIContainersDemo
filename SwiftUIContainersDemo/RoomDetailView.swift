import SwiftUI

struct RoomDetailView: View {
    let roomId: String // chỉ là mã phòng ("123"), phần hiển thị "Phòng số ..." do view tự ghép
    @Binding var isConnected: Bool

    // Giả lập phòng có rất nhiều bức tranh (1...60)
    let artworkIds = Array(1...60)

    let columns = [GridItem(.adaptive(minimum: 80), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "paintbrush.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.orange)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Phòng số \(roomId)")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(isConnected ? "Trạng thái phòng: Đang vẽ mượt mà" : "Mất kết nối mạng...")
                            .font(.caption)
                            .foregroundColor(isConnected ? .green : .red)
                    }
                }

                Text("Tranh trong phòng (\(artworkIds.count))")
                    .font(.headline)

                // CÁCH ĐI TAY: mỗi ô là 1 NavigationLink(value:)
                // Bấm vào = SwiftUI tự append ArtworkRoute vào path => tra .navigationDestination(for: ArtworkRoute.self) ở ContentView => push ArtworkDetailView
                // Người dùng phải bấm từng bước: Sảnh -> Phòng -> Tranh. Còn deep link thì gán cả path 1 lần (xem .onOpenURL ở ContentView).
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(artworkIds, id: \.self) { artworkId in
                        NavigationLink(value: ArtworkRoute(roomId: roomId, artworkId: artworkId)) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(UIColor.systemGray6))
                                .frame(height: 80)
                                .overlay(
                                    Text("#\(artworkId)")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                )
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Phòng Vẽ Trực Tuyến")
        .navigationBarTitleDisplayMode(.inline)
        // Lưu ý: KHÔNG đặt .navigationDestination bên trong LazyVGrid/ForEach (view lazy có thể chưa được tạo => SwiftUI không tìm thấy quy tắc).
        // Quy tắc cho ArtworkRoute được khai báo ở root (ContentView) để deep link push thẳng tranh cũng tìm thấy.
    }
}

#Preview {
    // Bọc trong NavigationStack để thấy được navigationTitle và bấm thử vào tranh
    NavigationStack {
        RoomDetailView(roomId: "123", isConnected: .constant(true))
            .navigationDestination(for: ArtworkRoute.self) { route in
                ArtworkDetailView(route: route)
            }
    }
}

//"Đăng ký URL scheme artmate" nghĩa là báo cho iOS biết: mọi đường link bắt đầu bằng artmate:// thì mở bằng app của mình.

// giả lập việc mở một đường link trên simulator, ngay từ terminal. Kết quả giống như người dùng bấm vào link artmate://room/123 trên iPhone thật.
//  xcrun simctl openurl booted artmate://room/123
//  xcrun simctl openurl booted artmate://room/123/42   => mở thẳng tranh 42 trong phòng 123 (Back: Tranh 42 -> Phòng 123 -> Sảnh)
