import SwiftUI

/// Movimiento nuevo del correo, según el canvas «Correo»: nombre y monto
/// arriba, chips de categoría y pago que se despliegan en la misma tarjeta,
/// «⋯» con el resto de ajustes y la franja Descartar / Registrar.
struct EmailNewMovementCard: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let row: EmailMovement
    @Binding var draft: EmailDraft
    @Binding var panel: EmailCardPanel?
    let categories: [Categoria]
    let methods: [ExpensePaymentMethod]
    let isSavingAlias: Bool
    let onRememberName: (String) -> Void
    let onRegister: () -> Void
    let onDiscard: () -> Void

    private var category: Categoria? { categories.first { $0.id == draft.categoryID } }
    private var method: ExpensePaymentMethod? { methods.first { $0.id == draft.paymentID } }
    private var color: Color { category?.color ?? AppTheme.secondaryText }
    private var isRemembered: Bool { !(row.alias ?? "").isEmpty }

    var body: some View {
        EmailCard(border: draft.needsPayment ? AppTheme.warning.opacity(0.35) : AppTheme.separator) {
            summary
            chips
            if panel == .category { categoryOptions.transition(AppMotion.reveal) }
            if panel == .payment { paymentOptions.transition(AppMotion.reveal) }
            if panel == .more { moreOptions.transition(AppMotion.reveal) }
            EmailCardFooter {
                Button { toggle(.more) } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                        .frame(width: 56, height: 50)
                        .background(panel == .more ? AppTheme.popoverSurface : .clear)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Más opciones")
                .accessibilityAddTraits(panel == .more ? .isSelected : [])
                EmailConfirmedCardAction(title: "Descartar", question: "¿Descartar este movimiento?",
                    confirmTitle: "Descartar", message: "No se guardará como gasto y no volverá a aparecer en pendientes.",
                    action: onDiscard)
                EmailCardAction(title: "Registrar", icon: "checkmark",
                    tint: draft.isReady(for: row) ? AppTheme.accent : AppTheme.tertiaryText, emphasized: true) {
                    if draft.isReady(for: row) { onRegister() }
                    else if draft.needsPayment { open(.payment) }
                    else { open(.more) }
                }
            }
        }
        .animation(AppMotion.expand, value: panel)
    }

    private var summary: some View {
        HStack(spacing: 12) {
            Group {
                if let symbol = category?.symbolName {
                    Image(systemName: symbol).font(.system(size: 17, weight: .medium))
                } else {
                    Text(category?.monogram ?? "?").font(.system(size: 17, weight: .semibold))
                }
            }
            .foregroundStyle(color)
            .frame(width: 42, height: 42)
            .background(Circle().fill(color.opacity(0.16)))
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(draft.name.isEmpty ? row.descripcion : draft.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                Text([row.origen, EmailDates.short(row.fecha)].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.footnote)
                    .foregroundStyle(AppTheme.tertiaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(draft.total(for: row), format: .currency(code: "USD").precision(.fractionLength(2)))
                    .font(.system(size: 17, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.primaryText)
                    .contentTransition(.numericText())
                if let extra = draft.extraText {
                    Text(extra).font(.caption).foregroundStyle(AppTheme.tertiaryText)
                }
            }
            .fixedSize()
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .accessibilityElement(children: .combine)
    }

    private var chips: some View {
        ChipFlowLayout(spacing: 8) {
            chip(title: category?.nombre ?? "Categoría", isOpen: panel == .category, accessibility: "Categoría") {
                Circle().fill(color).frame(width: 8, height: 8)
            } action: { toggle(.category) }
            chip(title: method?.nombre ?? "Elegir pago", isOpen: panel == .payment, warns: draft.needsPayment, accessibility: "Método de pago") {
                Image(systemName: method?.icono ?? "creditcard").font(.system(size: 13, weight: .semibold))
            } action: { toggle(.payment) }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
    }

    private func chip<Leading: View>(title: String, isOpen: Bool, warns: Bool = false, accessibility: String,
                                     @ViewBuilder leading: () -> Leading, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                leading()
                Text(title).lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .opacity(0.6)
                    .rotationEffect(.degrees(isOpen ? 180 : 0))
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(warns ? AppTheme.warning : AppTheme.primaryText)
            .padding(.leading, 12).padding(.trailing, 10)
            .frame(height: 34)
            .background(Capsule().fill(warns ? AppTheme.warning.opacity(0.16) : isOpen ? AppTheme.strongBorder : AppTheme.controlSurface))
        }
        .buttonStyle(.pressable(scale: 0.95))
        .accessibilityLabel(accessibility)
        .accessibilityValue(title)
        .accessibilityAddTraits(isOpen ? .isSelected : [])
    }

    private var categoryOptions: some View {
        ChipFlowLayout(spacing: 8) {
            ForEach(categories) { item in
                EmailOptionChip(title: item.nombre, dot: item.color, isOn: item.id == draft.categoryID) {
                    draft.categoryID = item.id
                    panel = nil
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Categoría")
    }

    private var paymentOptions: some View {
        ChipFlowLayout(spacing: 8) {
            ForEach(methods) { item in
                EmailOptionChip(title: item.nombre, isOn: item.id == draft.paymentID) {
                    draft.paymentID = item.id
                    panel = nil
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Método de pago")
    }

    private var moreOptions: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Nombre").font(.caption).foregroundStyle(AppTheme.tertiaryText)
                TextField("Razón del gasto", text: $draft.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.primaryText)
                    .submitLabel(.done)
                    .accessibilityLabel("Nombre del gasto")
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(AppTheme.popoverSurface))

            HStack(spacing: 10) {
                Text(row.descripcion_original ?? row.descripcion)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(AppTheme.tertiaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
                if row.canHaveAlias {
                    Button {
                        onRememberName(isRemembered ? "" : draft.name)
                    } label: {
                        HStack(spacing: 6) {
                            if isSavingAlias { ProgressView().controlSize(.mini) }
                            Text(isRemembered ? "Recordado · Olvidar" : "Recordar nombre")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                        .frame(minHeight: 32)
                    }
                    .buttonStyle(.plain)
                    .disabled(isSavingAlias || (!isRemembered && draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                    .accessibilityHint("Usa este nombre en las próximas transferencias a este destinatario")
                }
            }

            HStack(spacing: 3) {
                segment("Pago completo", isOn: !draft.half) { draft.half = false }
                segment("Solo mi mitad", isOn: draft.half) { draft.half = true }
            }
            .padding(3)
            .background(Capsule().fill(AppTheme.popoverSurface))

            VStack(alignment: .leading, spacing: 0) {
                Toggle("Compra en el exterior", isOn: $draft.foreign.animation(AppMotion.fade))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.primaryText)
                    .tint(AppTheme.accent)
                    .frame(minHeight: 50)
                if draft.foreign {
                    HStack(spacing: 8) {
                        taxChip("isd", "ISD 5%")
                        taxChip("iva_digital", "IVA 15%")
                        Text("+ " + draft.tax(for: row).taxAmount.formatted(.currency(code: "USD").precision(.fractionLength(2))))
                            .font(.system(size: 13))
                            .monospacedDigit()
                            .foregroundStyle(AppTheme.tertiaryText)
                    }
                    .padding(.bottom, 12)
                    .transition(.opacity)
                    if draft.taxes.isEmpty {
                        Text("Elige al menos un impuesto.").font(.caption).foregroundStyle(AppTheme.warning).padding(.bottom, 10)
                    }
                }
            }
            .padding(.leading, 14).padding(.trailing, 12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(AppTheme.popoverSurface))
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
    }

    private func segment(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button { withAnimation(AppMotion.standard, action) } label: {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isOn ? AppTheme.backgroundTop : AppTheme.secondaryText)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(Capsule().fill(isOn ? AppTheme.primaryText : .clear))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func taxChip(_ id: String, _ title: String) -> some View {
        let isOn = draft.taxes.contains(id)
        return Button {
            if isOn { draft.taxes.removeAll { $0 == id } } else { draft.taxes.append(id) }
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isOn ? AppTheme.onAccent : AppTheme.secondaryText)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(Capsule().fill(isOn ? AppTheme.accent : AppTheme.controlSurface))
        }
        .buttonStyle(.pressable(scale: 0.95))
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func toggle(_ value: EmailCardPanel) {
        panel = panel == value ? nil : value
    }

    private func open(_ value: EmailCardPanel) {
        panel = value
    }
}

enum EmailDates {
    static func short(_ value: String) -> String {
        AppDateCodec.dateOnly(from: value)?.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "es"))) ?? value
    }
}
