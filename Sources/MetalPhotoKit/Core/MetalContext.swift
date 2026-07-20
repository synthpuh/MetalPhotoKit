import Metal

public struct MetalContext {
    public let device: any MTLDevice

    public let commandQueue: any MTLCommandQueue

    public init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw MetalPhotoKitError.deviceUnavailable
        }
        try self.init(device: device)
    }

    public init(device: any MTLDevice) throws {
        guard let queue = device.makeCommandQueue() else {
            throw MetalPhotoKitError.commandQueueCreationFailed
        }
        queue.label = K.Context.commandQueueLabel
        self.device = device
        self.commandQueue = queue
    }
}
