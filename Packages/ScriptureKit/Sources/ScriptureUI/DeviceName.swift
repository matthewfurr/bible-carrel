/// The device a settings sentence names: "this Mac" on the Mac, "this iPhone" on the phone. One
/// source, so each sentence is written once and its tests can pin either device.
public enum DeviceName {
    #if os(macOS)
    public static let current = "Mac"
    #else
    public static let current = "iPhone"
    #endif
}
