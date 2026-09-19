import SwiftUI
import CardCore

struct LibraryView: View {
    @EnvironmentObject var store: VaultStore
    @EnvironmentObject var nfc: NFCService
    let onCreate: () -> Void
    let onReference: () -> Void
    @State private var search = ""
    @State private var favoritesOnly = false
    @State private var category: CardCategory?
    private var filtered: [SavedCard] {
        store.cards.filter { card in
            (!favoritesOnly || card.favorite) && (category == nil || card.category == category) &&
            (search.isEmpty || [card.title, card.notes, card.category.title].joined(separator: " ").localizedStandardContains(search))
        }.sorted { $0.favorite == $1.favorite ? $0.updatedAt > $1.updatedAt : $0.favorite }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                hero
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary).accessibilityHidden(true)
                    TextField("ابحث في بطاقاتك", text: $search).accessibilityIdentifier("library-search")
                    if !search.isEmpty { Button { search = "" } label: { Image(systemName: "xmark.circle.fill").frame(minWidth: 44, minHeight: 44) }.accessibilityLabel("مسح البحث") }
                }.padding(.horizontal, 16).frame(minHeight: 52).background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
                filters
                if filtered.isEmpty {
                    ContentUnavailableView {
                        Label(store.cards.isEmpty ? "مساحتك جاهزة" : "لا توجد نتائج", systemImage: "square.stack")
                    } description: {
                        Text(store.cards.isEmpty ? "اقرأ وسمًا أو أنشئ أول بطاقة. بياناتك تبقى على جهازك." : "جرّب اسمًا آخر أو أزل التصفية.")
                    } actions: {
                        if search.isEmpty && store.cards.isEmpty { Button("إنشاء بطاقة", action: onCreate).buttonStyle(.bordered) }
                        else { Button("إظهار الكل") { search = ""; category = nil; favoritesOnly = false } }
                    }.padding(.vertical, 16)
                } else {
                    VStack(spacing: 12) {
                        ForEach(filtered) { card in
                            NavigationLink(value: card.id) { CardRow(card: card) }.buttonStyle(.plain)
                        }
                    }
                }
                Label("المرجع المحفوظ لا يحل محل مفتاح الدخول أو تذكرة السفر.", systemImage: "info.circle")
                    .font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }.padding(24).frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
        }.background(Theme.background).toolbar(.hidden, for: .navigationBar)
    }
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("قُرب").font(.system(.largeTitle, design: .rounded, weight: .bold))
                Text("كل ما حفظته، في مكانك.").font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Menu {
                Button("تجهيز وسم جديد", systemImage: "plus", action: onCreate)
                Button("مرجع فندق أو تنقل", systemImage: "bookmark", action: onReference)
            } label: { Image(systemName: "plus").font(.title3.weight(.medium)).frame(width: 48, height: 48).background(Theme.surface, in: Circle()) }
            .accessibilityLabel("إضافة بطاقة").accessibilityIdentifier("add-card")
        }
    }
    private var hero: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("\(store.cards.count) محفوظة").font(.headline)
                Spacer()
                Text("\(store.cards.filter(\.canWrite).count) قابلة للكتابة").font(.subheadline)
            }
            Button(action: onCreate) {
                Label("تجهيز محتوى للكتابة", systemImage: "square.and.pencil")
                    .font(.headline).frame(maxWidth: .infinity, minHeight: 48)
                    .background(.white, in: RoundedRectangle(cornerRadius: 14)).foregroundStyle(Theme.ink)
            }.accessibilityIdentifier("library-write")
            Button { nfc.scan() } label: {
                Label(nfc.busy ? "القراءة جارية…" : "قراءة بطاقة أو وسم", systemImage: "radiowaves.left.and.right")
                    .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
            }.disabled(nfc.busy).accessibilityIdentifier("scan-tag")
        }.foregroundStyle(.white).padding(20).background(Theme.ink, in: RoundedRectangle(cornerRadius: 24))
    }
    private var filters: some View {
        HStack {
            Text("مكتبتك").font(.title3.weight(.bold))
            Spacer()
            Button { favoritesOnly.toggle() } label: { Image(systemName: favoritesOnly ? "star.fill" : "star").frame(width: 44, height: 44) }
                .accessibilityLabel(favoritesOnly ? "إظهار جميع البطاقات" : "إظهار المفضلة")
                .accessibilityAddTraits(favoritesOnly ? .isSelected : [])
            Menu {
                Button("كل الفئات") { category = nil }
                ForEach(CardCategory.allCases) { value in Button(value.title) { category = value } }
            } label: { Label(category?.title ?? "الكل", systemImage: "line.3.horizontal.decrease").font(.subheadline).frame(minHeight: 44) }
        }
    }
}
