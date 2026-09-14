import Foundation
import CryptoKit

public enum BackupCodec {
    public static let maximumBytes = 4 * 1024 * 1024
    private struct Envelope: Codable { let format: String; let version: Int; let sealed: Data }
    public static func seal(_ cards: [SavedCard]) throws -> (data: Data, recoveryKey: String) {
        try CardCollection.validate(cards)
        let key = SymmetricKey(size: .bits256)
        let plain = try JSONEncoder().encode(cards)
        guard plain.count <= maximumBytes / 2 else { throw CardError.tooLarge }
        guard let sealed = try AES.GCM.seal(plain, using: key, authenticating: Data("TapVaultBackup/v1".utf8)).combined else { throw CardError.invalidData }
        let envelope = Envelope(format: "TapVaultBackup", version: 1, sealed: sealed)
        return (try JSONEncoder().encode(envelope), key.withUnsafeBytes { Data($0).base64EncodedString() })
    }
    public static func open(_ data: Data, recoveryKey: String) throws -> [SavedCard] {
        guard data.count <= maximumBytes else { throw CardError.tooLarge }
        let normalized = recoveryKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let keyData = Data(base64Encoded: normalized), keyData.count == 32 else { throw CardError.invalidKey }
        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        guard envelope.format == "TapVaultBackup", envelope.version == 1 else { throw CardError.unsupportedBackup }
        let box = try AES.GCM.SealedBox(combined: envelope.sealed)
        let plain = try AES.GCM.open(box, using: SymmetricKey(data: keyData), authenticating: Data("TapVaultBackup/v1".utf8))
        let cards = try JSONDecoder().decode([SavedCard].self, from: plain)
        try CardCollection.validate(cards); return cards
    }
}
