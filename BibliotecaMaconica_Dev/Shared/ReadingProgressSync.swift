import Foundation
import WatchConnectivity

struct ReadingProgressEvent: Codable, Equatable, Sendable {
    let workID: String
    let date: String
    let read: Bool
    let timestamp: Int64
    let eventID: String

    var key: String { "\(workID)|\(date)" }
    var isValid: Bool {
        Self.valid(work: workID, date: date) && timestamp >= 0 && timestamp < Int64.max &&
        !eventID.isEmpty && eventID.count <= 128
    }
    var message: [String: Any] {
        ["tipo": "progresso", "obraID": workID, "data": date, "lido": read,
         "atualizadoEm": timestamp, "eventoID": eventID]
    }

    static func parse(_ message: [String: Any]) -> Self? {
        guard message["tipo"] as? String == "progresso",
              let work = message["obraID"] as? String,
              let date = message["data"] as? String,
              let read = message["lido"] as? Bool,
              valid(work: work, date: date) else { return nil }
        let timestamp = (message["atualizadoEm"] as? NSNumber)?.int64Value ?? 0
        let id = message["eventoID"] as? String ?? "legacy"
        guard timestamp >= 0, timestamp < Int64.max, !id.isEmpty, id.count <= 128 else { return nil }
        return Self(workID: work, date: date, read: read, timestamp: timestamp, eventID: id)
    }

    static func valid(work: String, date: String) -> Bool {
        guard !work.isEmpty, work.count <= 200, !work.contains("|"),
              date.utf8.count == 5,
              date.utf8.enumerated().allSatisfy({ $0.offset == 2 ? $0.element == 47 : (48...57).contains($0.element) }) else { return false }
        let parts = date.split(separator: "/")
        guard parts.count == 2, let day = Int(parts[0]), let month = Int(parts[1]),
              (1...12).contains(month) else { return false }
        return (1...[31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][month - 1]).contains(day)
    }

    func isNewer(than other: Self) -> Bool {
        timestamp != other.timestamp ? timestamp > other.timestamp : eventID > other.eventID
    }
}

/// Review cards on the watch (relogio_revisao_v1.json): the phone sends today's session with its labels,
/// the watch sends back each grade. Same messages as the Wear OS Data Layer on Android.
struct CartaoRelogio: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let frente: String
    let verso: String
    let fonte: String
}

struct BaralhoRelogio: Codable, Equatable, Sendable {
    let hoje: String
    let total: Int
    let cartoes: [CartaoRelogio]
    let rotulos: [String: String]

    var message: [String: Any] {
        let dados = (try? JSONEncoder().encode(self)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
        return ["tipo": "cartoesRevisao", "baralho": dados]
    }

    static func parse(_ message: [String: Any]) -> Self? {
        guard message["tipo"] as? String == "cartoesRevisao", let texto = message["baralho"] as? String else { return nil }
        return try? JSONDecoder().decode(Self.self, from: Data(texto.utf8))
    }

    func rotulo(_ chave: String, _ valores: [String: String] = [:]) -> String {
        valores.reduce(rotulos[chave] ?? chave) { $0.replacingOccurrences(of: "{\($1.key)}", with: $1.value) }
    }
}

struct RespostaRelogio: Codable, Equatable, Sendable {
    let id: String
    let nota: String
    let eventoID: String

    var message: [String: Any] { ["tipo": "respostaRevisao", "id": id, "nota": nota, "eventoID": eventoID] }

    static func parse(_ message: [String: Any]) -> Self? {
        guard message["tipo"] as? String == "respostaRevisao", let id = message["id"] as? String,
              let nota = message["nota"] as? String, ["errei", "dificil", "acertei"].contains(nota),
              let evento = message["eventoID"] as? String, !evento.isEmpty else { return nil }
        return Self(id: id, nota: nota, eventoID: evento)
    }
}

struct ReadingProgressLedger: Codable, Sendable {
    private(set) var latest: [String: ReadingProgressEvent] = [:]
    private(set) var pending: [String: ReadingProgressEvent] = [:]

    mutating func edit(work: String, date: String, read: Bool, now: Int64,
                       id: String = UUID().uuidString) -> ReadingProgressEvent? {
        guard ReadingProgressEvent.valid(work: work, date: date) else { return nil }
        let previous = latest.values.map(\.timestamp).max() ?? 0
        guard previous < Int64.max - 1 else { return nil }
        let event = ReadingProgressEvent(workID: work, date: date, read: read,
                                         timestamp: max(now, previous + 1), eventID: id)
        guard event.isValid else { return nil }
        latest[event.key] = event
        pending[event.key] = event
        return event
    }

    mutating func receive(_ event: ReadingProgressEvent) -> Bool {
        guard event.isValid else { return false }
        if let old = latest[event.key], !event.isNewer(than: old) { return false }
        latest[event.key] = event
        pending.removeValue(forKey: event.key)
        return true
    }

    mutating func delivered(_ event: ReadingProgressEvent) {
        // A delayed acknowledgement must not remove a newer offline edit.
        if pending[event.key] == event { pending.removeValue(forKey: event.key) }
    }
}

final class ReadingProgressSyncTransport: NSObject, WCSessionDelegate, @unchecked Sendable {
    private let defaults: UserDefaults
    private let storageKey = "reading_progress_sync_v1"
    private let lock = NSLock()
    private var ledger: ReadingProgressLedger
    @MainActor private var onReceive: ((ReadingProgressEvent) -> Void)?
    @MainActor private var onBaralho: ((BaralhoRelogio) -> Void)?
    @MainActor private var onResposta: ((RespostaRelogio) -> Void)?
    private var respostasRecebidas: [String] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        ledger = defaults.data(forKey: storageKey)
            .flatMap { try? JSONDecoder().decode(ReadingProgressLedger.self, from: $0) } ?? ReadingProgressLedger()
        super.init()
    }

    @discardableResult
    func start(onReceive: @escaping @MainActor (ReadingProgressEvent) -> Void) -> Task<Void, Never>? {
        guard WCSession.isSupported() else { return nil }
        return Task { @MainActor in
            self.onReceive = onReceive
            let session = WCSession.default
            session.delegate = self
            if session.activationState != .activated { session.activate() }
            else { self.flush() }
        }
    }

    /// Review cards: the phone keeps the latest session as the application context; grades are queued.
    @MainActor func observarRevisao(baralho: ((BaralhoRelogio) -> Void)? = nil, resposta: ((RespostaRelogio) -> Void)? = nil) {
        if let baralho { onBaralho = baralho }
        if let resposta { onResposta = resposta }
        if WCSession.isSupported(), WCSession.default.activationState == .activated,
           let atual = BaralhoRelogio.parse(WCSession.default.receivedApplicationContext) { onBaralho?(atual) }
    }

    func enviarBaralho(_ baralho: BaralhoRelogio) {
        guard WCSession.isSupported() else { return }
        Task { @MainActor in
            let session = WCSession.default
            guard session.activationState == .activated else { return }
            #if os(iOS)
            guard session.isPaired, session.isWatchAppInstalled else { return }
            #endif
            try? session.updateApplicationContext(baralho.message)
        }
    }

    func enviarResposta(_ resposta: RespostaRelogio) {
        guard WCSession.isSupported() else { return }
        Task { @MainActor in
            guard WCSession.default.activationState == .activated else { return }
            WCSession.default.transferUserInfo(resposta.message)
        }
    }

    func enviar(obraID: String, data: String, lido: Bool) {
        let event = lock.withLock {
            let event = ledger.edit(work: obraID, date: data, read: lido,
                                    now: Int64(Date().timeIntervalSince1970 * 1_000))
            persistLocked()
            return event
        }
        guard let event, WCSession.isSupported() else { return }
        Task { @MainActor in
            self.flush()
            if WCSession.default.isReachable {
                WCSession.default.sendMessage(event.message, replyHandler: nil, errorHandler: { _ in })
            }
        }
    }

    private func persistLocked() {
        if let data = try? JSONEncoder().encode(ledger) { defaults.set(data, forKey: storageKey) }
    }

    @MainActor private func flush() {
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        #if os(iOS)
        guard session.isPaired, session.isWatchAppInstalled else { return }
        #else
        guard session.isCompanionAppInstalled else { return }
        #endif
        let pending = lock.withLock { Array(ledger.pending.values) }
        let queued = Set(session.outstandingUserInfoTransfers.compactMap {
            ReadingProgressEvent.parse($0.userInfo)?.eventID
        })
        for event in pending where !queued.contains(event.eventID) {
            session.transferUserInfo(event.message)
        }
    }

    private func apply(_ message: [String: Any]) {
        if let baralho = BaralhoRelogio.parse(message) {
            Task { @MainActor in self.onBaralho?(baralho) }
            return
        }
        if let resposta = RespostaRelogio.parse(message) {
            // A grade delivered twice (same event) is applied once.
            let nova = lock.withLock {
                guard !respostasRecebidas.contains(resposta.eventoID) else { return false }
                respostasRecebidas = Array((respostasRecebidas + [resposta.eventoID]).suffix(200))
                return true
            }
            if nova { Task { @MainActor in self.onResposta?(resposta) } }
            return
        }
        guard let event = ReadingProgressEvent.parse(message) else { return }
        Task { @MainActor in
            let accepted = self.lock.withLock {
                guard self.ledger.receive(event) else { return false }
                self.persistLocked()
                return true
            }
            // UI observers may enqueue another edit; never invoke them under the ledger lock.
            if accepted { self.onReceive?(event) }
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) { apply(message) }
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) { apply(userInfo) }
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) { apply(applicationContext) }

    func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: Error?) {
        guard error == nil, let event = ReadingProgressEvent.parse(userInfoTransfer.userInfo) else { return }
        lock.withLock {
            ledger.delivered(event)
            persistLocked()
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        guard activationState == .activated, error == nil else { return }
        apply(session.receivedApplicationContext)
        Task { @MainActor in self.flush() }
    }
    func sessionReachabilityDidChange(_ session: WCSession) { Task { @MainActor in self.flush() } }
    #if os(iOS)
    func sessionWatchStateDidChange(_ session: WCSession) { Task { @MainActor in self.flush() } }
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    #endif
}
