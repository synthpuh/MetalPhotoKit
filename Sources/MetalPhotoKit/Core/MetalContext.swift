import Metal

public struct MetalContext {
    public let device: any MTLDevice

    public let commandQueue: any MTLCommandQueue

    private let pipelineCache = ComputePipelineCache()

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

    /// Returns the compute pipeline state for the named shader function,
    /// building it from the package's shader library on first use and
    /// reusing it on every call after that.
    ///
    /// Pipeline state creation compiles and links a shader function into
    /// GPU-specific machine code — expensive enough that every `Filter`
    /// should look it up here rather than building its own.
    public func computePipelineState(function name: String) throws -> any MTLComputePipelineState {
        try pipelineCache.state(for: name, device: device)
    }
}

/// Reference-typed so every copy of a value-typed `MetalContext` shares one
/// cache instead of rebuilding pipeline states per copy.
private final class ComputePipelineCache {
    private let lock = NSLock()
    private var library: (any MTLLibrary)?
    private var states: [String: any MTLComputePipelineState] = [:]

    func state(for functionName: String, device: any MTLDevice) throws -> any MTLComputePipelineState {
        lock.lock()
        defer { lock.unlock() }

        if let cached = states[functionName] {
            return cached
        }

        let library = try self.library ?? Self.makeLibrary(device: device)
        self.library = library

        guard let function = library.makeFunction(name: functionName) else {
            throw MetalPhotoKitError.shaderFunctionNotFound(functionName)
        }

        let state: any MTLComputePipelineState
        do {
            state = try device.makeComputePipelineState(function: function)
        } catch {
            throw MetalPhotoKitError.computePipelineStateCreationFailed(error.localizedDescription)
        }

        states[functionName] = state
        return state
    }

    private static func makeLibrary(device: any MTLDevice) throws -> any MTLLibrary {
        do {
            return try device.makeDefaultLibrary(bundle: .module)
        } catch {
            throw MetalPhotoKitError.shaderLibraryLoadFailed(error.localizedDescription)
        }
    }
}
