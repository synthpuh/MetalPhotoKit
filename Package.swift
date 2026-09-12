// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MetalPhotoKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "MetalPhotoKit",
            targets: ["MetalPhotoKit"]
        ),
        .executable(
            name: "metalphotokit-benchmark",
            targets: ["MetalPhotoKitBenchmark"]
        ),
        .library(
            name: "BenchmarkCore",
            targets: ["BenchmarkCore"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "MetalPhotoKit",
            exclude: ["Shaders"],
            resources: [
                .copy("Resources/SampleImage.png"),
                .copy("Resources/Neutral.cube")
            ],
            plugins: ["MetalShaderCompilerPlugin"]
        ),
        .target(
            name: "BenchmarkCore",
            dependencies: ["MetalPhotoKit"]
        ),
        .executableTarget(
            name: "MetalPhotoKitBenchmark",
            dependencies: ["BenchmarkCore"]
        ),
        .testTarget(
            name: "MetalPhotoKitTests",
            dependencies: ["MetalPhotoKit"]
        ),
        .plugin(
            name: "MetalShaderCompilerPlugin",
            capability: .buildTool()
        ),
    ],
    swiftLanguageModes: [.v6]
)
