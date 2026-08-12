import Metal
import MetalPhotoKit
import Observation
import UIKit

/// Drives the demo screen: owns the GPU context, converts the selected
/// photo to a texture once, and re-runs the selected filter whenever its
/// parameters, the chosen filter, or the source photo change.
///
/// Filtering is non-destructive: every re-run starts from the original
/// ``sourceTexture``, never from a previous filter's output, so parameter
/// edits never compound. Each filter keeps its own parameter values, so
/// switching filters and back doesn't lose earlier tweaks.
@MainActor
@Observable
final class FilterDemoViewModel {
    private(set) var filteredImage: UIImage?
    private(set) var isProcessing = false
    private(set) var errorMessage: String?

    var sourceImage: UIImage {
        didSet { loadSourceTexture() }
    }

    var selectedFilterID: DemoFilterDescriptor.ID {
        didSet {
            parameterValues = parametersByFilterID[selectedFilterID] ?? selectedFilter.parameters.map(\.defaultValue)
        }
    }

    var parameterValues: [Float] {
        didSet {
            parametersByFilterID[selectedFilterID] = parameterValues
            scheduleReprocess()
        }
    }

    var selectedFilter: DemoFilterDescriptor {
        DemoFilterCatalog.all.first { $0.id == selectedFilterID } ?? DemoFilterCatalog.all[0]
    }

    private let context: MetalContext
    private let textureLoader: TextureLoader
    private var sourceTexture: (any MTLTexture)?
    private var reprocessTask: Task<Void, Never>?
    private var parametersByFilterID: [DemoFilterDescriptor.ID: [Float]]

    private static let debounceDelay: Duration = .milliseconds(150)
    private static let activityIndicatorDelay: Duration = .milliseconds(100)

    init?(sourceImage: UIImage) {
        guard let context = try? MetalContext() else { return nil }
        self.context = context
        self.textureLoader = TextureLoader(context: context)
        self.sourceImage = sourceImage
        self.parametersByFilterID = Dictionary(
            uniqueKeysWithValues: DemoFilterCatalog.all.map { ($0.id, $0.parameters.map(\.defaultValue)) }
        )

        let descriptor = DemoFilterCatalog.all[0]
        self.selectedFilterID = descriptor.id
        self.parameterValues = descriptor.parameters.map(\.defaultValue)

        loadSourceTexture()
    }

    /// Restores the currently selected filter's parameters to their
    /// defaults, leaving every other filter's saved values untouched.
    func resetParameters() {
        parameterValues = selectedFilter.parameters.map(\.defaultValue)
    }

    private func loadSourceTexture() {
        guard let cgImage = sourceImage.cgImage else {
            errorMessage = "Selected photo has no backing image data."
            return
        }
        do {
            sourceTexture = try textureLoader.texture(from: cgImage)
            errorMessage = nil
            scheduleReprocess()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func scheduleReprocess() {
        reprocessTask?.cancel()
        guard let sourceTexture else { return }

        let filter = selectedFilter.makeFilter(parameterValues)
        let context = context
        let loader = textureLoader

        reprocessTask = Task {
            try? await Task.sleep(for: Self.debounceDelay)
            guard !Task.isCancelled else { return }

            let indicatorTask = Task {
                try? await Task.sleep(for: Self.activityIndicatorDelay)
                guard !Task.isCancelled else { return }
                isProcessing = true
            }

            do {
                let chain = FilterChain(context: context, filters: [filter])
                let output = try await Task.detached(priority: .userInitiated) {
                    let resultTexture = try chain.run(on: sourceTexture)
                    // A no-op filter (e.g. blur at radius 0) hands back `sourceTexture`
                    // itself rather than a pooled texture — returning that to the pool
                    // would let a later checkout overwrite our persistent source.
                    defer {
                        if resultTexture !== sourceTexture {
                            context.returnTexture(resultTexture)
                        }
                    }
                    return try loader.cgImage(from: resultTexture)
                }.value

                indicatorTask.cancel()
                guard !Task.isCancelled else { return }
                filteredImage = UIImage(cgImage: output)
                errorMessage = nil
            } catch {
                indicatorTask.cancel()
                errorMessage = error.localizedDescription
            }

            isProcessing = false
        }
    }
}
