// swift-tools-version: 6.2
import PackageDescription

// Features: các màn hình (View) + ViewModel. Dùng DrawingEngine và Networking, nhưng chỉ qua protocol.
let package = Package(
    name: "Features",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "Features", targets: ["Features"]),
    ],
    dependencies: [
        .package(path: "../DrawingEngine"),
        .package(path: "../Networking"),
    ],
    targets: [
        .target(
            name: "Features",
            dependencies: ["DrawingEngine", "Networking"],
            // Giống app: code giao diện mặc định chạy trên MainActor (luồng chính)
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
    ],
    swiftLanguageModes: [.v6] // Swift 6: kiểm tra concurrency ở mức Complete, vi phạm là LỖI build
)
