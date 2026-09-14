import SwiftUI
import CardCore

struct TagInspectionView: View {
    let inspection: TagInspection
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("تم التعرف على الشريحة", systemImage: "checkmark.circle")
                .font(.headline).foregroundStyle(Theme.accent)
            field("نوع الشريحة", inspection.family)
            field("التقنية", inspection.technology)
            field("المعرّف المقروء", inspection.identifier.isEmpty ? "لم يوفّره النظام" : inspection.identifier)
            if let bytes = inspection.userMemoryBytes { field("ذاكرة المستخدم", "\(bytes) بايت", technical: false) }
            if let bytes = inspection.totalMemoryBytes { field("الذاكرة الكلية", "\(bytes) بايت", technical: false) }
            field("حالة NDEF", inspection.ndefStatus, technical: false)
            Text(inspection.detail).font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let version = inspection.versionResponse {
                DisclosureGroup("استجابة تعريف الطراز") {
                    Text(version).font(.footnote.monospaced()).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .environment(\.layoutDirection, .leftToRight)
                }.font(.footnote)
            }
            if let diagnostics = inspection.diagnostics, !diagnostics.isEmpty {
                DisclosureGroup("تفاصيل المحاولات") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(diagnostics.enumerated()), id: \.offset) { _, line in
                            Text(line).font(.footnote).textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }.padding(.top, 8)
                }.font(.footnote)
            }
            ShareLink(item: inspection.textReport) {
                Label("مشاركة معلومات الشريحة", systemImage: "square.and.arrow.up").frame(minHeight: 44)
            }.font(.subheadline)
        }.accessibilityIdentifier("tag-inspection")
    }
    private func field(_ title: String, _ value: String, technical: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(technical ? .body.monospaced() : .body)
                .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .environment(\.layoutDirection, technical ? .leftToRight : .rightToLeft)
        }.accessibilityElement(children: .combine)
    }
}
