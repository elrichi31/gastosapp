import SwiftUI

/// Desplegable abierto dentro de una tarjeta del correo; sólo uno a la vez en
/// toda la bandeja.
enum EmailCardPanel: Equatable {
    case category, payment, more
}

/// Tarjeta de un movimiento: fondo de superficie y borde que puede avisar.
struct EmailCard<Content: View>: View {
    var border: Color = AppTheme.separator
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                    .fill(AppTheme.surface)
                    .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous).strokeBorder(border, lineWidth: 1))
            )
            .clipShape(.rect(cornerRadius: AppTheme.Radius.card, style: .continuous))
    }
}

/// Botón de la franja inferior de la tarjeta (Descartar, Registrar…).
struct EmailCardAction: View {
    let title: String
    var icon: String?
    var tint: Color = AppTheme.secondaryText
    var emphasized = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.system(size: 14, weight: .bold)) }
                Text(title)
            }
            .font(.system(size: 15, weight: emphasized ? .bold : .semibold))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, minHeight: 50)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

/// Acción de la franja que pide confirmación antes de ejecutarse. El diálogo
/// cuelga del propio botón: en iOS 26 se presenta como popover anclado a su
/// vista, y colgado de la pantalla entera aparecía en cualquier sitio.
struct EmailConfirmedCardAction: View {
    let title: String
    let question: String
    let confirmTitle: String
    let message: String
    let action: () -> Void
    @State private var isConfirming = false

    var body: some View {
        EmailCardAction(title: title) { isConfirming = true }
            .confirmationDialog(question, isPresented: $isConfirming, titleVisibility: .visible) {
                Button(confirmTitle, role: .destructive, action: action)
            } message: {
                Text(message)
            }
    }
}

/// Franja de acciones al pie de la tarjeta, separadas por filetes.
struct EmailCardFooter<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(AppTheme.separator).frame(height: 1)
            HStack(spacing: 0) {
                Group(subviews: content) { subviews in
                    ForEach(Array(subviews.enumerated()), id: \.offset) { index, subview in
                        if index > 0 { Rectangle().fill(AppTheme.separator).frame(width: 1, height: 50) }
                        subview
                    }
                }
            }
        }
    }
}

/// Píldora elegible de los desplegables (categoría, pago, impuestos).
struct EmailOptionChip: View {
    let title: String
    var detail: String?
    var dot: Color?
    let isOn: Bool
    var onTint: Color = AppTheme.primaryText
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let dot { Circle().fill(dot).frame(width: 8, height: 8) }
                Text(title).lineLimit(1)
                if let detail { Text(detail).fontWeight(.medium).opacity(0.6) }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(isOn ? AppTheme.backgroundTop : AppTheme.primaryText)
            .padding(.horizontal, 14)
            .frame(height: 38)
            .background(Capsule().fill(isOn ? onTint : AppTheme.controlSurface))
        }
        .buttonStyle(.pressable(scale: 0.95))
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
