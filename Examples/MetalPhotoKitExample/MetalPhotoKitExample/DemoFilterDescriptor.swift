import Foundation
import Metal
import MetalPhotoKit

/// One tunable control for a ``DemoFilterDescriptor``: display name, what
/// kind of control it needs, and a starting value.
///
/// Every parameter is still stored and passed to `makeFilter` as a `Float`
/// — for `.choice`, that float is the selected option's index — so the
/// underlying `[Float]` plumbing in ``DemoFilterDescriptor`` and
/// `FilterDemoViewModel` doesn't need to know which kind it's carrying.
/// Only the view branches on `kind`, to pick a `Slider` or a `Picker`.
struct DemoFilterParameter {
    enum Kind {
        case continuous(range: ClosedRange<Float>)
        case choice(options: [String])
    }

    let name: String
    let kind: Kind
    let defaultValue: Float

    static func continuous(_ name: String, range: ClosedRange<Float>, defaultValue: Float) -> DemoFilterParameter {
        DemoFilterParameter(name: name, kind: .continuous(range: range), defaultValue: defaultValue)
    }

    static func choice(_ name: String, options: [String], defaultIndex: Int = 0) -> DemoFilterParameter {
        DemoFilterParameter(name: name, kind: .choice(options: options), defaultValue: Float(defaultIndex))
    }
}

/// One entry in the demo's filter picker: its title, its sliders, and how
/// to build the actual `Filter` from their current slider values, in order.
struct DemoFilterDescriptor: Identifiable {
    let id = UUID()
    let title: String
    let parameters: [DemoFilterParameter]
    let makeFilter: ([Float]) -> any Filter
}

/// New filters are added here as one more entry in `all`.
///
/// `lutTextures` is threaded in rather than loaded per filter instance:
/// they're GPU resources built once (see ``LUTLoader``) and reused across
/// every `LUTFilter` this catalog hands out, the same way `sourceTexture`
/// is loaded once and reused across filter runs. Order must match
/// ``DemoLUTGenerator/looks``, since the "Look" parameter picks into this
/// array by index.
enum DemoFilterCatalog {
    static func all(lutTextures: [any MTLTexture]) -> [DemoFilterDescriptor] {
        [
            DemoFilterDescriptor(
                title: "Exposure/Contrast",
                parameters: [
                    .continuous("Exposure", range: -2...2, defaultValue: 0),
                    .continuous("Contrast", range: 0...2, defaultValue: 1),
                ],
                makeFilter: { values in
                    ExposureContrastFilter(exposure: values[0], contrast: values[1])
                }
            ),
            DemoFilterDescriptor(
                title: "Gaussian Blur",
                parameters: [
                    .continuous("Radius", range: 0...64, defaultValue: 0),
                ],
                makeFilter: { values in
                    GaussianBlurFilter(radius: Int(values[0].rounded()))
                }
            ),
            DemoFilterDescriptor(
                title: "LUT",
                parameters: [
                    .choice("Look", options: DemoLUTGenerator.looks.map(\.name)),
                    .continuous("Intensity", range: 0...1, defaultValue: 0),
                ],
                makeFilter: { values in
                    let lookIndex = Int(values[0].rounded())
                    return LUTFilter(lutTexture: lutTextures[lookIndex], intensity: values[1])
                }
            ),
        ]
    }
}
