// swift-tools-version: 5.9
import PackageDescription
import Foundation

let rustLibrary = ProcessInfo.processInfo.environment["SUIZAI_RUST_LIB_DIR"] ?? "\(FileManager.default.currentDirectoryPath)/ios/.rust/host"

let package = Package(
    name: "SuizaiMockStore",
    platforms: [.macOS(.v13), .iOS(.v17)],
    targets: [
        .target(name: "SuizaiBridge", path: "Sources/Bridge", publicHeadersPath: "include"),
        .target(name: "MockStore", dependencies: ["SuizaiBridge"], path: "Sources/Shared",
                linkerSettings: [.unsafeFlags(["-L", rustLibrary, "-lsuizai_core"])]),
        .testTarget(name: "MockStoreTests", dependencies: ["MockStore"], path: "Tests")
    ]
)
