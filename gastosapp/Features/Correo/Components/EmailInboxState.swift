import SwiftUI

struct EmailInboxState: View {
    let title: String
    let message: String
    let icon: String
    var tint: Color = AppTheme.accent
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon).font(.title2.weight(.medium)).foregroundStyle(tint)
                .frame(width: 64, height: 64).background(tint.opacity(0.1), in: Circle()).accessibilityHidden(true)
            Text(title).font(.headline).foregroundStyle(AppTheme.primaryText)
            Text(message).font(.subheadline).foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 36)
    }
}
