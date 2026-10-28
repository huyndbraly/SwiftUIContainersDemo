// swift-tools-version: 6.2
import PackageDescription

// Networking: mọi thứ nói chuyện với server (URLSession, WebSocket). Cần DrawingEngine vì gửi/nhận nét vẽ.
let package = Package(
    name: "Networking",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "Networking", targets: ["Networking"]),
    ],
    dependencies: [
        .package(path: "../DrawingEngine"),
    ],
    targets: [
        .target(name: "Networking", dependencies: ["DrawingEngine"]),
    ],
    swiftLanguageModes: [.v6] // Swift 6: kiểm tra concurrency ở mức Complete, vi phạm là LỖI build
)
