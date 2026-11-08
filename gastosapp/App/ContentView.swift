//
//  ContentView.swift
//  gastosapp
//
//  Created by Nicolas Moina on 19/4/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ExpenseStore.self) private var store

    var body: some View {
        Group {
            if !store.isAuthResolved {
                ProgressView()
                    .tint(AppTheme.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.screenBackground)
            } else if store.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .task {
            await store.bootstrapSessionIfNeeded()
            guard store.isAuthenticated else { return }
            await LocalNotificationManager.prepareWeeklySummary(expenses: store.gastos)
            await LocalNotificationManager.prepareDailyExpenseReminder()
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            store.refreshSessionActivityWindow()
            Task {
                // Por si el arranque fue en segundo plano y no pudo leer la sesión.
                await store.bootstrapSessionIfNeeded()
                await store.renewMobileSessionWindowIfPossible()
            }
        }
        .keyboardDismissBehavior()
    }
}

#Preview {
    ContentView()
        .environment(ExpenseStore())
        .environment(BudgetStore())
}
