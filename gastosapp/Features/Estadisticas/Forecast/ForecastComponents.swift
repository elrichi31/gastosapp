import SwiftUI

/// Presentación compartida; los importes y la estimación siguen viniendo del servidor.
enum ForecastFormat {
    static func money(_ value: Double) -> String {
        value.formatted(.currency(code: "USD").locale(Locale(identifier: "en_US")))
    }

    static func month(_ value: String) -> String {
        guard let date = AppDateCodec.dateOnly(from: value + "-01") else { return value }
        let title = date.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "es")))
        return title.prefix(1).uppercased() + title.dropFirst()
    }

    static func date(_ value: String) -> String {
        guard let date = AppDateCodec.dateOnly(from: value) else { return value }
        return date.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "es")))
    }
}

struct ForecastSection<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline).foregroundStyle(AppTheme.primaryText)
                Text(subtitle).font(.subheadline).foregroundStyle(AppTheme.secondaryText).fixedSize(horizontal: false, vertical: true)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(AppTheme.cardBackground())
    }
}

struct ForecastAmountRow: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let title: String
    let detail: String?
    let value: Double
    var tint: Color = AppTheme.primaryText

    init(_ title: String, detail: String? = nil, value: Double, tint: Color = AppTheme.primaryText) {
        self.title = title; self.detail = detail; self.value = value; self.tint = tint
    }

    var body: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))
        layout {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.medium)).foregroundStyle(AppTheme.primaryText)
                if let detail { Text(detail).font(.caption).foregroundStyle(AppTheme.secondaryText) }
            }.frame(maxWidth: .infinity, alignment: .leading)
            Text(ForecastFormat.money(value)).font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(tint)
        }
        .accessibilityElement(children: .combine)
    }
}

struct ForecastNotice: View {
    let icon: String
    let message: String
    var tint: Color = AppTheme.warning

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundStyle(tint).accessibilityHidden(true)
            Text(message).font(.subheadline).foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.insetSurface, in: .rect(cornerRadius: AppTheme.Radius.control))
    }
}
