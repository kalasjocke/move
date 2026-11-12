// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "move",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "6.2.0"),
    ],
    targets: [
        .target(name: "MoveCore", dependencies: ["Yams"]),
        .executableTarget(name: "move", dependencies: ["MoveCore"]),
        .testTarget(name: "MoveCoreTests", dependencies: ["MoveCore"]),
    ]
)
