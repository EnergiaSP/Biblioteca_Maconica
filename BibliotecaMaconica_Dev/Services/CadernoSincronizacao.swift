import Foundation

/// A place where the notebook file is kept for sync (iCloud Drive, or the app's own account).
protocol ProvedorCaderno: Sendable {
    var opcao: CadernoSincronizacao.Opcao { get }
    /// nil when there is no notebook there yet.
    func ler() async throws -> Data?
    func gravar(_ dados: Data) async throws
}

/// Sync of the study notebook through the chosen service: read the remote notebook, merge it with the
/// local one without losing anything, apply the result here and write it back. A remote file that
/// cannot be read (a newer version of the app) is never overwritten. Same steps as Android `NotebookSync`.
enum CadernoSincronizacao {
    enum Opcao: String, CaseIterable, Identifiable {
        case nenhuma, icloud, contaPropria
        var id: String { rawValue }
    }

    enum Falha: LocalizedError {
        case indisponivel(String)
        case remotoIlegivel(String)

        var errorDescription: String? {
            switch self {
            case .indisponivel(let mensagem), .remotoIlegivel(let mensagem): mensagem
            }
        }
    }

    private static let chaveOpcao = "sincronizacaoCaderno"
    private static let chaveUltima = "sincronizacaoCadernoEm"

    static var opcaoEscolhida: Opcao {
        get { Opcao(rawValue: UserDefaults.standard.string(forKey: chaveOpcao) ?? "") ?? .nenhuma }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: chaveOpcao) }
    }

    static var ultimaSincronizacao: Date? {
        UserDefaults.standard.object(forKey: chaveUltima) as? Date
    }

    static func provedor(_ opcao: Opcao) -> ProvedorCaderno? {
        switch opcao {
        case .nenhuma: nil
        case .icloud: ProvedorICloud()
        case .contaPropria: ContaPropriaCaderno.provedor()
        }
    }

    /// Merges the remote notebook here and writes the result back; returns the merged notebook.
    @MainActor
    static func sincronizar(com provedor: ProvedorCaderno, configuracao: CadernoEstudo.Configuracao) async throws -> CadernoEstudo.Caderno {
        let remoto: CadernoEstudo.Caderno?
        if let dados = try await provedor.ler() {
            guard let caderno = CadernoEstudo.decodificar(dados, configuracao: configuracao) else {
                throw Falha.remotoIlegivel(configuracao.rotulo("remotoIlegivel"))
            }
            remoto = caderno
        } else {
            remoto = nil
        }
        let local = CadernoEstudo.coletar(configuracao: configuracao)
        let mesclado = CadernoEstudo.mesclar(local: local, importado: remoto ?? CadernoEstudo.vazio(configuracao),
                                             hoje: DossieSalvo.data(Date()), configuracao: configuracao)
        if mesclado != local { CadernoEstudo.aplicar(mesclado) }
        if mesclado != remoto { try await provedor.gravar(try CadernoEstudo.codificar(mesclado)) }
        UserDefaults.standard.set(Date(), forKey: chaveUltima)
        return mesclado
    }

    /// Automatic sync when the app comes back to the foreground; failures wait for the next time.
    @MainActor
    static func sincronizarSeEscolhido() async {
        guard let configuracao = CadernoEstudo.Configuracao.compartilhada, let provedor = provedor(opcaoEscolhida) else { return }
        _ = try? await sincronizar(com: provedor, configuracao: configuracao)
    }
}

/// The notebook in the app's iCloud Drive folder, next to the existing user data backup.
struct ProvedorICloud: ProvedorCaderno {
    let opcao = CadernoSincronizacao.Opcao.icloud
    private static let nomeArquivo = "caderno-biblioteca-maconica.json"

    private func arquivo() throws -> URL {
        guard let raiz = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
            throw CadernoSincronizacao.Falha.indisponivel(CadernoEstudo.Configuracao.compartilhada?.rotulo("semICloud")
                                                          ?? "iCloud indisponível.")
        }
        let pasta = raiz.appendingPathComponent("Documents/BreviarioMaconicoXXI", isDirectory: true)
        try FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)
        return pasta.appendingPathComponent(Self.nomeArquivo)
    }

    func ler() async throws -> Data? {
        try await Task.detached(priority: .utility) {
            let url = try arquivo()
            // A file kept only in the cloud is downloaded first (up to 20 s).
            if !FileManager.default.fileExists(atPath: url.path) {
                guard (try? FileManager.default.startDownloadingUbiquitousItem(at: url)) != nil else { return nil }
                for _ in 0..<40 where !FileManager.default.fileExists(atPath: url.path) {
                    try await Task.sleep(nanoseconds: 500_000_000)
                }
                guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            }
            var erro: NSError?
            var dados: Data?
            NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &erro) { dados = try? Data(contentsOf: $0) }
            if let erro { throw erro }
            return dados
        }.value
    }

    func gravar(_ dados: Data) async throws {
        try await Task.detached(priority: .utility) {
            let url = try arquivo()
            var erro: NSError?
            var falha: Error?
            NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &erro) { destino in
                do { try dados.write(to: destino, options: .atomic) } catch { falha = error }
            }
            if let erro { throw erro }
            if let falha { throw falha }
        }.value
    }
}
