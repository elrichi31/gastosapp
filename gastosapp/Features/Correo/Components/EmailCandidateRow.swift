import SwiftUI

struct EmailCandidateRow: View {
    let candidate: EmailCandidate
    let isSelected: Bool
    let onSelect: () -> Void
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3).foregroundStyle(isSelected ? AppTheme.accent : AppTheme.tertiaryText)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(candidate.gasto.descripcion).font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.primaryText)
                    Text(candidate.gasto.fecha).font(.caption).foregroundStyle(AppTheme.secondaryText)
                    if candidate.veredicto == "no_encaja" {
                        Label("Comprueba que sea el mismo gasto", systemImage: "exclamationmark.triangle")
                            .font(.caption).foregroundStyle(AppTheme.warning)
                    }
                }
                Spacer(minLength: 4)
                Text(candidate.gasto.monto, format: .currency(code: "USD"))
                    .font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.primaryText)
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.controlSurface, in: .rect(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(isSelected ? AppTheme.accent.opacity(0.5) : AppTheme.border, lineWidth: 1))
        }
        .buttonStyle(.plain).accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
