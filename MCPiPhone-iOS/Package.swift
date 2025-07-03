// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MCPiPhone-iOS",
    platforms: [
        .iOS(.v15),
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MCPServer", targets: ["MCPServer"])
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.9.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "MCPServer",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "Logging", package: "swift-log")
            ]
        )
    ]
)