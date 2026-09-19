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
    var kinds: [RecordKind] { RecordKind.allCases.filter { $0.group == self } }
}

extension RecordKind {
    var group: RecordGroup {
        switch self {
        case .text, .url, .location: return .everyday
        case .phone, .email, .sms, .contact: return .communication
        case .customURI, .json, .bytes: return .systems
        }
    }
}
