import Foundation

public enum BenchmarkError: Error, LocalizedError {
    case deviceUnavailable
    case metalPerformanceShadersUnsupported

    public var errorDescription: String? {
        switch self {
        case .deviceUnavailable:
            return "No Metal device available. This benchmark reads GPU command buffer timestamps and must run on real hardware — a Mac, or a physical iOS device via Xcode — not the iOS Simulator."
        case .metalPerformanceShadersUnsupported:
            return "This device doesn't support Metal Performance Shaders, required for the live-drawable-path comparison."
        }
    }
}
