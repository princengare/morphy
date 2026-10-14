// swift-tools-version: 6.2

import PackageDescription

let webPSourceFolders = ["src/dec", "src/enc", "src/dsp", "src/utils", "src/mux", "sharpyuv"]

let package = Package(
    name: "Morphy",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Morphy", targets: ["MorphyApp"]),
        .library(name: "MorphyCore", targets: ["MorphyCore"])
    ],
    targets: [
        .target(
            name: "CWebP",
            path: "Vendor/libwebp",
            exclude: webPSourceFolders.flatMap { ["\($0)/Makefile.am", "\($0)/Makefile.in"] }
                + ["sharpyuv/libsharpyuv.rc", "sharpyuv/libsharpyuv.pc.in",
                   "src/mux/libwebpmux.rc", "src/mux/libwebpmux.pc.in"],
            sources: webPSourceFolders,
            publicHeadersPath: "include",
            cSettings: [.headerSearchPath(".")]
        ),
        .target(
            name: "MorphyCore",
            dependencies: ["CWebP"]
        ),
        .executableTarget(
            name: "MorphyApp",
            dependencies: ["MorphyCore"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "MorphyCoreTests",
            dependencies: ["MorphyCore"]
        ),
        .testTarget(
            name: "MorphyAppTests",
            dependencies: ["MorphyApp"]
        )
    ]
)
