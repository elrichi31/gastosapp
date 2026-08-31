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
    @AppStorage(AppAppearancePreference.storageKey) private var appearanceRawValue = AppAppearancePreference.dark.rawValue

    init() {
        LocalNotificationManager.configureForegroundPresentation()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(budgetStore)
                .preferredColorScheme(selectedAppearance.colorScheme)
        }
    }

    private var selectedAppearance: AppAppearancePreference {
        AppAppearancePreference(rawValue: appearanceRawValue) ?? .system
    }
}
