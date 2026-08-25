import Metal

/// Grades an image through a 3D LUT (color lookup table), blending between
/// the original and fully graded result via `intensity`.
///
/// Build `lutTexture` once with ``LUTLoader`` — from a `.cube` file or its
/// bundled neutral table — and reuse it across filter instances; this filter
/// only samples it, it never uploads or owns it.
public struct LUTFilter: Filter {
    /// The 3D lookup table to grade through, previously uploaded by ``LUTLoader``.
    public let lutTexture: any MTLTexture

    /// Blend between the original color (0) and the fully graded color (1),
    /// clamped to ``K/LUT/intensityRange``.
    public let intensity: Float

    public init(lutTexture: any MTLTexture, intensity: Float = 1) {
        self.lutTexture = lutTexture
        self.intensity = intensity.clamped(to: K.LUT.intensityRange)
    }

    public func apply(to input: any MTLTexture, commandBuffer: any MTLCommandBuffer, context: MetalContext) throws -> any MTLTexture {
        guard intensity > 0 else { return input }

        let pipelineState = try context.computePipelineState(function: K.LUT.functionName)

        let output = try context.checkoutTexture(
            width: input.width,
            height: input.height,
            pixelFormat: input.pixelFormat
        )

        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw MetalPhotoKitError.commandEncoderCreationFailed
        }
        encoder.label = K.LUT.encoderLabel
        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(input, index: 0)
        encoder.setTexture(output, index: 1)
        encoder.setTexture(lutTexture, index: 2)

        var params = LUTParams(intensity: intensity)
        encoder.setBytes(&params, length: MemoryLayout<LUTParams>.stride, index: 0)

        let threadsPerThreadgroup = MTLSize(
            width: pipelineState.threadExecutionWidth,
            height: pipelineState.maxTotalThreadsPerThreadgroup / pipelineState.threadExecutionWidth,
            depth: 1
        )
        let threadgroupCount = MTLSize(
            width: (output.width + threadsPerThreadgroup.width - 1) / threadsPerThreadgroup.width,
            height: (output.height + threadsPerThreadgroup.height - 1) / threadsPerThreadgroup.height,
            depth: 1
        )
        encoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadsPerThreadgroup)
        encoder.endEncoding()

        return output
    }
}

/// Mirrors the Metal-side `LUTParams` struct layout exactly.
private struct LUTParams {
    var intensity: Float
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
