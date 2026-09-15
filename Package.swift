// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "ClearPaste",
    platforms: [.macOS("26.0")],
    products: [.executable(name: "ClearPaste", targets: ["ClearPaste"])],
    targets: [
        .target(name: "PasteCore"),
        .executableTarget(name: "ClearPaste", dependencies: ["PasteCore"]),
        .testTarget(name: "PasteCoreTests", dependencies: ["PasteCore", "ClearPaste"])
    ]
)
