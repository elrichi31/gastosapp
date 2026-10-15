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
    @AppStorage(AppAppearancePreference.storageKey) private var appearanceRawValue = AppAppearancePreference.defaultValue.rawValue

    init() {
        LocalNotificationManager.configureForegroundPresentation()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(budgetStore)
                .onAppear { selectedAppearance.apply() }
                .onChange(of: appearanceRawValue) { selectedAppearance.apply() }
        }
    }

    private var selectedAppearance: AppAppearancePreference {
        AppAppearancePreference(rawValue: appearanceRawValue) ?? .defaultValue
    }
}
