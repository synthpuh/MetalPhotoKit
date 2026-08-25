import Foundation

public enum MetalPhotoKitError: Error, LocalizedError, Equatable {
    case deviceUnavailable

    case commandQueueCreationFailed

    case textureCreationFailed

    case textureReadbackFailed

    case invalidImageSize

    case commandBufferCreationFailed

    case commandEncoderCreationFailed

    case shaderLibraryLoadFailed(String)

    case shaderFunctionNotFound(String)

    case computePipelineStateCreationFailed(String)

    case invalidLUTFile(String)

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
        case .commandEncoderCreationFailed:
            return "The command buffer failed to create a compute command encoder."
        case .shaderLibraryLoadFailed(let reason):
            return "Failed to load the compiled shader library: \(reason)"
        case .shaderFunctionNotFound(let name):
            return "No shader function named \"\(name)\" was found in the shader library."
        case .computePipelineStateCreationFailed(let reason):
            return "Failed to create a compute pipeline state: \(reason)"
        case .invalidLUTFile(let reason):
            return "Failed to parse the .cube LUT file: \(reason)"
        }
    }
}
