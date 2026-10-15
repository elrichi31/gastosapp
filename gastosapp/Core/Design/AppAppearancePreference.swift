import SwiftUI
import UIKit

enum AppAppearancePreference: String, CaseIterable, Identifiable {
    case system
    case dark
    case light

    static let storageKey = "app.appearance.preference"
    /// Valor cuando el usuario aún no eligió: la app nace en oscuro.
    static let defaultValue: AppAppearancePreference = .dark

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

    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .dark: return .dark
        case .light: return .light
        }
    }

    /// Aplica el tema a todas las ventanas, hojas abiertas incluidas.
    ///
    /// `preferredColorScheme` en la raíz no llega a una hoja ya presentada: la
    /// pantalla de Cuenta, desde donde se cambia el tema, se quedaba con el
    /// anterior hasta cerrarla. Fijarlo en la ventana sí la actualiza al momento.
    @MainActor
    func apply() {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = interfaceStyle
            }
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
