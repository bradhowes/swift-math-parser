// swift-tools-version:5.7

import PackageDescription

let package = Package(
  name: "swift-math-parser",
  platforms: [
    .iOS(.v13),
    .macOS(.v10_15),
    .tvOS(.v13),
    .watchOS(.v6),
  ],
  products: [
    .library(
      name: "MathParser",
      targets: ["MathParser"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-parsing", from: "0.12.0"),
  ],
  targets: [
    .target(
      name: "MathParser",
      dependencies: [.product(name: "Parsing", package: "swift-parsing")]
    ),
    .testTarget(
      name: "MathParserTests",
      dependencies: [.product(name: "Parsing", package: "swift-parsing"), "MathParser"]
    )
  ]
)

#if swift(>=5.6)
// Add the documentation compiler plugin if possible
package.dependencies.append(
  .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.3.0")
)
#endif
