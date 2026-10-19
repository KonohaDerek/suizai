// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SuizaiMockStore",
    platforms: [.macOS(.v13), .iOS(.v17)],
    targets: [
        .target(name: "MockStore", path: "Sources/Shared"),
        .testTarget(name: "MockStoreTests", dependencies: ["MockStore"], path: "Tests")
    ]
)
