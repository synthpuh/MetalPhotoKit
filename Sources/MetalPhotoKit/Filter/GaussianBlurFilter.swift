@preconcurrency import Metal

/// Separable Gaussian blur: a horizontal pass followed by a vertical pass,
/// each a 1D convolution over `radius` pixels either side of center via the
/// `gaussianBlur` compute kernel.
public struct GaussianBlurFilter: Filter {
    /// Blur radius in pixels, clamped to ``K/GaussianBlur/radiusRange``.
    public let radius: Int

    public init(radius: Int) {
        self.radius = radius.clamped(to: K.GaussianBlur.radiusRange)
    }

    public func apply(to input: any MTLTexture, commandBuffer: any MTLCommandBuffer, context: MetalContext) throws -> any MTLTexture {
        guard radius > 0 else { return input }

        let pipelineState = try context.computePipelineState(function: K.GaussianBlur.functionName)
        let weights = Self.weights(radius: radius)

        let intermediate = try context.checkoutTexture(
            width: input.width,
            height: input.height,
            pixelFormat: input.pixelFormat
        )
        let output = try context.checkoutTexture(
            width: input.width,
            height: input.height,
            pixelFormat: input.pixelFormat
        )

        try encodePass(
            source: input,
            destination: intermediate,
            direction: SIMD2<Int32>(1, 0),
            weights: weights,
            pipelineState: pipelineState,
            commandBuffer: commandBuffer
        )
        try encodePass(
            source: intermediate,
            destination: output,
            direction: SIMD2<Int32>(0, 1),
            weights: weights,
            pipelineState: pipelineState,
            commandBuffer: commandBuffer
        )

        // `intermediate` is purely internal to this pass; safe to pool once
        // the GPU work reading it has actually finished, not before.
        commandBuffer.addCompletedHandler { _ in
            context.returnTexture(intermediate)
        }

        return output
    }

    private func encodePass(
        source: any MTLTexture,
        destination: any MTLTexture,
        direction: SIMD2<Int32>,
        weights: [Float],
        pipelineState: any MTLComputePipelineState,
        commandBuffer: any MTLCommandBuffer
    ) throws {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw MetalPhotoKitError.commandEncoderCreationFailed
        }
        encoder.label = K.GaussianBlur.encoderLabel
        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(source, index: 0)
        encoder.setTexture(destination, index: 1)
        encoder.setBytes(weights, length: MemoryLayout<Float>.stride * weights.count, index: 0)

        var radiusValue = Int32(radius)
        encoder.setBytes(&radiusValue, length: MemoryLayout<Int32>.stride, index: 1)

        var directionValue = direction
        encoder.setBytes(&directionValue, length: MemoryLayout<SIMD2<Int32>>.stride, index: 2)

        let threadsPerThreadgroup = MTLSize(
            width: pipelineState.threadExecutionWidth,
            height: pipelineState.maxTotalThreadsPerThreadgroup / pipelineState.threadExecutionWidth,
            depth: 1
        )
        let threadgroupCount = MTLSize(
            width: (destination.width + threadsPerThreadgroup.width - 1) / threadsPerThreadgroup.width,
            height: (destination.height + threadsPerThreadgroup.height - 1) / threadsPerThreadgroup.height,
            depth: 1
        )
        encoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadsPerThreadgroup)
        encoder.endEncoding()
    }

    /// One-sided Gaussian weights `[center, ±1, ±2, ..., ±radius]`, normalized to sum to 1 over the full symmetric kernel.
    static func weights(radius: Int) -> [Float] {
        let sigma = Float(radius) / 3
        var weights = [Float](repeating: 0, count: radius + 1)
        var total: Float = 0

        for i in 0...radius {
            let x = Float(i)
            let weight = exp(-(x * x) / (2 * sigma * sigma))
            weights[i] = weight
            total += i == 0 ? weight : weight * 2
        }
        for i in 0...radius {
            weights[i] /= total
        }

        return weights
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
