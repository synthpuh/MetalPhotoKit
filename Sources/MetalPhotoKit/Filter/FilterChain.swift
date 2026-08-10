@preconcurrency import Metal

public struct FilterChain {
    private let context: MetalContext
    private let filters: [any Filter]

    public init(context: MetalContext, filters: [any Filter]) {
        self.context = context
        self.filters = filters
    }

    public func run(on source: any MTLTexture) throws -> any MTLTexture {
        guard !filters.isEmpty else { return source }

        let context = self.context
        guard let commandBuffer = context.commandQueue.makeCommandBuffer() else {
            throw MetalPhotoKitError.commandBufferCreationFailed
        }
        commandBuffer.label = "\(K.FilterChain.commandBufferLabelPrefix).\(filters.count)-filters"

        var current = source
        for filter in filters {
            let output = try filter.apply(to: current, commandBuffer: commandBuffer, context: context)

            // Only pool a texture once we know the GPU work encoded against
            // it — possibly still pending here — has actually completed.
            // Skip no-op filters (output === current) and the caller-owned
            // source, neither of which this chain may hand back.
            if output !== current, current !== source {
                let spent = current
                commandBuffer.addCompletedHandler { _ in
                    context.returnTexture(spent)
                }
            }
            current = output
        }

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        return current
    }
}
