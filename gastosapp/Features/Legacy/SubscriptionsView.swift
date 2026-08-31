import SwiftUI

struct SubscriptionsView: View {
    @Environment(SubscriptionStore.self) private var store

    @State private var mostrarAgregar = false

    private var grupos: [(categoria: ProviderCategoria, items: [Subscription])] {
        let dict = Dictionary(grouping: store.suscripciones, by: { $0.provider.categoria })
        return ProviderCategoria.allCases.compactMap { cat in
            guard let items = dict[cat], !items.isEmpty else { return nil }
            return (categoria: cat, items: items.sorted { $0.costoMensualEquivalente > $1.costoMensualEquivalente })
        }
    }

    var body: some View {
        ZStack {
            AppTheme.screenBackground.ignoresSafeArea()

            if store.suscripciones.isEmpty {
                vacio
            } else {
                ScrollView {
                    LazyVStack(spacing: 22) {
                        encabezado
                        totalCard
                        proximosCobros
                        ForEach(grupos, id: \.categoria) { grupo in
                            seccion(grupo.categoria, items: grupo.items)
                        }
                    }
                    .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
            }
        }
        .sheet(isPresented: $mostrarAgregar) {
            AddSubscriptionView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground {
                    AppTheme.screenBackground.ignoresSafeArea()
                }
        }
    }

    // MARK: - Encabezado

    private var encabezado: some View {
        AppScreenHeader(eyebrow: "\(store.suscripciones.count) activas", title: "Suscripciones") {
            AppCircleButton(
                icon: "plus",
                prominent: true,
                label: "Agregar suscripción",
                action: { mostrarAgregar = true }
            )
        }
    }

    // MARK: - Total

    private var totalCard: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Gasto mensual estimado")
                    .font(.caption2.weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(1.1)
                    .foregroundStyle(AppTheme.statementSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("$")
                        .font(.system(size: 24, weight: .semibold, design: .default))
                        .foregroundStyle(AppTheme.accent)
                    Text(formatear(store.totalMensual))
                        .font(.system(size: 42, weight: .bold, design: .default))
                        .foregroundStyle(AppTheme.onStatement)
                    Spacer(minLength: 0)
                }
            }

            AppTheme.statementHairline

            HStack {
                infoCol(titulo: "Anual", valor: "$\(formatear(store.totalAnual))")
                Spacer()
                infoCol(titulo: "Promedio/sub", valor: "$\(formatear(promedioPorSub))")
            }
        }
        .padding(24)
        .background(AppTheme.statementBackground(cornerRadius: 32))
        .accessibilityElement(children: .combine)
    }

    private func infoCol(titulo: String, valor: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(titulo)
                .font(.caption)
                .foregroundStyle(AppTheme.statementSecondary)
            Text(valor)
                .font(AppTheme.number(16, .semibold))
                .monospacedDigit()
                .foregroundStyle(AppTheme.onStatement)
        }
    }

    private var promedioPorSub: Double {
        guard !store.suscripciones.isEmpty else { return 0 }
        return store.totalMensual / Double(store.suscripciones.count)
    }

    // MARK: - Próximos cobros

    private var proximosCobros: some View {
        let proximos = store.suscripciones
            .sorted { $0.proximaFecha < $1.proximaFecha }
            .prefix(3)

        return VStack(alignment: .leading, spacing: 12) {
            Text("Próximos cobros")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(AppTheme.primaryText)
                .padding(.horizontal, 4)

            VStack(spacing: 10) {
                ForEach(Array(proximos)) { s in
                    HStack(spacing: 12) {
                        ProviderBadge(provider: s.provider, size: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.provider.nombre)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(AppTheme.primaryText)
                            Text(diasHasta(s.proximaFecha))
                                .font(.caption)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        Spacer()
                        Text("$\(formatear(s.monto))")
                            .font(.system(size: 14, weight: .semibold, design: .default))
                            .foregroundStyle(AppTheme.primaryText)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(AppTheme.controlSurface)
                    )
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func diasHasta(_ fecha: Date) -> String {
        let cal = Calendar.current
        let dias = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: fecha)).day ?? 0
        if dias < 0 { return "Vencida" }
        if dias == 0 { return "Hoy" }
        if dias == 1 { return "Mañana" }
        return "En \(dias) días"
    }

    // MARK: - Sección por categoría

    private func seccion(_ cat: ProviderCategoria, items: [Subscription]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: cat.icono)
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
                Text(cat.rawValue)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.primaryText)
                Spacer()
                Text("$\(formatear(items.reduce(0) { $0 + $1.costoMensualEquivalente }))/mes")
                    .font(.caption)
                    .foregroundStyle(AppTheme.tertiaryText)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, sub in
                    fila(sub)
                    if idx < items.count - 1 {
                        Divider()
                            .background(AppTheme.border)
                            .padding(.leading, 70)
                    }
                }
            }
            .background(AppTheme.cardBackground())
        }
    }

    private func fila(_ s: Subscription) -> some View {
        HStack(spacing: 14) {
            ProviderBadge(provider: s.provider, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(s.provider.nombre)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(AppTheme.primaryText)
                HStack(spacing: 6) {
                    Text(s.ciclo.rawValue)
                    Text("·")
                    Text(s.metodoPago.rawValue)
                }
                .font(.caption)
                .foregroundStyle(AppTheme.tertiaryText)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("$\(formatear(s.monto))")
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundStyle(AppTheme.primaryText)
                Text("≈ $\(formatear(s.costoMensualEquivalente))/m")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.tertiaryText)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .contextMenu {
            Button(role: .destructive) {
                store.remove(id: s.id)
            } label: {
                Label("Eliminar", systemImage: "trash")
            }
        }
    }

    // MARK: - Vacío

    private var vacio: some View {
        VStack(spacing: 18) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
            Text("Sin suscripciones")
                .font(.system(size: 24, weight: .bold, design: .default))
                .foregroundStyle(AppTheme.primaryText)
            Text("Agrega tus servicios para llevar el control de cuánto gastas al mes")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            Button { mostrarAgregar = true } label: {
                Label("Agregar suscripción", systemImage: "plus")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(AppTheme.accent))
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 30)
    }

    // MARK: - Helpers

    private func formatear(_ valor: Double) -> String {
        String(format: "%.2f", valor)
    }
}

#Preview {
    let store = SubscriptionStore()
    store.add(Subscription(provider: .netflix, monto: 15.99, ciclo: .mensual, proximaFecha: Date().addingTimeInterval(86_400 * 5), metodoPago: .credito))
    store.add(Subscription(provider: .spotify, monto: 10.99, ciclo: .mensual, proximaFecha: Date().addingTimeInterval(86_400 * 12), metodoPago: .debito))
    store.add(Subscription(provider: .chatgptPlus, monto: 20, ciclo: .mensual, proximaFecha: Date().addingTimeInterval(86_400 * 2), metodoPago: .credito))
    store.add(Subscription(provider: .iCloud, monto: 9.99, ciclo: .mensual, proximaFecha: Date().addingTimeInterval(86_400 * 20), metodoPago: .debito))
    return SubscriptionsView()
        .environment(store)
}
