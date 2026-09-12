/// One measured cell from a benchmark sweep — a filter or pipeline stage,
/// run at one point along whatever's being swept (an image resolution, a
/// blur radius, ...) — reduced to its mean and standard deviation across the
/// run's measured iterations.
public struct BenchmarkResult: Sendable {
    /// The swept variable's label for this row, e.g. an image resolution
    /// ("2048×1536") or a blur radius ("r=8").
    public let rowLabel: String

    /// The filter, pipeline stage, or path being measured, e.g.
    /// "GaussianBlur (r=8)", "Full chain", or "Live GPU".
    public let filterName: String

    public let meanMs: Double
    public let stddevMs: Double

    public init(rowLabel: String, filterName: String, meanMs: Double, stddevMs: Double) {
        self.rowLabel = rowLabel
        self.filterName = filterName
        self.meanMs = meanMs
        self.stddevMs = stddevMs
    }
}
