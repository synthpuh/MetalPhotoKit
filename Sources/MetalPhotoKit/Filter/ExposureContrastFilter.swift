import Metal

/// Adjusts exposure (in stops) and contrast around mid-gray via the
/// `exposureContrast` compute kernel.
public struct ExposureContrastFilter: Filter {
    /// Exposure adjustment in stops (EV), clamped to ``K/ExposureContrast/exposureRange``.
    public let exposure: Float

    /// Contrast multiplier around mid-gray, clamped to ``K/ExposureContrast/contrastRange``.
    public let contrast: Float

    public init(exposure: Float, contrast: Float) {
        self.exposure = exposure.clamped(to: K.ExposureContrast.exposureRange)
        self.contrast = contrast.clamped(to: K.ExposureContrast.contrastRange)
    }

    public func apply(to input: any MTLTexture, commandBuffer: any MTLCommandBuffer, context: MetalContext) throws -> any MTLTexture {
        let pipelineState = try context.computePipelineState(function: K.ExposureContrast.functionName)

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: input.pixelFormat,
            width: input.width,
            height: input.height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]

        guard let output = context.device.makeTexture(descriptor: descriptor) else {
            throw MetalPhotoKitError.textureCreationFailed
        }
        output.label = "\(K.Texture.textureLabelPrefix).exposure-contrast"

        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw MetalPhotoKitError.commandEncoderCreationFailed
        }
        encoder.label = K.ExposureContrast.encoderLabel
        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(input, index: 0)
        encoder.setTexture(output, index: 1)

        var params = ExposureContrastParams(exposure: exposure, contrast: contrast)
        encoder.setBytes(&params, length: MemoryLayout<ExposureContrastParams>.stride, index: 0)

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

/// Mirrors the Metal-side `ExposureContrastParams` struct layout exactly.
private struct ExposureContrastParams {
    var exposure: Float
    var contrast: Float
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
