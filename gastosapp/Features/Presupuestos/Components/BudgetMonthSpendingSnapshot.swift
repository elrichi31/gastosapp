import Foundation
import SwiftUI

struct BudgetMonthSpendingSnapshot {
    let budget: BudgetMonthly
    let monthlyMetrics: BudgetMonthlyMetrics
    let metricsByCategoryID: [Int: BudgetCategoryMetrics]
    let progressSegments: [BudgetProgressSegment]

    init(budget: BudgetMonthly, categories: [BudgetCategoryDetail], expenses: [Expense]) {
        let budgetYear = budget.anio
        let budgetMonth = budget.mes

        let computedMonthlyMetrics = BudgetMonthlyMetrics(
            categories: categories,
            expenses: expenses,
            year: budgetYear,
            month: budgetMonth
        )

        var spentByCategory: [Int: Double] = [:]
        if let range = Date.budgetMonthRange(year: budgetYear, month: budgetMonth) {
            for expense in expenses where range.contains(expense.fecha) {
                spentByCategory[expense.categoriaId, default: 0] += expense.monto
            }
        }

        let computedMetricsByCategoryID = Dictionary(uniqueKeysWithValues: categories.map { category in
            let spent = spentByCategory[category.categoriaId] ?? 0
            return (
                category.id,
                BudgetCategoryMetrics(budgeted: category.budgetedAmount, spent: spent)
            )
        })

        let computedProgressSegments: [BudgetProgressSegment]
        if computedMonthlyMetrics.budgeted > 0 {
            computedProgressSegments = categories.compactMap { category in
                guard let metrics = computedMetricsByCategoryID[category.id], metrics.spent > 0 else { return nil }
                return BudgetProgressSegment(
                    id: category.id,
                    fraction: min(metrics.spent / computedMonthlyMetrics.budgeted, 1),
                    color: category.displayCategory.color
                )
            }
        } else {
            computedProgressSegments = []
        }

        self.budget = budget
        monthlyMetrics = computedMonthlyMetrics
        metricsByCategoryID = computedMetricsByCategoryID
        progressSegments = computedProgressSegments
    }
}

struct BudgetProgressSegment: Identifiable {
    let id: Int
    let fraction: Double
    let color: Color
}
