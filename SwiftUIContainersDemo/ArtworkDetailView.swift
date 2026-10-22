import SwiftUI

// ==========================================
// DỮ LIỆU ĐIỀU HƯỚNG CHO MÀN HÌNH BỨC TRANH
// ==========================================
// Mỗi phần tử trong NavigationPath phải là Hashable (để SwiftUI so sánh path cũ/mới, biết màn nào được thêm/bớt).
// Bức tranh cần biết cả phòng lẫn số tranh, nên gói 2 giá trị vào 1 struct.
// Vì roomId (String) và artworkId (Int) đều Hashable sẵn => chỉ cần ghi ": Hashable", Swift tự sinh code == và hash.
// Dùng kiểu riêng (không dùng Int trần) để .navigationDestination(for: ArtworkRoute.self) không bị nhầm với các Int khác.
struct ArtworkRoute: Hashable {
    let roomId: String
    let artworkId: Int
}

struct ArtworkDetailView: View {
    let route: ArtworkRoute

    var body: some View {
        VStack(spacing: 20) {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.systemGray5))
                .frame(height: 300)
                .overlay(
                    Image(systemName: "photo.artframe")
                        .font(.system(size: 80))
                        .foregroundColor(.secondary)
                )

            Text("Bức tranh #\(route.artworkId)")
                .font(.title2)
                .fontWeight(.bold)

            Text("Thuộc phòng số \(route.roomId)")
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding()
        .navigationTitle("Tranh #\(route.artworkId)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ArtworkDetailView(route: ArtworkRoute(roomId: "123", artworkId: 42))
    }
}
