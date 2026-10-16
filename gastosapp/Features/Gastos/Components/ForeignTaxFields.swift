import SwiftUI

/// Compra en el exterior, según el canvas «Nuevo gasto»: interruptor, impuestos
/// marcables con su porcentaje y el desglose del total a registrar.
struct ForeignTaxFields: View {
    @Binding var enabled: Bool
    @Binding var selected: [String]
    @Binding var customRate: String
    let base: Double
    var legacyTotal = false

    private struct TaxOption {
        let id: String
        let label: String
        let short: String
        let rate: Double
        let hint: String
    }

    private static let options = [
        TaxOption(id: "isd", label: "Salida de divisas (ISD)", short: "ISD", rate: 5,
                  hint: "Compras con tarjeta en tiendas del exterior (Amazon, AliExpress, viajes)."),
        TaxOption(id: "iva_digital", label: "IVA servicios digitales", short: "IVA", rate: 15,
                  hint: "Suscripciones y apps extranjeras (Netflix, Spotify, ChatGPT, Google, Apple).")
    ]

    private var detail: ForeignTax { ForeignTax(base: base, selected: selected, customRate: customRate) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "globe")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(AppTheme.secondaryText)
                    .padding(.top, 2)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Compra en el exterior")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppTheme.primaryText)
                    Text("Tu banco cobró impuestos extra.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.tertiaryText)
                }
                Spacer(minLength: 8)
                Toggle("Compra en el exterior", isOn: $enabled.animation(AppMotion.fade))
                    .labelsHidden()
                    .tint(AppTheme.accent)
            }

            if legacyTotal && !enabled {
                Text("Este monto ya incluye impuestos y no tiene desglose. Activa la opción solo si introduces el precio original.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.warning)
            }

            if enabled {
                VStack(alignment: .leading, spacing: 10) {
                    Text("¿Qué te cobraron? Puedes marcar varios.")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.tertiaryText)

                    ForEach(Self.options, id: \.id) { option in
                        taxRow(option)
                    }
                    customRow
                    breakdown

                    if !detail.isValid {
                        Text("Elige un impuesto y revisa el porcentaje y el monto.")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.negative)
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(enabled ? AppTheme.surface : .clear)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(AppTheme.separator, lineWidth: 1))
        )
    }

    private func isOn(_ id: String) -> Bool { selected.contains(id) }

    private func toggle(_ id: String) {
        if isOn(id) { selected.removeAll { $0 == id } } else { selected.append(id) }
    }

    private func taxRow(_ option: TaxOption) -> some View {
        Button {
            toggle(option.id)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                checkbox(isOn(option.id))
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(option.label).fontWeight(.medium).foregroundStyle(AppTheme.primaryText)
                        Spacer(minLength: 8)
                        Text("\(Int(option.rate))%").monospacedDigit().foregroundStyle(AppTheme.tertiaryText)
                    }
                    .font(.subheadline)
                    Text(option.hint)
                        .font(.caption)
                        .foregroundStyle(AppTheme.tertiaryText)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(rowBackground(isOn(option.id)))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn(option.id) ? .isSelected : [])
    }

    private var customRow: some View {
        HStack(spacing: 12) {
            Button {
                toggle("custom")
            } label: {
                HStack(spacing: 12) {
                    checkbox(isOn("custom"))
                    Text("Otro porcentaje")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.primaryText)
                    Spacer(minLength: 8)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isOn("custom") ? .isSelected : [])

            if isOn("custom") {
                HStack(spacing: 4) {
                    TextField("0", text: $customRate)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .monospacedDigit()
                        .accessibilityLabel("Porcentaje personalizado")
                    Text("%").foregroundStyle(AppTheme.tertiaryText)
                }
                .font(.system(size: 15))
                .padding(.horizontal, 10)
                .frame(width: 84, height: 36)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(AppTheme.popoverSurface))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(rowBackground(isOn("custom")))
    }

    private var breakdown: some View {
        let lines = Self.options.filter { isOn($0.id) }.map { ("\($0.short) \(Int($0.rate))%", ForeignTax.cents(base * $0.rate / 100)) }
            + (isOn("custom") && (detail.customPercentage ?? 0) > 0
               ? [("Otro \(customRate)%", ForeignTax.cents(base * (detail.customPercentage ?? 0) / 100))] : [])
        return VStack(spacing: 6) {
            breakdownRow("Precio original", base, emphasized: false)
            ForEach(lines, id: \.0) { line in
                breakdownRow("+ \(line.0)", line.1, emphasized: false)
            }
            Rectangle().fill(AppTheme.separator).frame(height: 1)
            breakdownRow("Total a registrar", detail.total, emphasized: true)
        }
        .font(.subheadline)
        .monospacedDigit()
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.surface)
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(AppTheme.separator, lineWidth: 1))
        )
    }

    private func breakdownRow(_ label: String, _ value: Double, emphasized: Bool) -> some View {
        HStack {
            Text(label).foregroundStyle(emphasized ? AppTheme.primaryText : AppTheme.tertiaryText)
            Spacer()
            Text(value.formatted(.currency(code: "USD").precision(.fractionLength(2))))
                .foregroundStyle(AppTheme.primaryText)
        }
        .fontWeight(emphasized ? .semibold : .regular)
    }

    private func checkbox(_ on: Bool) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(on ? AppTheme.accent : .clear)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(on ? AppTheme.accent : AppTheme.strongBorder, lineWidth: 1.5)
            )
            .overlay {
                if on {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppTheme.onAccent)
                }
            }
            .frame(width: 22, height: 22)
            .accessibilityHidden(true)
    }

    private func rowBackground(_ on: Bool) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(AppTheme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(on ? AppTheme.accent : AppTheme.separator, lineWidth: 1.5)
            )
    }
}
