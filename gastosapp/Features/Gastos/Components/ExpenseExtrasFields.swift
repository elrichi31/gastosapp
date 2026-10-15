import SwiftUI

/// Etiquetas, según el canvas «Nuevo gasto»: las elegidas como chips que se
/// quitan al tocarlas, un campo para añadir y las usadas antes como atajos.
///
/// Sigue guardando el texto separado por comas que espera `ExpenseTags`, así
/// los formularios que ya lo usan no cambian.
struct ExpenseExtrasFields: View {
    @Binding var tagsText: String
    @Environment(ExpenseStore.self) private var store
    @State private var draft = ""
    @FocusState private var draftFocused: Bool

    /// Etiquetas que pone la app, no el usuario.
    private static let systemTags: Set<String> = ["auto", "exterior"]

    private var tags: [String] {
        ExpenseTags.normalize(tagsText)
    }

    /// Las etiquetas más usadas en los gastos registrados, sin las ya elegidas.
    private var suggested: [String] {
        let chosen = Set(tags)
        let counts = Dictionary(store.gastos.flatMap { $0.tags ?? [] }.map { ($0, 1) }, uniquingKeysWith: +)
        return counts
            .filter { !chosen.contains($0.key) && !Self.systemTags.contains($0.key) }
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .prefix(8)
            .map(\.key)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FormSectionTitle(
                title: "Etiquetas",
                trailing: tags.isEmpty ? "Opcional" : tags.count == 1 ? "1 añadida" : "\(tags.count) añadidas"
            )

            VStack(alignment: .leading, spacing: 12) {
                ChipFlowLayout(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        Button {
                            remove(tag)
                        } label: {
                            HStack(spacing: 6) {
                                Text("#\(tag)")
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                            .padding(.leading, 12)
                            .padding(.trailing, 8)
                            .frame(height: 32)
                            .background(Capsule().fill(AppTheme.accent.opacity(0.18)))
                        }
                        .buttonStyle(.pressable(scale: 0.94))
                        .accessibilityLabel("Quitar etiqueta \(tag)")
                    }

                    HStack(spacing: 1) {
                        Text("#").foregroundStyle(AppTheme.tertiaryText)
                        TextField("añadir etiqueta", text: $draft)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .focused($draftFocused)
                            .onSubmit { add(draft) }
                            .onChange(of: draft) { _, value in
                                if value.contains(",") { add(value) }
                            }
                            .accessibilityLabel("Nueva etiqueta")
                    }
                    .font(.subheadline)
                    .frame(minWidth: 120, minHeight: 32)
                }

                if !suggested.isEmpty {
                    Rectangle().fill(AppTheme.separator).frame(height: 1)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Usadas antes")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.tertiaryText)
                        ChipFlowLayout(spacing: 6) {
                            ForEach(suggested, id: \.self) { tag in
                                Button {
                                    add(tag)
                                } label: {
                                    Text("#\(tag)")
                                        .font(.footnote.weight(.medium))
                                        .foregroundStyle(AppTheme.secondaryText)
                                        .padding(.horizontal, 14)
                                        .frame(height: 36)
                                        .background(Capsule().fill(AppTheme.popoverSurface))
                                }
                                .buttonStyle(.pressable(scale: 0.94))
                                .accessibilityLabel("Añadir etiqueta \(tag)")
                            }
                        }
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.surface)
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(AppTheme.separator, lineWidth: 1))
            )

            if !ExpenseTags.isValid(tags) {
                Text("Hasta 10 etiquetas de 30 caracteres.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.negative)
            }
        }
    }

    private func add(_ raw: String) {
        let names = ExpenseTags.normalize(raw.replacingOccurrences(of: "#", with: ""))
        draft = ""
        guard !names.isEmpty else { return }
        tagsText = (tags + names.filter { !tags.contains($0) }).joined(separator: ", ")
    }

    private func remove(_ tag: String) {
        tagsText = tags.filter { $0 != tag }.joined(separator: ", ")
    }
}
