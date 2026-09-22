import Foundation

final class BibliotecaRAGCatalogService {
    enum Erro: LocalizedError {
        case catalogoNaoEncontrado
        case pacoteNaoEncontrado(String)
        case urlRemotaInvalida(String)

        var errorDescription: String? {
            switch self {
            case .catalogoNaoEncontrado:
                "Catalogo RAG nao encontrado."
            case .pacoteNaoEncontrado(let arquivo):
                "Pacote RAG nao encontrado: \(arquivo)"
            case .urlRemotaInvalida(let arquivo):
                "URL remota invalida para o pacote: \(arquivo)"
            }
        }
    }

    private let catalogo: BibliotecaRAGCatalogo
    private let raizPacotes: URL?
    private let fileManager: FileManager
    private let obrasBloqueadas = Set([
        "breviario_maconico_rizzardo_da_camino"
    ])

    var pacotes: [BibliotecaRAGPacote] {
        pacotesPermitidos(catalogo.pacotes)
    }

    init(
        catalogoURL: URL? = Bundle.main.url(forResource: "rag_catalogo", withExtension: "json"),
        fileManager: FileManager = .default
    ) throws {
        self.fileManager = fileManager

        guard let catalogoURL else {
            throw Erro.catalogoNaoEncontrado
        }

        let dados = try Data(contentsOf: catalogoURL)
        catalogo = try JSONDecoder().decode(BibliotecaRAGCatalogo.self, from: dados)
        raizPacotes = Self.localizarRaizPacotes(catalogoURL: catalogoURL, catalogo: catalogo, fileManager: fileManager)
    }

    func buscar(
        termo: String,
        escopo: BibliotecaBuscaEscopo,
        area: BibliotecaArea?,
        obraID: String?,
        limite: Int = 80,
        offset: Int = 0,
        obrasExcluidas: Set<String> = [],
        filtro: BibliotecaFiltroMetadados = .init()
    ) throws -> [BibliotecaResultadoBusca] {
        let termoLimpo = termo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard termoLimpo.isEmpty == false else {
            return []
        }

        let pacotes = pacotesParaBusca(escopo: escopo, area: area, obraID: obraID)
        guard pacotes.isEmpty == false else {
            return []
        }

        var resultados: [BibliotecaResultadoBusca] = []
        let inicio = max(0, offset)
        let tamanho = max(1, limite)
        let limitePorPacote = tamanho + inicio

        for pacote in pacotes where !pacote.obraIDs.allSatisfy(obrasExcluidas.contains) {
            try Task.checkCancellation()
            guard let url = urlPacote(pacote) else {
                continue
            }

            try autoreleasepool {
                let banco = try BibliotecaSQLiteService(url: url, somenteLeitura: true)
                let encontrados = try banco.buscarResultadosBiblioteca(
                        termo: termoLimpo,
                        escopo: escopo,
                        area: area,
                        obraID: obraID,
                        limite: limitePorPacote,
                        obrasExcluidas: obrasExcluidas,
                        incluirNotas: false,
                        filtro: filtro
                      )

                resultados.append(contentsOf: encontrados)
            }
        }

        let selecionados = Array(resultados.sorted {
            if $0.ranking != $1.ranking { return $0.ranking < $1.ranking }
            if $0.obra.id != $1.obra.id { return $0.obra.id < $1.obra.id }
            if $0.item.pagina != $1.item.pagina { return ($0.item.pagina ?? 0) < ($1.item.pagina ?? 0) }
            return ($0.blocoID ?? $0.item.data) < ($1.blocoID ?? $1.item.data)
        }.dropFirst(inicio).prefix(tamanho))
        // Only hydrate notes for the requested page of results, not every candidate in the corpus.
        var notas: [String: [Int: [String]]] = [:]
        for (id, trechos) in Dictionary(grouping: selecionados, by: { $0.obra.id }) {
            try Task.checkCancellation()
            guard let pacote = pacotes.first(where: { $0.obraIDs.contains(id) }),
                  let url = urlPacote(pacote) else {
                throw Erro.pacoteNaoEncontrado(id)
            }
            let banco = try BibliotecaSQLiteService(url: url, somenteLeitura: true)
            let porPagina = try banco.carregarNotasPorPagina(obraID: id, paginas: Array(Set(trechos.compactMap { $0.item.pagina })))
            notas[id] = porPagina
        }
        return selecionados.map { hit in
            BibliotecaResultadoBusca(obra: hit.obra,
                item: hit.item.atualizado(rodape: notas[hit.obra.id]?[hit.item.pagina ?? 0]?.joined(separator: "\n")),
                contexto: hit.contexto, ranking: hit.ranking, blocoID: hit.blocoID)
        }
    }

    func obras(area: BibliotecaArea? = nil) -> [BibliotecaObra] {
        pacotes
            .filter { pacote in
                area == nil || pacote.area == area
            }
            .flatMap { pacote in
                pacote.obras.map { obra in
                    BibliotecaObra(
                        id: obra.id,
                        titulo: obra.titulo,
                        autor: obra.autor,
                        area: pacote.area,
                        tipo: obra.tipo,
                        recursoJSON: nil,
                        descricao: "Obra estruturada no acervo RAG.",
                        assuntos: obra.assuntos,
                        ativa: true
                    )
                }
            }
            .sorted { $0.titulo.localizedCaseInsensitiveCompare($1.titulo) == .orderedAscending }
    }

    func totaisPorObra() -> [String: Int] {
        pacotes.reduce(into: [String: Int]()) { parcial, pacote in
            for obra in pacote.obras {
                parcial[obra.id] = obra.paginas
            }
        }
    }

    func carregarIndicePaginas(obraID: String) throws -> [BreviarioItem] {
        guard let package = pacotes.first(where: { $0.obraIDs.contains(obraID) }), let url = urlPacote(package) else {
            throw Erro.pacoteNaoEncontrado(obraID)
        }
        return try BibliotecaSQLiteService(url: url, somenteLeitura: true).carregarIndicePaginas(obraID: obraID)
    }

    func carregarItens(obraID: String, paginas: [Int]? = nil) -> [BreviarioItem] {
        guard let pacote = pacotes.first(where: { $0.obraIDs.contains(obraID) }),
              let url = urlPacote(pacote),
              let banco = try? BibliotecaSQLiteService(url: url, somenteLeitura: true),
              let itens = try? banco.carregarItensBiblioteca(obraID: obraID, paginas: paginas) else {
            return []
        }

        return itens
    }

    func percorrerItens(obraID: String, receber: ([BreviarioItem]) -> Bool) throws {
        guard let pacote = pacotes.first(where: { $0.obraIDs.contains(obraID) }),
              let url = urlPacote(pacote) else { return }
        let banco = try BibliotecaSQLiteService(url: url, somenteLeitura: true)
        try banco.percorrerItensBiblioteca(obraID: obraID, receber: receber)
    }

    private func pacotesParaBusca(
        escopo: BibliotecaBuscaEscopo,
        area: BibliotecaArea?,
        obraID: String?
    ) -> [BibliotecaRAGPacote] {
        let selecionados: [BibliotecaRAGPacote]
        switch escopo {
        case .appTodo:
            selecionados = pacotes
        case .area:
            let areaBusca = area
            selecionados = pacotes.filter { pacote in
                areaBusca == nil || pacote.area == areaBusca
            }
        case .obraAtual:
            guard let obraID else {
                return []
            }
            selecionados = pacotes.filter { $0.obraIDs.contains(obraID) }
        }

        return selecionados.sorted { primeiro, segundo in
            if primeiro.area != segundo.area {
                return ordemArea(primeiro.area) < ordemArea(segundo.area)
            }
            if primeiro.tamanhoBytes != segundo.tamanhoBytes {
                return primeiro.tamanhoBytes < segundo.tamanhoBytes
            }
            return primeiro.titulo.localizedCaseInsensitiveCompare(segundo.titulo) == .orderedAscending
        }
    }

    private func pacotesPermitidos(_ pacotes: [BibliotecaRAGPacote]) -> [BibliotecaRAGPacote] {
        pacotes.filter { pacote in
            pacote.obraIDs.allSatisfy { obrasBloqueadas.contains($0) == false }
        }
    }

    private func urlPacote(_ pacote: BibliotecaRAGPacote) -> URL? {
        if let localURL = Self.urlPacoteLocal(arquivo: pacote.arquivo, fileManager: fileManager) {
            return localURL
        }

        if let bundleURL = Bundle.main.url(
            forResource: pacote.nomeArquivoSemExtensao,
            withExtension: "sqlite",
            subdirectory: pacote.subdiretorioBundle
        ) {
            return bundleURL
        }

        if let raizPacotes {
            let url = raizPacotes.appendingPathComponent(pacote.arquivo)
            if fileManager.fileExists(atPath: url.path) {
                return url
            }
        }

        return nil
    }

    static func urlPacoteLocal(arquivo: String, fileManager: FileManager = .default) -> URL? {
        let url = raizPacotesLocal(fileManager: fileManager).appendingPathComponent(arquivo)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    static func raizPacotesLocal(fileManager: FileManager = .default) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return base
            .appendingPathComponent("BreviarioMaconicoXXI", isDirectory: true)
            .appendingPathComponent("RAGPackages", isDirectory: true)
    }

    func urlOrigemPacote(_ pacote: BibliotecaRAGPacote) -> URL? {
        if let bundleURL = Bundle.main.url(
            forResource: pacote.nomeArquivoSemExtensao,
            withExtension: "sqlite",
            subdirectory: pacote.subdiretorioBundle
        ) {
            return bundleURL
        }

        guard let raizPacotes else {
            return nil
        }

        let url = raizPacotes.appendingPathComponent(pacote.arquivo)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    func urlRemotaPacote(_ pacote: BibliotecaRAGPacote) -> URL? {
        if let urlString = pacote.url,
           let url = URL(string: urlString) {
            return url
        }

        guard let baseURL = catalogo.baseURL?.removendoBarrasFinais,
              let encodedArquivo = pacote.arquivo.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "\(baseURL)/\(encodedArquivo)") else {
            return nil
        }

        return url
    }

    private func ordemArea(_ area: BibliotecaArea) -> Int {
        switch area {
        case .breviarios:
            return 0
        case .dicionariosMaconicos:
            return 1
        case .judiciarioMaconico:
            return 2
        case .bibliotecaMaconica:
            return 3
        }
    }

    private static func localizarRaizPacotes(
        catalogoURL: URL,
        catalogo: BibliotecaRAGCatalogo,
        fileManager: FileManager
    ) -> URL? {
        let bundleCandidate = catalogoURL
            .deletingLastPathComponent()
            .appendingPathComponent("RAGPackages", isDirectory: true)
        if fileManager.fileExists(atPath: bundleCandidate.path) {
            return bundleCandidate
        }

        if let origem = catalogo.origem {
            let reportsCandidate = URL(fileURLWithPath: origem)
                .deletingLastPathComponent()
                .appendingPathComponent("RAGPackages", isDirectory: true)
            if fileManager.fileExists(atPath: reportsCandidate.path) {
                return reportsCandidate
            }
        }

        return nil
    }
}

private extension String {
    var removendoBarrasFinais: String {
        var valor = self
        while valor.hasSuffix("/") {
            valor.removeLast()
        }
        return valor
    }
}

private extension BibliotecaRAGPacote {
    var nomeArquivoSemExtensao: String {
        URL(fileURLWithPath: arquivo).deletingPathExtension().lastPathComponent
    }

    var subdiretorioBundle: String {
        let diretorio = URL(fileURLWithPath: arquivo).deletingLastPathComponent().relativePath
        if diretorio == "." || diretorio.isEmpty {
            return "RAGPackages"
        }
        return "RAGPackages/\(diretorio)"
    }
}
