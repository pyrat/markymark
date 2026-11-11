// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MarkyMark",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "MarkyMark", resources: [.process("Resources")]),
        .testTarget(name: "MarkyMarkTests", dependencies: ["MarkyMark"])
    ]
)
