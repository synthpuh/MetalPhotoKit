enum Statistics {
    static func mean(_ values: [Double]) -> Double {
        values.reduce(0, +) / Double(values.count)
    }

    static func stddev(_ values: [Double]) -> Double {
        let m = mean(values)
        let variance = values.reduce(0) { $0 + ($1 - m) * ($1 - m) } / Double(values.count)
        return variance.squareRoot()
    }
}
