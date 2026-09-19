import CardCore

enum RecordGroup: String, CaseIterable, Identifiable {
    case everyday, communication, systems
    var id: String { rawValue }
    var title: String {
        switch self {
        case .everyday: return "الاستخدام اليومي"
        case .communication: return "التواصل"
        case .systems: return "الأنظمة والبيانات المتقدمة"
        }
    }
    var kinds: [RecordKind] {
        switch self {
        case .everyday: return [.url, .text, .location]
        case .communication: return [.phone, .email, .sms, .contact]
        case .systems: return [.customURI, .json, .bytes]
        }
    }
}

extension RecordKind {
    var explanation: String {
        switch self {
        case .url: return "رابط موقع، قائمة طعام أو صفحة شخصية؛ يفتحه القارئ المتوافق."
        case .text: return "ملاحظة أو تعليمات أو رقم منتج يمكن قراءته من الوسم."
        case .location: return "رابط خرائط يصل إلى المكان الذي تحدده بالإحداثيات."
        case .phone: return "رقم هاتف جاهز للاتصال بعد موافقة من يقرأ الوسم."
        case .email: return "عنوان بريد مع موضوع ورسالة اختياريين لتجهيز بريد جديد."
        case .sms: return "رقم مستلم لتجهيز رسالة نصية؛ لا تُرسل الرسالة تلقائيًا."
        case .contact: return "الاسم والهاتف والبريد في بطاقة اتصال بصيغة vCard."
        case .customURI: return "رابط إلى شاشة داخل تطبيق أو نظام يدعم هذا النوع من الروابط."
        case .json: return "بيانات منظمة يقرأها تطبيقك أو نظامك المتوافق."
        case .bytes: return "محتوى ثنائي مع نوع MIME تختاره لنظام يعرف طريقة قراءته."
        }
    }
    var example: String {
        switch self {
        case .url: return "https://example.com/menu"
        case .text: return "تعليمات استخدام الجهاز"
        case .location: return "موقع المكتب أو نقطة لقاء"
        case .phone: return "+966500000000"
        case .email: return "hello@example.com"
        case .sms: return "رقم خدمة العملاء"
        case .contact: return "بطاقة تواصل شخصية"
        case .customURI: return "myapp://item/123"
        case .json: return "{\"product\":123}"
        case .bytes: return "01 A2 FF"
        }
    }
    var technicalExample: Bool {
        switch self {
        case .url, .phone, .email, .customURI, .json, .bytes: return true
        default: return false
        }
    }
    var group: RecordGroup {
        switch self {
        case .text, .url, .location: return .everyday
        case .phone, .email, .sms, .contact: return .communication
        case .customURI, .json, .bytes: return .systems
        }
    }
}
