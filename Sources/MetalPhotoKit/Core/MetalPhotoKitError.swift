import Foundation

public enum MetalPhotoKitError: Error, LocalizedError, Equatable {
    case deviceUnavailable

    case commandQueueCreationFailed

    case textureCreationFailed

    case textureReadbackFailed

    case invalidImageSize

    case commandBufferCreationFailed

    public var errorDescription: String? {
        switch self {
        case .deviceUnavailable:
            return "No Metal-capable GPU is available. MetalPhotoKit requires real hardware or a simulator with Metal support."
        case .commandQueueCreationFailed:
            return "The Metal device could not create a command queue."
        case .textureCreationFailed:
            return "Failed to create an MTLTexture from the source image."
        case .textureReadbackFailed:
            return "Failed to read pixel data back from the GPU texture."
        case .invalidImageSize:
            return "The image has zero width or height, or no backing CGImage."
        case .commandBufferCreationFailed:
            return "The command queue failed to create a command buffer."
        }
    }
}
