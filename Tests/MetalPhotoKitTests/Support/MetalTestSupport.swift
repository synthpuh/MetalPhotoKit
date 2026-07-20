import Metal

/// Shared support for tests that need a real Metal device.
///
/// `MTLCreateSystemDefaultDevice()` returns `nil` in environments with no
/// GPU access — some CI runners, some sandboxed builds. Tests that exercise
/// real GPU work gate on `MetalTestSupport.isAvailable` via the
/// `.enabled(if:)` trait, so they're *skipped* rather than failed when no
/// device exists.
enum MetalTestSupport {
    static let device: (any MTLDevice)? = MTLCreateSystemDefaultDevice()

    static var isAvailable: Bool { device != nil }
}
