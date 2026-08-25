import Testing
import Metal
import Foundation
@testable import MetalPhotoKit

@Suite("LUTFilter")
struct LUTFilterTests {

    @Test("clamps intensity to its valid range", .enabled(if: MetalTestSupport.isAvailable))
    func clampsIntensityToValidRange() throws {
        let device = try #require(MetalTestSupport.device)
        let texture = try LUTLoader(device: device).neutralTexture()

        let overdriven = LUTFilter(lutTexture: texture, intensity: 5)
        #expect(overdriven.intensity == K.LUT.intensityRange.upperBound)

        let underdriven = LUTFilter(lutTexture: texture, intensity: -5)
        #expect(underdriven.intensity == K.LUT.intensityRange.lowerBound)
    }

    @Test("zero intensity leaves a pixel unchanged, regardless of the LUT", .enabled(if: MetalTestSupport.isAvailable))
    func zeroIntensityPreservesPixel() throws {
        let device = try #require(MetalTestSupport.device)
        let context = try MetalContext(device: device)
        let loader = TextureLoader(device: device)
        let lutTexture = try LUTLoader(device: device).neutralTexture()

        let source = try #require(TextureLoaderTests.makeCGImage(width: 2, height: 2, color: (0.5, 0.25, 0.75)))
        let texture = try loader.texture(from: source)
        let untouched = try loader.cgImage(from: texture).dataProvider?.data as Data?

        let chain = FilterChain(context: context, filters: [LUTFilter(lutTexture: lutTexture, intensity: 0)])
        let result = try chain.run(on: texture)
        let processed = try loader.cgImage(from: result).dataProvider?.data as Data?

        #expect(untouched == processed)
    }

    @Test("the neutral LUT at full intensity leaves a pixel unchanged", .enabled(if: MetalTestSupport.isAvailable))
    func neutralLUTAtFullIntensityPreservesPixel() throws {
        let device = try #require(MetalTestSupport.device)
        let context = try MetalContext(device: device)
        let loader = TextureLoader(device: device)
        let lutTexture = try LUTLoader(device: device).neutralTexture()

        let source = try #require(TextureLoaderTests.makeCGImage(width: 2, height: 2, color: (0.5, 0.25, 0.75)))
        let texture = try loader.texture(from: source)
        let untouched = try loader.cgImage(from: texture).dataProvider?.data as Data?

        let chain = FilterChain(context: context, filters: [LUTFilter(lutTexture: lutTexture, intensity: 1)])
        let result = try chain.run(on: texture)
        let processed = try loader.cgImage(from: result).dataProvider?.data as Data?

        #expect(untouched == processed)
    }

    @Test("a non-identity LUT grades a mid-range color via genuine trilinear interpolation", .enabled(if: MetalTestSupport.isAvailable))
    func invertLUTGradesInterpolatedColor() throws {
        let device = try #require(MetalTestSupport.device)
        let context = try MetalContext(device: device)
        let loader = TextureLoader(device: device)

        // Every corner maps (r, g, b) -> (1-r, 1-g, 1-b). Inversion is linear
        // along each axis, so trilinear interpolation reproduces it exactly
        // even for a source color that isn't a corner value.
        let url = try LUTLoaderTests.writeCubeFile("""
        LUT_3D_SIZE 2

        1.0 1.0 1.0
        0.0 1.0 1.0
        1.0 0.0 1.0
        0.0 0.0 1.0
        1.0 1.0 0.0
        0.0 1.0 0.0
        1.0 0.0 0.0
        0.0 0.0 0.0
        """)
        defer { try? FileManager.default.removeItem(at: url) }
        let lutTexture = try LUTLoader(device: device).texture(fromCubeFileAt: url)

        let source = try #require(TextureLoaderTests.makeCGImage(width: 2, height: 2, color: (0.5, 0.25, 0.75)))
        let texture = try loader.texture(from: source)

        let expectedImage = try #require(TextureLoaderTests.makeCGImage(width: 2, height: 2, color: (0.5, 0.75, 0.25)))
        let expected = try loader.cgImage(from: try loader.texture(from: expectedImage)).dataProvider?.data as Data?

        let chain = FilterChain(context: context, filters: [LUTFilter(lutTexture: lutTexture, intensity: 1)])
        let result = try chain.run(on: texture)
        let processed = try loader.cgImage(from: result).dataProvider?.data as Data?

        // GPU trilinear sampling and blending happen in floating point, then
        // get quantized back to 8 bits, so the sampled result can land ±1
        // away from a value that skipped the GPU roundtrip entirely.
        let expectedBytes = try #require(expected).map(Int.init)
        let processedBytes = try #require(processed).map(Int.init)
        #expect(expectedBytes.count == processedBytes.count)
        for (expectedByte, processedByte) in zip(expectedBytes, processedBytes) {
            #expect(abs(expectedByte - processedByte) <= 1)
        }
    }
}
