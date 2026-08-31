import SwiftUI

struct MainTabView: View {
    enum Tab: Hashable {
        case inicio, gastos, presupuestos, stats, perfil
    }

    @State private var seleccion: Tab = .inicio

    var body: some View {
        currentTabView
        .environment(\.floatingTabBarHeight, FloatingTabBarMetrics.totalHeight)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PillTabBar(seleccion: $seleccion)
                .padding(.horizontal, 12)
                .padding(.vertical, FloatingTabBarMetrics.outerVerticalPadding)
                .frame(maxWidth: .infinity)
        }
        .ignoresSafeArea(.keyboard)
        .sensoryFeedback(.selection, trigger: seleccion)
    }

    @ViewBuilder
    private var currentTabView: some View {
        switch seleccion {
        case .inicio:
            HomeView()
        case .gastos:
            GastosView()
        case .presupuestos:
            BudgetsView()
        case .stats:
            StatsView()
        case .perfil:
            ProfileView()
        }
    }
}

private struct PillTabBar: View {
    @Binding var seleccion: MainTabView.Tab
    @Namespace private var indicator

    private let items: [(tab: MainTabView.Tab, icon: String, title: String)] = [
        (.inicio, "house.fill", "Inicio"),
        (.gastos, "creditcard.fill", "Gastos"),
        (.presupuestos, "target", "Presupuestos"),
        (.stats, "chart.bar.fill", "Análisis"),
        (.perfil, "person.fill", "Perfil")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.tab) { item in
                botonTab(tab: item.tab, icono: item.icon, titulo: item.title)
            }
        }
        .padding(FloatingTabBarMetrics.innerPadding)
        .background(AppTheme.chromeBackground(Capsule()))
        .accessibilityElement(children: .contain)
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
                    .font(.system(size: 16, weight: .semibold))
                Text(titulo)
                    .font(.system(size: 9, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 2)
            }
            .foregroundStyle(activo ? AppTheme.accent : AppTheme.tertiaryText)
            .frame(maxWidth: .infinity)
            .frame(height: FloatingTabBarMetrics.itemHeight)
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
        .buttonStyle(.plain)
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
