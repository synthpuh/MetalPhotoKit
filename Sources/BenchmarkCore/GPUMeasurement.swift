import Dispatch
import Metal
import MetalPerformanceShaders
import MetalPhotoKit

struct Timing {
    let gpuSeconds: Double
    let wallSeconds: Double

    var gpuMilliseconds: Double { gpuSeconds * 1000 }
    var wallMilliseconds: Double { wallSeconds * 1000 }
}

/// Runs `filters` in sequence inside a single command buffer, mirroring what
/// `FilterChain.run(on:)` does — reimplemented here (rather than reused)
/// purely so the benchmark can read `gpuStartTime`/`gpuEndTime` off the exact
/// command buffer that carried the work, which `FilterChain` doesn't expose.
enum GPUMeasurement {
    static func measure(filter: any Filter, input: any MTLTexture, context: MetalContext) throws -> (output: any MTLTexture, timing: Timing) {
        try measure(filters: [filter], input: input, context: context)
    }

    static func measure(filters: [any Filter], input: any MTLTexture, context: MetalContext) throws -> (output: any MTLTexture, timing: Timing) {
        guard let commandBuffer = context.commandQueue.makeCommandBuffer() else {
            throw MetalPhotoKitError.commandBufferCreationFailed
        }

        let wallStart = DispatchTime.now()
        var current = input
        var spent: [any MTLTexture] = []
        for filter in filters {
            let output = try filter.apply(to: current, commandBuffer: commandBuffer, context: context)
            if output !== current, current !== input {
                spent.append(current)
            }
            current = output
        }
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        let wallSeconds = Double(DispatchTime.now().uptimeNanoseconds - wallStart.uptimeNanoseconds) / 1_000_000_000

        for texture in spent {
            context.returnTexture(texture)
        }

        let timing = Timing(gpuSeconds: commandBuffer.gpuEndTime - commandBuffer.gpuStartTime, wallSeconds: wallSeconds)
        return (current, timing)
    }

    /// The live-preview path `FilterChainMetalView` takes: the filter chain
    /// plus a GPU resample into a fixed drawable-sized texture, all in one
    /// command buffer, with no CPU readback at any point.
    static func measureLivePath(
        filters: [any Filter],
        input: any MTLTexture,
        destination: any MTLTexture,
        context: MetalContext
    ) throws -> Timing {
        guard let commandBuffer = context.commandQueue.makeCommandBuffer() else {
            throw MetalPhotoKitError.commandBufferCreationFailed
        }

        let wallStart = DispatchTime.now()
        var current = input
        var spent: [any MTLTexture] = []
        for filter in filters {
            let output = try filter.apply(to: current, commandBuffer: commandBuffer, context: context)
            if output !== current, current !== input {
                spent.append(current)
            }
            current = output
        }

        let scale = MPSImageBilinearScale(device: context.device)
        scale.encode(commandBuffer: commandBuffer, sourceTexture: current, destinationTexture: destination)
        if current !== input {
            spent.append(current)
        }

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        let wallSeconds = Double(DispatchTime.now().uptimeNanoseconds - wallStart.uptimeNanoseconds) / 1_000_000_000

        for texture in spent {
            context.returnTexture(texture)
        }

        return Timing(gpuSeconds: commandBuffer.gpuEndTime - commandBuffer.gpuStartTime, wallSeconds: wallSeconds)
    }

    /// The readback path any non-live consumer takes: run the chain, then pay
    /// the CPU cost of copying pixels out and wrapping them as a `CGImage`.
    static func measureReadbackPath(
        filters: [any Filter],
        input: any MTLTexture,
        context: MetalContext,
        loader: TextureLoader
    ) throws -> (chain: Timing, readbackCPUSeconds: Double, totalWallSeconds: Double) {
        let (output, chainTiming) = try measure(filters: filters, input: input, context: context)

        let readStart = DispatchTime.now()
        _ = try loader.cgImage(from: output)
        let readbackCPUSeconds = Double(DispatchTime.now().uptimeNanoseconds - readStart.uptimeNanoseconds) / 1_000_000_000

        if output !== input {
            context.returnTexture(output)
        }

        return (chainTiming, readbackCPUSeconds, chainTiming.wallSeconds + readbackCPUSeconds)
    }
}
