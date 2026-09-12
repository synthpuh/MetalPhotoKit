/// An image size to benchmark at, paired with a display label for reports.
public struct Resolution: Sendable {
    public let label: String
    public let width: Int
    public let height: Int

    public init(label: String, width: Int, height: Int) {
        self.label = label
        self.width = width
        self.height = height
    }
}
