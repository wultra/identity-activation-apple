// swift-tools-version:5.7

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
        .package(url: "https://github.com/wultra/powerauth-mobile-sdk-spm.git", .upToNextMinor(from: "1.7.8")),
        .package(url: "https://github.com/wultra/networking-apple.git", .upToNextMinor(from: "1.1.8"))
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
