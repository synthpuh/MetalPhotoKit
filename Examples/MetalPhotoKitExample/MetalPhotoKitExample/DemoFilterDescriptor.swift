import Foundation
import MetalPhotoKit

/// One tunable slider for a ``DemoFilterDescriptor``: display name, valid
/// range, and starting value.
struct DemoFilterParameter {
    let name: String
    let range: ClosedRange<Float>
    let defaultValue: Float
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
enum DemoFilterCatalog {
    static let all: [DemoFilterDescriptor] = [
        DemoFilterDescriptor(
            title: "Exposure/Contrast",
            parameters: [
                DemoFilterParameter(name: "Exposure", range: -2...2, defaultValue: 0),
                DemoFilterParameter(name: "Contrast", range: 0...2, defaultValue: 1),
            ],
            makeFilter: { values in
                ExposureContrastFilter(exposure: values[0], contrast: values[1])
            }
        ),
        DemoFilterDescriptor(
            title: "Gaussian Blur",
            parameters: [
                DemoFilterParameter(name: "Radius", range: 0...64, defaultValue: 0),
            ],
            makeFilter: { values in
                GaussianBlurFilter(radius: Int(values[0].rounded()))
            }
        ),
    ]
}
