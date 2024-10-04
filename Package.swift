// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "WultraDigitalOnboarding",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(name: "WultraDigitalOnboarding", targets: ["WultraDigitalOnboarding"])
    ],
    dependencies: [
        .package(name: "PowerAuth2", url: "https://github.com/wultra/powerauth-mobile-sdk-spm.git", .upToNextMinor(from: "1.9.0")),
        .package(name: "WultraPowerAuthNetworking", url: "https://github.com/wultra/networking-apple.git", .upToNextMinor(from: "1.5.0"))
    ],
    targets: [
        .target(
            name: "WultraDigitalOnboarding",
            dependencies: ["PowerAuth2", .product(name: "PowerAuthCore", package: "PowerAuth2"), "WultraPowerAuthNetworking"],
            path: "Sources"
        )
    ],
    swiftLanguageVersions: [.v5]
)
