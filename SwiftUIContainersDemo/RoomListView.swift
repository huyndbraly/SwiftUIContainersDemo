import SwiftUI

// ==========================================
// DỮ LIỆU ĐIỀU HƯỚNG CHO MÀN DANH SÁCH PHÒNG
// ==========================================
// Màn danh sách phòng không cần dữ liệu gì kèm theo, nhưng path vẫn cần 1 giá trị Hashable để đại diện cho nó.
// Không dùng String được vì String đã là "mã phòng" (=> RoomDetailView), dùng lại sẽ bị nhầm.
// => Tạo 1 struct rỗng làm "vé vào cửa" riêng: struct không có thuộc tính nào thì Swift vẫn tự sinh Hashable.
struct RoomListRoute: Hashable {}

struct RoomListView: View {
    // Giả lập danh sách mã phòng đang mở (có phòng 123)
    let roomIds = ["101", "102", "115", "123", "128", "136", "150", "199"]

    var body: some View {
        List(roomIds, id: \.self) { roomId in
            // Bấm vào 1 phòng = SwiftUI tự append(roomId) (String) vào path => tra .navigationDestination(for: String.self) ở ContentView => push RoomDetailView
            NavigationLink(value: roomId) {
                HStack(spacing: 12) {
                    Image(systemName: "paintbrush.fill")
                        .foregroundColor(.orange)
                    Text("Phòng số \(roomId)")
                        .font(.body)
                        .fontWeight(.medium)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Danh sách phòng")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        RoomListView()
            .navigationDestination(for: String.self) { roomId in
                RoomDetailView(roomId: roomId, isConnected: .constant(true))
            }
    }
}
