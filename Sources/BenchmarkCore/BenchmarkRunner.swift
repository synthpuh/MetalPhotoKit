import Metal
import MetalPerformanceShaders
import MetalPhotoKit

/// Runs GPU-timed sweeps over `MetalPhotoKit`'s filter chain and reduces each
/// to structured ``BenchmarkResult``s — one per (row, filter) cell — ready to
/// hand to ``BenchmarkMarkdown`` or any other consumer.
public struct BenchmarkRunner {
    public let context: MetalContext

    public var deviceName: String { context.device.name }

    private let loader: TextureLoader
    private let lutTexture: any MTLTexture

    public init(context: MetalContext) throws {
        self.context = context
        self.loader = TextureLoader(device: context.device)
        self.lutTexture = try LUTLoader(device: context.device).neutralTexture()
    }

    /// Creates the default system device and gates on the hardware
    /// requirements every sweep here needs.
    ///
    /// - Throws: ``BenchmarkError/deviceUnavailable`` if no Metal device is
    ///   available (as under the iOS Simulator), or
    ///   ``BenchmarkError/metalPerformanceShadersUnsupported`` if the device
    ///   can't run the live-path resample.
    public init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw BenchmarkError.deviceUnavailable
        }
        guard MPSSupportsMTLDevice(device) else {
            throw BenchmarkError.metalPerformanceShadersUnsupported
        }
        try self.init(context: MetalContext(device: device))
    }

    /// Per-filter and full-chain GPU time, across `resolutions`.
    public func runFilterChainSweep(
        resolutions: [Resolution] = BenchmarkDefaults.resolutions,
        warmupIterations: Int = BenchmarkDefaults.warmupIterations,
        measuredIterations: Int = BenchmarkDefaults.measuredIterations
    ) throws -> [BenchmarkResult] {
        var results: [BenchmarkResult] = []

        for resolution in resolutions {
            let source = try loader.texture(from: SyntheticImage.make(width: resolution.width, height: resolution.height))
            let exposureFilter = ExposureContrastFilter(exposure: BenchmarkDefaults.exposure, contrast: BenchmarkDefaults.contrast)
            let blurFilter = GaussianBlurFilter(radius: BenchmarkDefaults.blurRadius)
            let lutFilter = LUTFilter(lutTexture: lutTexture, intensity: BenchmarkDefaults.lutIntensity)
            let filters: [any Filter] = [exposureFilter, blurFilter, lutFilter]

            try warmUp(filters: filters, source: source, iterations: warmupIterations)

            var exposureMs: [Double] = []
            var blurMs: [Double] = []
            var lutMs: [Double] = []
            var chainMs: [Double] = []

            for _ in 0..<measuredIterations {
                exposureMs.append(try measureAndDiscard(filter: exposureFilter, source: source))
                blurMs.append(try measureAndDiscard(filter: blurFilter, source: source))
                lutMs.append(try measureAndDiscard(filter: lutFilter, source: source))

                let (chainOutput, chainTiming) = try GPUMeasurement.measure(filters: filters, input: source, context: context)
                context.returnTexture(chainOutput)
                chainMs.append(chainTiming.gpuMilliseconds)
            }

            results.append(contentsOf: [
                result(resolution.label, "ExposureContrast", exposureMs),
                result(resolution.label, "GaussianBlur (r=\(BenchmarkDefaults.blurRadius))", blurMs),
                result(resolution.label, "LUT", lutMs),
                result(resolution.label, "Full chain", chainMs),
            ])
        }

        return results
    }

    /// Readback path (chain + `getBytes` + `CGImage`) vs. live drawable path
    /// (chain + GPU resample, no CPU copy), across `resolutions`.
    public func runPathComparison(
        resolutions: [Resolution] = BenchmarkDefaults.resolutions,
        warmupIterations: Int = BenchmarkDefaults.warmupIterations,
        measuredIterations: Int = BenchmarkDefaults.measuredIterations
    ) throws -> [BenchmarkResult] {
        let liveDestination = try context.checkoutTexture(
            width: BenchmarkDefaults.liveDrawableSize.width,
            height: BenchmarkDefaults.liveDrawableSize.height,
            pixelFormat: .bgra8Unorm
        )
        defer { context.returnTexture(liveDestination) }

        var results: [BenchmarkResult] = []

        for resolution in resolutions {
            let source = try loader.texture(from: SyntheticImage.make(width: resolution.width, height: resolution.height))
            let filters: [any Filter] = [
                ExposureContrastFilter(exposure: BenchmarkDefaults.exposure, contrast: BenchmarkDefaults.contrast),
                GaussianBlurFilter(radius: BenchmarkDefaults.blurRadius),
                LUTFilter(lutTexture: lutTexture, intensity: BenchmarkDefaults.lutIntensity),
            ]

            try warmUp(filters: filters, source: source, iterations: warmupIterations)

            var chainGPUMs: [Double] = []
            var readbackCPUMs: [Double] = []
            var readbackTotalMs: [Double] = []
            var liveGPUMs: [Double] = []

            for _ in 0..<measuredIterations {
                let readback = try GPUMeasurement.measureReadbackPath(filters: filters, input: source, context: context, loader: loader)
                chainGPUMs.append(readback.chain.gpuMilliseconds)
                readbackCPUMs.append(readback.readbackCPUSeconds * 1000)
                readbackTotalMs.append(readback.totalWallSeconds * 1000)

                let liveTiming = try GPUMeasurement.measureLivePath(filters: filters, input: source, destination: liveDestination, context: context)
                liveGPUMs.append(liveTiming.gpuMilliseconds)
            }

            results.append(contentsOf: [
                result(resolution.label, "Chain GPU", chainGPUMs),
                result(resolution.label, "Readback CPU", readbackCPUMs),
                result(resolution.label, "Readback total", readbackTotalMs),
                result(resolution.label, "Live GPU", liveGPUMs),
            ])
        }

        return results
    }

    /// `GaussianBlurFilter` GPU time across `radii` at a fixed resolution —
    /// the separable two-pass kernel is expected to scale roughly linearly
    /// with radius, since each pass is an O(radius) convolution per pixel.
    public func runRadiusSweep(
        resolution: Resolution = BenchmarkDefaults.radiusSweepResolution,
        radii: [Int] = BenchmarkDefaults.radiusSweepRadii,
        warmupIterations: Int = BenchmarkDefaults.warmupIterations,
        measuredIterations: Int = BenchmarkDefaults.measuredIterations
    ) throws -> [BenchmarkResult] {
        let source = try loader.texture(from: SyntheticImage.make(width: resolution.width, height: resolution.height))

        var results: [BenchmarkResult] = []

        for radius in radii {
            let blurFilter = GaussianBlurFilter(radius: radius)
            try warmUp(filters: [blurFilter], source: source, iterations: warmupIterations)

            var blurMs: [Double] = []
            for _ in 0..<measuredIterations {
                blurMs.append(try measureAndDiscard(filter: blurFilter, source: source))
            }

            results.append(result("r=\(radius)", "GaussianBlur", blurMs))
        }

        return results
    }

    private func warmUp(filters: [any Filter], source: any MTLTexture, iterations: Int) throws {
        for _ in 0..<iterations {
            let (output, _) = try GPUMeasurement.measure(filters: filters, input: source, context: context)
            context.returnTexture(output)
        }
    }

    private func measureAndDiscard(filter: any Filter, source: any MTLTexture) throws -> Double {
        let (output, timing) = try GPUMeasurement.measure(filter: filter, input: source, context: context)
        context.returnTexture(output)
        return timing.gpuMilliseconds
    }

    private func result(_ rowLabel: String, _ filterName: String, _ samplesMs: [Double]) -> BenchmarkResult {
        BenchmarkResult(
            rowLabel: rowLabel,
            filterName: filterName,
            meanMs: Statistics.mean(samplesMs),
            stddevMs: Statistics.stddev(samplesMs)
        )
    }
}
