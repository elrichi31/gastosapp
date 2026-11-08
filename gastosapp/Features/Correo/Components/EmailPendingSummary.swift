import SwiftUI

/// «Por registrar»: total de los movimientos nuevos y el botón que registra de
/// una vez los que ya tienen forma de pago.
struct EmailPendingSummary: View {
    let total: Double
    let count: Int
    let missingPayment: Int
    let isWorking: Bool
    let onRegister: () -> Void

    private var ready: Int { count - missingPayment }
    private var buttonTitle: String {
        if ready == 0 { return "Elegir pago" }
        if ready == count { return count == 1 ? "Registrar" : "Registrar todos" }
        return "Registrar \(ready)"
    }
    private var subtitle: String {
        let base = count == 1 ? "1 movimiento" : "\(count) movimientos"
        return missingPayment > 0 ? "\(base) · \(missingPayment) sin pago" : base
    }

    var body: some View {
        let text = total.formatted(.currency(code: "USD").precision(.fractionLength(2)))
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Por registrar").font(.footnote).foregroundStyle(AppTheme.secondaryText)
                (Text(String(text.dropLast(3))) + Text(String(text.suffix(3))).font(.system(size: 20, weight: .semibold)).foregroundColor(AppTheme.tertiaryText))
                    .font(.system(size: 30, weight: .semibold))
                    .tracking(-0.8)
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.primaryText)
                    .contentTransition(.numericText())
                Text(subtitle).font(.footnote).foregroundStyle(AppTheme.tertiaryText)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 8)
            Button(action: onRegister) {
                HStack(spacing: 6) {
                    if isWorking { ProgressView().controlSize(.small).tint(AppTheme.backgroundTop) }
                    else { Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)) }
                    Text(buttonTitle)
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppTheme.backgroundTop)
                .padding(.horizontal, 16)
                .frame(height: 44)
                .background(Capsule().fill(AppTheme.primaryText))
            }
            .buttonStyle(.pressable(scale: 0.96))
            .disabled(isWorking)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                .fill(LinearGradient(colors: [AppTheme.accent.opacity(0.16), AppTheme.primaryText.opacity(0.02)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous).strokeBorder(AppTheme.accent.opacity(0.3), lineWidth: 1))
        )
    }
}
