import SwiftUI

struct EmailInboxFilters: View {
    @Binding var tab: String
    @Binding var query: String
    let counts: [String: Int]
    let isWorking: Bool
    var body: some View {
        VStack(spacing: 14) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { tabs }
                VStack(alignment: .leading, spacing: 8) { tabs }
            }
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(AppTheme.tertiaryText).accessibilityHidden(true)
                TextField("Buscar descripción, banco o fecha", text: $query)
                    .font(.subheadline).foregroundStyle(AppTheme.primaryText)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .submitLabel(.search)
                if !query.isEmpty {
                    Button("Limpiar búsqueda", systemImage: "xmark.circle.fill") { query = "" }
                        .labelStyle(.iconOnly).foregroundStyle(AppTheme.tertiaryText)
                }
            }
            .padding(.horizontal, 14).frame(minHeight: 46)
            .background(AppTheme.controlSurface, in: .rect(cornerRadius: AppTheme.Radius.control))
        }
        .disabled(isWorking)
    }
    private var tabs: some View {
        ForEach(EmailReviewTab.allCases) { item in
            let active = tab == item.rawValue
            Button { tab = item.rawValue } label: {
                HStack(spacing: 6) {
                    Text(item.title)
                    Text(counts[item.rawValue] ?? 0, format: .number)
                        .monospacedDigit().foregroundStyle(active ? AppTheme.accent : AppTheme.tertiaryText)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(active ? AppTheme.primaryText : AppTheme.secondaryText)
                .padding(.horizontal, 12).frame(minHeight: 42)
                .background(active ? AppTheme.accent.opacity(0.14) : AppTheme.controlSurface, in: Capsule())
                .overlay(Capsule().strokeBorder(active ? AppTheme.accent.opacity(0.35) : .clear, lineWidth: 1))
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(item.title)
            .accessibilityValue("\(counts[item.rawValue] ?? 0) pendientes")
            .accessibilityAddTraits(active ? .isSelected : [])
        }
    }
}
