import SwiftUI

/// Pestañas Nuevos / Duplicados / Recibidos con su contador y, si se pide,
/// el campo de búsqueda.
struct EmailInboxFilters: View {
    @Binding var tab: String
    @Binding var query: String
    let counts: [String: Int]
    let isWorking: Bool
    var showsSearch = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showsSearch {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(AppTheme.tertiaryText)
                        .accessibilityHidden(true)
                    TextField("Descripción, fecha o banco", text: $query)
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.primaryText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .accessibilityLabel("Buscar movimientos")
                    if !query.isEmpty {
                        Button("Limpiar búsqueda", systemImage: "xmark.circle.fill") { query = "" }
                            .labelStyle(.iconOnly)
                            .foregroundStyle(AppTheme.tertiaryText)
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(Capsule().fill(AppTheme.popoverSurface))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            HStack(spacing: 4) {
                ForEach(EmailReviewTab.allCases) { item in
                    let active = tab == item.rawValue
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) { tab = item.rawValue }
                    } label: {
                        HStack(spacing: 6) {
                            Text(item.title)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Text(counts[item.rawValue] ?? 0, format: .number)
                                .font(.caption.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(active ? AppTheme.accent : AppTheme.tertiaryText)
                        }
                        .font(.system(size: 14, weight: active ? .semibold : .medium))
                        .foregroundStyle(active ? AppTheme.backgroundTop : AppTheme.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(Capsule().fill(active ? AppTheme.primaryText : .clear))
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.title)
                    .accessibilityValue("\(counts[item.rawValue] ?? 0) pendientes")
                    .accessibilityAddTraits(active ? .isSelected : [])
                }
            }
            .padding(4)
            .background(Capsule().fill(AppTheme.surface))
        }
        .disabled(isWorking)
    }
}
