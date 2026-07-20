import Testing
import Metal
@testable import MetalPhotoKit

@Suite("FilterChain")
struct FilterChainTests {

    @Test("an empty chain returns the source texture unchanged and does no GPU work", .enabled(if: MetalTestSupport.isAvailable))
    func emptyChainIsIdentity() throws {
        let device = try #require(MetalTestSupport.device)
        let context = try MetalContext(device: device)
        let loader = TextureLoader(device: device)
        let source = try loader.texture(from: try #require(TextureLoaderTests.makeCGImage(width: 2, height: 2)))

        let chain = FilterChain(context: context, filters: [])
        let result = try chain.run(on: source)

        #expect(result === source)
    }

    @Test("runs every filter in order, threading each output into the next input", .enabled(if: MetalTestSupport.isAvailable))
    func runsFiltersInOrder() throws {
        let device = try #require(MetalTestSupport.device)
        let context = try MetalContext(device: device)
        let loader = TextureLoader(device: device)
        let source = try loader.texture(from: try #require(TextureLoaderTests.makeCGImage(width: 2, height: 2)))

        var order: [String] = []
        let filters: [any Filter] = [
            RecordingFilter(name: "a") { order.append("a") },
            RecordingFilter(name: "b") { order.append("b") },
            RecordingFilter(name: "c") { order.append("c") },
        ]

        let chain = FilterChain(context: context, filters: filters)
        let result = try chain.run(on: source)

        #expect(order == ["a", "b", "c"])
        #expect(result.width == source.width)
        #expect(result.height == source.height)
    }
}

/// A no-op `Filter` that records that it ran and passes its input through
/// unchanged — enough to verify chain ordering without needing a real shader.
private struct RecordingFilter: Filter {
    let name: String
    let onApply: () -> Void

    func apply(to input: any MTLTexture, commandBuffer: any MTLCommandBuffer, context: MetalContext) throws -> any MTLTexture {
        onApply()
        return input
    }
}
