import SwiftUI
import UIKit

struct ContentView: View {
    // các phòng vẽ chung đang diễn ra
    let activeRooms = [
        RoomInfo(title: "Ký họa phong cảnh Hà Nội", host: "Huy & Thảo", members: 4, category: "Digital Painting"),
        RoomInfo(title: "Thử thách vẽ chân dung 15p", host: "Minh Quân", members: 6, category: "Sketch"),
        RoomInfo(title: "Sáng tạo thế giới Xianxia", host: "Danh Huy", members: 3, category: "Concept Art")
    ]
    
    // các tác phẩm vẽ cộng tác
    let collaborativeArtworks = ["Tác phẩm #01", "Tác phẩm #02", "Tác phẩm #03", "Tác phẩm #04"]
    
    // Chia 2 cột tác phẩm cộng tác
    let columns = [
        GridItem(.flexible(), spacing: 15),
        GridItem(.flexible(), spacing: 15)
    ]

    var body: some View {
        // [CONTAINER CHÍNH]: ScrollView bọc toàn bộ nội dung màn hình để người dùng có thể cuộn dọc xem hết thông tin
        ScrollView {
            // [CONTAINER DỌC - VStack]: Sắp xếp tất cả các khối giao diện từ trên xuống dưới với khoảng cách đều nhau (spacing: 20)
            VStack(alignment: .leading, spacing: 20) {
                
                // --- PHẦN 1: HEADER STUDIO CỦA NGHỆ SĨ ---
                // [CONTAINER CHỒNG LỚP - ZStack]: Dùng để xếp ảnh bìa nằm dưới và đè một phần ảnh đại diện (Avatar) lên trên
                ZStack(alignment: .bottom) {
                    // Khối hình chữ nhật làm ảnh bìa nền (sử dụng Color(UIColor...) sau khi đã import UIKit)
                    Rectangle()
                        .fill(Color(UIColor.systemGray5))
                        .frame(height: 180)
                    
                    // [CONTAINER NGANG - HStack]: Sắp xếp Avatar và tên nghệ sĩ nằm cạnh nhau theo chiều ngang ở phần đáy ảnh bìa
                    HStack(alignment: .bottom) {
                        // Khối tròn hiển thị Avatar nghệ sĩ
                        Circle()
                            .fill(Color(UIColor.systemBackground))
                            .frame(width: 84, height: 84)
                            .overlay(Circle().stroke(Color(UIColor.systemBackground), lineWidth: 4))
                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                        
                        // [CONTAINER DỌC - VStack]: Chứa thông tin tên và mô tả ngắn của nghệ sĩ
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Nguyễn Danh Huy")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            Text("artMate Creator • Drawing Together")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.bottom, 8)
                        
                        Spacer() // Đẩy toàn bộ thông tin sang lề trái
                    }
                    .padding(.horizontal)
                    .offset(y: 35) // Dịch chuyển phần chứa avatar và tên tràn xuống biên dưới ảnh bìa tạo hiệu ứng nổi
                }
                .padding(.bottom, 45) // Bù khoảng trống để các thành phần bên dưới không bị che khuất do hiệu ứng offset
                
                // --- PHẦN 2: CÁC NÚT THAO TÁC NHANH ---
                // [CONTAINER NGANG - HStack]: Đặt nút "Tạo phòng vẽ chung" và nút "Quét mã QR" nằm trên cùng một hàng ngang
                HStack(spacing: 12) {
                    // Nút bấm tạo phòng vẽ mới (Drawing Together)
                    Button(action: {}) {
                        HStack {
                            Image(systemName: "paintbrush.pointed.fill")
                            Text("Tạo phòng vẽ chung")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity) // Mở rộng hết chiều ngang có thể
                        .padding(.vertical, 12)
                        .background(Color.primary) // Màu nền tự động đổi theo chế độ Sáng/Tối (Light/Dark mode)
                        .foregroundColor(Color(UIColor.systemBackground))
                        .cornerRadius(12)
                    }
                    
                    // Nút bấm mở máy ảnh quét mã phòng nhanh
                    Button(action: {}) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.title2)
                            .padding(11)
                            .background(Color(UIColor.systemGray6))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                
                // Đường kẻ ngang phân tách các khu vực giao diện
                Divider()
                    .padding(.horizontal)
                
                // --- PHẦN 3: DANH SÁCH PHÒNG VẼ TRỰC TUYẾN (CUỘN NGANG) ---
                // [CONTAINER DỌC - VStack]: Gom nhóm tiêu đề phần phòng vẽ và danh sách bên dưới
                VStack(alignment: .leading, spacing: 10) {
                    // [CONTAINER NGANG - HStack]: Dùng để đặt tiêu đề ở góc trái và nút "Xem tất cả" ở góc phải
                    HStack {
                        Text("Phòng Drawing Together đang mở")
                            .font(.headline)
                        Spacer()
                        Text("Xem tất cả")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // [CONTAINER CUỘN NGANG - ScrollView]: Cho phép vuốt qua lại theo chiều ngang để xem các thẻ phòng vẽ
                    ScrollView(.horizontal, showsIndicators: false) {
                        // [CONTAINER NGANG - HStack]: Xếp các thẻ phòng vẽ thành một hàng ngang dài liên tiếp
                        HStack(spacing: 15) {
                            // Duyệt qua mảng dữ liệu activeRooms để sinh ra các thẻ phòng tương ứng
                            ForEach(activeRooms, id: \.title) { room in
                                // [CONTAINER DỌC - VStack]: Nội dung bên trong mỗi thẻ phòng vẽ (Số lượng người, Tên phòng, Chủ phòng, Nút tham gia)
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Label("\(room.members) đang vẽ", systemImage: "person.2.fill")
                                            .font(.caption2)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color(UIColor.systemGray6))
                                            .foregroundColor(.secondary)
                                            .cornerRadius(6)
                                        Spacer()
                                    }
                                    
                                    Text(room.title)
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .lineLimit(1)
                                    
                                    Text("Host: \(room.host)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Button(action: {}) {
                                        Text("Tham gia vẽ")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 6)
                                            .background(Color(UIColor.systemGray6))
                                            .foregroundColor(.primary)
                                            .cornerRadius(6)
                                    }
                                }
                                .padding()
                                .frame(width: 200) // Cố định chiều rộng cho từng thẻ card phòng vẽ ngang
                                .background(Color(UIColor.systemBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color(UIColor.systemGray4), lineWidth: 0.8) // Viền khung basic tinh tế
                                )
                                .cornerRadius(14)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // --- PHẦN 4: BỘ SƯU TẬP TÁC PHẨM CỘNG TÁC (LƯỚI 2 CỘT) ---
                // [CONTAINER DỌC - VStack]: Gom nhóm tiêu đề và lưới tác phẩm
                VStack(alignment: .leading, spacing: 10) {
                    Text("Tác phẩm cộng tác (Collab Arts)")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    // [CONTAINER LƯỚI - LazyVGrid]: Tự động sắp xếp các tác phẩm thành dạng lưới 2 cột tối ưu hiệu năng
                    LazyVGrid(columns: columns, spacing: 15) {
                        ForEach(collaborativeArtworks, id: \.self) { art in
                            // [CONTAINER DỌC - VStack]: Bố cục từng ô tác phẩm gồm khung hình minh họa và tên chú thích bên dưới
                            VStack(alignment: .leading, spacing: 6) {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(UIColor.systemGray6))
                                    .frame(height: 130)
                                    .overlay(
                                        Image(systemName: "photo.stack.fill")
                                            .font(.largeTitle)
                                            .foregroundColor(.secondary)
                                    )
                                
                                Text(art)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Text("Vẽ chung bởi Nhóm artMate")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
            }
            .padding(.bottom, 30) // Tạo khoảng đệm an toàn ở đáy màn hình khi cuộn hết trang
        }
    }
}

// Cấu trúc mô phỏng kiểu dữ liệu của một phòng vẽ chung
struct RoomInfo {
    let title: String
    let host: String
    let members: Int
    let category: String
}

#Preview {
    ContentView()
}
