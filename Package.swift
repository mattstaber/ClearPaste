// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "EasyPaste",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "EasyPaste", targets: ["EasyPaste"])],
    targets: [
        .target(name: "PasteCore"),
        .executableTarget(name: "EasyPaste", dependencies: ["PasteCore"]),
        .testTarget(name: "PasteCoreTests", dependencies: ["PasteCore", "EasyPaste"])
    ]
)
