#if DEBUG
import SwiftUI
import Metal
import ImageIO

/// Interactive canvas for tuning ``ExposureContrastFilter`` against the
/// bundled sample image. Debug-only: excluded from release builds.
struct DebugPreview: View {
    @State private var exposure: Float = 0
    @State private var contrast: Float = 1
    @State private var sourceImage: CGImage?
    @State private var processedImage: CGImage?
    @State private var errorMessage: String?

    @State private var device: (any MTLDevice)?
    @State private var context: MetalContext?
    @State private var sourceTexture: (any MTLTexture)?

    var body: some View {
        VStack(spacing: 20) {
            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
            } else {
                HStack(spacing: 12) {
                    preview(sourceImage, label: "Before")
                    preview(processedImage, label: "After")
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                slider("Exposure", value: $exposure, range: K.ExposureContrast.exposureRange)
                slider("Contrast", value: $contrast, range: K.ExposureContrast.contrastRange)
            }
        }
        .padding()
        .onAppear(perform: loadSourceImage)
        .onChange(of: exposure) { _, _ in reprocess() }
        .onChange(of: contrast) { _, _ in reprocess() }
    }

    @ViewBuilder
    private func preview(_ cgImage: CGImage?, label: String) -> some View {
        VStack(spacing: 4) {
            Group {
                if let cgImage {
                    Image(cgImage, scale: 1, label: Text(label))
                        .resizable()
                        .scaledToFit()
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.secondary.opacity(0.2))
                }
            }
            .frame(width: 180, height: 135)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(label).font(.caption)
        }
    }

    private func slider(_ title: String, value: Binding<Float>, range: ClosedRange<Float>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(title): \(value.wrappedValue, specifier: "%.2f")")
                .font(.caption)
            Slider(value: value, in: range)
        }
    }

    private func loadSourceImage() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            errorMessage = "No Metal device available in this environment."
            return
        }
        guard
            let url = Bundle.module.url(
                forResource: K.DebugPreview.sampleImageName,
                withExtension: K.DebugPreview.sampleImageExtension
            ),
            let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
            let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
        else {
            errorMessage = "Couldn't load the bundled sample image."
            return
        }

        do {
            let context = try MetalContext(device: device)
            let sourceTexture = try TextureLoader(device: device).texture(from: cgImage)

            self.device = device
            self.context = context
            self.sourceTexture = sourceTexture
            self.sourceImage = cgImage
            self.errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        reprocess()
    }

    private func reprocess() {
        guard let context, let sourceTexture else { return }
        do {
            let chain = FilterChain(context: context, filters: [ExposureContrastFilter(exposure: exposure, contrast: contrast)])
            let resultTexture = try chain.run(on: sourceTexture)
            processedImage = try TextureLoader(context: context).cgImage(from: resultTexture)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    DebugPreview()
}
#endif
