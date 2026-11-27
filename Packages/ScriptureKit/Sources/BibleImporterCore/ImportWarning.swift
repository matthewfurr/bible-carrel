/// A recoverable problem found while importing. Import continues; warnings are reported.
public struct ImportWarning: Error, CustomStringConvertible, Sendable, Equatable {
    public let message: String

    public init(_ message: String) {
        self.message = message
    }

    public var description: String { message }
}
