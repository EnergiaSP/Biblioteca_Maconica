import Foundation
import UIKit

@MainActor
enum UserDataPersistenceService {
    private static let chavesExatas: Set<String> = [
        "appAtivado",
        "notificacaoDiariaAtiva",
        "notificacaoDiariaHora",
        "notificacaoDiariaMinuto",
        "vozLeituraGenero",
        "velocidadeLeitura",
        "tamanhoTextoLeitura",
        "espacamentoTextoLeitura",
        "temaApp",
        "temaLeitura",
        "modoLeituraSemDistracoes",
        "modoLeituraLivrosContinuo",
        "analiseIAAtiva",
        "obrasNotificacaoIDs",
        "biblioteca_obra_selecionada",
        "nomeUsuarioPDFPremium",
        "comentarios_datas_com_conteudo",
        "leituras_favoritas",
        "leituras_concluidas",
        "leituras_recentes",
        "edicoes_textos_diarios",
        "backup_solicitacoes_obras",
        "backup_fontes_oficiais"
    ]

    private static let prefixosProtegidos = [
        "comentario_",
        "reflexao_",
        "destaques_",
        "analise_ia_",
        "leituras_favoritas_",
        "leituras_concluidas_",
        "leituras_recentes_",
        "edicoes_textos_diarios_"
    ]

    private static var observador: NSObjectProtocol?
    private static var observadorICloud: NSObjectProtocol?
    private static var observadorAtivacao: NSObjectProtocol?
    private static var observadorSegundoPlano: NSObjectProtocol?
    private static var backupPendente: DispatchWorkItem?
    private static var snapshot = UserBackupSnapshot()
    private static var ultimoConteudoSalvo: [String: Any]?
    private static var restaurando = false
    private static let disco = DispatchQueue(label: "biblioteca.backup.local", qos: .utility)
    private static let nuvem = DispatchQueue(label: "biblioteca.backup.cloud", qos: .utility)

    static func iniciar() {
        guard observador == nil else { return }
        if let url = try? BackupFiles.localURL(),
           let data = try? Data(contentsOf: url),
           let saved = UserBackupSnapshot.decode(data) {
            snapshot = saved
            let current = dadosAtuaisProtegidos()
            for (key, value) in saved.values where deveProteger(key) && current[key] == nil {
                UserDefaults.standard.set(value, forKey: key)
            }
        }
        observador = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { _ in Task { @MainActor in agendarBackup() } }
        observadorICloud = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default, queue: .main
        ) { _ in Task { @MainActor in carregarNuvem() } }
        observadorAtivacao = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { _ in Task { @MainActor in carregarNuvem() } }
        observadorSegundoPlano = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
        ) { _ in Task { @MainActor in salvarBackup() } }
        salvarBackup()
        carregarNuvem()
    }

    static func salvarBackup() {
        guard !restaurando else { return }
        let current = dadosAtuaisProtegidos()
        guard !conteudoIgual(current, ultimoConteudoSalvo) else { return }
        capturarAlteracoesLocais(current)
        ultimoConteudoSalvo = current
        persistir(snapshot)
    }

    static func conteudoIgual(_ atual: [String: Any], _ anterior: [String: Any]?) -> Bool {
        guard let anterior else { return false }
        return NSDictionary(dictionary: atual).isEqual(to: anterior)
    }

    private static func persistir(_ value: UserBackupSnapshot) {
        disco.async {
            do { try BackupFiles.writeLocal(value) }
            catch { Task { @MainActor in ultimoConteudoSalvo = nil } }
        }
        nuvem.async {
            var combined = value
            for remote in BackupFiles.cloudSnapshots() { combined.merge(remote) }
            BackupFiles.publish(combined)
            Task { @MainActor in receber(combined) }
        }
    }

    private static func carregarNuvem() {
        nuvem.async {
            NSUbiquitousKeyValueStore.default.synchronize()
            let remote = BackupFiles.cloudSnapshots()
            Task { @MainActor in
                for value in remote { receber(value) }
            }
        }
    }

    private static func receber(_ remote: UserBackupSnapshot) {
        // Capture local edits made during the cloud read before merging remote keys.
        capturarAlteracoesLocais(dadosAtuaisProtegidos())
        let before = snapshot
        snapshot.merge(remote)
        guard snapshot != before else { return }
        let current = dadosAtuaisProtegidos()
        let restored = snapshot.values.filter { deveProteger($0.key) }
        if !conteudoIgual(current, restored) {
            disco.async { try? BackupFiles.preserveBeforeRestore(before) }
        }
        restaurando = true
        for key in Set(current.keys).union(restored.keys) {
            if let value = restored[key] { UserDefaults.standard.set(value, forKey: key) }
            else { UserDefaults.standard.removeObject(forKey: key) }
        }
        restaurando = false
        ultimoConteudoSalvo = restored
        NotificationCenter.default.post(name: .progressoLeituraSincronizado, object: nil)
        persistir(snapshot)
    }

    private static func agendarBackup() {
        backupPendente?.cancel()
        let work = DispatchWorkItem { salvarBackup() }
        backupPendente = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: work)
    }

    private static func dadosAtuaisProtegidos() -> [String: Any] {
        guard let domain = Bundle.main.bundleIdentifier else { return [:] }
        return (UserDefaults.standard.persistentDomain(forName: domain) ?? [:]).filter {
            deveProteger($0.key) && PropertyListSerialization.propertyList($0.value, isValidFor: .binary)
        }
    }

    private static func deveProteger(_ chave: String) -> Bool {
        chavesExatas.contains(chave) || prefixosProtegidos.contains { chave.hasPrefix($0) }
    }

    private static func capturarAlteracoesLocais(_ current: [String: Any]) {
        let managed = Set(snapshot.records.values.map(\.key).filter { deveProteger($0) }).union(current.keys)
        snapshot.capture(current, managedKeys: managed)
    }
}

// Cloud container discovery, coordination and disk writes never run on the UI thread.
private enum BackupFiles {
    private static let file = "user-data-backup.plist"
    private static let cloudKey = "breviario_user_data_backup_v3"
    private static let legacyKey = "breviario_user_data_backup_v2"

    static func localURL() throws -> URL {
        let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                   appropriateFor: nil, create: true)
            .appendingPathComponent("BreviarioMaconicoXXI", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(file)
    }

    private static func cloudURL() -> URL? {
        guard let root = FileManager.default.url(forUbiquityContainerIdentifier: nil) else { return nil }
        let directory = root.appendingPathComponent("Documents/BreviarioMaconicoXXI", isDirectory: true)
        guard (try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)) != nil else { return nil }
        return directory.appendingPathComponent(file)
    }

    static func cloudSnapshots() -> [UserBackupSnapshot] {
        let store = NSUbiquitousKeyValueStore.default
        var values = [store.data(forKey: cloudKey) ?? store.data(forKey: legacyKey)]
            .compactMap { $0 }.compactMap(UserBackupSnapshot.decode)
        if let url = cloudURL(), FileManager.default.fileExists(atPath: url.path) {
            var error: NSError?
            NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &error) { coordinated in
                if let data = try? Data(contentsOf: coordinated), let value = UserBackupSnapshot.decode(data) {
                    values.append(value)
                }
            }
        }
        return values
    }

    static func publish(_ snapshot: UserBackupSnapshot) {
        guard let data = try? snapshot.encoded() else { return }
        let store = NSUbiquitousKeyValueStore.default
        if let existing = store.data(forKey: cloudKey), UserBackupSnapshot.decode(existing) == nil { return }
        let otherValues = store.dictionaryRepresentation.filter { $0.key != cloudKey }
        let otherBytes = (try? PropertyListSerialization.data(fromPropertyList: otherValues, format: .binary, options: 0).count) ?? 900_000
        // The quota covers the whole store, including the legacy backup kept for rollback.
        if data.count + otherBytes <= 900_000 {
            store.set(data, forKey: cloudKey)
            store.synchronize()
        }
        guard let url = cloudURL() else { return }
        var error: NSError?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forMerging, error: &error) { coordinated in
            var combined = snapshot
            if let data = try? Data(contentsOf: coordinated) {
                guard let remote = UserBackupSnapshot.decode(data) else { return }
                combined.merge(remote)
            }
            if let data = try? combined.encoded() { try? data.write(to: coordinated, options: .atomic) }
        }
    }

    static func preserveBeforeRestore(_ snapshot: UserBackupSnapshot) throws {
        let folder = try localURL().deletingLastPathComponent().appendingPathComponent("RestoreHistory", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try snapshot.encoded().write(to: folder.appendingPathComponent(UUID().uuidString + ".plist"), options: .atomic)
    }

    static func writeLocal(_ snapshot: UserBackupSnapshot) throws {
        let url = try localURL()
        if let existing = try? Data(contentsOf: url), UserBackupSnapshot.decode(existing) == nil {
            let quarantine = url.deletingLastPathComponent().appendingPathComponent("backup-unreadable-\(UUID().uuidString).plist")
            try existing.write(to: quarantine, options: .atomic)
        }
        try snapshot.encoded().write(to: url, options: .atomic)
    }
}
