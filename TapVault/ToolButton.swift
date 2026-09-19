import SwiftUI

struct ToolButton: View {
    let title: String
    let subtitle: String
    let symbol: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: symbol).font(.title2).frame(width: 32).foregroundStyle(Theme.accent).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) { Text(title).font(.headline).foregroundStyle(.primary); Text(subtitle).font(.subheadline).foregroundStyle(.secondary) }
                Spacer(minLength: 0)
                Image(systemName: "chevron.backward").font(.caption).foregroundStyle(.secondary).accessibilityHidden(true)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(20).background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
        }.buttonStyle(.plain)
    }
}
