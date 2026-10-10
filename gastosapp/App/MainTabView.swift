import SwiftUI

struct MainTabView: View {
    enum Tab: Hashable {
        case inicio, gastos, presupuestos, stats
    }

    @State private var seleccion: Tab = .inicio
    @State private var chrome = TabBarChrome()

    var body: some View {
        currentTabView
        .environment(\.floatingTabBarHeight, FloatingTabBarMetrics.reservedHeight)
        .environment(chrome)
        // La barra va en un `overlay`, no en un `safeAreaInset`: así no inyecta
        // ningún espacio implícito en el contenido. Todo el hueco bajo la barra
        // lo pide cada pantalla con `.floatingTabBarInset()`, que es lo único
        // que reserva sitio en toda la app. Con `safeAreaInset` había dos
        // fuentes de hueco —la implícita, que SwiftUI no propaga a lo que
        // empuja un `NavigationStack`, y la explícita— y unas pantallas
        // quedaban tapadas mientras otras reservaban el doble.
        .overlay(alignment: .bottom) {
            PillTabBar(seleccion: $seleccion, isCompact: chrome.isCompact)
                .padding(.horizontal, 12)
                .padding(.bottom, FloatingTabBarMetrics.outerVerticalPadding)
        }
        .ignoresSafeArea(.keyboard)
        .sensoryFeedback(.selection, trigger: seleccion)
        .onChange(of: seleccion) { _, _ in
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                chrome.isCompact = false
            }
        }
    }

    private var currentTabView: some View {
        tabContent
            // La identidad por pestaña es lo que le da a SwiftUI algo que
            // transicionar: sin el `id` cambiaría el contenido en seco.
            .id(seleccion)
            .transition(.opacity)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch seleccion {
        case .inicio:
            HomeView()
        case .gastos:
            GastosView()
        case .presupuestos:
            BudgetsView()
        case .stats:
            StatsView()
        }
    }
}

private struct PillTabBar: View {
    @Binding var seleccion: MainTabView.Tab
    let isCompact: Bool
    @Namespace private var indicator

    private let items: [(tab: MainTabView.Tab, icon: String, title: String)] = [
        (.inicio, "house.fill", "Inicio"),
        (.gastos, "creditcard.fill", "Gastos"),
        (.presupuestos, "target", "Presupuestos"),
        (.stats, "chart.bar.fill", "Análisis")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.tab) { item in
                botonTab(tab: item.tab, icono: item.icon, titulo: item.title)
            }
        }
        .padding(FloatingTabBarMetrics.innerPadding)
        .appChromeBackground(Capsule())
        .accessibilityElement(children: .contain)
    }

    /// Cuánto se reduce el icono cuando el rótulo está visible.
    private var iconShrinkFactor: CGFloat {
        FloatingTabBarMetrics.iconSize / FloatingTabBarMetrics.compactIconSize
    }

    private func botonTab(tab: MainTabView.Tab, icono: String, titulo: String) -> some View {
        let activo = seleccion == tab
        return Button {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.8)) {
                seleccion = tab
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icono)
                    .font(.system(size: FloatingTabBarMetrics.compactIconSize, weight: .semibold))
                    .scaleEffect(isCompact ? 1 : iconShrinkFactor, anchor: .center)
                    .frame(height: FloatingTabBarMetrics.compactIconSize)
                    .symbolEffect(.bounce, value: activo)
                if !isCompact {
                    Text(titulo)
                        .font(.system(size: 9, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, 2)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .foregroundStyle(activo ? AppTheme.accent : AppTheme.tertiaryText)
            .frame(maxWidth: .infinity)
            .frame(height: isCompact ? FloatingTabBarMetrics.compactItemHeight : FloatingTabBarMetrics.itemHeight)
            .background {
                if activo {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.accent.opacity(0.22), AppTheme.accent.opacity(0.10)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(Capsule().strokeBorder(AppTheme.accent.opacity(0.20), lineWidth: 0.75))
                        .matchedGeometryEffect(id: "tab", in: indicator)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.pressable(scale: 0.9))
        .accessibilityLabel(titulo)
        .accessibilityValue(activo ? "Seleccionado" : "")
        .accessibilityAddTraits(activo ? .isSelected : [])
    }
}

#Preview {
    MainTabView()
        .environment(ExpenseStore())
        .environment(BudgetStore())
}
