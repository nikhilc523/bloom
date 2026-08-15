import Foundation

/// Menstrual flow intensity. Core-minimal field (see docs/product/01-data-model.md).
enum Flow: String, CaseIterable, Codable, Sendable {
    case none
    case spotting
    case light
    case medium
    case heavy

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
