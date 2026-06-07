// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "flutter_bicubic_resize",
    platforms: [
        .iOS("13.0"),
        .macOS("10.15")
    ],
    products: [
        .library(name: "flutter-bicubic-resize", targets: ["flutter_bicubic_resize"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "flutter_bicubic_resize",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            cSettings: [
                // Public C headers (resize.h) live here; resize.c includes them by name.
                .headerSearchPath("include/flutter_bicubic_resize"),
                // FFI symbols must stay exported (mirrors podspec OTHER_CFLAGS).
                .unsafeFlags(["-fvisibility=default"])
            ]
        )
    ]
)
