import SwiftUI

struct ExpenseExtrasFields: View {
    @Binding var tagsText: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Etiquetas").font(.headline)
            TextField("viaje, familia", text: $tagsText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Text("Hasta 10 etiquetas de 30 caracteres, separadas por comas.")
                .font(.caption).foregroundStyle(AppTheme.secondaryText)
            if !ExpenseTags.isValid(ExpenseTags.normalize(tagsText)) {
                Text("Revisa la cantidad y longitud de las etiquetas.").foregroundStyle(AppTheme.negative)
            }
        }
        .padding(16).background(AppTheme.controlSurface, in: .rect(cornerRadius: 16))
    }
}
