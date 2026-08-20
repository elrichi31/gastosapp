import SwiftUI

enum BudgetMovementGroupPosition {
    case single
    case top
    case middle
    case bottom

    var topRadius: CGFloat {
        switch self {
        case .single, .top: return 20
        case .middle, .bottom: return 0
        }
    }

    var bottomRadius: CGFloat {
        switch self {
        case .single, .bottom: return 20
        case .middle, .top: return 0
        }
    }

    var showsBottomDivider: Bool { self == .top || self == .middle }
    var showsTopDivider: Bool { self == .middle || self == .bottom }
}

struct BudgetGroupedShape: Shape {
    let position: BudgetMovementGroupPosition

    func path(in rect: CGRect) -> Path {
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: position.topRadius,
            bottomLeadingRadius: position.bottomRadius,
            bottomTrailingRadius: position.bottomRadius,
            topTrailingRadius: position.topRadius,
            style: .continuous
        )
        return shape.path(in: rect)
    }
}
