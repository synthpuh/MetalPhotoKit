import Metal

public struct FilterChain {
    private let context: MetalContext
    private let filters: [any Filter]

    public init(context: MetalContext, filters: [any Filter]) {
        self.context = context
        self.filters = filters
    }

    public func run(on source: any MTLTexture) throws -> any MTLTexture {
        guard !filters.isEmpty else { return source }

        guard let commandBuffer = context.commandQueue.makeCommandBuffer() else {
            throw MetalPhotoKitError.commandBufferCreationFailed
        }
        commandBuffer.label = "\(K.FilterChain.commandBufferLabelPrefix).\(filters.count)-filters"

        var current = source
        for filter in filters {
            current = try filter.apply(to: current, commandBuffer: commandBuffer, context: context)
        }

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        return current
    }
}
