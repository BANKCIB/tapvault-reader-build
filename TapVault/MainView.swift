import SwiftUI
import CardCore

struct EditorRequest: Identifiable { let id = UUID(); var card: SavedCard?; var reference = false }

struct MainView: View {
    @EnvironmentObject var store: VaultStore
    @EnvironmentObject var nfc: NFCService
    @State private var editor: EditorRequest?
    @State private var alertText: String?
    var body: some View {
        TabView {
            NavigationStack {
                LibraryView(onCreate: { editor = EditorRequest() }, onReference: { editor = EditorRequest(reference: true) })
                    .navigationDestination(for: UUID.self) { id in CardDetailView(id: id) }
            }.tabItem { Label("مكتبتي", systemImage: "square.grid.2x2") }
            NavigationStack { ToolsView(onCreate: { editor = EditorRequest() }, onReference: { editor = EditorRequest(reference: true) }) }
                .tabItem { Label("الأدوات", systemImage: "wave.3.right") }
            NavigationStack { SettingsView() }.tabItem { Label("الخزنة", systemImage: "lock.shield") }
        }
        .sheet(item: $editor) { request in CardEditor(card: request.card, reference: request.reference) }
        .onReceive(nfc.$scanned) { card in
            guard let card else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                guard store.isUnlocked, nfc.scanned?.id == card.id else { return }; editor = EditorRequest(card: card)
            }
        }
        .onReceive(nfc.$errorMessage) { if let message = $0 { alertText = message } }
        .onReceive(store.$errorMessage) { if let message = $0 { alertText = message } }
        .onChange(of: nfc.writeSucceeded) { _, success in
            if success { DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { alertText = "تمت كتابة البيانات والتحقق من مطابقتها على وسم الوجهة." } }
        }
        .alert("قُرب", isPresented: Binding(get: { alertText != nil }, set: { if !$0 { alertText = nil } })) {
            Button("حسنًا", role: .cancel) { alertText = nil; nfc.errorMessage = nil; store.errorMessage = nil }
        } message: { Text(alertText ?? "") }
    }
}

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
                        Label(search.isEmpty ? "مساحتك جاهزة" : "لا توجد نتائج", systemImage: "square.stack")
                    } description: {
                        Text(search.isEmpty ? "اقرأ وسمًا أو أنشئ أول بطاقة. بياناتك تبقى على جهازك." : "جرّب اسمًا آخر أو أزل التصفية.")
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
                Button("نص أو رابط جديد", systemImage: "plus", action: onCreate)
                Button("مرجع فندق أو تنقل", systemImage: "bookmark", action: onReference)
            } label: { Image(systemName: "plus").font(.title3.weight(.medium)).frame(width: 48, height: 48).background(Theme.surface, in: Circle()) }
            .accessibilityLabel("إضافة بطاقة").accessibilityIdentifier("add-card")
        }
    }
    private var hero: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("مساحة شخصية").font(.footnote.weight(.medium)).foregroundStyle(.white.opacity(0.8))
                    Text("قرّب. احفظ.\nوابقَ منظمًا.").font(.system(.title, design: .rounded, weight: .semibold))
                }
                Spacer(minLength: 8)
                Image(systemName: "wave.3.right").font(.system(size: 44, weight: .ultraLight)).foregroundStyle(Color(red: 0.63, green: 0.88, blue: 0.81)).accessibilityHidden(true)
            }
            HStack(spacing: 24) {
                metric(store.cards.count, "محفوظة")
                metric(store.cards.filter(\.canWrite).count, "قابلة للكتابة")
                Spacer(minLength: 0)
            }
            Button { nfc.scan() } label: {
                Label(nfc.busy ? "القراءة جارية…" : "قراءة بطاقة أو وسم", systemImage: "radiowaves.left.and.right")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(.white, in: RoundedRectangle(cornerRadius: 14)).foregroundStyle(Theme.ink)
            }.disabled(nfc.busy).accessibilityIdentifier("scan-tag")
        }.foregroundStyle(.white).padding(24).background(Theme.ink, in: RoundedRectangle(cornerRadius: 28))
    }
    private func metric(_ value: Int, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) { Text(value, format: .number).font(.title2.weight(.semibold)).monospacedDigit(); Text(label).font(.caption).foregroundStyle(.white.opacity(0.8)) }
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

struct ToolsView: View {
    @EnvironmentObject var nfc: NFCService
    let onCreate: () -> Void
    let onReference: () -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("أدوات بسيطة.\nاستخدام واضح.").font(.largeTitle.weight(.bold))
                Text("اقرأ البيانات القياسية، أو جهز وسمًا جديدًا لاستخدامك.").foregroundStyle(.secondary)
                VStack(spacing: 12) {
                    ToolButton(title: "قراءة بطاقة أو وسم", subtitle: "التعرّف على الشريحة أولًا، ثم قراءة NDEF إن توفر", symbol: "radiowaves.left.and.right") { nfc.scan() }.disabled(nfc.busy)
                    ToolButton(title: "قراءة NDEF مباشرة", subtitle: "المسار القياسي لقراءة الرسائل من الوسوم المتوافقة", symbol: "doc.text.viewfinder") { nfc.scanNDEF() }.disabled(nfc.busy)
                    ToolButton(title: "إنشاء نص أو رابط", subtitle: "احفظه، ثم اكتبه على وسم متوافق", symbol: "square.and.pencil", action: onCreate)
                    ToolButton(title: "إضافة مرجع بطاقة", subtitle: "اسم الجهة والملاحظات ورابطها الرسمي", symbol: "bookmark", action: onReference)
                }
                Label(nfc.status, systemImage: nfc.busy ? "hourglass" : "wave.3.right").font(.callout).foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 16) {
                    Text("ما الذي يدعمه التطبيق؟").font(.headline)
                    capability("القراءة والحفظ", "بيانات NDEF المتاحة على الوسوم المتوافقة.", "checkmark.circle")
                    capability("الكتابة", "نصوص وروابط على وسم قابل للكتابة، مع فحص السعة والتحقق بعد الكتابة.", "checkmark.circle")
                    capability("بطاقات الفندق والقطار", "يمكن حفظ مرجعها. استخدامها كمفتاح أو تذكرة رقمية يحتاج إلى إصدار رسمي من الجهة.", "building.2")
                    capability("Apple Wallet", "يدعم فتح ملف بطاقة أصلي توفره الجهة. لا يحوّل مسح البطاقة البلاستيكية إلى مفتاح في المحفظة.", "wallet.pass")
                }.padding(20).background(Theme.surface, in: RoundedRectangle(cornerRadius: 22))
            }.padding(24).frame(maxWidth: 700).frame(maxWidth: .infinity)
        }.background(Theme.background).navigationTitle("الأدوات").navigationBarTitleDisplayMode(.inline)
    }
    private func capability(_ title: String, _ detail: String, _ symbol: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).foregroundStyle(Theme.accent).frame(width: 24).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) { Text(title).font(.subheadline.weight(.semibold)); Text(detail).font(.footnote).foregroundStyle(.secondary) }
        }
    }
}

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
