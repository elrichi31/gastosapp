import SwiftUI

struct AddExpenseSheet: View {
    private enum ComposerMode: Hashable, CaseIterable {
        case normal
        case recurrente
        case suscripcion

        var icon: String {
            switch self {
            case .normal:
                return "dollarsign.circle.fill"
            case .recurrente:
                return "repeat.circle.fill"
            case .suscripcion:
                return "rectangle.stack.fill"
            }
        }

        var accessibilityLabel: String {
            switch self {
            case .normal:
                return "Registrar gasto"
            case .recurrente:
                return "Registrar gasto recurrente"
            case .suscripcion:
                return "Registrar suscripción"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @State private var mode: ComposerMode = .normal

    let onSaved: (Bool) -> Void

    init(startInRecurringMode: Bool = false, onSaved: @escaping (Bool) -> Void) {
        _mode = State(initialValue: startInRecurringMode ? .recurrente : .normal)
        self.onSaved = onSaved
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 14)
                .background(AppTheme.backgroundBottom)

            content
        }
        .navigationBarBackButtonHidden(true)
        .swipeBackBehavior()
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            closeButton
            composerSelector
        }
    }

    private var closeButton: some View {
        Button(action: dismiss.callAsFunction) {
            Image(systemName: "chevron.left")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppTheme.primaryText.opacity(0.78))
                .frame(width: 42, height: 42)
                .background(SelectorCircleBackground())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Cerrar")
    }

    private var composerSelector: some View {
        HStack(spacing: 6) {
            ForEach(ComposerMode.allCases, id: \.self, content: composerButton)
        }
        .frame(maxWidth: .infinity)
        .padding(6)
        .background(GastosCapsuleBackground())
    }

    private func composerButton(_ mode: ComposerMode) -> some View {
        let isSelected = self.mode == mode
        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                self.mode = mode
            }
        } label: {
            Image(systemName: mode.icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(isSelected ? .black : AppTheme.primaryText.opacity(0.68))
                .frame(width: 52, height: 42)
                .background(Capsule().fill(isSelected ? AppTheme.accent : .clear))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.accessibilityLabel)
    }

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .normal:
            AddExpenseView(onSaved: saveNormalExpense)
        case .recurrente:
            AddRecurringExpenseView(kind: .recurrente, onSaved: saveRecurringExpense)
        case .suscripcion:
            AddSubscriptionView(showsCloseButton: false, onSaved: saveRecurringExpense)
        }
    }

    private func saveNormalExpense() {
        onSaved(false)
        dismiss()
    }

    private func saveRecurringExpense() {
        onSaved(true)
        dismiss()
    }
}

private struct SelectorCircleBackground: View {
    var body: some View {
        Circle()
            .fill(AppTheme.controlSurface)
            .overlay(Circle().stroke(AppTheme.primaryText.opacity(0.08), lineWidth: 1))
    }
}
