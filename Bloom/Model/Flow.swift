import Foundation

/// Menstrual flow intensity. Core-minimal field (see docs/product/01-data-model.md).
/// The one field shared by default — but only as a *state* ("period started"),
/// never the intensity (see `Shareability`).
enum Flow: String, CaseIterable, Codable, Sendable, SharePermitted {
    case none
    case spotting
    case light
    case medium
    case heavy

    static var shareability: Shareability { .shareable }

    var label: String {
        switch self {
        case .none: "None"
        case .spotting: "Spotting"
        case .light: "Light"
        case .medium: "Medium"
        case .heavy: "Heavy"
        }
    }
}
