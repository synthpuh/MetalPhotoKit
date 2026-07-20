import Metal
import CoreGraphics
import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Converts CPU-side images into GPU textures, and reads GPU textures back
/// into CPU-side images.
///
/// ## Why textures instead of `UIImage`
/// `UIImage` is a CPU-side, format-opaque wrapper: it might be backed by
/// compressed data (JPEG/HEIC), a `CGImage`, or nothing decoded yet at all.
/// A GPU shader can't run over that — it needs an `MTLTexture`, a block of
/// GPU memory with a known, fixed pixel layout (``K/Texture/pixelFormat``,
/// 4 bytes per pixel) that thousands of GPU threads can address directly and
/// in parallel. `TextureLoader` performs the one-time conversion from
/// "opaque CPU image" to "GPU-addressable pixel buffer," so every ``Filter``
/// downstream only ever has to deal in textures.
///
/// The conversion logic lives on `CGImage`, the lowest-level image type
/// Core Graphics offers; `UIImage` overloads are thin convenience wrappers
/// around it.
public struct TextureLoader {
    private let device: any MTLDevice

    /// Creates a loader bound to a specific device. Textures must be created
    /// by the same `MTLDevice` that will later run filters over them.
    public init(device: any MTLDevice) {
        self.device = device
    }

    /// Creates a loader using the device from a ``MetalContext``.
    public init(context: MetalContext) {
        self.device = context.device
    }

    // MARK: - Image -> Texture

    /// Converts a `CGImage` into an `MTLTexture`.
    ///
    /// This draws the image into a CPU-side bitmap whose byte layout matches
    /// ``K/Texture/pixelFormat`` exactly, then copies those bytes into GPU
    /// memory via `replace(region:mipmapLevel:withBytes:bytesPerRow:)`.
    ///
    /// - Throws: ``MetalPhotoKitError/invalidImageSize`` if the image has
    ///   zero width or height, or ``MetalPhotoKitError/textureCreationFailed``
    ///   if the bitmap context or the GPU texture can't be allocated.
    public func texture(from image: CGImage) throws -> any MTLTexture {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else {
            throw MetalPhotoKitError.invalidImageSize
        }

        let bytesPerRow = width * K.Texture.bytesPerPixel
        var pixelData = [UInt8](repeating: 0, count: bytesPerRow * height)

        guard let bitmapContext = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: K.Texture.bitmapInfo.rawValue
        ) else {
            throw MetalPhotoKitError.textureCreationFailed
        }
        bitmapContext.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: K.Texture.pixelFormat,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]

        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw MetalPhotoKitError.textureCreationFailed
        }
        texture.label = "\(K.Texture.textureLabelPrefix).\(width)x\(height)"

        let region = MTLRegionMake2D(0, 0, width, height)
        pixelData.withUnsafeBytes { buffer in
            texture.replace(region: region, mipmapLevel: 0, withBytes: buffer.baseAddress!, bytesPerRow: bytesPerRow)
        }

        return texture
    }

    #if canImport(UIKit)
    /// Convenience over `texture(from:)` for `UIImage` input.
    ///
    /// - Throws: ``MetalPhotoKitError/invalidImageSize`` if `image` has no
    ///   backing `CGImage`.
    public func texture(from image: UIImage) throws -> any MTLTexture {
        guard let cgImage = image.cgImage else {
            throw MetalPhotoKitError.invalidImageSize
        }
        return try texture(from: cgImage)
    }
    #endif

    // MARK: - Texture -> Image

    /// Reads a texture's pixels back into CPU memory and wraps them in a `CGImage`.
    ///
    /// This is the inverse of `texture(from:)`: `getBytes` copies the
    /// GPU-resident pixels into a CPU buffer, and a `CGDataProvider` wraps
    /// that buffer as a `CGImage` without an extra copy.
    ///
    /// - Throws: ``MetalPhotoKitError/textureReadbackFailed`` if the pixels
    ///   can't be copied out or re-wrapped as a `CGImage`.
    public func cgImage(from texture: any MTLTexture) throws -> CGImage {
        let width = texture.width
        let height = texture.height
        let bytesPerRow = width * K.Texture.bytesPerPixel

        var pixelData = [UInt8](repeating: 0, count: bytesPerRow * height)
        let region = MTLRegionMake2D(0, 0, width, height)
        pixelData.withUnsafeMutableBytes { buffer in
            texture.getBytes(buffer.baseAddress!, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        }

        guard let provider = CGDataProvider(data: Data(pixelData) as CFData) else {
            throw MetalPhotoKitError.textureReadbackFailed
        }

        guard let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 8 * K.Texture.bytesPerPixel,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: K.Texture.bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else {
            throw MetalPhotoKitError.textureReadbackFailed
        }

        return cgImage
    }

    #if canImport(UIKit)
    /// Convenience over `cgImage(from:)` that wraps the result in a `UIImage`.
    public func image(from texture: any MTLTexture) throws -> UIImage {
        UIImage(cgImage: try cgImage(from: texture))
    }
    #endif
}
