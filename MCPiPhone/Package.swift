// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MCPiPhone",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "MCPiPhone",
            targets: ["MCPiPhone"]
        ),
        .executable(
            name: "mcp-ios-server",
            targets: ["MCPServer"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.9.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "MCPiPhone",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "Logging", package: "swift-log"),
            ]
        ),
        .executableTarget(
            name: "MCPServer",
            dependencies: ["MCPiPhone"]
        ),
        .testTarget(
            name: "MCPiPhoneTests",
            dependencies: ["MCPiPhone"]
        ),
    ]
)