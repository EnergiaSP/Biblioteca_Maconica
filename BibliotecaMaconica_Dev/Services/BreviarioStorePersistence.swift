import CryptoKit
import Foundation

@MainActor
extension BreviarioStore {
func restaurarDadosEmbutidos() {
        do {
            let url = try Self.criarURLImportado(obraID: obraSelecionada.id)

            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }

            carregar()
        } catch {
            self.erro = "Não foi possível restaurar os dados embutidos."
        }
    }

    nonisolated static func processarImportacao(url: URL, obraID: String) throws -> BreviarioData {
        let acessoLiberado = url.startAccessingSecurityScopedResource()
        defer {
            if acessoLiberado {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let obra = carregarObrasDoCatalogo().first { $0.id == obraID }
            ?? .breviarioSeculoXXI
        let texto = try PDFOCRService.extrairTexto(
            url: url,
            modo: obra.tipo == .breviarioDiario ? .breviarioDiario : .obraGenerica
        )
        let dadosImportados = importar(textoOCR: texto, obra: obra)
        let midias = try PDFOCRService.renderizarPaginas(url: url, obraID: obraID)
        let dadosDaObra = vincularMidias(
            midias,
            em: aplicarObraID(obraID, em: dadosImportados)
        )

        guard dadosDaObra.itens.isEmpty == false else {
            throw ImportError.semItens
        }

        let dados = try JSONEncoder().encode(dadosDaObra)
        let destino = try criarURLImportado(obraID: obraID)
        try dados.write(to: destino, options: .atomic)
        if let hash = sha256PDF(url) {
            try? registrarPDFImportado(hash, obraID: obraID)
        }

        return dadosDaObra
    }

    // MARK: - PDFs already imported (the same file is not imported twice as another work)

    nonisolated static func mensagemPDFDuplicado(_ titulo: String) -> String {
        "Este PDF já foi importado como “\(titulo)”."
    }

    /// SHA-256 of the PDF, read in blocks (the file picker URL needs its security scope).
    nonisolated static func sha256PDF(_ url: URL) -> String? {
        let acesso = url.startAccessingSecurityScopedResource()
        defer { if acesso { url.stopAccessingSecurityScopedResource() } }
        guard let arquivo = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? arquivo.close() }
        var hash = SHA256()
        while let bloco = try? arquivo.read(upToCount: 1 << 16), !bloco.isEmpty { hash.update(data: bloco) }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private nonisolated static func urlPDFsImportados() throws -> URL {
        try criarURLImportado(obraID: "registro").deletingLastPathComponent().appendingPathComponent("pdfs-importados.json")
    }

    private nonisolated static func pdfsImportados() -> [String: String] {
        guard let url = try? urlPDFsImportados(), let dados = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: String].self, from: dados)) ?? [:]
    }

    nonisolated static func registrarPDFImportado(_ hash: String, obraID: String) throws {
        var registro = pdfsImportados()
        registro[hash] = obraID
        try JSONEncoder().encode(registro).write(to: try urlPDFsImportados(), options: .atomic)
    }

    /// The work that already holds this PDF, while its imported content still exists.
    nonisolated static func obraComPDF(_ hash: String, obras: [BibliotecaObra]) -> BibliotecaObra? {
        guard let obraID = pdfsImportados()[hash], let obra = obras.first(where: { $0.id == obraID }),
              let arquivo = try? criarURLImportado(obraID: obraID), FileManager.default.fileExists(atPath: arquivo.path) else { return nil }
        return obra
    }

    nonisolated static func importar(textoOCR: String, obra: BibliotecaObra) -> BreviarioData {
        if obra.tipo == .breviarioDiario {
            return BreviarioImportService.importar(textoOCR: textoOCR)
        }

        return BreviarioImportService.importarObraGenerica(
            textoOCR: textoOCR,
            tituloObra: obra.titulo,
            autor: obra.autor,
            obraID: obra.id,
            tipo: obra.tipo
        )
    }

    nonisolated static func carregarDados(url: URL, obraID: String) throws -> BreviarioData {
        let dados = try Data(contentsOf: url)

        if let dadosCompletos = try? JSONDecoder().decode(BreviarioData.self, from: dados) {
            let itens = TextEditsService.aplicarEdicoes(
                em: BreviarioImportService.corrigirRodapesEmbutidos(
                    itens: aplicarObraID(obraID, em: dadosCompletos.itens)
                ),
                obraID: obraID
            )
            let indice = BreviarioImportService.vincularIndice(
                dadosCompletos.indiceRemissivo,
                aos: itens
            )
            return BreviarioData(itens: itens, indiceRemissivo: indice)
        }

        let itens = TextEditsService.aplicarEdicoes(
            em: BreviarioImportService.corrigirRodapesEmbutidos(
                itens: aplicarObraID(obraID, em: try JSONDecoder().decode([BreviarioItem].self, from: dados))
            ),
            obraID: obraID
        )
        return BreviarioData(itens: itens, indiceRemissivo: [])
    }

    nonisolated static func carregarDadosDaObra(_ obra: BibliotecaObra) throws -> BreviarioData {
        guard let url = try urlDadosDaObra(obra) else {
            return BreviarioData(itens: [], indiceRemissivo: [])
        }

        return try carregarDados(url: url, obraID: obra.id)
    }

    /// The imported or edited copy when it exists, otherwise the bundled file.
    nonisolated static func urlDadosDaObra(_ obra: BibliotecaObra) throws -> URL? {
        let urlImportado = try criarURLImportado(obraID: obra.id)
        return FileManager.default.fileExists(atPath: urlImportado.path)
            ? urlImportado
            : obra.recursoJSON.flatMap { Bundle.main.url(forResource: $0, withExtension: "json") }
    }

    nonisolated static func carregarItensDaObra(_ obra: BibliotecaObra) throws -> [BreviarioItem] {
        try carregarDadosDaObra(obra).itens
    }

    nonisolated static func aplicarObraID(_ obraID: String, em dados: BreviarioData) -> BreviarioData {
        BreviarioData(
            itens: aplicarObraID(obraID, em: dados.itens),
            indiceRemissivo: dados.indiceRemissivo
        )
    }

    nonisolated static func aplicarObraID(_ obraID: String, em itens: [BreviarioItem]) -> [BreviarioItem] {
        itens.map { item in
            BreviarioItem(
                id: item.id,
                data: item.data,
                titulo: item.titulo,
                frase: item.frase,
                texto: item.texto,
                rodape: item.rodape,
                autor: item.autor,
                pagina: item.pagina,
                obraID: obraID,
                paginaMidia: item.paginaMidia
            )
        }
    }

    nonisolated static func vincularMidias(
        _ midias: [Int: PaginaMidia],
        em dados: BreviarioData
    ) -> BreviarioData {
        guard midias.isEmpty == false else {
            return dados
        }

        return BreviarioData(
            itens: dados.itens.map { item in
                let pagina = item.pagina ?? BreviarioImportService.paginaDaObra(item)
                return BreviarioItem(
                    id: item.id,
                    data: item.data,
                    titulo: item.titulo,
                    frase: item.frase,
                    texto: item.texto,
                    rodape: item.rodape,
                    autor: item.autor,
                    pagina: item.pagina,
                    obraID: item.obraID,
                    paginaMidia: pagina.flatMap { midias[$0] } ?? item.paginaMidia
                )
            },
            indiceRemissivo: dados.indiceRemissivo
        )
    }

    func itemAtualizadoAposImportacao() {
        erro = nil
    }

    func atualizarSnapshotCompartilhado() {
        guard let item = itemDoDia else {
            return
        }

        let snapshot = BreviarioSnapshot(
            id: item.id,
            data: item.data,
            titulo: item.titulo,
            frase: item.fraseExibicao ?? "",
            texto: item.texto,
            autor: item.autorDocumental ?? "",
            obraID: item.obraID,
            rodape: item.rodape
        )
        BreviarioSnapshotProvider.salvarSnapshotAtual(snapshot)
    }

    func substituirItem(_ item: BreviarioItem) {
        guard let indice = indicesPorID[item.id] else {
            return
        }

        itens[indice] = item
    }

    func reconstruirIndices() {
        itensPorID = itens.reduce(into: [:]) { parcial, item in
            parcial[item.id] = item
        }
        itensPorData = itens.reduce(into: [:]) { parcial, item in
            parcial[item.data] = item
        }
        itensPorPaginaDaObra = itens.reduce(into: [:]) { parcial, item in
            if let pagina = item.pagina {
                parcial[pagina] = item
            }

            if let paginaObra = BreviarioImportService.paginaDaObra(item) {
                parcial[paginaObra] = item
            }
        }
        indicesPorID = itens.enumerated().reduce(into: [:]) { parcial, elemento in
            parcial[elemento.element.id] = elemento.offset
        }
    }
}
