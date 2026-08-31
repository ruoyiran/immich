import AVFoundation
import CoreGraphics
import CoreMedia
import Foundation
import ImageIO
import Photos
import UniformTypeIdentifiers

struct AppleLivePhotoWriterInput {
  let stillURL: URL
  let motionURL: URL
  let outputDirectory: URL
  let assetIdentifier: String
}

struct AppleLivePhotoWriterOutput {
  let stillURL: URL
  let motionURL: URL
}

enum AppleLivePhotoWriterError: Error {
  case invalidStill
  case cannotCreateStill
  case cannotFinalizeStill
  case missingVideoTrack
  case cannotAddTrack(AVMediaType)
  case cannotCreateMetadataFormat(OSStatus)
  case cannotStartReading(Error?)
  case cannotStartWriting(Error?)
  case cannotAppendSample(Error?)
  case cannotAppendStillImageTime
  case cannotFinishWriting(Error?)
  case cannotSaveToPhotoLibrary(Error?)
}

enum AppleLivePhotoWriter {
  static func write(_ input: AppleLivePhotoWriterInput) async throws -> AppleLivePhotoWriterOutput {
    guard !input.assetIdentifier.isEmpty else {
      throw AppleLivePhotoWriterError.invalidStill
    }
    try FileManager.default.createDirectory(
      at: input.outputDirectory, withIntermediateDirectories: true)
    let stillURL = input.outputDirectory.appendingPathComponent("paired.heic")
    let motionURL = input.outputDirectory.appendingPathComponent("paired.mov")
    try? FileManager.default.removeItem(at: stillURL)
    try? FileManager.default.removeItem(at: motionURL)

    try writeStill(
      sourceURL: input.stillURL, outputURL: stillURL, assetIdentifier: input.assetIdentifier)
    do {
      try await writeMotion(
        sourceURL: input.motionURL, outputURL: motionURL, assetIdentifier: input.assetIdentifier)
    } catch {
      try? FileManager.default.removeItem(at: stillURL)
      try? FileManager.default.removeItem(at: motionURL)
      throw error
    }
    return AppleLivePhotoWriterOutput(stillURL: stillURL, motionURL: motionURL)
  }

  static func saveToPhotoLibrary(_ output: AppleLivePhotoWriterOutput, title: String) async throws
    -> String
  {
    try await withCheckedThrowingContinuation { continuation in
      var placeholder: PHObjectPlaceholder?
      PHPhotoLibrary.shared().performChanges {
        let request = PHAssetCreationRequest.forAsset()
        let stillOptions = PHAssetResourceCreationOptions()
        stillOptions.originalFilename = title
        request.addResource(with: .photo, fileURL: output.stillURL, options: stillOptions)

        let motionOptions = PHAssetResourceCreationOptions()
        let stem = URL(fileURLWithPath: title).deletingPathExtension().lastPathComponent
        motionOptions.originalFilename = stem + ".MOV"
        request.addResource(with: .pairedVideo, fileURL: output.motionURL, options: motionOptions)
        placeholder = request.placeholderForCreatedAsset
      } completionHandler: { success, error in
        if success, let identifier = placeholder?.localIdentifier {
          continuation.resume(returning: identifier)
        } else {
          continuation.resume(throwing: AppleLivePhotoWriterError.cannotSaveToPhotoLibrary(error))
        }
      }
    }
  }

  private static func writeStill(sourceURL: URL, outputURL: URL, assetIdentifier: String) throws {
    guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
      CGImageSourceGetCount(source) > 0,
      let imageType = CGImageSourceGetType(source)
    else {
      throw AppleLivePhotoWriterError.invalidStill
    }
    let imageCount = CGImageSourceGetCount(source)
    guard
      let destination = CGImageDestinationCreateWithURL(
        outputURL as CFURL,
        imageType,
        imageCount,
        nil
      )
    else {
      throw AppleLivePhotoWriterError.cannotCreateStill
    }
    for index in 0..<imageCount {
      var properties =
        (CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]) ?? [:]
      if index == 0 {
        var makerApple =
          (properties[kCGImagePropertyMakerAppleDictionary] as? [String: Any]) ?? [:]
        makerApple["17"] = assetIdentifier
        properties[kCGImagePropertyMakerAppleDictionary] = makerApple
      }
      CGImageDestinationAddImageFromSource(
        destination,
        source,
        index,
        properties as CFDictionary
      )
    }
    guard CGImageDestinationFinalize(destination) else {
      throw AppleLivePhotoWriterError.cannotFinalizeStill
    }
  }

  private static func writeMotion(sourceURL: URL, outputURL: URL, assetIdentifier: String)
    async throws
  {
    let asset = AVURLAsset(url: sourceURL)
    let tracks = try await asset.load(.tracks)
    guard tracks.contains(where: { $0.mediaType == .video }) else {
      throw AppleLivePhotoWriterError.missingVideoTrack
    }
    let duration = try await asset.load(.duration)
    let reader = try AVAssetReader(asset: asset)
    let writer = try AVAssetWriter(url: outputURL, fileType: .mov)

    let contentIdentifier = AVMutableMetadataItem()
    contentIdentifier.identifier = .quickTimeMetadataContentIdentifier
    contentIdentifier.value = assetIdentifier as NSString
    let sourceMetadata = try await asset.load(.metadata).filter {
      $0.identifier != .quickTimeMetadataContentIdentifier
    }
    writer.metadata = sourceMetadata + [contentIdentifier]

    var bindings: [(input: AVAssetWriterInput, output: AVAssetReaderTrackOutput)] = []
    for track in tracks {
      let binding = try await makeBinding(
        track: track,
        mediaType: track.mediaType,
        reader: reader,
        writer: writer
      )
      if track.mediaType == .video {
        binding.input.transform = try await track.load(.preferredTransform)
      }
      bindings.append(binding)
    }

    var stillImageTimeInput: AVAssetWriterInput?
    var metadataAdaptor: AVAssetWriterInputMetadataAdaptor?
    if try await !hasStillImageTimeMetadata(tracks) {
      let metadataDescription = try makeStillImageTimeFormatDescription()
      let input = AVAssetWriterInput(
        mediaType: .metadata,
        outputSettings: nil,
        sourceFormatHint: metadataDescription
      )
      guard writer.canAdd(input) else {
        throw AppleLivePhotoWriterError.cannotAddTrack(.metadata)
      }
      writer.add(input)
      stillImageTimeInput = input
      metadataAdaptor = AVAssetWriterInputMetadataAdaptor(assetWriterInput: input)
    }

    guard writer.startWriting() else {
      throw AppleLivePhotoWriterError.cannotStartWriting(writer.error)
    }
    guard reader.startReading() else {
      writer.cancelWriting()
      throw AppleLivePhotoWriterError.cannotStartReading(reader.error)
    }
    writer.startSession(atSourceTime: .zero)

    if let metadataAdaptor, let stillImageTimeInput {
      let stillImageTime = CMTimeMinimum(
        CMTime(seconds: 0.5, preferredTimescale: 600),
        duration
      )
      let marker = AVMutableMetadataItem()
      marker.identifier = AVMetadataIdentifier(
        rawValue: "mdta/com.apple.quicktime.still-image-time")
      marker.dataType = kCMMetadataBaseDataType_SInt8 as String
      marker.value = 0 as NSNumber
      let markerRange = CMTimeRange(
        start: stillImageTime,
        duration: CMTime(value: 1, timescale: 600)
      )
      guard metadataAdaptor.append(AVTimedMetadataGroup(items: [marker], timeRange: markerRange))
      else {
        reader.cancelReading()
        writer.cancelWriting()
        throw AppleLivePhotoWriterError.cannotAppendStillImageTime
      }
      stillImageTimeInput.markAsFinished()
    }

    try await copy(bindings: bindings, reader: reader, writer: writer)
  }

  private static func hasStillImageTimeMetadata(_ tracks: [AVAssetTrack]) async throws -> Bool {
    let stillImageTimeIdentifier = "mdta/com.apple.quicktime.still-image-time"
    for track in tracks where track.mediaType == .metadata {
      for description in try await track.load(.formatDescriptions) {
        let identifiers = CMMetadataFormatDescriptionGetIdentifiers(description) as? [String]
        if identifiers?.contains(stillImageTimeIdentifier) == true {
          return true
        }
      }
    }
    return false
  }

  private static func makeBinding(
    track: AVAssetTrack,
    mediaType: AVMediaType,
    reader: AVAssetReader,
    writer: AVAssetWriter
  ) async throws -> (input: AVAssetWriterInput, output: AVAssetReaderTrackOutput) {
    let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
    output.alwaysCopiesSampleData = false
    guard reader.canAdd(output) else {
      throw AppleLivePhotoWriterError.cannotAddTrack(mediaType)
    }
    reader.add(output)

    let formatDescription = try await track.load(.formatDescriptions).first
    let input = AVAssetWriterInput(
      mediaType: mediaType, outputSettings: nil, sourceFormatHint: formatDescription)
    guard writer.canAdd(input) else {
      throw AppleLivePhotoWriterError.cannotAddTrack(mediaType)
    }
    writer.add(input)
    return (input, output)
  }

  private static func makeStillImageTimeFormatDescription() throws -> CMFormatDescription {
    let specification: [String: Any] = [
      kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier as String:
        "mdta/com.apple.quicktime.still-image-time",
      kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType as String:
        kCMMetadataBaseDataType_SInt8 as String,
    ]
    var description: CMMetadataFormatDescription?
    let status = CMMetadataFormatDescriptionCreateWithMetadataSpecifications(
      allocator: kCFAllocatorDefault,
      metadataType: kCMMetadataFormatType_Boxed,
      metadataSpecifications: [specification] as CFArray,
      formatDescriptionOut: &description
    )
    guard status == noErr, let description else {
      throw AppleLivePhotoWriterError.cannotCreateMetadataFormat(status)
    }
    return description
  }

  private static func copy(
    bindings: [(input: AVAssetWriterInput, output: AVAssetReaderTrackOutput)],
    reader: AVAssetReader,
    writer: AVAssetWriter
  ) async throws {
    var active = Array(repeating: true, count: bindings.count)
    while active.contains(true) {
      var madeProgress = false
      for index in bindings.indices
      where active[index] && bindings[index].input.isReadyForMoreMediaData {
        let binding = bindings[index]
        if let sample = binding.output.copyNextSampleBuffer() {
          guard binding.input.append(sample) else {
            reader.cancelReading()
            writer.cancelWriting()
            throw AppleLivePhotoWriterError.cannotAppendSample(writer.error)
          }
        } else {
          binding.input.markAsFinished()
          active[index] = false
        }
        madeProgress = true
      }
      if reader.status == .failed {
        writer.cancelWriting()
        throw AppleLivePhotoWriterError.cannotStartReading(reader.error)
      }
      if !madeProgress {
        try await Task.sleep(nanoseconds: 1_000_000)
      }
    }

    await writer.finishWriting()
    guard reader.status == .completed else {
      throw AppleLivePhotoWriterError.cannotStartReading(reader.error)
    }
    guard writer.status == .completed else {
      throw AppleLivePhotoWriterError.cannotFinishWriting(writer.error)
    }
  }
}
