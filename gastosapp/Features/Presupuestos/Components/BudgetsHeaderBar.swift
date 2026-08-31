import SwiftUI

struct BudgetsHeaderBar: View {
    let year: Int
    let onPreviousYear: () -> Void
    let onNextYear: () -> Void
    let onAddTap: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            AppScreenHeader(eyebrow: "Tu plan", title: "Presupuestos") {
                AppCircleButton(
                    icon: "plus",
                    prominent: true,
                    label: "Crear presupuesto",
                    action: onAddTap
                )
            }

            AppPeriodStepper(
                label: "\(year)",
                onPrevious: onPreviousYear,
                onNext: onNextYear,
                previousLabel: "Año anterior",
                nextLabel: "Año siguiente"
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
    }
}
