import Foundation
import PackagePlugin

@main
struct MetalShaderCompilerPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        let shadersDirectory = target.directoryURL.appending(path: "Shaders")

        let metalFiles = (try? FileManager.default.contentsOfDirectory(atPath: shadersDirectory.path))?
            .filter { $0.hasSuffix(".metal") }
            .sorted()
            ?? []

        guard !metalFiles.isEmpty else { return [] }

        let outputDirectory = context.pluginWorkDirectoryURL
        let metallibURL = outputDirectory.appending(path: "default.metallib")
        let inputURLs = metalFiles.map { shadersDirectory.appending(path: $0) }

        return [
            .buildCommand(
                displayName: "Compiling Metal shaders for \(target.name)",
                executable: URL(fileURLWithPath: "/usr/bin/xcrun"),
                arguments: ["metal", "-o", metallibURL.path] + inputURLs.map(\.path),
                inputFiles: inputURLs,
                outputFiles: [metallibURL]
            )
        ]
    }
}
