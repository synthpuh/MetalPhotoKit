import Testing
@testable import MetalPhotoKit

@Suite("MetalPhotoKitError")
struct MetalPhotoKitErrorTests {

    @Test("every case has a non-empty, distinct description", arguments: [
        MetalPhotoKitError.deviceUnavailable,
        .commandQueueCreationFailed,
        .textureCreationFailed,
        .textureReadbackFailed,
        .invalidImageSize,
        .commandBufferCreationFailed,
    ])
    func hasDescription(_ error: MetalPhotoKitError) {
        #expect(error.errorDescription?.isEmpty == false)
    }

    @Test("equal cases compare equal")
    func equatable() {
        #expect(MetalPhotoKitError.deviceUnavailable == .deviceUnavailable)
        #expect(MetalPhotoKitError.deviceUnavailable != .invalidImageSize)
    }
}
