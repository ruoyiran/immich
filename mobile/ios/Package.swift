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
      exclude: [
        "Messages.g.swift", "MessagesImpl.swift", "PHAssetExtensions.swift",
        "PHAssetResourceExtensions.swift",
      ],
      sources: ["PMLiveWriter.swift", "AppleLivePhotoWriter.swift"]
    ),
    .testTarget(
      name: "PMLiveWriterCoreTests",
      dependencies: ["PMLiveWriterCore"],
      path: "PMLiveWriterTests",
      resources: [.copy("Fixtures")]
    ),
    .target(
      name: "RemoteImageHTTPStatusCore",
      path: "Runner/Images",
      exclude: [
        "ImageProcessing.swift", "ImageRequest.swift", "LocalImages.g.swift",
        "LocalImagesImpl.swift",
        "RemoteImages.g.swift", "RemoteImagesImpl.swift", "Thumbhash.swift",
      ],
      sources: ["RemoteImageHTTPStatus.swift"]
    ),
    .testTarget(
      name: "RemoteImageHTTPStatusCoreTests",
      dependencies: ["RemoteImageHTTPStatusCore"],
      path: "RemoteImageTests"
    ),
  ]
)
