import SwiftUI


// ==========================================
// VIEW CON: TÁCH RIÊNG BẢNG CHỌN MÀU & ĐỘ DÀY CỌ
// ==========================================

//Tham số (parameter): cách hiểu tạm chấp nhận
//let colorPalette: [Color]
//@Binding var selectedColor: Color
//@Binding var brushThickness: Double
//thực chất là thuộc tính lưu trữ (stored property) của struct, không phải tham số. Tham số nằm trong một hàm khởi tạo mà Swift tự sinh ngầm cho struct (memberwise initializer). Hàm này trông đại khái như sau:
//
//init(colorPalette: [Color],
//     selectedColor: Binding<Color>,
//     brushThickness: Binding<Double>) {
//    self.colorPalette = colorPalette          // gán tham số vào thuộc tính
//    self._selectedColor = selectedColor       // _selectedColor: bản thân wrapper Binding
//    self._brushThickness = brushThickness
//}
//
//Như vậy luồng đi là: đối số → tham số của init → được gán vào thuộc tính của struct. Vì Swift tự sinh init dựa đúng theo danh sách thuộc tính, nên hiểu "thuộc tính ≈ tham số" là cách nhớ chấp nhận được.
//
//Lưu ý về @Binding:
//- Thuộc tính khai báo Color, nhưng tham số của init có kiểu Binding<Color>.
//- Vì vậy bên ngoài phải truyền $selectedColor (có dấu $, tức là Binding trỏ tới @State ở view cha), không phải selectedColor (giá trị Color thuần).
//- Nếu truyền thiếu dấu $, Xcode sẽ báo lỗi kiểu kiểu "cannot convert value of type 'Color' to expected argument type 'Binding<Color>'".

struct BrushSettingsView: View {
    let colorPalette: [Color]
    
    @Binding var selectedColor: Color
    @Binding var brushThickness: Double
    
//    @Environment(\.colorScheme) var colorScheme
    
    @Environment(\.customAppColor) private var appThemeColor
    
    // Tầng con cũng có thể tự bắt sóng ScenePhase mà không cần view cha phải truyền hộ!
        @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Công cụ điều chỉnh cọ vẽ")
                .font(.headline)
            
            HStack {
                Image(systemName: scenePhase == .active ? "wifi" : "wifi.slash")
                Text(scenePhase == .active ? "Trạng thái: Sẵn sàng vẽ trực tuyến" : "Trạng thái: Tạm dừng kết nối")
                    .font(.caption2)
            }
            .foregroundColor(.secondary)
            
            // 1. Hàng chọn màu sắc cọ (Cuộn ngang)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(0..<colorPalette.count, id: \.self) { index in
                        let itemColor = colorPalette[index]
                        Circle()
                            .fill(itemColor)
                            .frame(width: 36, height: 36)
                            .overlay(
                                Circle()
                                    .stroke(Color.primary, lineWidth: selectedColor == itemColor ? 3 : 0)
                            )
                            .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                            .onTapGesture { // view modifier (bộ chỉnh sửa giao diện) dùng để bắt sự kiện khi người dùng chạm hoặc click vào một View bất kỳ
                                selectedColor = itemColor
                            }
                    }
                }
            }
            
            // 2. Thanh trượt điều chỉnh độ dày nét cọ (Slider)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Độ dày nét cọ:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(brushThickness)) pt")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                Slider(value: $brushThickness, in: 1...30, step: 1)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
//        .background(colorScheme == .dark ? Color.blue : Color.gray)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(UIColor.systemGray4), lineWidth: 0.8)
        )
    }
}

#Preview {
    // Preview riêng view con: không có @State của view cha nên dùng .constant(...) để tạo Binding giả (chỉ đọc)
    BrushSettingsView(
        colorPalette: [.red, .orange, .green, .blue, .purple],
        selectedColor: .constant(.blue),
        brushThickness: .constant(5)
    )
    .padding()
}
