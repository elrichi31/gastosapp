import SwiftUI

struct LoginSubmitSection: View {
    let isAuthenticating: Bool
    let canSubmit: Bool
    let errorMessage: String?
    let action: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            submitButton
            errorCard
        }
    }

    private var submitButton: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isAuthenticating {
                    ProgressView()
                        .tint(canSubmit ? AppTheme.onAccent : AppTheme.tertiaryText)
                }
                Text(isAuthenticating ? "Entrando..." : "Iniciar sesión")
                    .font(.headline)
            }
            .foregroundStyle(canSubmit ? AppTheme.onAccent : AppTheme.tertiaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(buttonBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.control, style: .continuous))
        }
        .disabled(!canSubmit)
    }

    @ViewBuilder
    private var errorCard: some View {
        if let errorMessage, !errorMessage.isEmpty {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppTheme.warning)
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.warning.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(AppTheme.warning.opacity(0.25), lineWidth: 1)
                    )
            )
        }
    }

    private var buttonBackground: Color {
        canSubmit ? AppTheme.accent : AppTheme.disabledFill
    }
}
