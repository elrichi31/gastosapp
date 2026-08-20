import SwiftUI

struct BudgetEditorHeader: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .background(Circle().fill(tint.opacity(0.16)))
            titleStack
            Spacer()
            closeButton
        }
    }

    private var titleStack: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(.title3, design: .default, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
            Text(subtitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.primaryText.opacity(0.48))
        }
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.primaryText.opacity(0.72))
                .frame(width: 44, height: 44)
                .background(Circle().fill(AppTheme.primaryText.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Cerrar")
    }
}

struct BudgetEditorTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            fieldTitle
            TextField(placeholder, text: $text)
                .keyboardType(keyboard)
                .font(.system(.headline, design: .default, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
                .tint(AppTheme.accent)
        }
        .padding(14)
        .background(AppTheme.cardBackground(cornerRadius: 18))
    }

    private var fieldTitle: some View {
        Text(title)
            .font(.caption2.weight(.bold))
            .textCase(.uppercase)
            .foregroundStyle(AppTheme.primaryText.opacity(0.42))
    }
}

struct BudgetEditorDateField: View {
    @Binding var date: Date

    var body: some View {
        HStack {
            label
            Spacer()
            DatePicker("", selection: $date, displayedComponents: .date)
                .labelsHidden()
                .tint(AppTheme.accent)
        }
        .padding(14)
        .background(AppTheme.cardBackground(cornerRadius: 18))
    }

    private var label: some View {
        Text("Fecha")
            .font(.caption2.weight(.bold))
            .textCase(.uppercase)
            .foregroundStyle(AppTheme.primaryText.opacity(0.42))
    }
}

struct BudgetEditorMenuField<Content: View>: View {
    let title: String
    let value: String
    @ViewBuilder let content: Content

    var body: some View {
        Menu { content } label: {
            HStack(spacing: 10) {
                label
                Spacer()
                Text(value)
                    .font(.system(.subheadline, design: .default, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText.opacity(0.42))
            }
            .padding(14)
            .background(AppTheme.cardBackground(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    private var label: some View {
        Text(title)
            .font(.caption2.weight(.bold))
            .textCase(.uppercase)
            .foregroundStyle(AppTheme.primaryText.opacity(0.42))
    }
}

struct BudgetEditorSaveButton: View {
    let isSaving: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isSaving { ProgressView().tint(.black) }
                Text(isSaving ? "Guardando…" : "Guardar")
            }
            .font(.headline.weight(.bold))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Capsule().fill(isEnabled ? AppTheme.accent : AppTheme.primaryText.opacity(0.18)))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

struct BudgetEditorErrorCard: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(AppTheme.warning)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(AppTheme.cardBackground(cornerRadius: 16))
    }
}
