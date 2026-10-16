import SwiftUI

// Piezas compartidas por «Iniciar sesión» y «Crear cuenta», según el canvas.

/// Campo con la etiqueta pequeña dentro de la caja y un anillo al enfocarlo.
struct AuthField<Trailing: View>: View {
    let label: String
    let isFocused: Bool
    /// Texto de ejemplo propio: el `prompt` de un campo de correo lo pinta iOS
    /// con el azul del sistema e ignora el color que se le da.
    var placeholder: String?
    var isEmpty = false
    @ViewBuilder let field: () -> AnyView
    @ViewBuilder let trailing: () -> Trailing

    init(
        label: String,
        isFocused: Bool,
        placeholder: String? = nil,
        isEmpty: Bool = false,
        @ViewBuilder field: @escaping () -> some View,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.label = label
        self.isFocused = isFocused
        self.placeholder = placeholder
        self.isEmpty = isEmpty
        self.field = { AnyView(field()) }
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 4) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.tertiaryText)
                    .accessibilityHidden(true)
                ZStack(alignment: .leading) {
                    if let placeholder, isEmpty {
                        Text(placeholder)
                            .foregroundStyle(AppTheme.placeholderText)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                    field()
                }
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.primaryText)
                    .tint(AppTheme.accent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing()
        }
        .padding(.leading, 18)
        .padding(.trailing, 6)
        .frame(height: 64)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(isFocused ? AppTheme.strongBorder : .clear, lineWidth: 2)
                )
        )
        .animation(AppMotion.fade, value: isFocused)
    }
}

extension AuthField where Trailing == EmptyView {
    init(label: String, isFocused: Bool, placeholder: String? = nil, isEmpty: Bool = false, @ViewBuilder field: @escaping () -> some View) {
        self.init(label: label, isFocused: isFocused, placeholder: placeholder, isEmpty: isEmpty, field: field) { EmptyView() }
    }
}

/// Botón de ojo para mostrar u ocultar la contraseña.
struct PasswordVisibilityButton: View {
    @Binding var isVisible: Bool

    var body: some View {
        Button {
            isVisible.toggle()
        } label: {
            Image(systemName: isVisible ? "eye.slash" : "eye")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(AppTheme.tertiaryText)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(isVisible ? "Ocultar contraseña" : "Mostrar contraseña")
    }
}

/// Aviso de error rojo bajo el formulario.
struct AuthErrorBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 16, weight: .semibold))
                .padding(.top, 1)
                .accessibilityHidden(true)
            Text(message)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(AppTheme.negative)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(AppTheme.negative.opacity(0.12)))
        .transition(AppMotion.reveal)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}

/// Botón principal blanco de 56 pt.
struct AuthPrimaryButton: View {
    let title: String
    var isWorking = false
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isWorking { ProgressView().tint(AppTheme.backgroundTop) }
                Text(title)
                    .font(.system(size: 17, weight: .bold))
            }
            .foregroundStyle(AppTheme.backgroundTop)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(Capsule().fill(AppTheme.primaryText))
            .opacity(isEnabled || isWorking ? 1 : 0.45)
            .contentShape(Capsule())
        }
        .buttonStyle(.pressable(scale: 0.98))
        .disabled(!isEnabled || isWorking)
    }
}
