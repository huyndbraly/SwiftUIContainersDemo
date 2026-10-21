import SwiftUI
import UIKit

struct ContentView: View {
    
    // Bản chất của struct: Khi một phương thức (như body) được thực thi bên trong một struct, Swift ngầm định cấu trúc đó là const (hằng số). Do đó, bạn không được phép thay đổi giá trị của bất kỳ biến nào được khai báo bằng let hay var thông thường bên trong struct.
    
    // Ngoại lệ duy nhất (@State): Khi bạn gắn từ khóa @State vào trước một biến (ví dụ: @State private var selectedArt: String? = nil), Swift và SwiftUI sẽ đưa biến đó ra khỏi vùng nhớ thông thường của struct. Nó được chuyển giao cho hệ thống quản lý trạng thái của SwiftUI hậu trường quản lý. Nhờ vậy, cấu trúc struct của bạn mới có "đặc quyền" được đọc, ghi và cập nhật lại giá trị của biến đó, đồng thời ra lệnh cho màn hình tự động vẽ lại (redraw) mỗi khi giá trị thay đổi.
    
    // 1. Khai báo Namespace và trạng thái để làm hiệu ứng phóng to (matchedGeometryEffect)
    @Namespace var animationNamespace //tạo không gian định danh chung cho 2 view để swiftUI nhận biết chúng là cùng 1 đối tượng
    @State private var selectedArt: String? = nil // Khai báo khả biến cho biến selectedArt, ? ở đây có nghĩa Biến này có thể chứa một chuỗi văn bản (String) hoặc nil (null - không có gì cả)
    // => Trong Swift, các kiểu dữ liệu cơ bản như String (chuỗi văn bản), Int (số nguyên), hay Double mặc định không bao giờ được phép mang giá trị rỗng hoặc nil
    
    let activeRooms = [
        RoomInfo(title: "Ký họa phong cảnh Hà Nội", host: "Huy & Thảo", members: 4, category: "Digital Painting"),
        RoomInfo(title: "Thử thách vẽ chân dung 15p", host: "Minh Quân", members: 6, category: "Sketch"),
        RoomInfo(title: "Sáng tạo thế giới Xianxia", host: "Danh Huy", members: 3, category: "Concept Art")
    ]
    
    let collaborativeArtworks = ["Bài học #01: Ký họa", "Bài học #02: Phối màu", "Bài học #03: Ánh sáng", "Bài học #04: Giải phẫu", "HUHU"]
    
    let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 15)
    ]
    
    //tự điều chỉnh chiều rộng tối thiểu 150point (ở đây dùng lazyVgrid nên scroll theo chiều dọc, theo quy tắc thiết kế cảu swiftUI thì ô nào nhiều chữ sẽ tự dài xuống, chiều ngang bị giới hạn theo chiều rộng thiết bị nên hệ thống sẽ tự tính toán chiều rộng cho phù hợp)
    
    
    let colorPalette: [Color] = [.red, .orange, .mint, .brown, .yellow, .green, .blue, .purple, .primary] //=> tường minh kiểu dữ liệu (Explicit Type Annotation) thay vì Swift có thể tự suy luận kiểu dữ liệu (Type Inference), Tránh swift nhầm lẫn, ví dụ .primary là một màu đặc biệt của hệ thống dynamic color thay đổi theo light/dark mode thuộc cấu trúc color trong swiftUI. Trong hệ sinh thái Apple (UIKit / SwiftUI), từ primary không chỉ dùng độc quyền cho màu sắc Color. Nó còn có thể xuất hiện trong các thuộc tính cấu hình văn bản (ví dụ primary là văn abnr chính, secondary là văn bản phụ), kiểu font chữ, hoặc các định nghĩa trạng thái giao diện khác.
    
    var body: some View { //Hệ thống swiftUI khi chạy sẽ tự tìm biến body này để xác định view cần hiển thị trên màn hình
        // view là một giao thức, đại diện cho bất kì thứ gì hiển thị trên màn hình (như nút bấm, chữ viết, hình ảnh, ...)
        // từ khóa some (gọi là opaque type) lệnh cho swift phải trả về kiểu data chuẩn view
        ZStack {
            // --- GIAO DIỆN CHÍNH ---
            ScrollView {
                // [CONTAINER DỌC - VStack]: Sắp xếp tất cả các khối giao diện từ trên xuống dưới (spacing: 20)
                VStack(alignment: .leading, spacing: 20) {
                    
                    // --- PHẦN 1: BẢNG VẼ CHÍNH (ZSTACK ĐÈ LÊN NỀN) ---
                    // [CONTAINER CHỒNG LỚP - ZStack]: Dùng để xếp nền hiển thị bên dưới và đè các công cụ vẽ, bảng vẽ lên trên
                    ZStack(alignment: .bottomLeading) {
                        // Khối hình chữ nhật làm không gian bảng vẽ nền
                        Rectangle()
                            .fill(Color(UIColor.systemGray6))
                            .frame(height: 220)
                            .overlay(
                                VStack(spacing: 8) {
                                    Image(systemName: "paintbrush.pointed.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.secondary)
                                    Text("Không gian vẽ tương tác trực tiếp")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            )
                        
                        // [CONTAINER DỌC - VStack]: Thanh chỉnh cọ nằm dọc ở góc trái màn hình vẽ
                        VStack(spacing: 12) {
                            Image(systemName: "slider.vertical.3")
                                .font(.body)
                            Divider().frame(width: 20)
                            Image(systemName: "paintbrush.fill")
                            Image(systemName: "pencil.tip")
                            Image(systemName: "eraser.fill")
                        }
                        .padding(10)
                        .background(Color(UIColor.systemBackground).opacity(0.9))
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                        .padding(.leading, 16)
                        .padding(.bottom, 16)
                    }
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // --- PHẦN 2: THANH CHỌN MÀU NẰM NGANG ---
                    // [CONTAINER CUỘN NGANG - ScrollView]: Giúp vuốt chọn màu mượt mà không bị tràn màn hình
                    ScrollView(.horizontal, showsIndicators: false) { //ẩn thanh cuộn
                        HStack(spacing: 20) {
                            ForEach(0..<colorPalette.count, id: \.self) { index in    //id: \.self: Giúp SwiftUI nhận diện định danh duy nhất cho từng vòng lặp, đảm bảo không bị lỗi xung đột giao diện khi render. Chỉ dùng \.self cho các kiểu dữ liệu nguyên thủy cơ bản (như Int, String, UUID...) chứ không dùng được cho cả một đối tượng phức tạp (struct/class).
                                Circle()
                                    .fill(colorPalette[index])
                                    .frame(width: 36, height: 36)
                                    .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // --- PHẦN 3: CÁC NÚT THAO TÁC NHANH ---
                    HStack(spacing: 12) {
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Tạo phòng học vẽ mới")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.primary)
                            .foregroundColor(Color(UIColor.systemBackground))
                            .cornerRadius(12)
                        }
                        
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
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // --- PHẦN 4: DANH SÁCH PHÒNG HỌC ĐANG MỞ (CUỘN NGANG) ---
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Phòng học Drawing Together")
                                .font(.headline)
                            Spacer()
                            Text("Xem tất cả")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 15) {
                                ForEach(activeRooms, id: \.title) { room in   //dùng chính title làm định danh cho mỗi đối tượng phòng học luôn
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Label("\(room.members) học viên", systemImage: "person.2.fill")
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
                                        
                                        Text("Giảng viên: \(room.host)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Button(action: {}) {
                                            Text("Vào lớp học")
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
                                    .frame(width: 200)
                                    .background(Color(UIColor.systemBackground))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color(UIColor.systemGray4), lineWidth: 0.8)
                                    )
                                    .cornerRadius(14)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // --- PHẦN 5: LƯỚI BÀI HỌC (LAZYVGRID THÍCH ỨNG & HERO ANIMATION) ---
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Thư viện bài học thực hành")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        // Sử dụng biến columns đã được cấu hình .adaptive ở trên
                        LazyVGrid(columns: columns, spacing: 15) {
                            ForEach(collaborativeArtworks, id: \.self) { art in
                                if selectedArt != art {
                                    Button(action: {
                                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                            selectedArt = art // Kích hoạt mở màn hình chi tiết
                                        }
                                        // matchedGeometryEffect: Lo phần không gian hình học (biết là bay từ đâu đến đâu).
                                        
                                        // withAnimation: Lo phần thời gian và tốc độ (biết là bay nhanh hay chậm, có nảy hay không).
                                    }) {
                                        VStack(alignment: .leading, spacing: 6) {
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color(UIColor.systemGray5))
                                                .frame(height: 130)
                                                .overlay(
                                                    Image(systemName: "book.closed.fill")
                                                        .font(.largeTitle)
                                                        .foregroundColor(.secondary)
                                                )
                                                // BẮT BUỘC PHẢI CÓ DÒNG NÀY ĐỂ LIÊN KẾT HIỆU ỨNG
                                                .matchedGeometryEffect(id: art, in: animationNamespace)
                                            
                                            Text(art)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.primary)
                                            
                                            Text("Hoàn thành bài tập")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                } else {
                                    // Giữ chỗ trống khi card đang phóng to bay đi
                                    VStack {}.frame(height: 180)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                }
                .padding(.bottom, 30)
            }
            
            
            
            
            
            
            
            // --- MÀN HÌNH CHI TIẾT BÀI HỌC (HIỆN KHI BẤM VÀO THẺ) ---
            if let currentItem = selectedArt {
                //chạm vào viền màn hình chi tiết để close
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            selectedArt = nil
                        }
                    }
                
                VStack(alignment: .leading, spacing: 16) {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(UIColor.systemGray5))
                        .frame(height: 240)
                        .overlay(
                            Image(systemName: "book.closed.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                        )
                    // Gắn hiệu ứng đích với cùng id và namespace
                        .matchedGeometryEffect(id: currentItem, in: animationNamespace, isSource: false)
                    
                    Text(currentItem)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Nội dung hướng dẫn chi tiết từng bước thực hành sáng tạo nghệ thuật cho bài học này.")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button(
                        // 1. Tầng thứ nhất: Khối action (Hành động khi bấm)
                        action: {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                selectedArt = nil
                            }
                        }
                    ) {
                        // 2. Tầng thứ hai: Khối nhãn hiển thị giao diện của nút (Label)
                        Text("Đóng hướng dẫn")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.primary)
                            .foregroundColor(Color(UIColor.systemBackground))
                            .cornerRadius(12)
                    }
                }
                .padding(24)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(24)
                .padding(20)
                .shadow(radius: 20)
                .transition(.opacity)
            }
        }
    }
}

struct RoomInfo {
    let title: String
    let host: String
    let members: Int
    let category: String
}

#Preview {
    ContentView()
}

//#Preview(traits: .landscapeLeft) {
//    ContentView()
//}
