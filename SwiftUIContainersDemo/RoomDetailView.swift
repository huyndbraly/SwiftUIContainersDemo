import SwiftUI

struct RoomDetailView: View {
    let roomId: String
    @Binding var isConnected: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "paintbrush.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Đang ở trong: \(roomId)")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(isConnected ? "Trạng thái phòng: Đang vẽ mượt mà" : "Mất kết nối mạng...")
                .foregroundColor(isConnected ? .green : .red)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Phòng Vẽ Trực Tuyến")
    }
}

#Preview {
    // Bọc trong NavigationStack để thấy được navigationTitle
    NavigationStack {
        RoomDetailView(roomId: "Phòng vẽ thủ công #999", isConnected: .constant(true))
    }
}

//"Đăng ký URL scheme artmate" nghĩa là báo cho iOS biết: mọi đường link bắt đầu bằng artmate:// thì mở bằng app của mình.

// giả lập việc mở một đường link trên simulator, ngay từ terminal. Kết quả giống như người dùng bấm vào link artmate://room/123 trên iPhone thật.
//  xcrun simctl openurl booted artmate://room/123
