//
//  gastosappApp.swift
//  gastosapp
//
//  Created by Nicolas Moina on 19/4/26.
//

import SwiftUI

@main
struct gastosappApp: App {
    @State private var store = ExpenseStore()
    @State private var budgetStore = BudgetStore()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppAppearancePreference.storageKey) private var appearanceRawValue = AppAppearancePreference.defaultValue.rawValue

    init() {
        LocalNotificationManager.configureForegroundPresentation()
    }

    var body: some Scene {
        WindowGroup {
            if Self.isHostingUnitTests {
                // Las pruebas unitarias corren dentro de la app. Si arrancara de
                // verdad, renovaría la sesión con el servidor y Xcode la cerraría
                // antes de guardar el token nuevo: el del llavero quedaba
                // inválido y la siguiente vez la app pedía iniciar sesión.
                Color.clear
            } else {
                ContentView()
                    .environment(store)
                    .environment(budgetStore)
                    .onAppear { selectedAppearance.apply() }
                    .onChange(of: appearanceRawValue) { selectedAppearance.apply() }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background, !Self.isHostingUnitTests { EmailConsumptionMonitor.schedule() }
        }
        .backgroundTask(.appRefresh(EmailConsumptionMonitor.taskIdentifier)) { [store] in
            await EmailConsumptionMonitor.checkInBackground(store: store)
        }
    }

    private static let isHostingUnitTests =
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    private var selectedAppearance: AppAppearancePreference {
        AppAppearancePreference(rawValue: appearanceRawValue) ?? .defaultValue
    }
}
