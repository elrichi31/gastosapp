import SwiftUI

struct EmailMovementReviewSheet: View {
    let row: EmailMovement
    @Bindable var review: EmailReviewStore
    @Environment(ExpenseStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var description = ""
    @State private var amount = ""
    @State private var categoryID = 0
    @State private var alias = ""
    @State private var foreignEnabled = false
    @State private var selected = ["isd"]
    @State private var customRate = ""
    @State private var selectedCandidate: EmailCandidate?
    @State private var saveAsNew = false
    @State private var confirmLink = false
    @State private var confirmDiscard = false
    @State private var savedAlias = ""
    @State private var lastAliasDescription = ""
    @State private var aliasFeedback: String?
    @State private var seeded = false
    @FocusState private var focusedField: Field?
    private enum Field: Hashable { case description, amount, alias }
    private var aliasDirty: Bool { row.canHaveAlias && alias.trimmingCharacters(in: .whitespacesAndNewlines) != savedAlias }
    private var isRefund: Bool { row.tipo == "ingreso" }
    private var base: Double { MoneyInput.parse(amount) ?? 0 }
    private var tax: ForeignTax { ForeignTax(base: base, selected: selected, customRate: customRate) }
    private var category: Categoria? { session.categorias.first { $0.id == categoryID } }
    private var canSave: Bool {
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && description.count <= 200 &&
        base.isFinite && base > 0 && base <= row.monto && category != nil && (!foreignEnabled || tax.isValid)
    }
    private var actionTitle: String {
        if isRefund { return "Descontar devolución" }
        return saveAsNew ? "Guardar gasto" : "Vincular gasto existente"
    }

    var body: some View {
        VStack(spacing: 0) {
            BudgetEditorHeader(title: isRefund ? "Revisar devolución" : "Revisar consumo",
                subtitle: "\(row.origen) · \(dateLabel)", icon: isRefund ? "arrow.uturn.backward" : "envelope",
                tint: isRefund ? AppTheme.secondaryAccent : AppTheme.accent, onClose: dismiss.callAsFunction)
                .padding(.horizontal, AppScreenMetrics.horizontalPadding).padding(.top, 24).padding(.bottom, 20)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    originalMovement
                    if row.canHaveAlias { aliasFields }
                    if !isRefund && !row.coincidencias.isEmpty { resolutionPicker }
                    if !isRefund && saveAsNew { newExpenseFields }
                    else { matchingExpenses }
                    if let error = review.error {
                        ExpenseFormStatusCard(status: .init(title: "No se pudo completar", message: error, icon: "exclamationmark.triangle", tint: AppTheme.warning))
                    }
                    Button("Descartar movimiento", role: .destructive) { confirmDiscard = true }
                        .font(.subheadline.weight(.medium)).foregroundStyle(AppTheme.negative)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .padding(.horizontal, AppScreenMetrics.horizontalPadding).padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(AppTheme.screenBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) { primaryAction }
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(review.isWorking)
        .onAppear(perform: seed)
        .disabled(review.isWorking)
        .confirmationDialog(isRefund ? "¿Descontar esta devolución?" : "¿Vincular el consumo?", isPresented: $confirmLink, titleVisibility: .visible) {
            if let candidate = selectedCandidate {
                Button(isRefund ? "Descontar devolución" : "Confirmar vínculo") {
                    Task { if await review.apply(["vincular": [["id": row.id, "gasto_id": candidate.id]]], using: session) { dismiss() } }
                }
            }
        } message: {
            if let candidate = selectedCandidate {
                Text(isRefund ? "Se descontarán \(row.monto.formatted(.currency(code: "USD"))) de «\(candidate.gasto.descripcion)»." : "Se vinculará con «\(candidate.gasto.descripcion)» sin crear otro gasto.")
            }
        }
        .confirmationDialog("¿Descartar este movimiento?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Descartar", role: .destructive) { Task { if await review.apply(["descartar": [row.id]], using: session) { dismiss() } } }
        } message: { Text("No se guardará como gasto y no volverá a aparecer en pendientes.") }
    }

    private var originalMovement: some View {
        VStack(alignment: .leading, spacing: 10) {
            AppSectionLabel(text: isRefund ? "DEVOLUCIÓN RECIBIDA" : "CONSUMO DETECTADO")
            Text(row.monto, format: .currency(code: "USD"))
                .font(.largeTitle.bold()).monospacedDigit().foregroundStyle(AppTheme.primaryText)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(row.descripcion_original ?? row.descripcion).font(.subheadline).foregroundStyle(AppTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var resolutionPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("¿Ya lo registraste?").font(.headline).foregroundStyle(AppTheme.primaryText)
            HStack(spacing: 8) {
                resolutionButton("Sí, vincular", saveNew: false)
                resolutionButton("Es otro gasto", saveNew: true)
            }
        }
    }
    private func resolutionButton(_ title: String, saveNew: Bool) -> some View {
        Button { saveAsNew = saveNew; selectedCandidate = nil; focusedField = nil } label: {
            Text(title).font(.subheadline.weight(.semibold))
                .foregroundStyle(saveAsNew == saveNew ? AppTheme.accent : AppTheme.secondaryText)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(saveAsNew == saveNew ? AppTheme.accent.opacity(0.14) : AppTheme.controlSurface, in: Capsule())
        }.buttonStyle(.plain).accessibilityAddTraits(saveAsNew == saveNew ? .isSelected : [])
    }

    private var newExpenseFields: some View {
        VStack(alignment: .leading, spacing: 14) {
            AppSectionTitle(title: "Tu gasto")
            BudgetEditorTextField(title: "Guardar como", placeholder: "Razón del gasto", text: $description)
                .focused($focusedField, equals: .description)
            Text("Solo para este gasto; no cambia el alias.").font(.caption).foregroundStyle(AppTheme.secondaryText)
            BudgetEditorTextField(title: "Tu parte", placeholder: "0.00", text: $amount, keyboard: .decimalPad)
                .focused($focusedField, equals: .amount)
            Text(base < row.monto && base > 0 ? "Solo se registrará tu parte; quedará marcado como compartido." : "Si compartiste el consumo, introduce solo lo que pagaste tú.")
                .font(.caption).foregroundStyle(AppTheme.secondaryText)
            if base > row.monto { Text("Tu parte no puede superar el consumo original.").font(.caption).foregroundStyle(AppTheme.warning) }
            BudgetEditorMenuField(title: "Categoría", value: category?.nombre ?? "Elegir") {
                ForEach(session.categorias) { category in Button(category.nombre) { categoryID = category.id } }
            }
            ForeignTaxFields(enabled: $foreignEnabled, selected: $selected, customRate: $customRate, base: base)
        }
    }

    private var matchingExpenses: some View {
        VStack(alignment: .leading, spacing: 14) {
            AppSectionTitle(title: isRefund ? "¿A qué gasto corresponde?" : "Elige el gasto registrado")
            Text(isRefund ? "Descontaremos el dinero recibido del gasto que elijas." : "Revisa la descripción, fecha y monto para evitar un registro duplicado.")
                .font(.caption).foregroundStyle(AppTheme.secondaryText)
            if row.coincidencias.isEmpty {
                EmailInboxState(title: "Sin gastos compatibles", message: "No encontramos un gasto del que descontar esta devolución. Puedes cerrar y revisarla más tarde.", icon: "doc.text.magnifyingglass")
            }
            ForEach(row.coincidencias) { candidate in
                EmailCandidateRow(candidate: candidate, isSelected: selectedCandidate?.id == candidate.id) {
                    selectedCandidate = candidate
                }
            }
        }
    }

    private var aliasFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppSectionTitle(title: savedAlias.isEmpty ? "Crear alias" : "Editar alias")
            Text("Ponle un nombre a este destinatario. Se usará en esta y en sus próximas transferencias.")
                .font(.caption).foregroundStyle(AppTheme.secondaryText)
            BudgetEditorTextField(title: "Alias del destinatario", placeholder: "Ej. Gimnasio, Arriendo, Mamá", text: $alias)
                .focused($focusedField, equals: .alias)
                .onChange(of: alias) { if aliasDirty { aliasFeedback = nil } }
            Button { focusedField = nil; Task { await saveAlias() } } label: {
                HStack(spacing: 8) {
                    if review.isSavingAlias { ProgressView().controlSize(.small) }
                    else { Image(systemName: "person.crop.circle.badge.checkmark") }
                    Text(review.isSavingAlias ? "Guardando alias…" : alias.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Quitar alias" : "Guardar alias")
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered).tint(AppTheme.accent)
            .disabled(!aliasDirty || alias.trimmingCharacters(in: .whitespacesAndNewlines).utf16.count > 200)
            if let aliasFeedback {
                Label(aliasFeedback, systemImage: "checkmark.circle").font(.caption).foregroundStyle(AppTheme.accent)
            } else if aliasDirty {
                Text("Guarda el alias antes de completar la revisión.").font(.caption).foregroundStyle(AppTheme.warning)
            } else if !savedAlias.isEmpty {
                Text("Vacía el campo y pulsa Quitar alias para eliminarlo.").font(.caption).foregroundStyle(AppTheme.secondaryText)
            }
        }
    }

    private func saveAlias() async {
        let cleanAlias = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        guard aliasDirty else { return }
        if await review.saveAlias(for: row, alias: cleanAlias, using: session) {
            let updated = row.updatingAlias(cleanAlias)
            // Keep an intentionally edited reason; otherwise use the newly saved alias.
            if description == lastAliasDescription { description = updated.descripcion }
            lastAliasDescription = updated.descripcion
            savedAlias = cleanAlias
            alias = cleanAlias
            aliasFeedback = cleanAlias.isEmpty ? "Alias eliminado" : "Alias guardado para próximas transferencias"
        }
    }

    private var primaryAction: some View {
        ExpensePrimarySaveButton(isSaving: review.isWorking && !review.isSavingAlias,
            isEnabled: !review.isWorking && !aliasDirty && (saveAsNew && !isRefund ? canSave : selectedCandidate != nil), title: actionTitle) {
                focusedField = nil
                if saveAsNew && !isRefund { Task { await save() } }
                else { confirmLink = true }
            }
            .padding(.horizontal, AppScreenMetrics.horizontalPadding).padding(.vertical, 14)
            .background(AppTheme.backgroundBottom)
    }
    private var dateLabel: String {
        AppDateCodec.dateOnly(from: row.fecha)?.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "es"))) ?? row.fecha
    }
    private func seed() {
        guard !seeded else { return }
        seeded = true
        review.error = nil; review.message = nil
        description = row.descripcion; amount = MoneyInput.format(row.monto)
        categoryID = row.categoria_id ?? session.categorias.first?.id ?? 0
        alias = row.alias ?? ""
        savedAlias = alias
        lastAliasDescription = row.descripcion
        saveAsNew = !isRefund && row.coincidencias.isEmpty
    }
    private func save() async {
        guard canSave, !aliasDirty else { return }
        var item: [String: Any] = ["id": row.id, "categoria_id": categoryID, "monto": base, "descripcion": description.trimmingCharacters(in: .whitespacesAndNewlines)]
        if foreignEnabled { item["impuestos"] = ["selected": selected, "customRate": customRate] }
        if await review.apply(["aceptar": [item]], using: session) { dismiss() }
    }
}
