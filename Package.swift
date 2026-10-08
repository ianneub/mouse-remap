// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "MouseRemap",
  platforms: [.macOS(.v15)],
  targets: [
    .executableTarget(
      name: "MouseRemap",
      swiftSettings: [.swiftLanguageMode(.v5)]
    ),
  ]
)
