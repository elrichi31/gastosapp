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
            .padding(.vertical, 16)
            .background(buttonBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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
                    .foregroundStyle(AppTheme.primaryText.opacity(0.72))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(AppTheme.warning.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var buttonBackground: LinearGradient {
        LinearGradient(
            colors: canSubmit
                ? [AppTheme.accent, AppTheme.accent]
                : [AppTheme.disabledFill, AppTheme.disabledFill],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
