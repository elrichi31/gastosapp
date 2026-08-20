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
        HStack(spacing: 12) {
            sectionSelector
            Spacer()
            addButton
        }
        .padding(.leading, 18)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .background(GastosCapsuleBackground())
    }

    private var sectionSelector: some View {
        HStack(spacing: 6) {
            ForEach(GastosSectionMode.allCases, id: \.self, content: modeButton)
        }
        .padding(4)
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
                    .font(.system(size: 16, weight: .bold))
                if isSelected {
                    Text(mode.title)
                        .font(.caption.weight(.bold))
                        .lineLimit(1)
                        .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .leading)))
                }
            }
            .foregroundStyle(isSelected ? AppTheme.onAccent : AppTheme.secondaryText)
            .padding(.horizontal, isSelected ? 13 : 0)
            .frame(width: isSelected ? nil : 42, height: 38)
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
                .shadow(color: AppTheme.accent.opacity(0.35), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Agregar gasto")
    }
}

private struct SelectorBackground: View {
    var body: some View {
        Capsule()
            .fill(AppTheme.controlSurface)
            .overlay(Capsule().strokeBorder(AppTheme.border, lineWidth: 1))
    }
}

struct GastosCapsuleBackground: View {
    var body: some View {
        AppTheme.chromeBackground(Capsule())
    }
}
