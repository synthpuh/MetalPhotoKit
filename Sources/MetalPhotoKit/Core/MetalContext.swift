import Metal

/// `@unchecked` because the compiler can't see through `any MTLDevice`/`any
/// MTLCommandQueue` — both are documented thread-safe by Apple, and the
/// caches behind them lock internally.
public struct MetalContext: @unchecked Sendable {
    public let device: any MTLDevice

    public let commandQueue: any MTLCommandQueue

    private let pipelineCache = ComputePipelineCache()

    private let texturePool = TexturePool()

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

    /// Checks out a texture of the given size, format, and usage from the
    /// pool, creating one only if none idle matches. Pair with
    /// ``returnTexture(_:)`` once the GPU work touching it has completed.
    public func checkoutTexture(
        width: Int,
        height: Int,
        pixelFormat: MTLPixelFormat,
        usage: MTLTextureUsage = [.shaderRead, .shaderWrite]
    ) throws -> any MTLTexture {
        try texturePool.checkout(width: width, height: height, pixelFormat: pixelFormat, usage: usage, device: device)
    }

    /// Returns a texture to the pool for reuse. Only call this once the GPU
    /// work that reads or writes the texture has actually finished — e.g.
    /// from a command buffer completion handler, not right after encoding.
    public func returnTexture(_ texture: any MTLTexture) {
        texturePool.checkin(texture)
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

/// Textures are interchangeable, and thus poolable, only if they match on
/// all four of these — a checkout must get back something a shader can use
/// exactly like a freshly-allocated texture of the requested description.
private struct TextureKey: Hashable {
    let width: Int
    let height: Int
    let pixelFormat: MTLPixelFormat
    let usage: MTLTextureUsage.RawValue

    init(width: Int, height: Int, pixelFormat: MTLPixelFormat, usage: MTLTextureUsage) {
        self.width = width
        self.height = height
        self.pixelFormat = pixelFormat
        self.usage = usage.rawValue
    }
}

/// Reference-typed so every copy of a value-typed `MetalContext` shares one
/// pool instead of each copy accumulating its own idle textures.
private final class TexturePool {
    private let lock = NSLock()
    private var idle: [TextureKey: [any MTLTexture]] = [:]

    func checkout(
        width: Int,
        height: Int,
        pixelFormat: MTLPixelFormat,
        usage: MTLTextureUsage,
        device: any MTLDevice
    ) throws -> any MTLTexture {
        let key = TextureKey(width: width, height: height, pixelFormat: pixelFormat, usage: usage)

        lock.lock()
        let reused = idle[key]?.popLast()
        lock.unlock()

        if let reused {
            return reused
        }

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = usage

        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw MetalPhotoKitError.textureCreationFailed
        }
        texture.label = "\(K.Texture.textureLabelPrefix).pooled.\(width)x\(height)"
        return texture
    }

    func checkin(_ texture: any MTLTexture) {
        let key = TextureKey(
            width: texture.width,
            height: texture.height,
            pixelFormat: texture.pixelFormat,
            usage: texture.usage
        )

        lock.lock()
        idle[key, default: []].append(texture)
        lock.unlock()
    }
}
