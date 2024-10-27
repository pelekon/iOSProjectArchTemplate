// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "ProjectMacros",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
        .macCatalyst(.v17)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ProjectMacros",
            targets: ["ProjectMacros"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "510.0.3")
    ],
    targets: [
        .macro(
            name: "Macros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ]
        ),
        .target(
            name: "ProjectMacros",
            dependencies: ["Macros"]
        ),
        .testTarget(
            name: "ProjectMacrosTests",
            dependencies: ["ProjectMacros"]),
    ]
)
