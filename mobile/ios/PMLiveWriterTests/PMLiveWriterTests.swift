import CryptoKit
import Foundation
import XCTest
@testable import PMLiveWriterCore

final class PMLiveWriterTests: XCTestCase {
  func testCanonicalFixtureMatchesServerByteForByte() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let still = directory.appendingPathComponent("still.heic")
    let motion = directory.appendingPathComponent("motion.mov")
    let output = directory.appendingPathComponent("fixture.pmlive")
    try Data([0x01, 0x02, 0x03]).write(to: still)
    try Data([0x04, 0x05]).write(to: motion)

    _ = try PMLiveWriter.write(
      PMLiveWriterInput(
        stillURL: still,
        motionURL: motion,
        outputURL: output,
        stillOriginalName: "IMG_0001.HEIC",
        motionOriginalName: "IMG_0001.MOV",
        stillUTI: "public.heic",
        motionUTI: "com.apple.quicktime-movie",
        createdUnixNano: -250_000_000,
        modifiedUnixNano: 1_700_000_000_500_000_000
      )
    )

    let encodedFixture = try XCTUnwrap(
      Bundle.module.url(
        forResource: "swift-canonical-v1.pmlive",
        withExtension: "base64",
        subdirectory: "Fixtures"
      )
    )
    let actualData = try Data(contentsOf: output)
    let encoded = try String(contentsOf: encodedFixture, encoding: .utf8)
    let expectedData = try XCTUnwrap(Data(base64Encoded: encoded, options: .ignoreUnknownCharacters))
    XCTAssertEqual(
      SHA256.hash(data: expectedData).map { String(format: "%02x", $0) }.joined(),
      "2338bb3dae91a895871776c0d7520b6328411ce3787a183ec8cd32423fe1e620",
      "portable fixture provenance changed"
    )
    let firstDifference = zip(actualData, expectedData).enumerated().first { $0.element.0 != $0.element.1 }
    XCTAssertEqual(actualData, expectedData, "first difference: \(String(describing: firstDifference))")
  }
}
