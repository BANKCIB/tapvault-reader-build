import Foundation

/// Information actually reported by the chip and Core NFC, independent of NDEF content.
public struct TagInspection: Codable, Hashable, Sendable {
    public var technology: String
    public var family: String
    public var identifier: String
    public var versionResponse: String?
    public var userMemoryBytes: Int?
    public var totalMemoryBytes: Int?
    public var ndefStatus: String
    public var detail: String
    public init(technology: String, family: String, identifier: String,
                ndefStatus: String = "لم يكتمل الفحص", detail: String = "تم التعرف على الشريحة.") {
        self.technology = technology; self.family = family; self.identifier = identifier
        self.ndefStatus = ndefStatus; self.detail = detail
    }
    public func validate() throws {
        guard !technology.isEmpty, technology.count <= 120, !family.isEmpty, family.count <= 120,
              identifier.count <= 256, (versionResponse?.count ?? 0) <= 512,
              ndefStatus.count <= 120, detail.count <= 2048 else { throw CardError.invalidData }
        for size in [userMemoryBytes, totalMemoryBytes].compactMap({ $0 }) {
            guard (0...1_048_576).contains(size) else { throw CardError.invalidData }
        }
        if let userMemoryBytes, let totalMemoryBytes, userMemoryBytes > totalMemoryBytes { throw CardError.invalidData }
    }
    public var textReport: String {
        var lines = ["تقرير فحص NFC", "التقنية: \(technology)", "الشريحة: \(family)",
                     "المعرّف المقروء: \(identifier)", "NDEF: \(ndefStatus)"]
        if let userMemoryBytes { lines.append("ذاكرة المستخدم: \(userMemoryBytes) بايت") }
        if let totalMemoryBytes { lines.append("الذاكرة الكلية: \(totalMemoryBytes) بايت") }
        if let versionResponse { lines.append("GET_VERSION: \(versionResponse)") }
        lines.append(detail)
        return lines.joined(separator: "\n")
    }
    public mutating func applyUltralightVersion(_ response: Data) {
        versionResponse = response.map { String(format: "%02X", $0) }.joined(separator: " ")
        guard let version = UltralightVersion.parse(response) else { return }
        family = version.name; userMemoryBytes = version.userBytes; totalMemoryBytes = version.totalBytes
    }
}

public struct UltralightVersion: Equatable, Sendable {
    public let name: String
    public let userBytes: Int
    public let totalBytes: Int
    /// NXP MF0ULX1 datasheet, GET_VERSION table 15. Do not infer a model from UID alone.
    public static func parse(_ response: Data) -> Self? {
        let bytes = Array(response)
        guard bytes.count == 8, bytes[0] == 0, bytes[1] == 4, bytes[2] == 3,
              [1, 2].contains(bytes[3]), bytes[4] == 1, bytes[5] == 0, bytes[7] == 3 else { return nil }
        switch bytes[6] {
        case 0x0B: return Self(name: "NXP MIFARE Ultralight EV1 · MF0UL11", userBytes: 48, totalBytes: 80)
        case 0x0E: return Self(name: "NXP MIFARE Ultralight EV1 · MF0UL21", userBytes: 128, totalBytes: 164)
        default: return nil
        }
    }
}
