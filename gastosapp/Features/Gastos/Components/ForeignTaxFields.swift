import SwiftUI

struct ForeignTaxFields: View {
    @Binding var enabled: Bool
    @Binding var selected: [String]
    @Binding var customRate: String
    let base: Double
    var legacyTotal = false

    private var detail: ForeignTax { ForeignTax(base: base, selected: selected, customRate: customRate) }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Compra en el exterior", isOn: $enabled).tint(AppTheme.accent)
            if legacyTotal && !enabled {
                Text("Este monto ya incluye impuestos y no tiene desglose. Activa la opción solo si introduces el precio original.")
                    .font(.caption).foregroundStyle(AppTheme.warning)
            }
            if enabled {
                Text("Introduce el precio original. Cada impuesto se calcula sobre ese precio.")
                    .font(.caption).foregroundStyle(AppTheme.secondaryText)
                taxToggle("ISD 5%", id: "isd")
                taxToggle("IVA servicios digitales 15%", id: "iva_digital")
                taxToggle("Otro porcentaje", id: "custom")
                if selected.contains("custom") {
                    TextField("Porcentaje (0–100)", text: $customRate).keyboardType(.decimalPad)
                }
                LabeledContent("Impuestos", value: detail.taxAmount.formatted(.currency(code: "USD")))
                LabeledContent("Total", value: detail.total.formatted(.currency(code: "USD"))).font(.headline)
                if !detail.isValid {
                    Text("Elige un impuesto y revisa el porcentaje y el monto.")
                        .font(.caption).foregroundStyle(AppTheme.negative)
                }
            }
        }
        .padding(16).background(AppTheme.controlSurface, in: .rect(cornerRadius: 16))
    }
    private func taxToggle(_ title: String, id: String) -> some View {
        Toggle(title, isOn: Binding(get: { selected.contains(id) }, set: { on in
            selected.removeAll { $0 == id }
            if on { selected.append(id) }
        })).tint(AppTheme.accent)
    }
}
