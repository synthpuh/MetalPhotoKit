import Metal
import CoreGraphics

enum K {
    enum Context {
        static let commandQueueLabel = "com.metalphotokit.command-queue"
    }

    enum Texture {
        static let pixelFormat: MTLPixelFormat = .bgra8Unorm

        static let bytesPerPixel = 4

        static let bitmapInfo = CGBitmapInfo(
            rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        )

        static let textureLabelPrefix = "com.metalphotokit.texture"
    }

    enum FilterChain {
        static let commandBufferLabelPrefix = "com.metalphotokit.filter-chain"
    }
}
