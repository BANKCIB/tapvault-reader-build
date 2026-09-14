import Foundation
import Combine
import CoreNFC
import CardCore

final class NFCService: NSObject, ObservableObject, NFCNDEFReaderSessionDelegate {
    @Published private(set) var busy = false
    @Published var status = "جاهز لقراءة وسم"
    @Published var errorMessage: String?
    @Published var scanned: SavedCard?
    @Published var writeSucceeded = false
    private var session: NFCNDEFReaderSession?
    private var pendingWrite: [TagRecord]?
    private var finished = false
    private var tagSession: NFCTagReaderSession?
    private var detectedCard: SavedCard?
    private var handlingTag = false
    var available: Bool { NFCNDEFReaderSession.readingAvailable }

    func scanNDEF() { begin(records: nil) }
    func write(_ card: SavedCard) {
        do {
            try card.validate()
            guard card.canWrite else { throw CardError.unsupportedRecord }
            begin(records: card.records)
        } catch { errorMessage = error.localizedDescription }
    }
    func cancel() {
        finished = true; detectedCard = nil; scanned = nil
        session?.invalidate(); tagSession?.invalidate()
    }
    private func begin(records: [TagRecord]?) {
        guard !busy else { return }
        guard available else { errorMessage = "قراءة NFC غير متاحة هنا. استخدم iPhone متوافقًا ونسخة موقعة بصلاحية قراءة الوسوم."; return }
        pendingWrite = records; scanned = nil; finished = false; writeSucceeded = false; errorMessage = nil; busy = true
        let next = NFCNDEFReaderSession(delegate: self, queue: .main, invalidateAfterFirstRead: false)
        session = next
        status = records == nil ? "قرّب أعلى iPhone من الوسم" : "قرّب وسم الوجهة وابقه ثابتًا"
        next.alertMessage = status; next.begin()
    }
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {}
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        guard self.session === session else { return }
        if !finished {
            if let nfcError = error as? NFCReaderError, nfcError.code == .readerSessionInvalidationErrorUserCanceled { status = "أُلغيت العملية" }
            else { errorMessage = "لم تكتمل العملية. قرّب وسم NDEF متوافقًا وأعد المحاولة.\n" + error.localizedDescription; status = "تعذرت العملية" }
        }
        self.session = nil; pendingWrite = nil; busy = false
    }
    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        guard self.session === session, !finished else { return }
        guard tags.count == 1, let tag = tags.first else {
            session.alertMessage = "أبعد البطاقات الأخرى؛ نحتاج وسمًا واحدًا فقط."
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                if self?.session === session { session.restartPolling() }
            }
            return
        }
        session.connect(to: tag) { [weak self] error in
            DispatchQueue.main.async {
                guard let self, self.session === session, !self.finished else { return }
                if let error { self.fail(session, "تعذر الاتصال. " + error.localizedDescription); return }
                tag.queryNDEFStatus { [weak self] status, capacity, error in
                    DispatchQueue.main.async {
                        guard let self, self.session === session, !self.finished else { return }
                        if let error { self.fail(session, "تعذر فحص الوسم. " + error.localizedDescription); return }
                        guard status != .notSupported else { self.fail(session, "لا يدعم هذا الوسم بيانات NDEF المتاحة للتطبيق."); return }
                        if let records = self.pendingWrite { self.performWrite(records, tag: tag, session: session, writable: status == .readWrite, capacity: capacity) }
                        else { self.performRead(tag, session: session, writable: status == .readWrite, capacity: capacity) }
                    }
                }
            }
        }
    }
    private func performRead(_ tag: NFCNDEFTag, session: NFCNDEFReaderSession, writable: Bool, capacity: Int) {
        tag.readNDEF { [weak self] message, error in
            DispatchQueue.main.async {
                guard let self, self.session === session, !self.finished else { return }
                if let error { self.fail(session, "تعذرت قراءة رسالة NDEF. جرّب فحص البطاقة لعرض معلومات الشريحة. " + error.localizedDescription); return }
                guard let message, !message.records.isEmpty else { self.fail(session, "الوسم فارغ. يمكنك إنشاء نص أو رابط وكتابته عليه."); return }
                let records = Self.records(message)
                let card = SavedCard(title: "وسم جديد", records: records, source: "قراءة NFC", capacity: capacity, sourceWritable: writable)
                do { try card.validate() } catch { self.fail(session, error.localizedDescription); return }
                self.scanned = card; self.finish(session, "تمت القراءة. راجع البيانات ثم احفظها.")
            }
        }
    }
    private func performWrite(_ records: [TagRecord], tag: NFCNDEFTag, session: NFCNDEFReaderSession, writable: Bool, capacity: Int) {
        guard writable else { fail(session, "الوسم للقراءة فقط. استخدم وسمًا آخر قابلًا للكتابة."); return }
        let payloads = records.compactMap { record -> NFCNDEFPayload? in
            guard let format = NFCTypeNameFormat(rawValue: record.tnf) else { return nil }
            return NFCNDEFPayload(format: format, type: record.type, identifier: record.identifier, payload: record.payload)
        }
        guard payloads.count == records.count else { fail(session, "تعذر تجهيز البيانات للكتابة."); return }
        let message = NFCNDEFMessage(records: payloads)
        guard message.length <= capacity else { fail(session, "سعة الوسم \(capacity) بايت؛ تحتاج الرسالة \(message.length) بايت. اختر وسمًا أكبر."); return }
        status = "جارٍ الكتابة ثم التحقق"; session.alertMessage = "أبقِ الوسم ثابتًا حتى ينتهي التحقق."
        tag.writeNDEF(message) { [weak self] error in
            DispatchQueue.main.async {
                guard let self, self.session === session, !self.finished else { return }
                if let error { self.fail(session, "تعذرت الكتابة وقد تكون البيانات جزئية. أعد قراءة الوسم. " + error.localizedDescription); return }
                tag.readNDEF { [weak self] verified, error in
                    DispatchQueue.main.async {
                        guard let self, self.session === session, !self.finished else { return }
                        guard error == nil, let verified, Self.records(verified) == records else {
                            self.fail(session, "نُفذت الكتابة لكن لم نتمكن من تأكيد مطابقة البيانات. أعد قراءة الوسم قبل استخدامه."); return
                        }
                        self.writeSucceeded = true; self.finish(session, "تمت الكتابة والتحقق من تطابق البيانات.")
                    }
                }
            }
        }
    }
    private static func records(_ message: NFCNDEFMessage) -> [TagRecord] {
        message.records.map { TagRecord(tnf: $0.typeNameFormat.rawValue, type: $0.type, identifier: $0.identifier, payload: $0.payload) }
    }
    private func fail(_ session: NFCNDEFReaderSession, _ message: String) {
        finished = true; errorMessage = message; status = "لم تكتمل العملية"; session.invalidate(errorMessage: message)
    }
    private func finish(_ session: NFCNDEFReaderSession, _ message: String) {
        finished = true; status = message; session.alertMessage = message; session.invalidate()
    }
}

extension NFCService: NFCTagReaderSessionDelegate {
    func scan() {
        guard !busy else { return }
        guard NFCTagReaderSession.readingAvailable else {
            errorMessage = "قراءة NFC غير متاحة. تحقق من صلاحية NFC في النسخة المثبتة."; return
        }
        guard let next = NFCTagReaderSession(pollingOption: [.iso14443, .iso15693], delegate: self, queue: .main) else {
            errorMessage = "تعذر بدء فحص البطاقة. أغلق أي جلسة NFC أخرى وأعد المحاولة."; return
        }
        scanned = nil; errorMessage = nil; detectedCard = nil; pendingWrite = nil
        finished = false; handlingTag = false; writeSucceeded = false; busy = true
        tagSession = next; status = "قرّب البطاقة من أعلى ظهر الآيفون وأبقها ثابتة"
        next.alertMessage = status; next.begin()
    }

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        guard tagSession === session, !finished else { return }
        status = "جارٍ البحث عن البطاقة"
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        guard tagSession === session else { return }
        if !finished {
            if let error = error as? NFCReaderError, error.code == .readerSessionInvalidationErrorUserCanceled {
                status = "أُلغي الفحص"
            } else if var card = detectedCard {
                card.inspection?.detail = "تم التعرف على الشريحة، لكن الاتصال انتهى قبل اكتمال فحص المحتوى. قرّب البطاقة وأعد الفحص."
                scanned = card; status = "تم التعرف على الشريحة؛ الفحص جزئي"
            } else {
                errorMessage = "لم تُكتشف بطاقة خلال الجلسة. ضع بطاقة واحدة قرب أعلى ظهر الآيفون وأعد المحاولة.\n" + error.localizedDescription
                status = "لم تُكتشف بطاقة"
            }
        }
        finished = true; tagSession = nil; detectedCard = nil; handlingTag = false; busy = false
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard tagSession === session, !finished, !handlingTag else { return }
        guard tags.count == 1, let tag = tags.first else {
            session.alertMessage = "أبعد البطاقات الأخرى واترك بطاقة واحدة فقط."
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self, self.tagSession === session, !self.finished else { return }
                session.restartPolling()
            }
            return
        }
        let ndefTag: NFCNDEFTag
        let info: TagInspection
        switch tag {
        case .miFare(let mifare):
            ndefTag = mifare
            let family: String
            switch mifare.mifareFamily {
            case .ultralight: family = "MIFARE Ultralight / NTAG"
            case .desfire: family = "MIFARE DESFire"
            case .plus: family = "MIFARE Plus"
            case .unknown: family = "MIFARE · طراز غير محدد"
            @unknown default: family = "MIFARE · طراز غير محدد"
            }
            info = TagInspection(technology: "ISO 14443 · Type A", family: family, identifier: Self.hex(mifare.identifier))
        case .iso15693(let vicinity):
            ndefTag = vicinity
            info = TagInspection(technology: "ISO 15693 · NFC-V", family: "ISO 15693", identifier: Self.hex(vicinity.identifier))
        case .iso7816(let iso):
            ndefTag = iso
            info = TagInspection(technology: "ISO 7816 · ISO 14443-4", family: "ISO 7816", identifier: Self.hex(iso.identifier))
        case .feliCa(let felica):
            ndefTag = felica
            info = TagInspection(technology: "FeliCa · NFC-F", family: "FeliCa", identifier: Self.hex(felica.currentIDm))
        @unknown default:
            finished = true; session.invalidate(errorMessage: "أعاد النظام نوع بطاقة غير معروف لهذا الإصدار."); return
        }
        handlingTag = true
        var card = SavedCard(title: info.family, source: "فحص شريحة NFC")
        card.inspection = info; detectedCard = card
        status = "تم اكتشاف الشريحة؛ جارٍ قراءة معلوماتها"; session.alertMessage = status
        session.connect(to: tag) { [weak self] error in
            DispatchQueue.main.async {
                guard let self, self.tagSession === session, !self.finished else { return }
                if let error {
                    self.completeInspection(session, detail: "اكتُشفت الشريحة وتعذر الاتصال لقراءة محتواها. أعد الفحص. " + error.localizedDescription)
                    return
                }
                if case .miFare(let mifare) = tag, mifare.mifareFamily == .ultralight {
                    // Read-only product information. No authentication, memory writes or access-key commands.
                    mifare.sendMiFareCommand(commandPacket: Data([0x60])) { [weak self] response, error in
                        DispatchQueue.main.async {
                            guard let self, self.tagSession === session, !self.finished else { return }
                            if error == nil, response.count == 8 {
                                self.detectedCard?.inspection?.applyUltralightVersion(response)
                                if let name = self.detectedCard?.inspection?.family { self.detectedCard?.title = name }
                            }
                            self.inspectNDEF(ndefTag, session: session)
                        }
                    }
                } else { self.inspectNDEF(ndefTag, session: session) }
            }
        }
    }

    private func inspectNDEF(_ tag: NFCNDEFTag, session: NFCTagReaderSession) {
        guard tagSession === session, !finished else { return }
        status = "جارٍ فحص بيانات NDEF"; session.alertMessage = status
        tag.queryNDEFStatus { [weak self] access, capacity, error in
            DispatchQueue.main.async {
                guard let self, self.tagSession === session, !self.finished else { return }
                if let error {
                    self.completeInspection(session, detail: "قُرئت معلومات الشريحة، وتعذر تحديد حالة NDEF. " + error.localizedDescription)
                    return
                }
                switch access {
                case .notSupported:
                    self.detectedCard?.inspection?.ndefStatus = "غير متاح"
                    self.completeInspection(session, detail: "تم التعرف على البطاقة. لا تتوفر رسالة NDEF عبر هذه الواجهة؛ لا يعني ذلك أن ذاكرة البطاقة فارغة.")
                    return
                case .readOnly: self.detectedCard?.inspection?.ndefStatus = "للقراءة فقط"
                case .readWrite: self.detectedCard?.inspection?.ndefStatus = "للقراءة والكتابة"
                @unknown default:
                    self.completeInspection(session, detail: "قُرئت معلومات الشريحة، لكن النظام أعاد حالة NDEF غير معروفة."); return
                }
                self.detectedCard?.capacity = max(0, capacity)
                self.detectedCard?.sourceWritable = access == .readWrite
                tag.readNDEF { [weak self] message, error in
                    DispatchQueue.main.async {
                        guard let self, self.tagSession === session, !self.finished else { return }
                        if let error {
                            self.completeInspection(session, detail: "قُرئت معلومات الشريحة؛ تعذرت قراءة رسالة NDEF. هذا لا يثبت أن البطاقة محمية. " + error.localizedDescription)
                            return
                        }
                        if let message, !message.records.isEmpty {
                            let records = Self.records(message)
                            var candidate = self.detectedCard
                            candidate?.records = records
                            do { try candidate?.validate() }
                            catch { self.completeInspection(session, detail: "قُرئت معلومات الشريحة، لكن رسالة NDEF تجاوزت حدود البيانات المدعومة."); return }
                            self.detectedCard = candidate
                            self.completeInspection(session, detail: "قُرئت معلومات الشريحة ورسالة NDEF. راجع البيانات واحفظها.")
                        } else {
                            self.completeInspection(session, detail: "قُرئت معلومات الشريحة. رسالة NDEF فارغة؛ هذا لا يصف باقي ذاكرة البطاقة.")
                        }
                    }
                }
            }
        }
    }

    private func completeInspection(_ session: NFCTagReaderSession, detail: String) {
        guard tagSession === session, !finished, var card = detectedCard else { return }
        card.inspection?.detail = String(detail.prefix(2048))
        do { try card.validate() }
        catch {
            finished = true; errorMessage = error.localizedDescription
            session.invalidate(errorMessage: "تعذر تجهيز نتيجة الفحص."); return
        }
        finished = true; scanned = card
        status = card.records.isEmpty ? "تمت قراءة معلومات الشريحة" : "تمت قراءة الشريحة وبيانات NDEF"
        session.alertMessage = status; session.invalidate()
    }

    private static func hex(_ data: Data) -> String {
        data.map { String(format: "%02X", $0) }.joined(separator: ":")
    }
}
