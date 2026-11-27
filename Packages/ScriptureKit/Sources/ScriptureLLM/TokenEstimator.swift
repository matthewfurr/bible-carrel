/// The spec's estimate for routing: about one token per four characters, rounded up. Good
/// enough to decide whether a request fits the on-device window with the margin `OnDeviceFit`
/// keeps; never used for billing.
public enum TokenEstimator {
    public static func estimate(_ text: String) -> Int {
        let count = text.utf8.count
        return count == 0 ? 0 : (count + 3) / 4
    }
}
