import Foundation

@MainActor
extension BreviarioStore {
func buscarBiblioteca(
        termo: String,
        escopo: BibliotecaBuscaEscopo,
        area: BibliotecaArea?,
        limite: Int = 50,
        offset: Int = 0,
        obraID: String? = nil,
        filtro: BibliotecaFiltroMetadados = .init()
    ) async throws -> [BibliotecaResultadoBusca] {
        let termoLimpo = termo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard termoLimpo.isEmpty == false else {
            return []
        }

        let obrasParaBusca: [BibliotecaObra]
        switch escopo {
        case .appTodo:
            obrasParaBusca = obras.filter(\.ativa)
        case .area:
            let areaBusca = area ?? obraSelecionada.area
            obrasParaBusca = obras(na: areaBusca)
        case .obraAtual:
            obrasParaBusca = [obras.first { $0.id == obraID } ?? obraSelecionada]
        }

        let obraAtualID = obraID ?? obraSelecionada.id
        let excluidasPorMetadados = Set(obras.filter { !filtro.corresponde($0) }.map(\.id))
        let areaEfetiva = escopo == .area ? (area ?? obraSelecionada.area) : area
        let inicio = max(0, offset)
        let tamanho = min(500, max(1, limite))
        let quantidade = inicio + tamanho
        let trabalho = Task.detached(priority: .userInitiated) { () throws -> [BibliotecaResultadoBusca] in
            var resultados: [BibliotecaResultadoBusca] = []
            var obrasLocais = Set<String>()

            for obra in obrasParaBusca where filtro.corresponde(obra) {
                try Task.checkCancellation()
                guard obra.recursoJSON != nil || Self.urlImportadoExistente(obraID: obra.id) != nil else {
                    continue
                }
                let dados = try Self.carregarDadosDaObra(obra)
                guard !dados.itens.isEmpty else { continue }

                // The local edition owns its navigation IDs and must not be duplicated by a RAG copy.
                obrasLocais.insert(obra.id)

                let termosPorData = Dictionary(grouping: dados.indiceRemissivo.flatMap { entrada in
                    entrada.datas.map { data in
                        (data: data, termo: entrada.termo)
                    }
                }, by: \.data)
                    .mapValues { pares in
                        pares.map(\.termo).joined(separator: " ")
                    }

                for item in dados.itens {
                    let conteudo = [
                        obra.titulo,
                        obra.autor ?? "",
                        obra.area.titulo,
                        obra.assuntos.joined(separator: " "),
                        item.data,
                        item.titulo,
                        item.frase,
                        item.texto,
                        item.rodape ?? "",
                        termosPorData[item.data] ?? ""
                    ].joined(separator: " ")

                    guard BibliotecaSQLiteService.corresponde(termo: termoLimpo, texto: conteudo) else {
                        continue
                    }

                    resultados.append(
                        BibliotecaResultadoBusca(
                            obra: obra,
                            item: item,
                            contexto: Self.contextoBusca(termo: termoLimpo, em: conteudo)
                        )
                    )

                }
            }

            try Task.checkCancellation()
            let catalogo = try BibliotecaRAGCatalogService()
            let excluidas = obrasLocais.union(excluidasPorMetadados)
            resultados += try catalogo.buscar(termo: termoLimpo, escopo: escopo,
                    area: areaEfetiva, obraID: obraAtualID, limite: quantidade, obrasExcluidas: excluidas, filtro: filtro)
            let urlBanco = BibliotecaSQLiteService.urlBancoPadrao()
            if FileManager.default.fileExists(atPath: urlBanco.path) {
                let banco = try BibliotecaSQLiteService(url: urlBanco)
                let encontrados = try banco.buscarResultadosBiblioteca(termo: termoLimpo, escopo: escopo,
                    area: areaEfetiva, obraID: obraAtualID, limite: quantidade, obrasExcluidas: excluidas, filtro: filtro)
                resultados += encontrados
            }
            try Task.checkCancellation()
            var chaves = Set<String>()
            return resultados.sorted {
                if $0.ranking != $1.ranking { return $0.ranking < $1.ranking }
                if $0.obra.id != $1.obra.id { return $0.obra.id < $1.obra.id }
                if $0.item.pagina != $1.item.pagina { return ($0.item.pagina ?? 0) < ($1.item.pagina ?? 0) }
                return ($0.blocoID ?? $0.item.data) < ($1.blocoID ?? $1.item.data)
            }.filter {
                chaves.insert($0.id).inserted
            }.dropFirst(inicio).prefix(tamanho).map { $0 }
        }
        return try await withTaskCancellationHandler(operation: { try await trabalho.value }, onCancel: { trabalho.cancel() })
    }

    func montarDossieEstudo(
        termo: String,
        escopo: BibliotecaBuscaEscopo,
        area: BibliotecaArea?,
        obraID: String? = nil,
        filtro: BibliotecaFiltroMetadados = .init()
    ) async throws -> BibliotecaDossieEstudo? {
        let termoLimpo = termo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard termoLimpo.isEmpty == false else {
            return nil
        }

        let resultados = try await buscarBiblioteca(
            termo: termoLimpo,
            escopo: escopo,
            area: area,
            limite: 30,
            obraID: obraID,
            filtro: filtro
        )

        guard resultados.isEmpty == false else {
            return BibliotecaDossieEstudo(
                termo: termoLimpo,
                escopo: escopo,
                area: area,
                resultados: [],
                termosRelacionados: [],
                obrasEnvolvidas: [],
                roteiro: Self.roteiroEstudo(termo: termoLimpo, resultados: []),
                perguntasFixacao: Self.perguntasFixacao(termo: termoLimpo, resultados: []),
                mapaConceitual: Self.mapaConceitual(termo: termoLimpo, resultados: [], termosRelacionados: []),
                revisaoEspacada: Self.revisaoEspacada(termo: termoLimpo),
                cruzamentos: Self.cruzamentosEstudo(resultados: []),
                limitesDaBase: Self.limitesDaBase(resultados: []),
                filtroMetadados: filtro
            )
        }

        let obrasEnvolvidas = resultados.reduce(into: [BibliotecaObra]()) { parcial, resultado in
            guard parcial.contains(where: { $0.id == resultado.obra.id }) == false else {
                return
            }

            parcial.append(resultado.obra)
        }

        let termosRelacionados = await Task.detached(priority: .utility) {
            Self.termosRelacionados(termo: termoLimpo, resultados: resultados)
        }.value

        return BibliotecaDossieEstudo(
            termo: termoLimpo,
            escopo: escopo,
            area: area,
            resultados: resultados,
            termosRelacionados: termosRelacionados,
            obrasEnvolvidas: obrasEnvolvidas,
            roteiro: Self.roteiroEstudo(termo: termoLimpo, resultados: resultados),
            perguntasFixacao: Self.perguntasFixacao(termo: termoLimpo, resultados: resultados),
            mapaConceitual: Self.mapaConceitual(
                termo: termoLimpo,
                resultados: resultados,
                termosRelacionados: termosRelacionados
            ),
            revisaoEspacada: Self.revisaoEspacada(termo: termoLimpo),
            cruzamentos: Self.cruzamentosEstudo(resultados: resultados),
            limitesDaBase: Self.limitesDaBase(resultados: resultados),
            filtroMetadados: filtro
        )
    }

    func montarIndiceBiblioteca() async -> [BibliotecaIndiceArea] {
        let obrasAtivas = obras.filter(\.ativa)

        return await Task.detached(priority: .utility) {
            let totaisRAG = (try? BibliotecaRAGCatalogService().totaisPorObra()) ?? [:]
            let indicesPorObra = obrasAtivas.map { obra in
                let dados = (try? Self.carregarDadosDaObra(obra)) ?? BreviarioData(itens: [], indiceRemissivo: [])
                let primeirosTitulos = dados.itens
                    .prefix(8)
                    .map { item in
                        [item.referenciaExibicao, item.titulo]
                            .filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
                            .joined(separator: " - ")
                    }

                return BibliotecaIndiceObra(
                    obra: obra,
                    totalItens: dados.itens.isEmpty ? (totaisRAG[obra.id] ?? 0) : dados.itens.count,
                    totalIndiceRemissivo: dados.indiceRemissivo.count,
                    primeirosTitulos: primeirosTitulos
                )
            }

            return BibliotecaArea.allCases.compactMap { area in
                let obrasDaArea = indicesPorObra.filter { $0.obra.area == area }
                guard obrasDaArea.isEmpty == false else {
                    return nil
                }

                return BibliotecaIndiceArea(area: area, obras: obrasDaArea)
            }
        }.value
    }

    nonisolated static func carregarIndicePaginas(obra: BibliotecaObra) throws -> [BreviarioItem] {
        let local = try carregarDadosDaObra(obra)
        if !local.itens.isEmpty {
            return local.itens.map { item in
                BreviarioItem(id: item.id, data: item.data, titulo: item.titulo, frase: "", texto: "", pagina: item.pagina, obraID: obra.id)
            }
        }
        return try BibliotecaRAGCatalogService().carregarIndicePaginas(obraID: obra.id)
    }

    func montarIndiceRemissivoGlobal(
        escopo: BibliotecaBuscaEscopo,
        area: BibliotecaArea?,
        obraID: String? = nil
    ) async -> [BibliotecaIndiceRemissivoGlobal] {
        let obrasParaIndice: [BibliotecaObra]
        switch escopo {
        case .appTodo:
            obrasParaIndice = obras.filter(\.ativa)
        case .area:
            obrasParaIndice = obras(na: area ?? obraSelecionada.area)
        case .obraAtual:
            obrasParaIndice = obras.filter { $0.ativa && $0.id == (obraID ?? obraSelecionada.id) }
        }

        return await Task.detached(priority: .utility) {
            var termos: [String: [BibliotecaResultadoBusca]] = [:]

            for obra in obrasParaIndice {
                guard let dados = try? Self.carregarDadosDaObra(obra) else {
                    continue
                }

                let itensPorData = Dictionary(dados.itens.map { ($0.data, $0) }, uniquingKeysWith: { primeiro, _ in primeiro })

                for entrada in dados.indiceRemissivo {
                    for data in entrada.datas {
                        guard let item = itensPorData[data] else {
                            continue
                        }

                        termos[entrada.termo, default: []].append(
                            BibliotecaResultadoBusca(
                                obra: obra,
                                item: item,
                                contexto: "Índice remissivo: \(entrada.paginasFormatadas)"
                            )
                        )
                    }
                }
            }

            return termos
                .map { termo, ocorrencias in
                    BibliotecaIndiceRemissivoGlobal(
                        termo: termo,
                        ocorrencias: ocorrencias
                    )
                }
                .sorted { $0.termo.localizedCaseInsensitiveCompare($1.termo) == .orderedAscending }
                .map { $0 }
        }.value
    }

    func salvarSolicitacaoInclusao(_ solicitacao: SolicitacaoInclusaoObra) throws {
        var solicitacoes = try carregarSolicitacoesInclusao()
        solicitacoes.append(solicitacao)
        let dados = try JSONEncoder().encode(solicitacoes)
        try dados.write(to: Self.urlSolicitacoesInclusao(), options: .atomic)
        UserDefaults.standard.set(dados, forKey: "backup_solicitacoes_obras")
    }

    func carregarSolicitacoesInclusao() throws -> [SolicitacaoInclusaoObra] {
        let url = try Self.urlSolicitacoesInclusao()
        guard FileManager.default.fileExists(atPath: url.path) else {
            guard let dadosBackup = UserDefaults.standard.data(forKey: "backup_solicitacoes_obras") else {
                return []
            }
            let solicitacoes = try JSONDecoder().decode([SolicitacaoInclusaoObra].self, from: dadosBackup)
            try dadosBackup.write(to: url, options: .atomic)
            return solicitacoes
        }

        let dados = try Data(contentsOf: url)
        return try JSONDecoder().decode([SolicitacaoInclusaoObra].self, from: dados)
    }

    func salvarFonteOficial(_ fonte: FonteOficialMaconica) throws {
        var fontes = fontesOficiais
        fontes.removeAll { $0.id == fonte.id }
        fontes.insert(fonte, at: 0)
        let dados = try JSONEncoder().encode(fontes)
        try dados.write(to: Self.urlFontesOficiais(), options: .atomic)
        UserDefaults.standard.set(dados, forKey: "backup_fontes_oficiais")
        fontesOficiais = fontes
    }

    func removerFonteOficial(_ fonte: FonteOficialMaconica) throws {
        var fontes = fontesOficiais
        fontes.removeAll { $0.id == fonte.id }
        let dados = try JSONEncoder().encode(fontes)
        try dados.write(to: Self.urlFontesOficiais(), options: .atomic)
        UserDefaults.standard.set(dados, forKey: "backup_fontes_oficiais")
        fontesOficiais = fontes
    }

    func carregarFontesOficiais() {
        fontesOficiais = (try? Self.carregarFontesOficiaisSalvas()) ?? Self.fontesOficiaisPadrao()
    }
}
