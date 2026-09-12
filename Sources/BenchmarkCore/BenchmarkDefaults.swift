public enum BenchmarkDefaults {
    public static let warmupIterations = 3
    public static let measuredIterations = 10

    public static let resolutions: [Resolution] = [
        Resolution(label: "1024×768", width: 1024, height: 768),
        Resolution(label: "2048×1536", width: 2048, height: 1536),
        Resolution(label: "4032×3024", width: 4032, height: 3024),
    ]

    public static let exposure: Float = 0.6
    public static let contrast: Float = 1.15
    public static let blurRadius = 8
    public static let lutIntensity: Float = 0.8

    /// Stand-in for an on-screen drawable size, matching what
    /// `FilterChainMetalView` resamples into on an iPhone 15/14/13-class
    /// display — the live path always ends by scaling into a fixed
    /// screen-sized target, not the source photo's own resolution.
    public static let liveDrawableSize = Resolution(label: "drawable", width: 1170, height: 2532)

    /// Fixed resolution for the blur radius sweep — large enough that
    /// per-radius GPU time is measurable above command buffer overhead.
    public static let radiusSweepResolution = Resolution(label: "2048×1536", width: 2048, height: 1536)

    public static let radiusSweepRadii = [2, 4, 8, 16, 32]
}
