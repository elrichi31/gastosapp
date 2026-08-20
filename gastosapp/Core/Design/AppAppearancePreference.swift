import SwiftUI

enum AppAppearancePreference: String, CaseIterable, Identifiable {
    case system
    case dark
    case light

    static let storageKey = "app.appearance.preference"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return "Sistema"
        case .dark:
            return "Oscuro"
        case .light:
            return "Claro"
        }
    }

    var icon: String {
        switch self {
        case .system:
            return "iphone"
        case .dark:
            return "moon.fill"
        case .light:
            return "sun.max.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .dark:
            return .dark
        case .light:
            return .light
        }
    }
}
