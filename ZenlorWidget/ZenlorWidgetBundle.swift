import SwiftUI
import WidgetKit

@main
struct ZenlorWidgetBundle: WidgetBundle {
    var body: some Widget {
        SpendingWidget()
        TodaySpendingWidget()
    }
}
