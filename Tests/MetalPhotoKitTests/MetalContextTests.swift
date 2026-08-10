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

    @Test("returning a texture hands back that exact object on the next matching checkout", .enabled(if: MetalTestSupport.isAvailable))
    func returnedTextureIsReusedByIdentity() throws {
        let device = try #require(MetalTestSupport.device)
        let context = try MetalContext(device: device)

        let first = try context.checkoutTexture(width: 8, height: 8, pixelFormat: .bgra8Unorm)
        context.returnTexture(first)
        let second = try context.checkoutTexture(width: 8, height: 8, pixelFormat: .bgra8Unorm)

        #expect(second === first)
    }

    @Test("a checkout with no idle match creates a fresh texture instead of reusing a mismatched one", .enabled(if: MetalTestSupport.isAvailable))
    func mismatchedCheckoutDoesNotReuse() throws {
        let device = try #require(MetalTestSupport.device)
        let context = try MetalContext(device: device)

        let returned = try context.checkoutTexture(width: 8, height: 8, pixelFormat: .bgra8Unorm)
        context.returnTexture(returned)

        let differentSize = try context.checkoutTexture(width: 16, height: 16, pixelFormat: .bgra8Unorm)
        #expect(differentSize !== returned)

        let differentFormat = try context.checkoutTexture(width: 8, height: 8, pixelFormat: .rgba8Unorm)
        #expect(differentFormat !== returned)
    }

    @Test("checking out twice before returning yields two distinct textures", .enabled(if: MetalTestSupport.isAvailable))
    func concurrentCheckoutsDoNotAlias() throws {
        let device = try #require(MetalTestSupport.device)
        let context = try MetalContext(device: device)

        let a = try context.checkoutTexture(width: 8, height: 8, pixelFormat: .bgra8Unorm)
        let b = try context.checkoutTexture(width: 8, height: 8, pixelFormat: .bgra8Unorm)

        #expect(a !== b)
    }
}
