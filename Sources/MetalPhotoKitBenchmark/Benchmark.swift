import BenchmarkCore
import Foundation

@main
struct Benchmark {
    static func main() {
        do {
            let runner = try BenchmarkRunner()

            FileHandleOutput.printProgress("Running filter chain sweep...")
            let chainResults = try runner.runFilterChainSweep()

            FileHandleOutput.printProgress("Running readback vs. live path comparison...")
            let pathResults = try runner.runPathComparison()

            FileHandleOutput.printProgress("Running blur radius sweep...")
            let radiusResults = try runner.runRadiusSweep()

            print("")
            print(BenchmarkMarkdown.render(
                deviceName: runner.deviceName,
                chainResults: chainResults,
                pathResults: pathResults,
                radiusResults: radiusResults
            ))
        } catch {
            FileHandleOutput.printError(error.localizedDescription)
            exit(1)
        }
    }
}

enum FileHandleOutput {
    static func printProgress(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }

    static func printError(_ message: String) {
        FileHandle.standardError.write(Data(("Error: " + message + "\n").utf8))
    }
}
