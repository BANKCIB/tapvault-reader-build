import SwiftUI
import UniformTypeIdentifiers
import PassKit
import CardCore

extension UTType { static let tapVaultBackup = UTType(exportedAs: "com.m7madv.tapvault.backup", conformingTo: .data) }

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.tapVaultBackup, .data] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let bytes = configuration.file.regularFileContents, bytes.count <= BackupCodec.maximumBytes else { throw CardError.tooLarge }
        data = bytes
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct BackupPackage: Identifiable { let id = UUID(); let data: Data; let recoveryKey: String }
struct RestorePackage: Identifiable { let id = UUID(); let data: Data }
struct WalletPackage: Identifiable { let id = UUID(); let controller: PKAddPassesViewController }
