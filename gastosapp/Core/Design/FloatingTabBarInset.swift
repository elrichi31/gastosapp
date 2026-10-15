import SwiftUI

/// Métricas de la barra de pestañas flotante.
///
/// `PillTabBar` se construye con estas constantes y `reservedHeight` es
/// exactamente el alto que la barra reserva en el área segura inferior, así que
/// las dos nunca pueden desincronizarse.
enum FloatingTabBarMetrics {
    /// Alto de cada pestaña con el rótulo visible (64 de cápsula − 2 × 4).
    static let itemHeight: CGFloat = 56
    /// Alto de cada pestaña cuando la barra se contrae al desplazar (54 − 2 × 4).
    static let compactItemHeight: CGFloat = 46
    static let innerPadding: CGFloat = 4
    static let outerVerticalPadding: CGFloat = 8
    /// Margen lateral de la cápsula; al contraerse se estrecha.
    static let horizontalInset: CGFloat = 16
    static let compactHorizontalInset: CGFloat = 64

    static var expandedHeight: CGFloat {
        itemHeight + innerPadding * 2 + outerVerticalPadding * 2
    }

    static var compactHeight: CGFloat {
        compactItemHeight + innerPadding * 2 + outerVerticalPadding * 2
    }

    /// Espacio reservado bajo el contenido.
    ///
    /// Siempre es el alto expandido, aunque la barra esté contraída: si el
    /// espacio reservado cambiara con el scroll, el contenido daría un salto
    /// justo mientras el usuario lo está desplazando.
    ///
    /// Incluye `outerVerticalPadding` arriba y abajo de la cápsula, así que al
    /// reservarlo queda ese mismo aire entre la barra y el último elemento.
    static var reservedHeight: CGFloat { expandedHeight }
}

/// Estado del cromo que reacciona al scroll de la pantalla activa.
@Observable
final class TabBarChrome {
    /// La barra inferior se contrae al alejarse del principio.
    var isCompact = false
    /// El encabezado necesita velo en cuanto hay contenido pasando por debajo.
    ///
    /// Umbral mucho más bajo que el de la barra: el velo tiene que aparecer en
    /// cuanto algo asoma, no cuando ya se ha desplazado medio dedo.
    var isScrolled = false
}

private struct FloatingTabBarHeightKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    /// Alto que reserva `floatingTabBarInset()`, o 0 fuera de `MainTabView`.
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

/// Contrae la barra en cuanto el contenido se separa del principio.
///
/// El umbral evita que el rebote elástico de la parte superior la haga
/// parpadear, y la histéresis (contraer a 40, expandir a 12) evita que oscile
/// cuando el usuario deja el scroll justo en el límite.
private struct TabBarCollapseModifier: ViewModifier {
    @Environment(TabBarChrome.self) private var chrome: TabBarChrome?

    private let collapseThreshold: CGFloat = 40
    private let expandThreshold: CGFloat = 12
    private let scrimThreshold: CGFloat = 6

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, offset in
                guard let chrome else { return }

                let scrolled = offset > scrimThreshold
                if scrolled != chrome.isScrolled {
                    withAnimation(.easeOut(duration: 0.22)) {
                        chrome.isScrolled = scrolled
                    }
                }

                let shouldCompact: Bool
                if chrome.isCompact {
                    shouldCompact = offset > expandThreshold
                } else {
                    shouldCompact = offset > collapseThreshold
                }
                guard shouldCompact != chrome.isCompact else { return }
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    chrome.isCompact = shouldCompact
                }
            }
            .onDisappear {
                guard let chrome else { return }
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    chrome.isCompact = false
                    chrome.isScrolled = false
                }
            }
    }
}

extension View {
    /// Reserva el hueco de la barra flotante. Es la **única** forma de hacerlo
    /// en toda la app.
    ///
    /// `MainTabView` dibuja la barra en un `overlay`, que no inyecta ningún
    /// espacio: si una superficie con scroll no llama a esto, su contenido pasa
    /// por debajo de la barra. La regla es literal —una llamada por cada
    /// `ScrollView` o `List` que se vea con la barra encima— y se puede
    /// auditar con un grep, porque no hay herencia implícita que compense un
    /// olvido ni un inset heredado que se sume por duplicado.
    ///
    /// Aplícalo al propio `ScrollView`/`List`, no a un contenedor lejano: el
    /// área segura sólo baja hasta el primer scroll que se encuentre, y un
    /// `NavigationStack` por medio la corta.
    ///
    /// No lo uses en hojas (`sheet`) ni en el login: ahí no hay barra. El valor
    /// del entorno sí se hereda en una hoja, así que reservaría un hueco que
    /// nada ocupa.
    func floatingTabBarInset() -> some View {
        modifier(FloatingTabBarInsetModifier())
    }

    /// Aplícalo al `ScrollView` o `List` de una pantalla raíz: contrae la barra
    /// inferior y avisa al encabezado de que hay contenido pasando por debajo.
    func tracksScrollChrome() -> some View {
        modifier(TabBarCollapseModifier())
    }
}
