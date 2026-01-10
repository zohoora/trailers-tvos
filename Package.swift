// swift-tools-version:5.9
// Package.swift for syntax validation only
// The actual app should be built with Xcode for tvOS

import PackageDescription

let package = Package(
    name: "Trailers",
    platforms: [
        .tvOS(.v17),
        .macOS(.v14) // For local compilation check
    ],
    products: [
        .library(
            name: "TrailersCore",
            targets: ["TrailersCore"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/kean/Nuke", from: "12.0.0")
    ],
    targets: [
        // Core logic only - no UIKit/SwiftUI dependencies
        .target(
            name: "TrailersCore",
            dependencies: [],
            path: "Trailers",
            exclude: [
                "Tests",
                "Views",
                "App",
                "ViewModels",
                "Services/ImagePipeline.swift",
                "Services/YouTubeLauncher.swift",
                "Resources"
            ],
            sources: [
                "Core",
                "Models",
                "Services/NetworkClient.swift",
                "Services/ResponseCache.swift",
                "Services/TMDBService.swift",
                "Services/NetworkMonitor.swift"
            ]
        )
    ]
)
