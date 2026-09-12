import Foundation

/// Formats ``BenchmarkResult`` sweeps as a Markdown report, ready to paste
/// into the README.
public enum BenchmarkMarkdown {
    public static func render(
        deviceName: String,
        chainResults: [BenchmarkResult],
        pathResults: [BenchmarkResult],
        radiusResults: [BenchmarkResult]
    ) -> String {
        var sections: [String] = []

        sections.append("""
        ### GPU filter chain benchmark

        Device: \(deviceName). \(BenchmarkDefaults.measuredIterations) measured iterations per cell after \(BenchmarkDefaults.warmupIterations) warmup runs, mean ± stddev. GPU time from `MTLCommandBuffer.gpuStartTime`/`gpuEndTime`.
        """)

        sections.append(pivotTable(
            heading: "#### Per-filter and full-chain GPU time",
            description: "Chain = ExposureContrast → GaussianBlur(r=\(BenchmarkDefaults.blurRadius)) → LUT.",
            rowHeader: "Resolution",
            results: chainResults,
            columnOrder: ["ExposureContrast", "GaussianBlur (r=\(BenchmarkDefaults.blurRadius))", "LUT", "Full chain"]
        ))

        sections.append(renderPathComparison(pathResults))

        sections.append(pivotTable(
            heading: "#### Gaussian blur radius sweep",
            description: "Fixed resolution \(BenchmarkDefaults.radiusSweepResolution.label). The separable two-pass kernel does O(radius) work per pixel, so GPU time is expected to scale roughly linearly with radius.",
            rowHeader: "Radius",
            results: radiusResults,
            columnOrder: ["GaussianBlur"]
        ))

        return sections.joined(separator: "\n\n")
    }

    private static func pivotTable(
        heading: String,
        description: String,
        rowHeader: String,
        results: [BenchmarkResult],
        columnOrder: [String]
    ) -> String {
        var rowOrder: [String] = []
        var byRow: [String: [String: BenchmarkResult]] = [:]
        for result in results {
            if !rowOrder.contains(result.rowLabel) {
                rowOrder.append(result.rowLabel)
            }
            byRow[result.rowLabel, default: [:]][result.filterName] = result
        }

        var lines = [
            heading,
            "",
            description,
            "",
            "| \(rowHeader) | \(columnOrder.joined(separator: " | ")) |",
            "|" + String(repeating: "---|", count: columnOrder.count + 1),
        ]
        for row in rowOrder {
            let cells = columnOrder.map { column in byRow[row]?[column].map(format) ?? "—" }
            lines.append("| \(row) | \(cells.joined(separator: " | ")) |")
        }

        return lines.joined(separator: "\n")
    }

    private static func renderPathComparison(_ results: [BenchmarkResult]) -> String {
        var rowOrder: [String] = []
        var byRow: [String: [String: BenchmarkResult]] = [:]
        for result in results {
            if !rowOrder.contains(result.rowLabel) {
                rowOrder.append(result.rowLabel)
            }
            byRow[result.rowLabel, default: [:]][result.filterName] = result
        }

        var lines = [
            "#### Readback path vs. live drawable path",
            "",
            "Readback = chain + `getBytes` + `CGImage` (the path any non-live consumer takes). Live = chain + GPU resample into a \(BenchmarkDefaults.liveDrawableSize.width)×\(BenchmarkDefaults.liveDrawableSize.height) drawable-sized texture in one command buffer, no CPU copy — what `FilterChainMetalView` does per frame.",
            "",
            "| Resolution | Chain GPU | Readback CPU (getBytes+CGImage) | Readback path total | Live path GPU | Live vs. readback |",
            "|---|---|---|---|---|---|",
        ]
        for row in rowOrder {
            guard
                let chainGPU = byRow[row]?["Chain GPU"],
                let readbackCPU = byRow[row]?["Readback CPU"],
                let readbackTotal = byRow[row]?["Readback total"],
                let liveGPU = byRow[row]?["Live GPU"]
            else { continue }

            let speedup = readbackTotal.meanMs / liveGPU.meanMs
            lines.append(
                "| \(row) | \(format(chainGPU)) | \(format(readbackCPU)) | \(format(readbackTotal)) | \(format(liveGPU)) | \(String(format: "%.1f", speedup))× faster |"
            )
        }

        return lines.joined(separator: "\n")
    }

    private static func format(_ result: BenchmarkResult) -> String {
        String(format: "%.2f ± %.2f ms", result.meanMs, result.stddevMs)
    }
}
