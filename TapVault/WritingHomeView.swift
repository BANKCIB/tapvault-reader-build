import SwiftUI
import CardCore

struct WritingHomeView: View {
    let onCreate: (RecordKind?) -> Void
    @State private var showSystems = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ماذا تريد أن تكتب؟").font(.title.weight(.bold))
                    Text("اختر المحتوى، أدخل التفاصيل، ثم قرّب وسمًا قابلًا للكتابة.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Button { onCreate(nil) } label: {
                    Label("جمع أكثر من محتوى في وسم واحد", systemImage: "square.stack.3d.up").frame(minHeight: 44)
                }.accessibilityIdentifier("open-writer")
                ForEach([RecordGroup.everyday, .communication]) { group in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(group.title).font(.headline).accessibilityAddTraits(.isHeader)
                        ForEach(group.kinds) { kind in
                            WritingOptionRow(kind: kind) { onCreate(kind) }
                        }
                    }
                }
                DisclosureGroup("للأنظمة والتطبيقات", isExpanded: $showSystems) {
                    VStack(spacing: 12) {
                        ForEach(RecordGroup.systems.kinds) { kind in
                            WritingOptionRow(kind: kind) { onCreate(kind) }
                        }
                    }.padding(.top, 12)
                }.font(.headline)
                DisclosureGroup("كيف تتم الكتابة؟") {
                    VStack(alignment: .leading, spacing: 12) {
                        instruction("1", "جهّز المحتوى", "اختر النوع وأدخل بياناتك. يمكنك إضافة أكثر من سجل.")
                        instruction("2", "راجع واحفظ", "سمّ المحتوى لتجده لاحقًا في مكتبتك. يظهر حجمه قبل الكتابة.")
                        instruction("3", "قرّب الوسم", "اضغط «كتابة على وسم»، ثم قرّب أعلى الآيفون. يفحص التطبيق السعة ويكتب البيانات ويتحقق منها.")
                        Text("الكتابة تستبدل محتوى الوسم. تحتاج إلى وسم يدعم NDEF وقابل للكتابة؛ فحص الشريحة وحده لا يعني أنها قابلة للكتابة.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }.padding(.top, 12)
                }.padding(18).background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
            }.padding(20).frame(maxWidth: 700).frame(maxWidth: .infinity)
        }.background(Theme.background).navigationTitle("الكتابة").navigationBarTitleDisplayMode(.inline)
    }

    private func instruction(_ number: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number).font(.headline).foregroundStyle(Theme.accent).frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}

struct WritingOptionRow: View {
    let kind: RecordKind
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: kind.symbol).font(.title3)
                    .foregroundStyle(Theme.accent).frame(width: 42, height: 42)
                    .background(Theme.accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 12)).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(kind.title).font(.headline).foregroundStyle(.primary)
                    Text(kind.explanation).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Text(kind.example).font(.caption).foregroundStyle(.secondary)
                        .environment(\.layoutDirection, kind.technicalExample ? .leftToRight : .rightToLeft)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.backward").font(.caption).foregroundStyle(.secondary).padding(.top, 12).accessibilityHidden(true)
            }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
        }.buttonStyle(.plain).accessibilityIdentifier("write-\(kind.rawValue)")
    }
}
