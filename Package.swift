// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-math-parser",
    platforms: [.iOS(.v13), .macOS(.v10_15), .tvOS(.v13), .watchOS(.v6)],
    products: [.library(name: "MathParser", targets: ["MathParser"])],
    dependencies: [.package(url: "https://github.com/pointfreeco/swift-parsing", from: "0.10.0")],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "MathParser",
            dependencies: [.product(name: "Parsing", package: "swift-parsing")]),
        .testTarget(
            name: "MathParserTests",
            dependencies: ["MathParser", .product(name: "Parsing", package: "swift-parsing")]),
    ]
)
