import Foundation

/// Replays canned chunks for any request made through `session()`, and records the last request
/// (with its body) so tests can assert on what a provider sent. A handler returning status 0
/// fails the load with `URLError.networkConnectionLost`.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) private static var _handler: (@Sendable (URLRequest) -> (HTTPURLResponse, [Data]))?
    nonisolated(unsafe) private static var _recordedRequest: URLRequest?
    nonisolated(unsafe) private static var _recordedBody: Data?
    private static let lock = NSLock()

    static var handler: (@Sendable (URLRequest) -> (HTTPURLResponse, [Data]))? {
        get { lock.withLock { _handler } }
        set { lock.withLock { _handler = newValue } }
    }
    static var recordedRequest: URLRequest? { lock.withLock { _recordedRequest } }
    static var recordedBody: Data? { lock.withLock { _recordedBody } }

    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let body = request.httpBody ?? request.httpBodyStream.map(Self.read)
        Self.lock.withLock {
            Self._recordedRequest = request
            Self._recordedBody = body
        }
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        let (response, chunks) = handler(request)
        if response.statusCode == 0 {
            client?.urlProtocol(self, didFailWithError: URLError(.networkConnectionLost))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        for chunk in chunks { client?.urlProtocol(self, didLoad: chunk) }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func read(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

import Testing

/// The one serialized parent of every suite that uses `StubURLProtocol`.
@Suite(.serialized) struct CloudProviderTests {}
