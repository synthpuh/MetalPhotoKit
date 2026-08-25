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

    enum ExposureContrast {
        static let functionName = "exposureContrast"
        static let encoderLabel = "com.metalphotokit.exposure-contrast"
        static let exposureRange: ClosedRange<Float> = -2...2
        static let contrastRange: ClosedRange<Float> = 0...2
    }

    enum GaussianBlur {
        static let functionName = "gaussianBlur"
        static let encoderLabel = "com.metalphotokit.gaussian-blur"
        static let radiusRange: ClosedRange<Int> = 0...64
    }

    enum LUT {
        static let functionName = "lut3D"
        static let encoderLabel = "com.metalphotokit.lut"
        static let intensityRange: ClosedRange<Float> = 0...1
        static let neutralLUTName = "Neutral"
        static let cubeFileExtension = "cube"
    }

    enum DebugPreview {
        static let sampleImageName = "SampleImage"
        static let sampleImageExtension = "png"
    }

    enum LiveFilterView {
        static let commandBufferLabel = "com.metalphotokit.live-preview"
        static let preferredFramesPerSecond = 60
    }
}
