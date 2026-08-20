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
                    .foregroundStyle(AppTheme.primaryText.opacity(0.58))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.cardBackground())
    }
}

struct ExpenseIconBadge: View {
    let systemName: String
    let color: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(AppTheme.primaryText)
            .frame(width: 28, height: 28)
            .background(color.opacity(0.85), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct ExpenseFormDivider: View {
    var body: some View {
        Divider()
            .background(AppTheme.primaryText.opacity(0.08))
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
                    .foregroundStyle(AppTheme.primaryText.opacity(0.7))
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.primaryText.opacity(0.4))
            }
        }
    }
}

struct ExpensePrimarySaveButton: View {
    let isSaving: Bool
    let isEnabled: Bool
    var title: String = "Guardar gasto"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isSaving {
                    ProgressView()
                        .tint(isEnabled ? AppTheme.onAccent : AppTheme.tertiaryText)
                }
                Text(isSaving ? "Guardando…" : title)
                    .font(.headline)
            }
            .foregroundStyle(isEnabled ? AppTheme.onAccent : AppTheme.tertiaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .disabled(!isEnabled)
    }

    private var background: LinearGradient {
        LinearGradient(
            colors: isEnabled
                ? [AppTheme.accent, AppTheme.accent]
                : [AppTheme.disabledFill, AppTheme.disabledFill],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
