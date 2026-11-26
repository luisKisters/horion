// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Horion",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "Horion", targets: ["Horion"]),
        .library(name: "HorionKit", targets: ["HorionKit"]),
    ],
    // Sparkle 2 (the update framework) is the one allowed package; only the app target uses it. scripts/verify.sh enforces this.
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.10.1"),
    ],
    targets: [
        .target(name: "HorionKit"),
        .executableTarget(
            name: "Horion",
            dependencies: [
                "HorionKit",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            resources: [.copy("Resources/Fonts")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(name: "HorionKitTests", dependencies: ["HorionKit"], resources: [.copy("Fixtures")]),
        .testTarget(name: "HorionTests", dependencies: ["Horion", "HorionKit"], swiftSettings: [.swiftLanguageMode(.v5)]),
    ]
)
