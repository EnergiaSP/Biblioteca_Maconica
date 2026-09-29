import Foundation
import CryptoKit

struct BibliotecaPacoteOfflineEstado: Identifiable, Hashable {
    let pacote: BibliotecaRAGPacote
    let instalado: Bool
    let tamanhoLocalBytes: Int
    let origemDisponivel: Bool
    /// Installed from an earlier catalog version: the recorded sha256 differs from the catalog's.
    var desatualizado = false

    var id: String { pacote.id }

    var titulo: String {
        pacote.obras.first?.titulo ?? pacote.titulo
    }

    /// Text quality of the package's works (qualidade_texto_v1.json); nil when no page was rated.
    var rotuloQualidade: String? {
        guard let configuracao = QualidadeTexto.Configuracao.compartilhada else { return nil }
        let contagens = pacote.obras.compactMap(\.qualidadeTexto)
        let total = QualidadeTextoObra(avaliadas: contagens.reduce(0) { $0 + $1.avaliadas },
                                       ruidosas: contagens.reduce(0) { $0 + $1.ruidosas },
                                       ilegiveis: contagens.reduce(0) { $0 + $1.ilegiveis })
        let nivel = QualidadeTexto.nivelObra(total, configuracao: configuracao)
        return nivel == "semAvaliacao" ? nil : configuracao.rotulos.obra[nivel]
    }

    var detalhe: String {
        let paginas = pacote.estatisticas.paginas
        let tamanho = Self.formatarBytes(instalado ? tamanhoLocalBytes : pacote.tamanhoBytes)
        return "\(paginas) páginas • \(tamanho)"
    }

    static func formatarBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

final class BibliotecaOfflinePackageService {
    enum Erro: LocalizedError {
        case origemIndisponivel(String)
        case downloadInvalido(String)
        case hashInvalido(String)

        var errorDescription: String? {
            switch self {
            case .origemIndisponivel(let titulo):
                "Pacote indisponivel para download: \(titulo)"
            case .downloadInvalido(let titulo):
                "Download invalido para: \(titulo)"
            case .hashInvalido(let titulo):
                "Validacao de integridade falhou para: \(titulo)"
            }
        }
    }

    private let catalogo: BibliotecaRAGCatalogService
    private let fileManager: FileManager

    init(catalogo: BibliotecaRAGCatalogService? = nil, fileManager: FileManager = .default) throws {
        guard let catalogo = catalogo ?? (try? BibliotecaRAGCatalogService()) else {
            throw BibliotecaRAGCatalogService.Erro.catalogoNaoEncontrado
        }

        self.catalogo = catalogo
        self.fileManager = fileManager
    }

    func estados(area: BibliotecaArea? = nil) -> [BibliotecaPacoteOfflineEstado] {
        catalogo.pacotes
            .filter { area == nil || $0.area == area }
            .map(estado)
            .sorted { primeiro, segundo in
                if primeiro.pacote.area != segundo.pacote.area {
                    return primeiro.pacote.area.titulo < segundo.pacote.area.titulo
                }
                return primeiro.titulo.localizedCaseInsensitiveCompare(segundo.titulo) == .orderedAscending
            }
    }

    func instalarPacote(_ pacote: BibliotecaRAGPacote) async throws {
        let destino = Self.urlLocal(arquivo: pacote.arquivo, fileManager: fileManager)
        try fileManager.createDirectory(at: destino.deletingLastPathComponent(), withIntermediateDirectories: true)

        // Download beside the package and replace only after validation, as on Android:
        // a failed update keeps the version already installed.
        let novo = destino.appendingPathExtension("download")
        try? fileManager.removeItem(at: novo)

        if let origem = catalogo.urlOrigemPacote(pacote) {
            try fileManager.copyItem(at: origem, to: novo)
        } else if let remota = catalogo.urlRemotaPacote(pacote) {
            let (temporario, resposta) = try await URLSession.shared.download(from: remota)
            guard let http = resposta as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                throw Erro.downloadInvalido(pacote.titulo)
            }
            try fileManager.moveItem(at: temporario, to: novo)
        } else {
            throw Erro.origemIndisponivel(pacote.titulo)
        }

        try validarPacote(pacote, em: novo)
        if fileManager.fileExists(atPath: destino.path) {
            _ = try fileManager.replaceItemAt(destino, withItemAt: novo)
        } else {
            try fileManager.moveItem(at: novo, to: destino)
        }
        if let sha256 = pacote.sha256, sha256.isEmpty == false {
            try Data(sha256.utf8).write(to: Self.urlVersao(arquivo: pacote.arquivo, fileManager: fileManager), options: .atomic)
        }
    }

    func removerPacote(_ pacote: BibliotecaRAGPacote) throws {
        let destino = Self.urlLocal(arquivo: pacote.arquivo, fileManager: fileManager)
        guard fileManager.fileExists(atPath: destino.path) else {
            return
        }

        try fileManager.removeItem(at: destino)
        try? fileManager.removeItem(at: Self.urlVersao(arquivo: pacote.arquivo, fileManager: fileManager))
    }

    func instalarTodos(
        area: BibliotecaArea? = nil,
        progresso: @escaping @Sendable (_ concluido: Int, _ total: Int, _ titulo: String) -> Void
    ) async throws {
        let pacotes = catalogo.pacotes.filter { area == nil || $0.area == area }
        let total = pacotes.count

        for (indice, pacote) in pacotes.enumerated() {
            if Self.urlLocalExiste(arquivo: pacote.arquivo, fileManager: fileManager) == false || desatualizado(pacote) {
                try await instalarPacote(pacote)
            }
            progresso(indice + 1, total, pacote.obras.first?.titulo ?? pacote.titulo)
        }
    }

    private func estado(_ pacote: BibliotecaRAGPacote) -> BibliotecaPacoteOfflineEstado {
        let urlLocal = Self.urlLocal(arquivo: pacote.arquivo, fileManager: fileManager)
        let instalado = fileManager.fileExists(atPath: urlLocal.path)
        let tamanhoLocal = (try? fileManager.attributesOfItem(atPath: urlLocal.path)[.size] as? Int) ?? 0

        return BibliotecaPacoteOfflineEstado(
            pacote: pacote,
            instalado: instalado,
            tamanhoLocalBytes: tamanhoLocal,
            origemDisponivel: catalogo.urlOrigemPacote(pacote) != nil || catalogo.urlRemotaPacote(pacote) != nil,
            desatualizado: instalado && desatualizado(pacote)
        )
    }

    /// Same rule as Android: `<arquivo>.sha256` records the version installed; missing counts as outdated.
    func desatualizado(_ pacote: BibliotecaRAGPacote) -> Bool {
        guard let esperado = pacote.sha256, esperado.isEmpty == false else {
            return false
        }
        let gravado = (try? String(contentsOf: Self.urlVersao(arquivo: pacote.arquivo, fileManager: fileManager), encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return gravado?.lowercased() != esperado.lowercased()
    }

    private func validarPacote(_ pacote: BibliotecaRAGPacote, em url: URL) throws {
        let tamanho = (try? fileManager.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        guard tamanho == pacote.tamanhoBytes else {
            try? fileManager.removeItem(at: url)
            throw Erro.downloadInvalido(pacote.titulo)
        }

        if let sha256 = pacote.sha256, sha256.isEmpty == false {
            let hash = try Self.sha256(url)
            guard hash.lowercased() == sha256.lowercased() else {
                try? fileManager.removeItem(at: url)
                throw Erro.hashInvalido(pacote.titulo)
            }
        }
    }

    private static func sha256(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer {
            try? handle.close()
        }

        var hasher = SHA256()
        while autoreleasepool(invoking: {
            let data = handle.readData(ofLength: 1024 * 1024)
            guard data.isEmpty == false else {
                return false
            }
            hasher.update(data: data)
            return true
        }) {}

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func urlLocal(arquivo: String, fileManager: FileManager) -> URL {
        BibliotecaRAGCatalogService.raizPacotesLocal(fileManager: fileManager)
            .appendingPathComponent(arquivo)
    }

    private static func urlVersao(arquivo: String, fileManager: FileManager) -> URL {
        urlLocal(arquivo: arquivo + ".sha256", fileManager: fileManager)
    }

    private static func urlLocalExiste(arquivo: String, fileManager: FileManager) -> Bool {
        fileManager.fileExists(atPath: urlLocal(arquivo: arquivo, fileManager: fileManager).path)
    }
}
