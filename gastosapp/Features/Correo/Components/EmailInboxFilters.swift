import SwiftUI

/// Pestañas Nuevos / Duplicados / Recibidos con su contador y, si se pide,
/// el campo de búsqueda.
struct EmailInboxFilters: View {
    @Binding var tab: String
    @Binding var query: String
    let counts: [String: Int]
    let isWorking: Bool
    var showsSearch = false
    @Namespace private var indicator

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
                .transition(AppMotion.reveal)
            }

            // Según el canvas «Correo»: el indicador se desliza entre pestañas y
            // el contador sólo aparece si hay algo, en verde en la activa.
            HStack(spacing: 4) {
                ForEach(EmailReviewTab.allCases) { item in
                    let active = tab == item.rawValue
                    let count = counts[item.rawValue] ?? 0
                    Button {
                        withAnimation(AppMotion.standard) { tab = item.rawValue }
                    } label: {
                        HStack(spacing: 6) {
                            Text(item.title)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            if count > 0 {
                                Text(count, format: .number)
                                    .font(.system(size: 11, weight: .bold))
                                    .monospacedDigit()
                                    .foregroundStyle(active ? AppTheme.onAccent : AppTheme.secondaryText)
                                    .padding(.horizontal, 5)
                                    .frame(minWidth: 18, minHeight: 18)
                                    .background(Capsule().fill(active ? AppTheme.accent : AppTheme.controlSurface))
                            }
                        }
                        .font(.system(size: 14, weight: active ? .semibold : .medium))
                        .foregroundStyle(active ? AppTheme.primaryText : AppTheme.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background {
                            if active {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(AppTheme.controlSurface)
                                    .matchedGeometryEffect(id: "tab", in: indicator)
                            }
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.title)
                    .accessibilityValue("\(count) pendientes")
                    .accessibilityAddTraits(active ? .isSelected : [])
                }
            }
            .padding(4)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(AppTheme.surface))
        }
        .disabled(isWorking)
    }
}
