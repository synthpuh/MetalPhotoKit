import Testing
import Metal
@testable import MetalPhotoKit

@Suite("ExposureContrastFilter")
struct ExposureContrastFilterTests {

    @Test("clamps exposure and contrast to their valid ranges")
    func clampsParametersToValidRanges() {
        let overdriven = ExposureContrastFilter(exposure: 10, contrast: -5)
        #expect(overdriven.exposure == K.ExposureContrast.exposureRange.upperBound)
        #expect(overdriven.contrast == K.ExposureContrast.contrastRange.lowerBound)

        let underdriven = ExposureContrastFilter(exposure: -10, contrast: 10)
        #expect(underdriven.exposure == K.ExposureContrast.exposureRange.lowerBound)
        #expect(underdriven.contrast == K.ExposureContrast.contrastRange.upperBound)
    }

    @Test("boosting contrast around mid-gray pushes a bright pixel to pure white", .enabled(if: MetalTestSupport.isAvailable))
    func contrastPushesBrightPixelToWhite() throws {
        let device = try #require(MetalTestSupport.device)
        let context = try MetalContext(device: device)
        let loader = TextureLoader(device: device)
        let source = try #require(TextureLoaderTests.makeCGImage(width: 2, height: 2, color: (0.75, 0.75, 0.75)))
        let texture = try loader.texture(from: source)

        let chain = FilterChain(context: context, filters: [ExposureContrastFilter(exposure: 0, contrast: 2)])
        let result = try chain.run(on: texture)
        let output = try loader.cgImage(from: result)

        let pixelData = try #require(output.dataProvider?.data as Data?)
        let bytesPerPixel = K.Texture.bytesPerPixel
        for byte in pixelData.prefix(bytesPerPixel) {
            #expect(byte == 255)
        }
    }

    @Test("zero exposure and unit contrast leave a pixel unchanged", .enabled(if: MetalTestSupport.isAvailable))
    func identityParametersPreservePixel() throws {
        let device = try #require(MetalTestSupport.device)
        let context = try MetalContext(device: device)
        let loader = TextureLoader(device: device)
        let source = try #require(TextureLoaderTests.makeCGImage(width: 2, height: 2, color: (0.5, 0.25, 0.75)))
        let texture = try loader.texture(from: source)
        let untouched = try loader.cgImage(from: texture).dataProvider?.data as Data?

        let chain = FilterChain(context: context, filters: [ExposureContrastFilter(exposure: 0, contrast: 1)])
        let result = try chain.run(on: texture)
        let processed = try loader.cgImage(from: result).dataProvider?.data as Data?

        #expect(untouched == processed)
    }
}
