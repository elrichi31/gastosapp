import SwiftUI

struct AppConfirmationDialog: View {
    let title: String
    let message: String
    let confirmTitle: String
    let cancelTitle: String
    let icon: String
    let tint: Color
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 48, height: 48)
                    .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(spacing: 6) {
                    Text(title)
                        .font(.system(.title3, design: .default, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                        .multilineTextAlignment(.center)

                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                Button(action: onCancel) {
                    Text(cancelTitle)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(AppTheme.insetBackground())
                }
                .buttonStyle(.plain)

                Button(action: onConfirm) {
                    Text(confirmTitle)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(tint)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(AppTheme.strongBorder, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.34), radius: 30, y: 12)
        )
        .padding(.horizontal, 24)
        .accessibilityElement(children: .contain)
    }
}

private struct AppConfirmationDialogModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var isPresented: Bool
    let title: String
    let message: String
    let confirmTitle: String
    let cancelTitle: String
    let icon: String
    let tint: Color
    let onConfirm: () -> Void

    private var dialogAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.18)
    }

    private var dialogTransition: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98))
    }

    func body(content: Content) -> some View {
        content
            .overlay {
                if isPresented {
                    ZStack {
                        Button(action: dismiss) {
                            Color.black.opacity(0.45)
                                .ignoresSafeArea()
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Cerrar diálogo")
                        .accessibilityHint("Cierra el cuadro de confirmación")

                        AppConfirmationDialog(
                            title: title,
                            message: message,
                            confirmTitle: confirmTitle,
                            cancelTitle: cancelTitle,
                            icon: icon,
                            tint: tint,
                            onCancel: dismiss,
                            onConfirm: {
                                dismiss()
                                onConfirm()
                            }
                        )
                        .accessibilityAction(.escape) {
                            dismiss()
                        }
                    }
                    .transition(dialogTransition)
                    .zIndex(20)
                }
            }
            .animation(dialogAnimation, value: isPresented)
    }

    private func dismiss() {
        if let dialogAnimation {
            withAnimation(dialogAnimation) {
                isPresented = false
            }
        } else {
            isPresented = false
        }
    }
}

extension View {
    func appConfirmationDialog(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        confirmTitle: String = "Eliminar",
        cancelTitle: String = "Cancelar",
        icon: String = "trash",
        tint: Color = AppTheme.negative,
        onConfirm: @escaping () -> Void
    ) -> some View {
        modifier(
            AppConfirmationDialogModifier(
                isPresented: isPresented,
                title: title,
                message: message,
                confirmTitle: confirmTitle,
                cancelTitle: cancelTitle,
                icon: icon,
                tint: tint,
                onConfirm: onConfirm
            )
        )
    }
}
