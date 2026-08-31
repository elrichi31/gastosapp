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
                .font(.title3.bold())
                .foregroundStyle(AppTheme.primaryText)
            Text(subtitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.tertiaryText)
        }
    }

    private var closeButton: some View {
        AppCircleButton(icon: "xmark", label: "Cerrar", action: onClose)
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
        .background((
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.controlSurface)
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(AppTheme.border, lineWidth: 1))
            ))
    }

    private var fieldTitle: some View {
        Text(title)
            .font(.caption2.weight(.bold))
            .textCase(.uppercase)
            .foregroundStyle(AppTheme.tertiaryText)
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
        .background((
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.controlSurface)
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(AppTheme.border, lineWidth: 1))
            ))
    }

    private var label: some View {
        Text("Fecha")
            .font(.caption2.weight(.bold))
            .textCase(.uppercase)
            .foregroundStyle(AppTheme.tertiaryText)
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
                    .foregroundStyle(AppTheme.tertiaryText)
            }
            .padding(14)
            .background((
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.controlSurface)
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(AppTheme.border, lineWidth: 1))
            ))
        }
        .buttonStyle(.plain)
    }

    private var label: some View {
        Text(title)
            .font(.caption2.weight(.bold))
            .textCase(.uppercase)
            .foregroundStyle(AppTheme.tertiaryText)
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
            .font(.headline)
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Capsule().fill(isEnabled ? AppTheme.accent : AppTheme.placeholderText))
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
            .background((
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.controlSurface)
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(AppTheme.border, lineWidth: 1))
            ))
    }
}
