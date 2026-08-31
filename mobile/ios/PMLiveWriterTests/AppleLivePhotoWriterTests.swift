import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import XCTest

@testable import PMLiveWriterCore

final class AppleLivePhotoWriterTests: XCTestCase {
  func testWritesMatchingAppleAssetIdentifiersAndStillImageTimeTrack() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let sourceStill = directory.appendingPathComponent("source.heic")
    let sourceMotion = directory.appendingPathComponent("source.mov")
    try writeStillFixture(to: sourceStill)
    try await writeMotionFixture(to: sourceMotion)

    let identifier = "6C8B7670-6B20-4FEE-A040-E8F93511F5A1"
    let output = try await AppleLivePhotoWriter.write(
      AppleLivePhotoWriterInput(
        stillURL: sourceStill,
        motionURL: sourceMotion,
        outputDirectory: directory.appendingPathComponent("output"),
        assetIdentifier: identifier
      )
    )

    let source = try XCTUnwrap(CGImageSourceCreateWithURL(output.stillURL as CFURL, nil))
    let properties = try XCTUnwrap(
      CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
    let makerApple = try XCTUnwrap(
      properties[kCGImagePropertyMakerAppleDictionary] as? [String: Any])
    XCTAssertEqual(makerApple["17"] as? String, identifier)

    let motionAsset = AVURLAsset(url: output.motionURL)
    let metadata = try await motionAsset.load(.metadata)
    let contentIdentifier = metadata.first { $0.identifier == .quickTimeMetadataContentIdentifier }
    let contentIdentifierValue = try await contentIdentifier?.load(.stringValue)
    XCTAssertEqual(contentIdentifierValue, identifier)
    let location = metadata.first { $0.identifier == .quickTimeMetadataLocationISO6709 }
    let locationValue = try await location?.load(.stringValue)
    XCTAssertEqual(locationValue, "+37.3317-122.0301/")

    let metadataTracks = try await motionAsset.loadTracks(withMediaType: .metadata)
    XCTAssertFalse(
      metadataTracks.isEmpty, "paired video must contain the still-image-time metadata track")
  }

  func testPreservesEveryImageInTheHEICContainer() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let sourceStill = directory.appendingPathComponent("source.heic")
    let sourceMotion = directory.appendingPathComponent("source.mov")
    try writeStillFixture(to: sourceStill, imageCount: 2)
    try await writeMotionFixture(to: sourceMotion)

    let output = try await AppleLivePhotoWriter.write(
      AppleLivePhotoWriterInput(
        stillURL: sourceStill,
        motionURL: sourceMotion,
        outputDirectory: directory.appendingPathComponent("output"),
        assetIdentifier: UUID().uuidString
      )
    )
    let outputSource = try XCTUnwrap(CGImageSourceCreateWithURL(output.stillURL as CFURL, nil))
    XCTAssertEqual(CGImageSourceGetCount(outputSource), 2)
  }

  func testConvertsExternalPairForSimulatorProbe() async throws {
    let environment = ProcessInfo.processInfo.environment
    guard let stillPath = environment["IMMICH_LIVE_PHOTO_STILL"],
      let motionPath = environment["IMMICH_LIVE_PHOTO_MOTION"],
      let outputPath = environment["IMMICH_LIVE_PHOTO_OUTPUT"]
    else {
      throw XCTSkip(
        "Set IMMICH_LIVE_PHOTO_STILL, IMMICH_LIVE_PHOTO_MOTION and IMMICH_LIVE_PHOTO_OUTPUT")
    }
    let output = try await AppleLivePhotoWriter.write(
      AppleLivePhotoWriterInput(
        stillURL: URL(fileURLWithPath: stillPath),
        motionURL: URL(fileURLWithPath: motionPath),
        outputDirectory: URL(fileURLWithPath: outputPath),
        assetIdentifier: UUID().uuidString
      )
    )
    XCTAssertTrue(FileManager.default.fileExists(atPath: output.stillURL.path))
    XCTAssertTrue(FileManager.default.fileExists(atPath: output.motionURL.path))
  }

  private func writeStillFixture(to url: URL, imageCount: Int = 1) throws {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let context = try XCTUnwrap(
      CGContext(
        data: nil,
        width: 4,
        height: 4,
        bitsPerComponent: 8,
        bytesPerRow: 16,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )
    )
    context.setFillColor(CGColor(red: 0.2, green: 0.6, blue: 0.9, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
    let image = try XCTUnwrap(context.makeImage())
    let destination = try XCTUnwrap(
      CGImageDestinationCreateWithURL(
        url as CFURL, UTType.heic.identifier as CFString, imageCount, nil))
    for _ in 0..<imageCount {
      CGImageDestinationAddImage(destination, image, nil)
    }
    XCTAssertTrue(CGImageDestinationFinalize(destination))
  }

  private func writeMotionFixture(to url: URL) async throws {
    let writer = try AVAssetWriter(url: url, fileType: .mov)
    let location = AVMutableMetadataItem()
    location.identifier = .quickTimeMetadataLocationISO6709
    location.value = "+37.3317-122.0301/" as NSString
    writer.metadata = [location]
    let input = AVAssetWriterInput(
      mediaType: .video,
      outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.hevc,
        AVVideoWidthKey: 16,
        AVVideoHeightKey: 16,
      ]
    )
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
      assetWriterInput: input,
      sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: 16,
        kCVPixelBufferHeightKey as String: 16,
      ]
    )
    XCTAssertTrue(writer.canAdd(input))
    writer.add(input)
    XCTAssertTrue(writer.startWriting())
    writer.startSession(atSourceTime: .zero)
    while !input.isReadyForMoreMediaData {
      try await Task.sleep(for: .milliseconds(5))
    }
    var pixelBuffer: CVPixelBuffer?
    XCTAssertEqual(
      CVPixelBufferPoolCreatePixelBuffer(nil, try XCTUnwrap(adaptor.pixelBufferPool), &pixelBuffer),
      kCVReturnSuccess
    )
    XCTAssertTrue(adaptor.append(try XCTUnwrap(pixelBuffer), withPresentationTime: .zero))
    input.markAsFinished()
    await writer.finishWriting()
    if let error = writer.error {
      throw error
    }
  }
}
