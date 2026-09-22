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
            self.erro = "Nao foi possivel restaurar os dados embutidos."
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

        return dadosDaObra
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
        let urlImportado = try criarURLImportado(obraID: obra.id)
        let url = FileManager.default.fileExists(atPath: urlImportado.path)
            ? urlImportado
            : obra.recursoJSON.flatMap { Bundle.main.url(forResource: $0, withExtension: "json") }

        guard let url else {
            return BreviarioData(itens: [], indiceRemissivo: [])
        }

        return try carregarDados(url: url, obraID: obra.id)
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
