import Metal
import MetalPhotoKit
import Observation
import UIKit

/// Drives the demo screen: owns the GPU context, converts the selected
/// photo to a texture once, and re-runs the full filter chain whenever any
/// parameter or the source photo changes.
///
/// All three filters — exposure/contrast, blur, then LUT — are always in
/// the chain, in that fixed order, each carrying its own persistent
/// parameter state. The tab picker only selects which filter's sliders are
/// visible; it never adds or removes anything from the chain. Every re-run
/// starts from the original ``sourceTexture``, never from a previous run's
/// output, so parameter edits never compound. Defaults are identity for
/// every filter, and each filter has a no-op fast path at its default, so
/// an untouched photo passes through unchanged and costs nothing extra.
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
            parameterValues = parametersByFilterID[selectedFilterID]
                ?? selectedFilter.parameters.map(\.defaultValue)
        }
    }

    var parameterValues: [Float] {
        didSet {
            parametersByFilterID[selectedFilterID] = parameterValues
            scheduleReprocess()
        }
    }

    var selectedFilter: DemoFilterDescriptor {
        filterCatalog.first { $0.id == selectedFilterID } ?? filterCatalog[0]
    }

    let filterCatalog: [DemoFilterDescriptor]

    private let context: MetalContext
    private let textureLoader: TextureLoader
    private var sourceTexture: (any MTLTexture)?
    private var reprocessTask: Task<Void, Never>?
    private var parametersByFilterID: [DemoFilterDescriptor.ID: [Float]]

    private static let debounceDelay: Duration = .milliseconds(150)
    private static let activityIndicatorDelay: Duration = .milliseconds(100)

    init?(sourceImage: UIImage) {
        guard let context = try? MetalContext() else { return nil }

        let lutLoader = LUTLoader(context: context)
        guard let lutTextures = try? DemoLUTGenerator.looks.map({ look in
            try lutLoader.texture(fromCubeFileContents: DemoLUTGenerator.cubeFile(transform: look.transform))
        }) else { return nil }

        self.context = context
        self.textureLoader = TextureLoader(context: context)
        self.filterCatalog = DemoFilterCatalog.all(lutTextures: lutTextures)
        self.sourceImage = sourceImage
        self.parametersByFilterID = Dictionary(
            uniqueKeysWithValues: filterCatalog.map { ($0.id, $0.parameters.map(\.defaultValue)) }
        )

        let descriptor = filterCatalog[0]
        self.selectedFilterID = descriptor.id
        self.parameterValues = descriptor.parameters.map(\.defaultValue)

        loadSourceTexture()
    }

    /// Restores the currently selected filter's parameters to their
    /// defaults, leaving every other filter's saved values untouched.
    func resetParameters() {
        parameterValues = selectedFilter.parameters.map(\.defaultValue)
    }

    /// Restores every filter in the chain to its defaults, not just the
    /// currently selected one.
    func resetAll() {
        parametersByFilterID = Dictionary(
            uniqueKeysWithValues: filterCatalog.map { ($0.id, $0.parameters.map(\.defaultValue)) }
        )
        parameterValues = parametersByFilterID[selectedFilterID] ?? selectedFilter.parameters.map(\.defaultValue)
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

        let filters = filterCatalog.map { descriptor in
            descriptor.makeFilter(parametersByFilterID[descriptor.id] ?? descriptor.parameters.map(\.defaultValue))
        }
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
                let chain = FilterChain(context: context, filters: filters)
                let output = try await Task.detached(priority: .userInitiated) {
                    let resultTexture = try chain.run(on: sourceTexture)
                    // If every filter is at its no-op default (e.g. an untouched
                    // photo), the chain hands back `sourceTexture` itself rather
                    // than a pooled texture — returning that to the pool would let
                    // a later checkout overwrite our persistent source.
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
