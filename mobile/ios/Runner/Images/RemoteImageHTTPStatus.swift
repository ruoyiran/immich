import Foundation

struct RemoteImageHTTPFailure: Error, Equatable {
  let statusCode: Int

  var code: String { "IOException" }

  var message: String {
    let reason = HTTPURLResponse.localizedString(forStatusCode: statusCode).capitalized
    return "HTTP \(statusCode): \(reason)"
  }
}

func remoteImageHTTPError(from response: URLResponse?) -> RemoteImageHTTPFailure? {
  guard let response = response as? HTTPURLResponse,
    !(200...299).contains(response.statusCode)
  else {
    return nil
  }
  return RemoteImageHTTPFailure(statusCode: response.statusCode)
}
