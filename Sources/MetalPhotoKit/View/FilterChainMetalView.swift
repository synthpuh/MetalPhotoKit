#if canImport(UIKit)
import Metal
import MetalKit
import MetalPerformanceShaders
import SwiftUI

/// Renders a filter chain live into an `MTKView`'s drawable, without ever
/// copying pixels back to the CPU.
///
/// ## Why not the compute-to-texture path
/// ``FilterChain/run(on:)`` writes into an ordinary `MTLTexture` — the
/// right target when the destination is a `CGImage`/`UIImage`, but the
/// wrong one for a live preview. Getting those pixels on screen would still
/// mean `getBytes` (a GPU-to-CPU copy), wrapping the result in a `CGImage`,
/// and handing it to SwiftUI to re-composite as a bitmap — a full
/// synchronous round trip on every parameter change. A `CAMetalLayer`
/// drawable, by contrast, is a texture the display compositor can present
/// directly: this view runs the same chain into an intermediate texture,
/// resamples it straight into the drawable's own texture on the GPU, and
/// presents that drawable. The pixels never leave GPU memory.
///
/// ## The draw loop
/// `MTKView` normally free-runs a display link, calling its delegate's
/// `draw(in:)` every frame at ``MTKView/preferredFramesPerSecond``, whether
/// or not anything changed — the right behavior for a game loop, wasteful
/// for a static preview that only changes when a slider moves. This view
/// instead sets `isPaused = true` and `enableSetNeedsDisplay = true`, Apple's
/// documented combination for on-demand rendering: the display link is
/// disengaged, and a frame is drawn only when something explicitly asks for
/// one — here, `updateUIView` calling `setNeedsDisplay()` whenever SwiftUI
/// hands this view new filters or a new source texture. Sizing works the
/// same way it does for any `MTKView`: `autoResizeDrawable` (on by default)
/// keeps the drawable's pixel size in step with the view's bounds and
/// `contentScaleFactor` (so it stays sharp on Retina displays) any time the
/// view's bounds change, which — because `enableSetNeedsDisplay` is on —
/// itself triggers exactly one redraw at the new size.
public struct FilterChainMetalView: UIViewRepresentable {
    private let context: MetalContext
    private let sourceTexture: (any MTLTexture)?
    private let filters: [any Filter]
    private let onError: (@MainActor (Error) -> Void)?

    /// - Parameters:
    ///   - context: The GPU context to run the chain and drive the view with.
    ///   - sourceTexture: The unfiltered texture to run the chain over each
    ///     frame. `nil` while a source hasn't loaded yet; the view draws nothing.
    ///   - filters: The filters to run, in order, exactly as ``FilterChain`` expects.
    ///   - onError: Called on the main actor if a draw fails. A single failed
    ///     frame doesn't stop the view — the next update tries again.
    public init(
        context: MetalContext,
        sourceTexture: (any MTLTexture)?,
        filters: [any Filter],
        onError: (@MainActor (Error) -> Void)? = nil
    ) {
        self.context = context
        self.sourceTexture = sourceTexture
        self.filters = filters
        self.onError = onError
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(context: context)
    }

    public func makeUIView(context uiKitContext: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: context.device)
        view.delegate = uiKitContext.coordinator
        view.colorPixelFormat = K.Texture.pixelFormat
        // The chain's output is resampled directly into the drawable's own
        // texture (see `Coordinator.draw`), so the drawable can't stay
        // restricted to render-target-only usage.
        view.framebufferOnly = false
        view.isPaused = true
        view.enableSetNeedsDisplay = true
        view.preferredFramesPerSecond = K.LiveFilterView.preferredFramesPerSecond
        return view
    }

    public func updateUIView(_ uiView: MTKView, context uiKitContext: Context) {
        uiKitContext.coordinator.update(sourceTexture: sourceTexture, filters: filters, onError: onError)
        uiView.setNeedsDisplay()
    }

    @MainActor
    public final class Coordinator: NSObject, MTKViewDelegate {
        private let context: MetalContext
        private let supportsScaling: Bool
        private var sourceTexture: (any MTLTexture)?
        private var filters: [any Filter] = []
        private var onError: (@MainActor (Error) -> Void)?

        init(context: MetalContext) {
            self.context = context
            self.supportsScaling = MPSSupportsMTLDevice(context.device)
        }

        func update(sourceTexture: (any MTLTexture)?, filters: [any Filter], onError: (@MainActor (Error) -> Void)?) {
            self.sourceTexture = sourceTexture
            self.filters = filters
            self.onError = onError
        }

        /// `MTKView` already keeps `drawableSize` in sync with the view's
        /// bounds and `contentScaleFactor`, and — because
        /// `enableSetNeedsDisplay` is on — a bounds change triggers its own
        /// `draw(in:)` call. There's nothing to cache here; the next `draw(in:)`
        /// picks up `view.drawableSize` and resamples to match.
        public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        public func draw(in view: MTKView) {
            guard
                let sourceTexture,
                supportsScaling,
                let drawable = view.currentDrawable,
                view.drawableSize.width > 0, view.drawableSize.height > 0
            else { return }

            do {
                let chain = FilterChain(context: context, filters: filters)
                let filtered = try chain.run(on: sourceTexture)

                guard let commandBuffer = context.commandQueue.makeCommandBuffer() else {
                    throw MetalPhotoKitError.commandBufferCreationFailed
                }
                commandBuffer.label = K.LiveFilterView.commandBufferLabel

                // A straight blit would require `filtered` and the drawable to
                // be pixel-for-pixel the same size, which only holds by
                // coincidence; the drawable tracks the view's on-screen size,
                // `filtered` is the source photo's native resolution. Scaling
                // is the resample step a compute-to-texture chain never
                // needed, since every filter there both reads and writes at
                // the same fixed resolution.
                let scale = MPSImageBilinearScale(device: context.device)
                scale.encode(commandBuffer: commandBuffer, sourceTexture: filtered, destinationTexture: drawable.texture)

                if filtered !== sourceTexture {
                    let context = context
                    commandBuffer.addCompletedHandler { _ in
                        context.returnTexture(filtered)
                    }
                }

                commandBuffer.present(drawable)
                commandBuffer.commit()
            } catch {
                onError?(error)
            }
        }
    }
}
#endif
