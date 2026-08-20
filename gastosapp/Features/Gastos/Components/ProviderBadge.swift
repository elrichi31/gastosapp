import SwiftUI

struct ProviderBadge: View {
    let provider: Provider
    var size: CGFloat = 44

    var body: some View {
        let cornerRadius = size * 0.28
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(provider.color)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(AppTheme.primaryText.opacity(0.08), lineWidth: 1)
                )

            Text(provider.iniciales)
                .font(.system(size: size * 0.42, weight: .semibold, design: .default))
                .foregroundStyle(AppTheme.primaryText)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .padding(.horizontal, 4)
        }
        .frame(width: size, height: size)
    }
}
