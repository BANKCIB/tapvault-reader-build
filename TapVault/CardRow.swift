import SwiftUI
import CardCore

struct CardRow: View {
    let card: SavedCard
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: card.category.symbol).font(.title3).foregroundStyle(Theme.accent)
                .frame(width: 48, height: 56).background(Theme.accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 14)).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(card.title).font(.headline).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                Text(card.capability).font(.caption).foregroundStyle(.secondary)
                if card.isExpired { Label("انتهى التاريخ المسجل", systemImage: "clock.badge.exclamationmark").font(.caption).foregroundStyle(.red) }
            }
            Spacer(minLength: 0)
            if card.favorite { Image(systemName: "star.fill").font(.caption).foregroundStyle(Theme.accent).accessibilityLabel("مفضلة") }
            Image(systemName: "chevron.backward").font(.caption.weight(.semibold)).foregroundStyle(.tertiary).accessibilityHidden(true)
        }.padding(16).background(Theme.surface, in: RoundedRectangle(cornerRadius: 20)).contentShape(Rectangle())
    }
}
