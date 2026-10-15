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

        var title: String {
            switch self {
            case .normal: return "Normal"
            case .recurrente: return "Recurrente"
            case .suscripcion: return "Suscripción"
            }
        }

        var sheetTitle: String {
            switch self {
            case .normal: return "Nuevo gasto"
            case .recurrente: return "Nuevo recurrente"
            case .suscripcion: return "Nueva suscripción"
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
            VStack(spacing: 16) {
                FormSheetHeader(title: mode.sheetTitle, closeIcon: "xmark", onClose: dismiss.callAsFunction)
                    .contentTransition(.opacity)
                FormSegmentedTabs(values: ComposerMode.allCases, selection: $mode) { $0.title }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(AppTheme.backgroundTop)

            content
        }
        .background(AppTheme.screenBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .swipeBackBehavior()
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
