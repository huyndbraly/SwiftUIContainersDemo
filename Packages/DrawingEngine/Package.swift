// swift-tools-version: 6.2
import PackageDescription

// DrawingEngine: dữ liệu nét vẽ + luật cập nhật bảng vẽ. Thuần Swift, không phụ thuộc package nào.
let package = Package(
    name: "DrawingEngine",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "DrawingEngine", targets: ["DrawingEngine"]),
    ],
    targets: [
        .target(name: "DrawingEngine"),
    ],
    swiftLanguageModes: [.v6] // Swift 6: kiểm tra concurrency ở mức Complete, vi phạm là LỖI build
)
