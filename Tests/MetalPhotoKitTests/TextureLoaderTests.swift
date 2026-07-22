import Testing
import Metal
import CoreGraphics
#if canImport(UIKit)
import UIKit
#endif
@testable import MetalPhotoKit

@Suite("TextureLoader")
struct TextureLoaderTests {

    @Test("round-trips a solid color image's dimensions through texture and back", .enabled(if: MetalTestSupport.isAvailable))
    func roundTripsDimensions() throws {
        let device = try #require(MetalTestSupport.device)
        let loader = TextureLoader(device: device)
        let source = try #require(Self.makeCGImage(width: 4, height: 4))

        let texture = try loader.texture(from: source)
        #expect(texture.width == 4)
        #expect(texture.height == 4)

        let roundTripped = try loader.cgImage(from: texture)
        #expect(roundTripped.width == 4)
        #expect(roundTripped.height == 4)
    }

    #if canImport(UIKit)
    @Test("rejects a UIImage with no backing CGImage", .enabled(if: MetalTestSupport.isAvailable))
    func rejectsImageWithNoCGImage() throws {
        let device = try #require(MetalTestSupport.device)
        let loader = TextureLoader(device: device)

        #expect(throws: MetalPhotoKitError.invalidImageSize) {
            try loader.texture(from: UIImage())
        }
    }
    #endif

    static func makeCGImage(
        width: Int,
        height: Int,
        color: (red: CGFloat, green: CGFloat, blue: CGFloat) = (0.5, 0.25, 0.75)
    ) -> CGImage? {
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * K.Texture.bytesPerPixel,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: K.Texture.bitmapInfo.rawValue
        ) else { return nil }

        context.setFillColor(red: color.red, green: color.green, blue: color.blue, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }
}
