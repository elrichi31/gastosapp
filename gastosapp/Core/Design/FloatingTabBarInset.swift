import SwiftUI

/// Métricas de la barra de pestañas flotante.
///
/// `PillTabBar` se construye con estas constantes y `totalHeight` es exactamente
/// el alto que la barra reserva en el área segura inferior, así que las dos
/// nunca pueden desincronizarse.
enum FloatingTabBarMetrics {
    static let itemHeight: CGFloat = 46
    static let innerPadding: CGFloat = 7
    static let outerVerticalPadding: CGFloat = 10

    static var totalHeight: CGFloat {
        itemHeight + innerPadding * 2 + outerVerticalPadding * 2
    }
}

private struct FloatingTabBarHeightKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    /// Alto que ocupa la barra flotante, o 0 donde no hay barra (sheets, login).
    var floatingTabBarHeight: CGFloat {
        get { self[FloatingTabBarHeightKey.self] }
        set { self[FloatingTabBarHeightKey.self] = newValue }
    }
}

private struct FloatingTabBarInsetModifier: ViewModifier {
    @Environment(\.floatingTabBarHeight) private var height

    func body(content: Content) -> some View {
        // Un espaciador dentro de `safeAreaInset` (y no `safeAreaPadding`): es el
        // único que además hace que un ScrollView reserve content inset al final.
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: height)
        }
    }
}

extension View {
    /// Reserva el espacio de la barra flotante en pantallas donde el
    /// `safeAreaInset` de `MainTabView` no llega por sí solo.
    ///
    /// Hace falta en los destinos de `navigationDestination`: SwiftUI no propaga
    /// el inset del área segura del contenedor a las vistas que un
    /// `NavigationStack` empuja, sólo a su raíz. Sin esto, el contenido del
    /// final del scroll (por ejemplo el botón de guardar) queda debajo de la barra.
    ///
    /// Es inofensivo donde el inset sí llega: ahí el entorno vale 0.
    func floatingTabBarInset() -> some View {
        modifier(FloatingTabBarInsetModifier())
    }
}
