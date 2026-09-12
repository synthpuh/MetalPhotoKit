import CoreGraphics

/// Procedurally generates a gradient `CGImage` at an exact pixel size, so the
/// benchmark isn't tied to (or limited by) any bundled sample asset.
enum SyntheticImage {
    static func make(width: Int, height: Int) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue

        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        )!

        let colors = [
            CGColor(red: 0.85, green: 0.35, blue: 0.2, alpha: 1),
            CGColor(red: 0.1, green: 0.4, blue: 0.75, alpha: 1),
            CGColor(red: 0.95, green: 0.85, blue: 0.2, alpha: 1),
        ]
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0, 0.5, 1])!
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: 0),
            end: CGPoint(x: width, y: height),
            options: []
        )

        return context.makeImage()!
    }
}
