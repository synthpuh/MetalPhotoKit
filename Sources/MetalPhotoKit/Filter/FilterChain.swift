@preconcurrency import Metal

public struct FilterChain {
    private let context: MetalContext
    private let filters: [any Filter]

    public init(context: MetalContext, filters: [any Filter]) {
        self.context = context
        self.filters = filters
    }

    /// Runs `filters` in sequence, threading each filter's output into the
    /// next, and returns the final texture.
    ///
    /// The returned texture is usually checked out from `context`'s texture
    /// pool; ownership passes to the caller, who must call
    /// ``MetalContext/returnTexture(_:)`` once done with it (e.g. after
    /// reading it back into a `CGImage`) or it stays checked out forever.
    /// Exception: if every filter is a no-op for its current parameters (or
    /// `filters` is empty), the result is `source` itself, unchanged — check
    /// the returned texture isn't `source` before returning it to the pool,
    /// or you'll hand the caller's own texture to the next unrelated checkout.
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
