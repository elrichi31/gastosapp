import SwiftUI

struct ExpenseFormStatus {
    let title: String
    let message: String
    let icon: String
    let tint: Color
}

struct ExpenseFormStatusCard: View {
    let status: ExpenseFormStatus

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ExpenseIconBadge(systemName: status.icon, color: status.tint)

            VStack(alignment: .leading, spacing: 4) {
                Text(status.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText)
                Text(status.message)
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.controlSurface)
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(AppTheme.border, lineWidth: 1))
        )
    }
}

struct ExpenseIconBadge: View {
    let systemName: String
    let color: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 30, height: 30)
            .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct ExpenseFormDivider: View {
    var body: some View {
        Divider()
            .background(AppTheme.border)
            .padding(.leading, 56)
    }
}

struct ExpenseFormMenuRow<PickerContent: View>: View {
    let icon: String
    let color: Color
    let title: String
    let value: String
    @ViewBuilder let picker: () -> PickerContent

    var body: some View {
        HStack(spacing: 14) {
            ExpenseIconBadge(systemName: icon, color: color)
            Text(title)
                .foregroundStyle(AppTheme.primaryText)
            Spacer()
            menu
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var menu: some View {
        Menu {
            picker()
        } label: {
            HStack(spacing: 4) {
                Text(value)
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.tertiaryText)
            }
        }
    }
}

struct ExpensePrimarySaveButton: View {
    let isSaving: Bool
    let isEnabled: Bool
    var title: String = "Guardar gasto"
    /// Texto del botón deshabilitado: dice qué falta en lugar de repetir la acción.
    var disabledHint: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isSaving {
                    ProgressView()
                        .tint(AppTheme.onAccent)
                }
                Text(isSaving ? "Guardando…" : (isEnabled ? title : disabledHint ?? title))
                    .font(.system(size: 17, weight: .bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isEnabled || isSaving ? AppTheme.onAccent : AppTheme.tertiaryText)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(Capsule().fill(isEnabled || isSaving ? AppTheme.accent : AppTheme.popoverSurface))
            .contentShape(Capsule())
        }
        .buttonStyle(.pressable(scale: 0.98))
        .disabled(!isEnabled)
    }
}

// MARK: - Piezas del canvas «Nuevo gasto»

/// Encabezado de hoja: cerrar a la izquierda y título centrado.
struct FormSheetHeader: View {
    let title: String
    var closeIcon = "xmark"
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
                .accessibilityAddTraits(.isHeader)
            HStack {
                Button(action: onClose) {
                    Image(systemName: closeIcon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(AppTheme.popoverSurface))
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Cerrar")
                Spacer()
            }
        }
    }
}

/// Selector de tipo con pastilla blanca, como «Normal / Recurrente».
struct FormSegmentedTabs<Value: Hashable>: View {
    let values: [Value]
    @Binding var selection: Value
    let title: (Value) -> String

    var body: some View {
        HStack(spacing: 0) {
            ForEach(values, id: \.self) { value in
                let isSelected = value == selection
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) { selection = value }
                } label: {
                    Text(title(value))
                        .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? AppTheme.backgroundTop : AppTheme.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(Capsule().fill(isSelected ? AppTheme.primaryText : .clear))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Capsule().fill(AppTheme.popoverSurface))
    }
}

/// Monto grande centrado con el símbolo atenuado y una línea de ayuda debajo.
struct FormAmountEntry: View {
    let label: String
    @Binding var text: String
    var hint: (text: String, color: Color)?
    var focus: FocusState<Bool>.Binding

    /// Tamaño según cuántos caracteres tiene el monto.
    ///
    /// Antes se usaba `minimumScaleFactor`, que iOS resuelve en el primer
    /// dibujo: al editar un gasto el monto aparecía encogido y crecía de golpe
    /// al tocar una cifra. Con un tamaño calculado es igual siempre.
    private var fontSize: CGFloat {
        switch text.count {
        case 0...5: return 64
        case 6: return 58
        case 7: return 52
        case 8: return 46
        case 9: return 42
        default: return 38
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.tertiaryText)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("$")
                    .font(.system(size: fontSize * 0.56, weight: .semibold))
                    .foregroundStyle(AppTheme.tertiaryText)
                TextField("", text: $text, prompt: Text("0").foregroundStyle(AppTheme.placeholderText))
                    .keyboardType(.decimalPad)
                    .focused(focus)
                    .font(.system(size: fontSize, weight: .semibold))
                    .tracking(-2)
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppTheme.primaryText)
                    .tint(AppTheme.accent)
                    .fixedSize()
                    .accessibilityLabel("Monto en dólares")
            }
            .frame(maxWidth: .infinity, minHeight: 76)
            .animation(.snappy(duration: 0.2), value: fontSize)
            .contentShape(.rect)
            .onTapGesture { focus.wrappedValue = true }

            if let hint {
                HStack(spacing: 6) {
                    Circle().fill(hint.color).frame(width: 6, height: 6)
                    Text(hint.text)
                }
                .font(.footnote)
                .foregroundStyle(AppTheme.tertiaryText)
                .multilineTextAlignment(.center)
                .frame(minHeight: 18)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

/// Grupo de filas con etiqueta fija a la izquierda.
struct FormGroupedRows<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.surface)
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(AppTheme.separator, lineWidth: 1))
            )
    }
}

struct FormLabeledRow<Content: View>: View {
    let label: String
    var showsDivider = true
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(AppTheme.tertiaryText)
                .frame(width: 84, alignment: .leading)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .overlay(alignment: .bottom) {
            if showsDivider { Rectangle().fill(AppTheme.separator).frame(height: 1) }
        }
    }
}

/// Título de sección de formulario, con texto secundario opcional a la derecha.
struct FormSectionTitle: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.tertiaryText)
            }
        }
    }
}

/// Chips de categoría: punto de color y, al elegir, borde y fondo del mismo color.
struct CategoryChipPicker: View {
    let categories: [Categoria]
    @Binding var selectedID: Int
    var onPick: (Int) -> Void = { _ in }

    var body: some View {
        ChipFlowLayout(spacing: 8) {
            ForEach(categories) { category in
                let isSelected = category.id == selectedID
                let color = category.color
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        selectedID = category.id
                        onPick(category.id)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Circle().fill(color).frame(width: 8, height: 8)
                        Text(category.nombre).lineLimit(1)
                    }
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(AppTheme.primaryText)
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .background(
                        Capsule()
                            .fill(isSelected ? color.opacity(0.16) : AppTheme.popoverSurface)
                            .overlay(Capsule().strokeBorder(isSelected ? color : .clear, lineWidth: 1.5))
                    )
                }
                .buttonStyle(.pressable(scale: 0.95))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Categoría")
    }
}

/// Tarjetas de método de pago en una fila desplazable.
struct PaymentMethodPicker: View {
    let methods: [ExpensePaymentMethod]
    @Binding var selectedID: Int
    var onPick: (Int) -> Void = { _ in }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(methods) { method in
                    let isSelected = method.id == selectedID
                    Button {
                        selectedID = method.id
                        onPick(method.id)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: method.icono)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(isSelected ? AppTheme.primaryText : AppTheme.secondaryText)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(method.shortLabel)
                                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                                    .foregroundStyle(AppTheme.primaryText)
                                if method.nombre != method.shortLabel {
                                    Text(method.nombre)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.tertiaryText)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(AppTheme.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(isSelected ? AppTheme.accent : AppTheme.separator, lineWidth: 1.5)
                                )
                        )
                    }
                    .buttonStyle(.pressable(scale: 0.96))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
        .scrollClipDisabled()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Método de pago")
    }
}

/// Botón principal fijo al pie, sobre el cristal desenfocado del resto de la app.
struct FormStickySaveBar<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .background(AppFooterScrim())
    }
}

/// Encabezado fijo de hoja sobre el cristal desenfocado, con el contenido
/// pasando por debajo al desplazar.
struct FormSheetChrome<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 10)
            .background(AppHeaderScrim(fadeHeight: 36))
    }
}
