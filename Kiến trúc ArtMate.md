ArtMate · prototype SwiftUIContainersDemo

# Kiến trúc app: MVVM + Service, 3 Swift Package

Mũi tên đi từ tầng trên xuống tầng dưới: tầng trên được `import` tầng dưới, tầng dưới không biết gì về tầng trên. View không gọi URLSession hay Socket; chúng đi qua ViewModel, rồi qua protocol của tầng Networking.

App: điều hướng + ráp các mảnh Features: màn hình (MVVM) Networking: gọi mạng DrawingEngine: dữ liệu + luật vẽ ── import (phụ thuộc) - - - gọi qua mạng

## Mỗi package làm gì, được dùng ai

| Package | Chứa | Được import | Không được |
| --- | --- | --- | --- |
| DrawingEngine | Mô hình nét vẽ, `BoardState.apply(event)`: luật cập nhật bảng vẽ | Không gì cả (chỉ Swift) | SwiftUI, UIKit, URLSession |
| Networking | Protocol `LessonService`, `DrawingSocket` và bản thật dùng URLSession | DrawingEngine | SwiftUI, View, ViewModel |
| Features | View + ViewModel của Bài học và Phòng vẽ, `AppDependencies` | DrawingEngine, Networking | Gọi thẳng URLSession / tạo socket trong View |
| App target | Điểm vào app, `ContentView`, route, các demo khác | Features | Chứa logic mạng hay luật vẽ |

## Dữ liệu đi qua các tầng thế nào

### Màn Bài học

1. `LessonListView` hiện ra, `.task` gọi `viewModel.load()`
2. ViewModel gọi `service.fetchLessons()`, rồi 20 lần `fetchThumbnail` song song trong TaskGroup
3. `LiveLessonService` dùng URLSession ở luồng nền
4. ViewModel gán `lessons`, `thumbnails` → View tự vẽ lại
5. Rời màn: `.task` huỷ, cả 20 lượt tải bị huỷ theo

### Phòng vẽ chung

1. Kéo ngón tay → `viewModel.dispatch(.strokeProgress)`
2. ViewModel → `socket.sendLive(...)` → server
3. Server chốt nét, gửi lại mọi máy → socket dịch JSON thành `BoardEvent`
4. ViewModel nhận `SocketEvent` → `board.apply(event)` (DrawingEngine)
5. View đọc `viewModel.board` → Canvas vẽ lại

## Dependency Injection: ráp ở một chỗ

`SwiftUIContainersDemoApp` là *composition root*: nó bỏ `AppDependencies.live` vào môi trường bằng `.environment(\.dependencies, .live)`. `ContentView` lấy ra bằng `@Environment(\.dependencies)`, rồi truyền vào màn con qua init: `LessonListView(service:)`, `SharedBoardView(socket:)`. ViewModel chỉ biết protocol, nên Preview của màn Bài học chạy với `PreviewLessonService` (dữ liệu giả, không cần mạng) mà không sửa dòng nào của View hay ViewModel.

## Đã kiểm chứng

- Build app thành công với 3 package local (`Packages/DrawingEngine`, `Packages/Networking`, `Packages/Features`).
- Tìm `URLSession` / `webSocketTask` trong app và Features: không có; chỉ `AppDependencies.live` tạo socket thật.
- Chạy lại kịch bản vòng đời trên simulator: tải bài học rồi rời màn → log huỷ task; vào phòng → kết nối; Home → ngắt; mở lại → nối lại; vẽ 1 nét → server chốt và trả về (seq 1).

Chưa chuyển: các màn demo bài học cũ (LiveDrawingView, RoomList, ArtworkDetail, BrushSettings) vẫn ở app target vì không gọi mạng. Chưa có test target cho DrawingEngine.