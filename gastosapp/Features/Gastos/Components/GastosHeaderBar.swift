import SwiftUI

enum GastosSectionMode: Hashable, CaseIterable {
    case movimientos
    case recurrentes
    case calendario

    var title: String {
        switch self {
        case .movimientos:
            return "Movimientos"
        case .recurrentes:
            return "Recurrentes"
        case .calendario:
            return "Calendario"
        }
    }

    var icon: String {
        switch self {
        case .movimientos:
            return "list.bullet"
        case .recurrentes:
            return "repeat.circle.fill"
        case .calendario:
            return "calendar"
        }
    }
}

struct GastosHeaderBar: View {
    @Binding var sectionMode: GastosSectionMode

    let onAddTap: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Tu dinero")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.secondaryText)
                    Text("Gastos")
                        .font(.largeTitle.bold())
                        .foregroundStyle(AppTheme.primaryText)
                }

                Spacer()
                addButton
            }

            sectionSelector
        }
        .frame(maxWidth: .infinity)
    }

    private var sectionSelector: some View {
        HStack(spacing: 6) {
            ForEach(GastosSectionMode.allCases, id: \.self, content: modeButton)
        }
        .padding(5)
        .frame(maxWidth: .infinity)
        .background(SelectorBackground())
    }

    private func modeButton(_ mode: GastosSectionMode) -> some View {
        let isSelected = sectionMode == mode
        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                sectionMode = mode
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: mode.icon)
                    .font(.system(size: 14, weight: .bold))
                Text(mode.title)
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? AppTheme.onAccent : AppTheme.secondaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(Capsule().fill(isSelected ? AppTheme.accent : .clear))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.title)
    }

    private var addButton: some View {
        Button(action: onAddTap) {
            Image(systemName: "plus")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(AppTheme.onAccent)
                .frame(width: 44, height: 44)
                .background(Circle().fill(AppTheme.accent))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Agregar gasto")
    }
}

private struct SelectorBackground: View {
    var body: some View {
        Capsule()
            .fill(AppTheme.controlSurface)
            .overlay(Capsule().strokeBorder(AppTheme.strongBorder, lineWidth: 1))
    }
}

struct GastosCapsuleBackground: View {
    var body: some View {
        AppTheme.chromeBackground(Capsule())
    }
}
