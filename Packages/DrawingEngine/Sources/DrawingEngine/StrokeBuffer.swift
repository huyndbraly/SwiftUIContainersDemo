// ==========================================
// DRAWING ENGINE: bộ đệm nét vẽ an toàn đa luồng
// ==========================================
// actor = class có "người gác cửa": mỗi lúc chỉ cho ĐÚNG 1 việc chạm vào dữ liệu bên trong.
// => Dù sự kiện từ server tới dồn dập, không bao giờ có 2 luồng cùng ghi vào mảng nét một lúc (data race).
// Gọi hàm của actor từ bên ngoài phải `await` (có thể phải xếp hàng chờ tới lượt).

public actor StrokeBuffer {
    private var state = BoardState() // chỉ actor này được sửa

    public init() {}

    // Ghi 1 sự kiện vào bộ đệm, trả về BẢN SAO trạng thái mới.
    // BoardState là struct (kiểu giá trị) + Sendable => mang bản sao sang luồng chính để vẽ là an toàn,
    // luồng chính có sửa bản sao cũng không ảnh hưởng dữ liệu bên trong actor.
    public func apply(_ event: BoardEvent) -> BoardState {
        state.apply(event)
        return state
    }
}
