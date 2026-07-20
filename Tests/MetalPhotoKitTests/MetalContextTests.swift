import Testing
import Metal
@testable import MetalPhotoKit

@Suite("MetalContext")
struct MetalContextTests {

    @Test("init(device:) labels the command queue", .enabled(if: MetalTestSupport.isAvailable))
    func initWithDeviceLabelsQueue() throws {
        let device = try #require(MetalTestSupport.device)
        let context = try MetalContext(device: device)
        #expect(context.commandQueue.label == K.Context.commandQueueLabel)
    }

    @Test("init() succeeds when a system device exists", .enabled(if: MetalTestSupport.isAvailable))
    func initDefaultSucceeds() throws {
        let context = try MetalContext()
        #expect(context.device.name.isEmpty == false)
    }
}
