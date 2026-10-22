import SwiftUI
import UIKit

struct ContentView: View {
    
    // Bản chất của struct: struct là kiểu giá trị (value type). Bên trong một phương thức/thuộc tính tính toán KHÔNG có từ khóa mutating (như getter của body), Swift coi self là bất biến (giống hằng số). Do đó trong body bạn không thể gán lại giá trị cho các stored property khai báo bằng var thông thường (còn let thì vốn không bao giờ gán lại được ở bất cứ đâu).
    // Protocol View yêu cầu body là non-mutating, nên ta không thể đánh dấu body là mutating để lách luật này.
    
    // Giải pháp (@State): Khi gắn @State vào một biến (ví dụ: @State private var selectedArt: String? = nil), giá trị thật KHÔNG nằm trong struct nữa mà được SwiftUI lưu trữ ở bên ngoài (storage do SwiftUI quản lý, gắn với vòng đời của view trên màn hình). Struct chỉ giữ một "tham chiếu" tới vùng lưu trữ đó, và setter của @State là nonmutating => vì vậy dù self bất biến, ta vẫn gán được selectedArt = ... trong body/closure.
    // Mỗi khi giá trị thay đổi, SwiftUI sẽ tính lại body và vẽ lại (redraw) những view có ĐỌC biến đó.
    // Ngoài @State còn có các property wrapper tương tự như @Binding, @StateObject, @ObservedObject, @Environment...
    
    // --- KHAI BÁO @ENVIRONMENT ĐỂ BẮT SÓNG MÔI TRƯỜNG HỆ THỐNG ---
    @Environment(\.colorScheme) var colorScheme // truy xuất trực tiếp giá trị cấu hình colorScheme được truyền ngầm trong môi trường của hệ thống view
    
    @Environment(\.customAppColor) private var appThemeColor // Hứng màu chủ đạo từ môi trường chung
    
    // 1. Khai báo Namespace và trạng thái để làm hiệu ứng phóng to (matchedGeometryEffect)
    @Namespace var animationNamespace //tạo không gian định danh chung cho 2 view để swiftUI nhận biết chúng là cùng 1 đối tượng
    @State private var selectedArt: String? = nil // Khai báo biến trạng thái selectedArt kiểu Optional: dấu ? nghĩa là biến này có thể chứa một chuỗi (String) hoặc nil (không có giá trị). nil = chưa chọn bài học nào.
    // => Trong Swift, MỌI kiểu không có dấu ? (String, Int, Double, Bool, kể cả struct/class tự định nghĩa) đều không được phép mang giá trị nil.
    //    Lưu ý: "rỗng" khác "nil". String vẫn được phép rỗng ("") và Int vẫn được là 0. Chỉ nil là bị cấm, muốn chứa nil phải khai báo Optional (String?).
    
    
    // TRẠNG THÁI CHO BẢNG MÀU VÀ CỌ VẼ (Sử dụng @State ở View Cha)
    @State private var selectedColor: Color = .blue // Màu sắc cọ đang được chọn
    @State private var brushThickness: Double = 5.0 // Độ dày nét cọ đang được chọn
    
    
    // khai báo path là một @State vì path thay đổi thì SwiftUI cần vẽ lại để push hoặc pop màn hình.
    @State private var navigationPathScreen = NavigationPath() // NavigationPath() lúc đầu rỗng, tức là chỉ có màn hình root (Sảnh Chờ).
    
    
    // HỨNG TRẠNG THÁI VÒNG ĐỜI CỦA APP (Active, Inactive, Background)
    @Environment(\.scenePhase) private var scenePhase
    
    // Trạng thái giả lập kết nối socket phòng vẽ
    @State private var isSocketConnected: Bool = true
    
    // Lưu lại ID phòng vẽ hiện tại để khi user mở lại app, biết đường tự động nhảy vào lại đúng phòng đó
    @State private var currentActiveRoomID: String? = nil
    
    
    let activeRooms = [
        RoomInfo(title: "Ký họa phong cảnh Hà Nội", host: "Huy & Thảo", members: 4, category: "Digital Painting"),
        RoomInfo(title: "Thử thách vẽ chân dung 15p", host: "Minh Quân", members: 6, category: "Sketch"),
        RoomInfo(title: "Sáng tạo thế giới Xianxia", host: "Danh Huy", members: 3, category: "Concept Art")
    ]
    
    let collaborativeArtworks = ["Bài học #01: Ký họa", "Bài học #02: Phối màu", "Bài học #03: Ánh sáng", "Bài học #04: Giải phẫu", "HUHU"]
    
    let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 15)
    ]
    
    // .adaptive(minimum: 150): SwiftUI xếp CÀNG NHIỀU CỘT CÀNG TỐT sao cho mỗi cột rộng ít nhất 150pt, sau đó chia đều phần chiều ngang còn dư cho các cột.
    // Ví dụ iPhone rộng ~393pt, trừ padding 2 bên còn ~361pt => vừa 2 cột (2 x 150 + spacing 15 = 315 ≤ 361), không đủ chỗ cho 3 cột.
    // spacing: 15 trong GridItem là khoảng cách NGANG giữa các cột (khoảng cách dọc giữa các hàng nằm ở LazyVGrid(spacing:)).
    // LazyVGrid cuộn theo chiều dọc: chiều rộng ô bị giới hạn bởi màn hình, còn chiều cao mỗi hàng bằng ô CAO NHẤT trong hàng đó (ô nhiều chữ sẽ dài xuống).
    
    
    let colorPalette: [Color] = [.red, .orange, .mint, .brown, .yellow, .green, .blue, .purple, .primary]
    // [Color]: Kiểu dữ liệu (Type) của hằng số, ký hiệu dấu ngoặc vuông [...] đại diện cho kiểu mảng (Array). Nó chỉ định rằng mảng này chỉ được phép chứa các phần tử có kiểu dữ liệu là Color.
    // => Khai báo tường minh kiểu dữ liệu (Explicit Type Annotation) [Color] ở đây là BẮT BUỘC, không chỉ để "dễ đọc".
    //    Cú pháp .red, .orange... (implicit member expression) là cách viết tắt của Color.red, Color.orange, Swift cần biết trước kiểu (contextual type) để hiểu dấu chấm đó thuộc về kiểu nào.
    //    Nếu viết let colorPalette = [.red, .orange] (để Swift tự suy luận - Type Inference) sẽ lỗi biên dịch: "Reference to member 'red' cannot be resolved without a contextual type".
    // .primary là màu động (dynamic color) của hệ thống: đen ở light mode, trắng ở dark mode.
    //    Từ primary/secondary không chỉ có ở Color: còn có HierarchicalShapeStyle.primary/.secondary dùng với .foregroundStyle(.primary) cho văn bản chính/phụ, hay UIColor.label/.secondaryLabel bên UIKit.
    
    
    var body: some View { // body là yêu cầu bắt buộc của protocol View, SwiftUI sẽ gọi body để biết view cần hiển thị trên màn hình (và gọi lại mỗi khi @State thay đổi)
        // View là một giao thức (protocol), đại diện cho bất kì thứ gì hiển thị trên màn hình (as nút bấm, chữ viết, hình ảnh, ...)
        // từ khóa some (opaque type): body trả về MỘT kiểu cụ thể duy nhất có tuân thủ View. Compiler biết chính xác kiểu đó (ở đây là ZStack<...> lồng rất dài), chỉ là ẩn đi để ta không phải viết ra.
        //    Vì phải là một kiểu duy nhất nên mọi nhánh đều phải ra cùng kiểu. Các câu lệnh if/else bên trong chạy được là nhờ @ViewBuilder (body ngầm định có) gộp các nhánh thành một kiểu chung.
        NavigationStack(path: $navigationPathScreen) {
            
//          path: Nhãn đối số
//          NavigationStack cũng là một struct như BrushSettingsView. Apple viết sẵn hàm khởi tạo của nó, đại khái như sau:
//
//            struct NavigationStack<Data, Root: View>: View {
//                init(path: Binding<NavigationPath>,      // ← tham số tên "path"
//                     @ViewBuilder root: () -> Root)      // ← tham số "root" = màn hình gốc
//            }
            ZStack {
                // --- GIAO DIỆN CHÍNH ---
                ScrollView {
                    // [CONTAINER DỌC - VStack]: Sắp xếp tất cả các khối giao diện từ trên xuống dưới (spacing: 20)
                    VStack(alignment: .leading, spacing: 20) {
                        
                        // ---  HIỂN THỊ TRẠNG THÁI MÔI TRƯỜNG @ENVIRONMENT ---
                        HStack {
                            Image(systemName: colorScheme == .dark ? "moon.fill" : "sun.max.fill")
                                .foregroundColor(colorScheme == .dark ? .yellow : .orange)
                            Text(colorScheme == .dark ? "Môi trường: Đang bật Dark Mode" : "Môi trường: Đang bật Light Mode")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                        }
                        .padding(.horizontal)
                        
                        
                        // --- HIỂN THỊ TRẠNG THÁI SOCKET & PHÒNG VẼ TRỰC QUAN ---
                        HStack(spacing: 8) {
                            Circle()
                                .fill(isSocketConnected ? Color.green : Color.red)
                                .frame(width: 10, height: 10)
                            Text(isSocketConnected ? "Socket: Đang trực tuyến" : "Socket: Đã ngắt kết nối (Tiết kiệm pin)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        // Nút bấm thủ công để test chuyển màn hình phòng vẽ
                        Button(action: {
                            navigationPathScreen.append("Phòng vẽ thủ công #999")
                        }) {
                            Text("Test vào phòng nhanh")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(appThemeColor)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        
                        
                        
                        // --- PHẦN 1: BẢNG VẼ CHÍNH (ZSTACK ĐÈ LÊN NỀN) ---
                        // [CONTAINER CHỒNG LỚP - ZStack]: Dùng để xếp nền hiển thị bên dưới và đè các công cụ vẽ, bảng vẽ lên trên
                        ZStack(alignment: .bottomLeading) {
                            // Khối hình chữ nhật làm không gian bảng vẽ nền (Màu sắc phản hồi theo selectedColor)
                            Rectangle()
                                .fill(Color(UIColor.systemGray6))
                                .frame(height: 220)
                                .overlay(
                                    VStack(spacing: 8) {
                                        Image(systemName: "paintbrush.pointed.fill")
                                            .font(.system(size: 40))
                                            .foregroundColor(selectedColor)
                                        Text("Đang dùng cọ cỡ: \(Int(brushThickness))px")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                )
                            
                            // [CONTAINER DỌC - VStack]: Thanh chỉnh cọ nằm dọc ở góc DƯỚI BÊN TRÁI màn hình vẽ (do ZStack(alignment: .bottomLeading))
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
                        
                        // --- PHẦN 2: Khai báo BẢNG CHỌN MÀU & ĐỘ DÀY CỌ (ĐÃ ĐƯA RA KHỎI SCROLLVIEW CON ĐỂ ĐỨNG ĐỘC LẬP TRONG VSTACK) ---
                        // Đối số (argument)
                        // Còn colorPalette:, selectedColor:, brushThickness: là nhãn đối số (argument label).
                        BrushSettingsView(
                            colorPalette: colorPalette,
                            selectedColor: $selectedColor,
                            brushThickness: $brushThickness
                        )
                        .padding(.horizontal)
                        
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
                                    ForEach(activeRooms, id: \.title) { room in
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
                            
                            LazyVGrid(columns: columns, spacing: 15) {
                                ForEach(collaborativeArtworks, id: \.self) { art in
                                    if selectedArt != art {
                                        Button(action: {
                                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                                selectedArt = art
                                            }
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
                                        VStack {}.frame(height: 180)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                    }
                    .padding(.bottom, 30)
                }
                // Modifier phải có dấu chấm ở đầu (.navigationTitle) để gắn vào ScrollView phía trên.
                // Nếu thiếu dấu chấm, Swift hiểu là self.navigationTitle(...) => tạo ra một view MỚI bọc chính ContentView bên trong => body gọi lại body => đệ quy vô hạn, app crash.
                .navigationTitle("Sảnh Chờ ArtMate")
                // 4. ĐỊNH NGHĨA ĐÍCH ĐẾN KHI PATH CÓ CHỨA MÃ PHÒNG (STRING)
                .navigationDestination(for: String.self) { roomID in               // Navigation Destination (hay gọi tắt là Destination) là nơi mà người dùng có thể đi đến (màn hình, giao diện, hoặc một View bất kỳ trong ứng dụng).
                    RoomDetailView(roomId: roomID, isConnected: $isSocketConnected)
                }

                // --- MÀN HÌNH CHI TIẾT BÀI HỌC (phải nằm TRONG ZStack để đè lên ScrollView) ---
                if let currentItem = selectedArt {
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
                            .matchedGeometryEffect(id: currentItem, in: animationNamespace, isSource: false)
                        
                        Text(currentItem)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Nội dung hướng dẫn chi tiết từng bước thực hành sáng tạo nghệ thuật cho bài học này.")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                selectedArt = nil
                            }
                        }) {
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
            } // đóng ZStack
        } // đóng NavigationStack
        // --- 5. ĐẶT .onChange Ở CẤP GỐC (gắn vào NavigationStack) ĐỂ LUÔN LẮNG NGHE VÒNG ĐỜI APP ---
        // Nếu gắn vào view nằm trong if let (chỉ tồn tại khi mở thẻ bài học) thì chỉ nghe được lúc thẻ đang mở.
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .active:
                print("🟢 [App Active]: Mở lại app -> Kết nối lại Socket!")
                isSocketConnected = true
                // Nếu có lưu phòng cũ, tự động đẩy lại vào path để phục hồi màn hình
                if let savedRoom = currentActiveRoomID {
                    navigationPathScreen.append(savedRoom)
                    currentActiveRoomID = nil // reset sau khi đã phục hồi
                }

            case .inactive:
                print("🟡 [App Inactive]: Tạm dừng.")

            case .background:
                print("🔴 [App Background]: Đẩy xuống nền -> Ngắt kết nối Socket để cứu pin!")
                isSocketConnected = false
                // Lưu lại vết phòng nếu đang đứng ở màn hình chi tiết (giả lập)
                currentActiveRoomID = "Phòng DeepLink #123"

            @unknown default:
                break
            }
        }
        // --- 6. BẮT URL ĐỂ LÀM DEEP LINK ---
        .onOpenURL { url in
            // Xử lý URL dạng: artmate://room/123
            if url.scheme == "artmate", url.host == "room" {
                let roomId = url.pathComponents.dropFirst().joined(separator: "/")
                let targetRoom = roomId.isEmpty ? "Phòng Mặc Định" : "Phòng số \(roomId)"

                print("🔗 Đã nhận Deep Link nhảy vào: \(targetRoom)")
                // Nhét thẳng vào giỏ NavigationPath -> App tự động đẩy màn hình nhảy vào phòng vẽ!
                navigationPathScreen.append(targetRoom)
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
