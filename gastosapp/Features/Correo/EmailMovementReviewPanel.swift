import SwiftUI

/// Revisión de un movimiento del correo, desplegada en línea bajo su fila.
///
/// Antes era una hoja que subía desde abajo y tapaba la bandeja; ahora se
/// abre como un desplegable y la fila sigue a la vista. `onFinish` la cierra
/// tras vincular, guardar o descartar.
struct EmailMovementReviewPanel: View {
    let row: EmailMovement
    @Bindable var review: EmailReviewStore
    let onFinish: () -> Void
    @Environment(ExpenseStore.self) private var session
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
    @State private var tagsText = ""

    /// Los valores que salen de la fila se ponen aquí y no en `onAppear`: si
    /// no, el panel se abría mostrando la sección equivocada y luego saltaba.
    init(row: EmailMovement, review: EmailReviewStore, onFinish: @escaping () -> Void) {
        self.row = row
        self.review = review
        self.onFinish = onFinish
        _description = State(initialValue: row.descripcion)
        _amount = State(initialValue: MoneyInput.format(row.monto))
        _categoryID = State(initialValue: row.categoria_id ?? 0)
        _alias = State(initialValue: row.alias ?? "")
        _savedAlias = State(initialValue: row.alias ?? "")
        _lastAliasDescription = State(initialValue: row.descripcion)
        _saveAsNew = State(initialValue: row.tipo != "ingreso" && row.coincidencias.isEmpty)
    }
    @FocusState private var focusedField: Field?
    private enum Field: Hashable { case description, amount, alias }
    private var aliasDirty: Bool { row.canHaveAlias && alias.trimmingCharacters(in: .whitespacesAndNewlines) != savedAlias }
    private var isRefund: Bool { row.tipo == "ingreso" }
    private var base: Double { MoneyInput.parse(amount) ?? 0 }
    private var tax: ForeignTax { ForeignTax(base: base, selected: selected, customRate: customRate) }
    private var category: Categoria? { session.categorias.first { $0.id == categoryID } }
    private var tags: [String] { ExpenseTags.normalize(tagsText) }
    private var canSave: Bool {
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && description.count <= 200 &&
        base.isFinite && base > 0 && base <= row.monto && category != nil && (!foreignEnabled || tax.isValid) &&
        ExpenseTags.isValid(tags)
    }
    private var actionTitle: String {
        if isRefund { return "Descontar devolución" }
        return saveAsNew ? "Guardar gasto" : "Vincular gasto existente"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            originalMovement
            if row.canHaveAlias { aliasFields }
            if !isRefund && !row.coincidencias.isEmpty { resolutionPicker }
            if !isRefund && saveAsNew {
                newExpenseFields.transition(AppMotion.reveal)
            } else {
                matchingExpenses.transition(AppMotion.reveal)
            }
            if let error = review.error {
                ExpenseFormStatusCard(status: .init(title: "No se pudo completar", message: error, icon: "exclamationmark.triangle", tint: AppTheme.warning))
                    .transition(AppMotion.reveal)
            }
            VStack(spacing: 4) {
                primaryAction
                Button("Descartar movimiento", role: .destructive) { confirmDiscard = true }
                    .font(.subheadline.weight(.medium)).foregroundStyle(AppTheme.negative)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 12)
        .animation(AppMotion.standard, value: saveAsNew)
        .animation(AppMotion.fade, value: review.error)
        .onAppear(perform: seed)
        .disabled(review.isWorking)
        .confirmationDialog(isRefund ? "¿Descontar esta devolución?" : "¿Vincular el consumo?", isPresented: $confirmLink, titleVisibility: .visible) {
            if let candidate = selectedCandidate {
                Button(isRefund ? "Descontar devolución" : "Confirmar vínculo") {
                    Task { if await review.apply(["vincular": [["id": row.id, "gasto_id": candidate.id]]], using: session) { onFinish() } }
                }
            }
        } message: {
            if let candidate = selectedCandidate {
                Text(isRefund ? "Se descontarán \(row.monto.formatted(.currency(code: "USD"))) de «\(candidate.gasto.descripcion)»." : "Se vinculará con «\(candidate.gasto.descripcion)» sin crear otro gasto.")
            }
        }
        .confirmationDialog("¿Descartar este movimiento?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Descartar", role: .destructive) { Task { if await review.apply(["descartar": [row.id]], using: session) { onFinish() } } }
        } message: { Text("No se guardará como gasto y no volverá a aparecer en pendientes.") }
    }

    /// El monto ya está en la fila; aquí sólo el texto tal como llegó del banco.
    private var originalMovement: some View {
        VStack(alignment: .leading, spacing: 6) {
            AppSectionLabel(text: isRefund ? "DEVOLUCIÓN RECIBIDA" : "CONSUMO DETECTADO")
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
        Button {
            withAnimation(AppMotion.standard) { saveAsNew = saveNew; selectedCandidate = nil }
            focusedField = nil
        } label: {
            Text(title).font(.system(size: 15, weight: saveAsNew == saveNew ? .semibold : .medium))
                .foregroundStyle(saveAsNew == saveNew ? AppTheme.backgroundTop : AppTheme.primaryText)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(saveAsNew == saveNew ? AppTheme.primaryText : AppTheme.popoverSurface, in: Capsule())
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
            VStack(alignment: .leading, spacing: 10) {
                FormSectionTitle(title: "Categoría")
                CategoryChipPicker(categories: session.categorias, selectedID: $categoryID)
            }
            ForeignTaxFields(enabled: $foreignEnabled, selected: $selected, customRate: $customRate, base: base)
            ExpenseExtrasFields(tagsText: $tagsText)
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
                    withAnimation(AppMotion.standard) { selectedCandidate = candidate }
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
    }
    private func seed() {
        guard !seeded else { return }
        seeded = true
        review.error = nil; review.message = nil
        if categoryID == 0 { categoryID = session.categorias.first?.id ?? 0 }
    }
    private func save() async {
        guard canSave, !aliasDirty else { return }
        var item: [String: Any] = ["id": row.id, "categoria_id": categoryID, "monto": base, "descripcion": description.trimmingCharacters(in: .whitespacesAndNewlines)]
        if foreignEnabled { item["impuestos"] = ["selected": selected, "customRate": customRate] }
        let knownIDs = Set(session.gastos.map(\.id))
        guard await review.apply(["aceptar": [item]], using: session) else { return }
        await applyTags(excluding: knownIDs)
        onFinish()
    }

    /// Pone las etiquetas en el gasto recién creado. Aceptar un movimiento del
    /// correo no recibe etiquetas, así que se busca el gasto nuevo que
    /// coincide y se editan, conservando las que ya traía (p. ej. `auto`).
    private func applyTags(excluding knownIDs: Set<Int>) async {
        guard !tags.isEmpty else { return }
        let cleanDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let created = session.gastos.first(where: {
            !knownIDs.contains($0.id) && $0.descripcion == cleanDescription && abs($0.monto - base) < 0.005
        }) else { return }
        let current = created.tags ?? []
        guard !Set(tags).isSubset(of: Set(current)) else { return }
        var merged = current
        for tag in tags where !merged.contains(tag) { merged.append(tag) }
        _ = await session.updateExpense(
            id: created.id,
            descripcion: created.descripcion,
            monto: created.monto,
            fecha: created.fecha,
            categoria: created.categoria,
            metodoPago: created.metodoPago,
            isRecurrent: created.isRecurrent,
            tags: merged,
            foreignTax: created.foreignTax
        )
    }
}
