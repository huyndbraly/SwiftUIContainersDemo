//
//  SwiftUIContainersDemoApp.swift
//  SwiftUIContainersDemo
//
//  Created by Admin on 20/10/26.
//

import SwiftUI
import Features

@main
struct SwiftUIContainersDemoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                // COMPOSITION ROOT: chỗ DUY NHẤT quyết định app dùng service thật hay giả.
                // Muốn chạy với server khác / dữ liệu giả => chỉ đổi dòng này, không sửa màn hình nào.
                .environment(\.dependencies, .live)
        }
    }
}
