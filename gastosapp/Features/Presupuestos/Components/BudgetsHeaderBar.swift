import SwiftUI

/// Barra de Presupuestos: una sola fila, igual que la de Gastos.
///
/// Antes llevaba encima un `AppScreenHeader` con "Tu plan / Presupuestos".
/// Eran ~70pt gastados en repetir lo que ya dice la pestaña seleccionada, y
/// empujaban el primer bloque real fuera de la primera pantalla. Aquí lo único
/// que hace falta es el año —que sí cambia— y la acción de crear.
struct BudgetsHeaderBar: View {
    let year: Int
    let onPreviousYear: () -> Void
    let onNextYear: () -> Void
    let onAddTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AppPeriodStepper(
                label: "\(year)",
                onPrevious: onPreviousYear,
                onNext: onNextYear,
                previousLabel: "Año anterior",
                nextLabel: "Año siguiente",
                expands: true
            )

            AppCircleButton(
                icon: "plus",
                prominent: true,
                label: "Crear presupuesto",
                action: onAddTap
            )
        }
        .frame(maxWidth: .infinity)
    }
}
