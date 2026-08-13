import Foundation

struct PMLiveWriterInput {
  let stillURL: URL
  let motionURL: URL
  let outputURL: URL
  let stillOriginalName: String
  let motionOriginalName: String
  let stillUTI: String
  let motionUTI: String
  let createdUnixNano: Int64
  let modifiedUnixNano: Int64
}

enum PMLiveWriterError: Error {
  case invalidInput(String)
  case fileTooLarge
}

enum PMLiveWriter {
  private static let blockSize = 512
  private static let copyBufferSize = 1024 * 1024
  private static let maximumUSTARSize: UInt64 = 0o77_777_777_777

  private struct Manifest: Encodable {
    let version = 1
    let container = "pmlive-v1"
    let createdUnixNano: String
    let modifiedUnixNano: String
    let resources: [Resource]

    enum CodingKeys: String, CodingKey {
      case version
      case container
      case createdUnixNano = "created_unix_nano"
      case modifiedUnixNano = "modified_unix_nano"
      case resources
    }
  }

  private struct Resource: Encodable {
    let role: String
    let entry: String
    let originalName: String
    let uti: String
    let length: UInt64

    enum CodingKeys: String, CodingKey {
      case role
      case entry
      case originalName = "original_name"
      case uti
      case length
    }
  }

  static func write(_ input: PMLiveWriterInput) throws -> URL {
    let stillSize = try regularFileSize(input.stillURL)
    let motionSize = try regularFileSize(input.motionURL)
    guard !input.stillOriginalName.isEmpty, !input.motionOriginalName.isEmpty,
          !input.stillUTI.isEmpty, !input.motionUTI.isEmpty else {
      throw PMLiveWriterError.invalidInput("PMLive resource metadata is incomplete")
    }

    let manifest = Manifest(
      createdUnixNano: String(input.createdUnixNano),
      modifiedUnixNano: String(input.modifiedUnixNano),
      resources: [
        Resource(
          role: "still",
          entry: "still",
          originalName: input.stillOriginalName,
          uti: input.stillUTI,
          length: stillSize
        ),
        Resource(
          role: "paired_video",
          entry: "motion",
          originalName: input.motionOriginalName,
          uti: input.motionUTI,
          length: motionSize
        ),
      ]
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    let manifestData = try encoder.encode(manifest)

    let directory = input.outputURL.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let temporaryURL = directory.appendingPathComponent(".\(input.outputURL.lastPathComponent).\(UUID().uuidString).part")
    guard FileManager.default.createFile(atPath: temporaryURL.path, contents: nil) else {
      throw PMLiveWriterError.invalidInput("Cannot create PMLive output")
    }

    do {
      let output = try FileHandle(forWritingTo: temporaryURL)
      do {
        try writeEntry(name: "manifest.json", data: manifestData, output: output)
        try writeEntry(name: "still", file: input.stillURL, size: stillSize, output: output)
        try writeEntry(name: "motion", file: input.motionURL, size: motionSize, output: output)
        try output.write(contentsOf: Data(repeating: 0, count: blockSize * 2))
        try output.synchronize()
        try output.close()
      } catch {
        try? output.close()
        throw error
      }

      if FileManager.default.fileExists(atPath: input.outputURL.path) {
        _ = try FileManager.default.replaceItemAt(input.outputURL, withItemAt: temporaryURL)
      } else {
        try FileManager.default.moveItem(at: temporaryURL, to: input.outputURL)
      }
      return input.outputURL
    } catch {
      try? FileManager.default.removeItem(at: temporaryURL)
      throw error
    }
  }

  private static func regularFileSize(_ url: URL) throws -> UInt64 {
    let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
    guard values.isRegularFile == true, let size = values.fileSize, size >= 0 else {
      throw PMLiveWriterError.invalidInput("PMLive resource is not a regular file")
    }
    let unsigned = UInt64(size)
    guard unsigned <= maximumUSTARSize else {
      throw PMLiveWriterError.fileTooLarge
    }
    return unsigned
  }

  private static func writeEntry(name: String, data: Data, output: FileHandle) throws {
    let size = UInt64(data.count)
    try output.write(contentsOf: header(name: name, size: size))
    try output.write(contentsOf: data)
    try writePadding(size: size, output: output)
  }

  private static func writeEntry(name: String, file: URL, size: UInt64, output: FileHandle) throws {
    try output.write(contentsOf: header(name: name, size: size))
    let input = try FileHandle(forReadingFrom: file)
    do {
      var copied: UInt64 = 0
      while copied < size {
        let remaining = size - copied
        let count = Int(min(UInt64(copyBufferSize), remaining))
        guard let chunk = try input.read(upToCount: count), !chunk.isEmpty else {
          throw PMLiveWriterError.invalidInput("PMLive resource changed while reading")
        }
        copied += UInt64(chunk.count)
        try output.write(contentsOf: chunk)
      }
      if let extra = try input.read(upToCount: 1), !extra.isEmpty {
        throw PMLiveWriterError.invalidInput("PMLive resource changed while reading")
      }
      try input.close()
    } catch {
      try? input.close()
      throw error
    }
    try writePadding(size: size, output: output)
  }

  private static func writePadding(size: UInt64, output: FileHandle) throws {
    let remainder = Int(size % UInt64(blockSize))
    if remainder != 0 {
      try output.write(contentsOf: Data(repeating: 0, count: blockSize - remainder))
    }
  }

  private static func header(name: String, size: UInt64) throws -> Data {
    guard let nameBytes = name.data(using: .utf8), nameBytes.count <= 100, size <= maximumUSTARSize else {
      throw PMLiveWriterError.invalidInput("USTAR entry is out of range")
    }
    var bytes = [UInt8](repeating: 0, count: blockSize)
    bytes.replaceSubrange(0..<nameBytes.count, with: nameBytes)
    try writeOctal(0o644, width: 8, offset: 100, bytes: &bytes)
    try writeOctal(0, width: 8, offset: 108, bytes: &bytes)
    try writeOctal(0, width: 8, offset: 116, bytes: &bytes)
    try writeOctal(size, width: 12, offset: 124, bytes: &bytes)
    try writeOctal(0, width: 12, offset: 136, bytes: &bytes)
    for index in 148..<156 { bytes[index] = 0x20 }
    bytes[156] = Character("0").asciiValue!
    let magic = Array("ustar\0".utf8)
    bytes.replaceSubrange(257..<(257 + magic.count), with: magic)
    bytes[263] = Character("0").asciiValue!
    bytes[264] = Character("0").asciiValue!
    let checksum = bytes.reduce(UInt64(0)) { $0 + UInt64($1) }
    let checksumText = String(format: "%06llo", checksum)
    guard checksumText.utf8.count == 6 else {
      throw PMLiveWriterError.invalidInput("USTAR checksum is out of range")
    }
    bytes.replaceSubrange(148..<154, with: checksumText.utf8)
    bytes[154] = 0
    bytes[155] = 0x20
    return Data(bytes)
  }

  private static func writeOctal(_ value: UInt64, width: Int, offset: Int, bytes: inout [UInt8]) throws {
    let text = String(value, radix: 8)
    guard text.utf8.count <= width - 1 else {
      throw PMLiveWriterError.fileTooLarge
    }
    let padded = String(repeating: "0", count: width - 1 - text.utf8.count) + text
    bytes.replaceSubrange(offset..<(offset + width - 1), with: padded.utf8)
    bytes[offset + width - 1] = 0
  }
}
