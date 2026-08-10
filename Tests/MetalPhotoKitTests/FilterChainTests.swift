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

    @Test("an intermediate output is back in the pool by the time run() returns", .enabled(if: MetalTestSupport.isAvailable))
    func intermediateOutputIsPooledAfterRun() throws {
        let device = try #require(MetalTestSupport.device)
        let context = try MetalContext(device: device)
        let loader = TextureLoader(device: device)
        let source = try loader.texture(from: try #require(TextureLoaderTests.makeCGImage(width: 2, height: 2)))

        var intermediateOutput: (any MTLTexture)?
        let filters: [any Filter] = [
            CapturingFilter { intermediateOutput = $0 },
            CapturingFilter { _ in },
        ]

        let chain = FilterChain(context: context, filters: filters)
        _ = try chain.run(on: source)

        let captured = try #require(intermediateOutput)
        let checkedOut = try context.checkoutTexture(width: captured.width, height: captured.height, pixelFormat: captured.pixelFormat)
        #expect(checkedOut === captured)
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

/// A `Filter` that checks out a pooled texture as its output (without
/// encoding any GPU work) and reports it, so a test can assert on what
/// `FilterChain` does with that texture afterward.
private struct CapturingFilter: Filter {
    let onOutput: (any MTLTexture) -> Void

    func apply(to input: any MTLTexture, commandBuffer: any MTLCommandBuffer, context: MetalContext) throws -> any MTLTexture {
        let output = try context.checkoutTexture(width: input.width, height: input.height, pixelFormat: input.pixelFormat)
        onOutput(output)
        return output
    }
}
