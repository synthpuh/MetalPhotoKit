import Testing
import Metal
import MetalPerformanceShaders
import BenchmarkCore

struct BenchmarkSuiteTests {

    /// Runs the full `BenchmarkCore` sweep and prints its Markdown report —
    /// a measurement harness for the README, not a pass/fail check, so it
    /// makes no assertions. Skipped rather than failed when there's no real
    /// GPU to read command buffer timestamps from, e.g. the iOS Simulator.
    @Test(.enabled(if: MTLCreateSystemDefaultDevice().map(MPSSupportsMTLDevice) ?? false))
    func printsFullBenchmarkReport() throws {
        let runner = try BenchmarkRunner()

        let chainResults = try runner.runFilterChainSweep()
        let pathResults = try runner.runPathComparison()
        let radiusResults = try runner.runRadiusSweep()

        print(BenchmarkMarkdown.render(
            deviceName: runner.deviceName,
            chainResults: chainResults,
            pathResults: pathResults,
            radiusResults: radiusResults
        ))
    }
}
