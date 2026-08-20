import SwiftUI

struct AddBudgetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(BudgetStore.self) private var budgets
    @Environment(ExpenseStore.self) private var session

    @State private var year: Int
    @State private var month: Int

    init(defaultYear: Int) {
        let currentMonth = Calendar.current.component(.month, from: Date())
        _year = State(initialValue: Self.validInitialYear(defaultYear))
        _month = State(initialValue: currentMonth)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            selectors
            statusMessage
            saveButton
        }
        .padding(.horizontal, 22)
        .padding(.top, 32)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppTheme.screenBackground.ignoresSafeArea())
        .onAppear(perform: selectFirstAvailableMonth)
        .onChange(of: year) { selectFirstAvailableMonth() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Nuevo mes")
                    .font(.system(.title3, design: .default, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
                Text("Elige el mes para activar su presupuesto.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText.opacity(0.48))
            }
            Spacer()
            closeButton
        }
    }

    private var closeButton: some View {
        Button(action: dismiss.callAsFunction) {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.primaryText.opacity(0.72))
                .frame(width: 44, height: 44)
                .background(Circle().fill(AppTheme.primaryText.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Cerrar")
    }

    private var selectors: some View {
        HStack(spacing: 10) {
            selectorMenu(title: "Año", value: "\(year)", options: yearOptions)
            selectorMenu(title: "Mes", value: monthLabel, options: monthOptions)
        }
    }

    private func selectorMenu(title: String, value: String, options: [BudgetOption]) -> some View {
        Menu {
            ForEach(options) { option in
                Button(option.title) { option.action() }
            }
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption2.weight(.bold))
                        .textCase(.uppercase)
                        .foregroundStyle(AppTheme.primaryText.opacity(0.42))
                    Text(value)
                        .font(.system(.headline, design: .default, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText.opacity(0.42))
            }
            .padding(14)
            .background(AppTheme.cardBackground(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .disabled(options.isEmpty)
    }

    @ViewBuilder
    private var statusMessage: some View {
        if let error = budgets.saveErrorMessage {
            Text(error)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.warning)
        } else if availableMonths.isEmpty {
            Text("No hay meses disponibles para crear en este año.")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.primaryText.opacity(0.50))
        }
    }

    private var saveButton: some View {
        Button(action: save) {
            Text(budgets.isSavingBudget ? "Guardando…" : "Crear mes")
                .font(.headline.weight(.bold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Capsule().fill(canSave ? AppTheme.accent : AppTheme.primaryText.opacity(0.18)))
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
    }

    private var canSave: Bool {
        availableMonths.contains(where: { $0.value == month }) && !budgets.isSavingBudget
    }

    private var yearOptions: [BudgetOption] {
        availableYears.map { value in
            BudgetOption(title: "\(value)") { year = value }
        }
    }

    private var monthOptions: [BudgetOption] {
        availableMonths.map { item in
            BudgetOption(title: item.label) { month = item.value }
        }
    }

    private var monthLabel: String {
        availableMonths.first(where: { $0.value == month })?.label ?? "Sin meses"
    }

    private var availableYears: [Int] {
        Self.availableYearsFromToday()
    }

    private var availableMonths: [(value: Int, label: String)] {
        budgets.availableMonths(for: year)
    }

    private func save() {
        Task {
            let ok = await budgets.createBudget(using: session, year: year, month: month)
            guard ok else { return }
            dismiss()
        }
    }

    private func selectFirstAvailableMonth() {
        guard !availableMonths.contains(where: { $0.value == month }) else { return }
        month = availableMonths.first?.value ?? Calendar.current.component(.month, from: Date())
    }

    private static func availableYearsFromToday() -> [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array(currentYear...(currentYear + 2))
    }

    private static func validInitialYear(_ defaultYear: Int) -> Int {
        let years = availableYearsFromToday()
        return min(max(defaultYear, years.first ?? defaultYear), years.last ?? defaultYear)
    }
}

private struct BudgetOption: Identifiable {
    let id = UUID()
    let title: String
    let action: () -> Void
}
