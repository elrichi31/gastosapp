import SwiftUI

/// Posible duplicado: lo que llegó del correo frente al gasto ya registrado,
/// con las señales que coinciden, y «Es otro gasto» / «Es el mismo».
struct EmailDuplicateCard: View {
    let row: EmailMovement
    @Binding var candidateID: Int?
    let onOther: () -> Void
    let onSame: (EmailCandidate) -> Void

    private var candidate: EmailCandidate? {
        row.coincidencias.first { $0.id == candidateID } ?? row.coincidencias.first
    }

    var body: some View {
        EmailCard {
            Label("Posible duplicado", systemImage: "square.on.square")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.warning)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(Capsule().fill(AppTheme.warning.opacity(0.14)))
                .padding([.horizontal, .top], 14)

            if let candidate {
                HStack(spacing: 4) {
                    side(title: "DEL CORREO", name: row.descripcion, amount: row.monto, date: row.fecha)
                    Text("=").font(.system(size: 18)).foregroundStyle(AppTheme.tertiaryText).frame(width: 24).accessibilityHidden(true)
                    side(title: "YA REGISTRADO", name: candidate.gasto.descripcion, amount: candidate.gasto.monto, date: candidate.gasto.fecha)
                }
                .padding(14)

                EmailSignals(row: row, candidate: candidate)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)

                if row.coincidencias.count > 1 {
                    EmailCandidatePicker(candidates: row.coincidencias, selectedID: candidate.id) { candidateID = $0 }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 12)
                }
            }

            EmailCardFooter {
                EmailCardAction(title: "Es otro gasto", action: onOther)
                EmailCardAction(title: "Es el mismo", tint: AppTheme.accent, emphasized: true) {
                    if let candidate { onSame(candidate) }
                }
                .disabled(candidate == nil)
            }
        }
    }

    private func side(title: String, name: String, amount: Double, date: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 11, weight: .semibold)).tracking(0.3).foregroundStyle(AppTheme.tertiaryText)
            Text(name).font(.system(size: 15, weight: .semibold)).foregroundStyle(AppTheme.primaryText).lineLimit(1)
            Text(amount, format: .currency(code: "USD").precision(.fractionLength(2)))
                .font(.system(size: 15)).monospacedDigit().foregroundStyle(AppTheme.primaryText)
            Text(EmailDates.short(date)).font(.caption).foregroundStyle(AppTheme.tertiaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(AppTheme.popoverSurface))
        .accessibilityElement(children: .combine)
    }
}

/// Devolución recibida: se descuenta del gasto que corresponde.
struct EmailRefundCard: View {
    let row: EmailMovement
    @Binding var candidateID: Int?
    let onIgnore: () -> Void
    let onDeduct: (EmailCandidate) -> Void

    private var candidate: EmailCandidate? {
        row.coincidencias.first { $0.id == candidateID } ?? row.coincidencias.first
    }

    var body: some View {
        EmailCard {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.descripcion).font(.system(size: 16, weight: .semibold)).foregroundStyle(AppTheme.primaryText).lineLimit(2)
                    Group {
                        if let candidate {
                            Text("Descontar de \(candidate.gasto.descripcion) · \(candidate.gasto.monto.formatted(.currency(code: "USD").precision(.fractionLength(2))))")
                        } else {
                            Text("No encontramos un gasto del que descontarla")
                        }
                    }
                    .font(.footnote).foregroundStyle(AppTheme.tertiaryText)
                }
                Spacer(minLength: 8)
                Text("+" + row.monto.formatted(.currency(code: "USD").precision(.fractionLength(2))))
                    .font(.system(size: 17, weight: .semibold)).monospacedDigit()
                    .foregroundStyle(AppTheme.positive)
                    .fixedSize()
            }
            .padding(14)
            .accessibilityElement(children: .combine)

            if row.coincidencias.count > 1, let candidate {
                EmailCandidatePicker(candidates: row.coincidencias, selectedID: candidate.id) { candidateID = $0 }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
            }

            EmailCardFooter {
                EmailConfirmedCardAction(title: "Ignorar", question: "¿Ignorar esta devolución?",
                    confirmTitle: "Ignorar", message: "No se descontará de ningún gasto y no volverá a aparecer en pendientes.",
                    action: onIgnore)
                EmailCardAction(title: "Descontar", tint: candidate == nil ? AppTheme.tertiaryText : AppTheme.accent, emphasized: true) {
                    if let candidate { onDeduct(candidate) }
                }
                .disabled(candidate == nil)
            }
        }
    }
}

/// Qué coincide entre el movimiento y el gasto registrado.
private struct EmailSignals: View {
    let row: EmailMovement
    let candidate: EmailCandidate

    private var signals: [String] {
        var list: [String] = []
        if abs(row.monto - candidate.gasto.monto) < 0.005 { list.append("Mismo monto") }
        if candidate.dias == 0 { list.append("Mismo día") }
        let a = row.descripcion.normalizedLookupKey, b = candidate.gasto.descripcion.normalizedLookupKey
        if !a.isEmpty, !b.isEmpty, a.contains(b) || b.contains(a) { list.append("Mismo comercio") }
        return list
    }

    var body: some View {
        ChipFlowLayout(spacing: 6) {
            ForEach(signals, id: \.self) { signal in
                Label(signal, systemImage: "checkmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.positive)
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(Capsule().fill(AppTheme.positive.opacity(0.1)))
            }
            if candidate.veredicto == "no_encaja" {
                Label("Comprueba que sea el mismo", systemImage: "exclamationmark.triangle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.warning)
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(Capsule().fill(AppTheme.warning.opacity(0.14)))
            }
        }
    }
}

/// Con varias coincidencias, elige con cuál comparar.
private struct EmailCandidatePicker: View {
    let candidates: [EmailCandidate]
    let selectedID: Int
    let onPick: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Otras coincidencias").font(.caption.weight(.medium)).foregroundStyle(AppTheme.tertiaryText)
            ChipFlowLayout(spacing: 8) {
                ForEach(candidates) { candidate in
                    EmailOptionChip(title: candidate.gasto.descripcion,
                        detail: candidate.gasto.monto.formatted(.currency(code: "USD").precision(.fractionLength(2))),
                        isOn: candidate.id == selectedID) { onPick(candidate.id) }
                }
            }
        }
    }
}
