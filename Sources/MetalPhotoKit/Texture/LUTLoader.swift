import Metal
import Foundation

/// Loads 3D LUTs (color lookup tables) as GPU textures for ``LUTFilter``.
///
/// ## Why a 3D texture
/// A LUT maps every possible input RGB color to a graded output color. A 3D
/// texture indexed by (R, G, B) stores exactly that mapping, so the GPU's
/// texture-sampling hardware can look up and interpolate a value in one
/// instruction instead of the shader doing the interpolation itself.
public struct LUTLoader {
    private let device: any MTLDevice

    /// Creates a loader bound to a specific device. LUT textures must be
    /// created by the same `MTLDevice` that will later run filters over them.
    public init(device: any MTLDevice) {
        self.device = device
    }

    /// Creates a loader using the device from a ``MetalContext``.
    public init(context: MetalContext) {
        self.device = context.device
    }

    /// Parses a `.cube` LUT file — the DaVinci Resolve / Adobe standard
    /// format — and uploads it as a 3D texture ready for ``LUTFilter``.
    ///
    /// - Throws: ``MetalPhotoKitError/invalidLUTFile(_:)`` if the file is
    ///   malformed, or ``MetalPhotoKitError/textureCreationFailed`` if the
    ///   GPU texture can't be allocated.
    public func texture(fromCubeFileAt url: URL) throws -> any MTLTexture {
        let contents = try String(contentsOf: url, encoding: .utf8)
        return try texture(fromCubeFileContents: contents)
    }

    /// Parses `.cube`-formatted text and uploads it as a 3D texture ready
    /// for ``LUTFilter``. Same format as ``texture(fromCubeFileAt:)``, but
    /// for LUTs built or fetched in memory rather than read from disk.
    ///
    /// - Throws: ``MetalPhotoKitError/invalidLUTFile(_:)`` if the text is
    ///   malformed, or ``MetalPhotoKitError/textureCreationFailed`` if the
    ///   GPU texture can't be allocated.
    public func texture(fromCubeFileContents contents: String) throws -> any MTLTexture {
        let table = try Self.parseCube(contents)
        return try makeTexture(size: table.size, rgb: table.values)
    }

    /// The package's bundled identity LUT: a 2×2×2 table that maps every
    /// color to itself. Trilinear interpolation reproduces an identity
    /// mapping exactly from just its 8 corner points — identity is already
    /// linear along each axis — so this is a correct "no grade" starting
    /// point, not a coarse approximation.
    public func neutralTexture() throws -> any MTLTexture {
        guard let url = Bundle.module.url(
            forResource: K.LUT.neutralLUTName,
            withExtension: K.LUT.cubeFileExtension
        ) else {
            throw MetalPhotoKitError.invalidLUTFile("Bundled neutral LUT resource is missing.")
        }
        return try texture(fromCubeFileAt: url)
    }

    private func makeTexture(size: Int, rgb: [Float]) throws -> any MTLTexture {
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .type3D
        descriptor.pixelFormat = .rgba32Float
        descriptor.width = size
        descriptor.height = size
        descriptor.depth = size
        descriptor.usage = [.shaderRead]

        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw MetalPhotoKitError.textureCreationFailed
        }
        texture.label = "\(K.Texture.textureLabelPrefix).lut.\(size)"

        var rgba = [Float](repeating: 1, count: size * size * size * 4)
        for i in 0..<(size * size * size) {
            rgba[i * 4 + 0] = rgb[i * 3 + 0]
            rgba[i * 4 + 1] = rgb[i * 3 + 1]
            rgba[i * 4 + 2] = rgb[i * 3 + 2]
        }

        let bytesPerRow = size * MemoryLayout<Float>.stride * 4
        let bytesPerImage = bytesPerRow * size
        let region = MTLRegionMake3D(0, 0, 0, size, size, size)
        rgba.withUnsafeBytes { buffer in
            texture.replace(
                region: region,
                mipmapLevel: 0,
                slice: 0,
                withBytes: buffer.baseAddress!,
                bytesPerRow: bytesPerRow,
                bytesPerImage: bytesPerImage
            )
        }

        return texture
    }

    /// Parses `.cube` text into its declared size and flat `[r, g, b, r, g, b, ...]`
    /// data, in the file's native order (red fastest-varying, then green,
    /// then blue) — which is exactly the row-major order a 3D texture needs.
    private static func parseCube(_ contents: String) throws -> (size: Int, values: [Float]) {
        var size: Int?
        var values: [Float] = []

        for rawLine in contents.split(separator: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }

            if line.hasPrefix("LUT_3D_SIZE") {
                let parts = line.split(separator: " ")
                guard parts.count == 2, let parsedSize = Int(parts[1]), parsedSize >= 2 else {
                    throw MetalPhotoKitError.invalidLUTFile("Malformed LUT_3D_SIZE line: \"\(line)\"")
                }
                size = parsedSize
                continue
            }

            // Everything else that isn't a data row (TITLE, DOMAIN_MIN, DOMAIN_MAX,
            // LUT_1D_SIZE, ...) starts with a letter or quote — skip it as metadata
            // this loader doesn't need.
            guard line.first?.isNumber == true || line.first == "-" else { continue }

            let components = line.split(separator: " ").compactMap { Float($0) }
            guard components.count == 3 else {
                throw MetalPhotoKitError.invalidLUTFile("Expected 3 floats per data line, got: \"\(line)\"")
            }
            values.append(contentsOf: components)
        }

        guard let size else {
            throw MetalPhotoKitError.invalidLUTFile("Missing LUT_3D_SIZE.")
        }
        guard values.count == size * size * size * 3 else {
            throw MetalPhotoKitError.invalidLUTFile(
                "Expected \(size * size * size) data lines for LUT_3D_SIZE \(size), found \(values.count / 3)."
            )
        }

        return (size, values)
    }
}
