import Metal

public protocol Filter {
    func apply(to input: any MTLTexture, commandBuffer: any MTLCommandBuffer, context: MetalContext) throws -> any MTLTexture
}
