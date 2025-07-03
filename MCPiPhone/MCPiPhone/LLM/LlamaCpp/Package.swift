// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LlamaCppSwift",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "LlamaCppSwift",
            targets: ["LlamaCppSwift"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "LlamaCppSwift",
            dependencies: ["LlamaCppBridge"],
            path: "Sources/LlamaCppSwift"
        ),
        .target(
            name: "LlamaCppBridge",
            dependencies: [],
            path: "Sources/LlamaCppBridge",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
                .define("GGML_USE_METAL", to: "1"),
                .define("GGML_USE_ACCELERATE", to: "1"),
                .unsafeFlags(["-O3", "-DNDEBUG"])
            ],
            linkerSettings: [
                .linkedFramework("Accelerate"),
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit"),
                .linkedFramework("MetalPerformanceShaders")
            ]
        ),
        .testTarget(
            name: "LlamaCppSwiftTests",
            dependencies: ["LlamaCppSwift"]
        ),
    ]
)