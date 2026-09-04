import Foundation
import XCTest

@testable import RemoteImageHTTPStatusCore

final class RemoteImageHTTPStatusTests: XCTestCase {
  func testReturnsStructuredErrorForServerFailure() throws {
    let response = try XCTUnwrap(
      HTTPURLResponse(
        url: URL(string: "https://example.test/thumbnail")!,
        statusCode: 503,
        httpVersion: nil,
        headerFields: nil
      )
    )

    let error = try XCTUnwrap(remoteImageHTTPError(from: response))

    XCTAssertEqual(error.code, "IOException")
    XCTAssertEqual(error.message, "HTTP 503: Service Unavailable")
  }

  func testAcceptsSuccessfulHTTPResponse() throws {
    let response = try XCTUnwrap(
      HTTPURLResponse(
        url: URL(string: "https://example.test/thumbnail")!,
        statusCode: 206,
        httpVersion: nil,
        headerFields: nil
      )
    )

    XCTAssertNil(remoteImageHTTPError(from: response))
  }
}
