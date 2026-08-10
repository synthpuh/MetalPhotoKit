import Testing
import Metal
import CoreGraphics
@testable import MetalPhotoKit

@Suite("GaussianBlurFilter")
struct GaussianBlurFilterTests {

    @Test("clamps radius to its valid range")
    func clampsRadiusToValidRange() {
        let overdriven = GaussianBlurFilter(radius: 1000)
        #expect(overdriven.radius == K.GaussianBlur.radiusRange.upperBound)

        let underdriven = GaussianBlurFilter(radius: -5)
        #expect(underdriven.radius == K.GaussianBlur.radiusRange.lowerBound)
    }

    @Test("weights are symmetric-normalized and peak at the center")
    func weightsAreNormalizedAndPeakAtCenter() {
        let weights = GaussianBlurFilter.weights(radius: 5)

        let total = weights[0] + weights[1...].reduce(0) { $0 + 2 * $1 }
        #expect(abs(total - 1) < 0.0001)

        for i in 1..<weights.count {
            #expect(weights[i - 1] > weights[i])
        }
    }

    @Test("zero radius leaves a pixel unchanged", .enabled(if: MetalTestSupport.isAvailable))
    func zeroRadiusPreservesPixel() throws {
        let device = try #require(MetalTestSupport.device)
        let context = try MetalContext(device: device)
        let loader = TextureLoader(device: device)
        let source = try #require(TextureLoaderTests.makeCGImage(width: 4, height: 4, color: (0.5, 0.25, 0.75)))
        let texture = try loader.texture(from: source)
        let untouched = try loader.cgImage(from: texture).dataProvider?.data as Data?

        let chain = FilterChain(context: context, filters: [GaussianBlurFilter(radius: 0)])
        let result = try chain.run(on: texture)
        let processed = try loader.cgImage(from: result).dataProvider?.data as Data?

        #expect(untouched == processed)
    }

    @Test("blurring a hard edge softens the seam while leaving pixels far from it alone", .enabled(if: MetalTestSupport.isAvailable))
    func blurSoftensHardEdge() throws {
        let device = try #require(MetalTestSupport.device)
        let context = try MetalContext(device: device)
        let loader = TextureLoader(device: device)

        let width = 32
        let height = 8
        let radius = 6
        let source = try #require(Self.makeHardEdgeImage(width: width, height: height))
        let texture = try loader.texture(from: source)

        let chain = FilterChain(context: context, filters: [GaussianBlurFilter(radius: radius)])
        let result = try chain.run(on: texture)
        let output = try loader.cgImage(from: result)
        let pixelData = try #require(output.dataProvider?.data as Data?)

        let bytesPerPixel = K.Texture.bytesPerPixel
        let bytesPerRow = width * bytesPerPixel
        let middleRow = (height / 2) * bytesPerRow

        func blueByte(atColumn column: Int) -> UInt8 {
            pixelData[pixelData.startIndex + middleRow + column * bytesPerPixel]
        }

        let seamColumn = width / 2
        #expect(blueByte(atColumn: seamColumn) > 0)
        #expect(blueByte(atColumn: seamColumn) < 255)

        #expect(blueByte(atColumn: 0) == 0)
        #expect(blueByte(atColumn: width - 1) == 255)
    }

    static func makeHardEdgeImage(width: Int, height: Int) -> CGImage? {
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * K.Texture.bytesPerPixel,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: K.Texture.bitmapInfo.rawValue
        ) else { return nil }

        context.setFillColor(red: 0, green: 0, blue: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
        context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        context.fill(CGRect(x: width / 2, y: 0, width: width - width / 2, height: height))

        return context.makeImage()
    }
}
