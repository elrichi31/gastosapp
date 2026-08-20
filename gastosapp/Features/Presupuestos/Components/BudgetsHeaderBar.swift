import SwiftUI

struct BudgetsHeaderBar: View {
    let year: Int
    let onPreviousYear: () -> Void
    let onNextYear: () -> Void
    let onAddTap: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text("Presupuestos")
                .font(.system(.title3, design: .default, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .layoutPriority(1)

            Spacer(minLength: 6)
            yearSelector
            addButton
        }
        .padding(.leading, 16)
        .padding(.trailing, 12)
        .padding(.vertical, 10)
        .background(headerBackground)
    }

    private var yearSelector: some View {
        HStack(spacing: 2) {
            yearButton(icon: "chevron.left", action: onPreviousYear, label: "Año anterior")
            Text(verbatim: "\(year)")
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(AppTheme.primaryText)
                .contentTransition(.numericText())
                .frame(minWidth: 42)
            yearButton(icon: "chevron.right", action: onNextYear, label: "Año siguiente")
        }
        .padding(3)
        .background(
            Capsule()
                .fill(AppTheme.controlSurface)
                .overlay(Capsule().stroke(AppTheme.border, lineWidth: 1))
        )
        .accessibilityElement(children: .contain)
    }

    private func yearButton(icon: String, action: @escaping () -> Void, label: String) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppTheme.primaryText.opacity(0.8))
                .frame(width: 44, height: 44)
                .background(Circle().fill(AppTheme.insetSurface))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var addButton: some View {
        Button(action: onAddTap) {
            Image(systemName: "plus")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.accent, Color(red: 0.25, green: 0.85, blue: 0.55)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Crear presupuesto")
    }

    private var headerBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(AppTheme.chromeSurface)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.42))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AppTheme.primaryText.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.16), radius: 16, y: 6)
    }
}
