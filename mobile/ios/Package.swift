// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "PMLiveWriterCore",
  platforms: [.macOS(.v13)],
  products: [.library(name: "PMLiveWriterCore", targets: ["PMLiveWriterCore"])],
  targets: [
    .target(
      name: "PMLiveWriterCore",
      path: "Runner/Sync",
      exclude: ["Messages.g.swift", "MessagesImpl.swift", "PHAssetExtensions.swift", "PHAssetResourceExtensions.swift"],
      sources: ["PMLiveWriter.swift"]
    ),
    .testTarget(
      name: "PMLiveWriterCoreTests",
      dependencies: ["PMLiveWriterCore"],
      path: "PMLiveWriterTests",
      resources: [.copy("Fixtures")]
    ),
  ]
)
