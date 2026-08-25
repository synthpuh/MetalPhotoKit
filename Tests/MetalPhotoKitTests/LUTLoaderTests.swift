import Testing
import Metal
import Foundation
@testable import MetalPhotoKit

@Suite("LUTLoader")
struct LUTLoaderTests {

    @Test("loads the bundled neutral LUT as a 2x2x2 3D texture", .enabled(if: MetalTestSupport.isAvailable))
    func loadsNeutralLUT() throws {
        let device = try #require(MetalTestSupport.device)
        let texture = try LUTLoader(device: device).neutralTexture()

        #expect(texture.textureType == .type3D)
        #expect(texture.width == 2)
        #expect(texture.height == 2)
        #expect(texture.depth == 2)
    }

    @Test("parses a well-formed .cube file into a texture of the declared size", .enabled(if: MetalTestSupport.isAvailable))
    func parsesWellFormedCubeFile() throws {
        let device = try #require(MetalTestSupport.device)
        let url = try Self.writeCubeFile("""
        TITLE "Test"
        LUT_3D_SIZE 2

        0.0 0.0 0.0
        1.0 0.0 0.0
        0.0 1.0 0.0
        1.0 1.0 0.0
        0.0 0.0 1.0
        1.0 0.0 1.0
        0.0 1.0 1.0
        1.0 1.0 1.0
        """)
        defer { try? FileManager.default.removeItem(at: url) }

        let texture = try LUTLoader(device: device).texture(fromCubeFileAt: url)
        #expect(texture.width == 2)
    }

    @Test("rejects a .cube file missing LUT_3D_SIZE", .enabled(if: MetalTestSupport.isAvailable))
    func rejectsMissingSize() throws {
        let device = try #require(MetalTestSupport.device)
        let url = try Self.writeCubeFile("0.0 0.0 0.0\n1.0 1.0 1.0")
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(throws: MetalPhotoKitError.self) {
            try LUTLoader(device: device).texture(fromCubeFileAt: url)
        }
    }

    @Test("rejects a .cube file whose data row count doesn't match its declared size", .enabled(if: MetalTestSupport.isAvailable))
    func rejectsMismatchedRowCount() throws {
        let device = try #require(MetalTestSupport.device)
        let url = try Self.writeCubeFile("""
        LUT_3D_SIZE 2
        0.0 0.0 0.0
        1.0 1.0 1.0
        """)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(throws: MetalPhotoKitError.self) {
            try LUTLoader(device: device).texture(fromCubeFileAt: url)
        }
    }

    static func writeCubeFile(_ contents: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("cube")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
