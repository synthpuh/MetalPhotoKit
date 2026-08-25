import Foundation

/// Procedurally generates a few classic color-grading looks as `.cube` text,
/// so the demo can show off ``LUTFilter`` without shipping downloaded LUT
/// files. Each look is just a per-pixel transform sampled onto a grid.
enum DemoLUTGenerator {
    struct Look {
        let name: String
        let transform: (Float, Float, Float) -> (Float, Float, Float)
    }

    /// Order matters: `DemoFilterCatalog` picks into the loaded textures by
    /// index, matching this array's order.
    static let looks: [Look] = [
        Look(name: "Warm / Film", transform: warmFilm),
        Look(name: "Teal & Orange", transform: coolTealOrange),
        Look(name: "High-Contrast B&W", transform: highContrastBW),
    ]

    /// Renders `transform` as `.cube`-formatted text: `size` samples per
    /// axis, in the format's required red-fastest, then green, then blue
    /// order.
    static func cubeFile(size: Int = 17, transform: (Float, Float, Float) -> (Float, Float, Float)) -> String {
        var lines = ["LUT_3D_SIZE \(size)", ""]
        for b in 0..<size {
            for g in 0..<size {
                for r in 0..<size {
                    let input = (
                        Float(r) / Float(size - 1),
                        Float(g) / Float(size - 1),
                        Float(b) / Float(size - 1)
                    )
                    let output = transform(input.0, input.1, input.2)
                    lines.append("\(output.0) \(output.1) \(output.2)")
                }
            }
        }
        return lines.joined(separator: "\n")
    }

    /// Warm, gently faded film stock: lifted blacks, a mild contrast boost,
    /// and a push toward orange at the expense of blue.
    private static func warmFilm(_ r: Float, _ g: Float, _ b: Float) -> (Float, Float, Float) {
        func graded(_ value: Float) -> Float {
            let lifted = 0.04 + 0.96 * value
            return (lifted - 0.5) * 1.1 + 0.5
        }
        return (
            clamp(graded(r) * 1.08 + 0.02),
            clamp(graded(g) * 1.02),
            clamp(graded(b) * 0.88 - 0.01)
        )
    }

    /// Classic cinematic split tone: shadows pulled toward teal, highlights
    /// pushed toward orange, blended by luminance.
    private static func coolTealOrange(_ r: Float, _ g: Float, _ b: Float) -> (Float, Float, Float) {
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        let shadowWeight = 1 - smoothstep(0, 0.5, luminance)
        let highlightWeight = smoothstep(0.5, 1, luminance)

        func contrasted(_ value: Float) -> Float {
            (value - 0.5) * 1.08 + 0.5
        }

        let rr = r - 0.10 * shadowWeight + 0.12 * highlightWeight
        let gg = g + 0.02 * shadowWeight
        let bb = b + 0.12 * shadowWeight - 0.08 * highlightWeight
        return (clamp(contrasted(rr)), clamp(contrasted(gg)), clamp(contrasted(bb)))
    }

    /// Punchy black & white: a red-weighted luma (classic "red filter" film
    /// look) pushed through a strong contrast curve.
    private static func highContrastBW(_ r: Float, _ g: Float, _ b: Float) -> (Float, Float, Float) {
        let luma = 0.4 * r + 0.4 * g + 0.2 * b
        let value = clamp((luma - 0.5) * 1.6 + 0.5)
        return (value, value, value)
    }

    private static func smoothstep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
        let t = clamp((x - edge0) / (edge1 - edge0))
        return t * t * (3 - 2 * t)
    }

    private static func clamp(_ value: Float, _ range: ClosedRange<Float> = 0...1) -> Float {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
