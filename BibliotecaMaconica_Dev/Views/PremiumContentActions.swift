import SwiftUI
import UniformTypeIdentifiers
import UIKit

extension HomeView {
    func abrirItemEstudo(_ item: BreviarioItem) {
        guard let obra = store.obras.first(where: { $0.id == item.obraID }) else { return }
        abrirResultadoBuscaBiblioteca(BibliotecaResultadoBusca(obra: obra, item: item, contexto: ""))
    }

func atualizarConteudoPremiumCache() {
        conteudoPremiumTask?.cancel()
        carregandoColecoes = true
        let itens = store.itens
        let indice = store.indiceRemissivo
        let obraAtual = store.obraSelecionada.id
        let obras = store.obras.filter(\.ativa)

        conteudoPremiumTask = Task.detached(priority: .userInitiated) {
            var todosItens: [BreviarioItem] = []
            var termosPorChave: [String: String] = [:]
            var obrasComFalha: [String] = []
            let catalogo = try? BibliotecaRAGCatalogService()
            let regras = RegrasEstudo.compartilhadas
            let palavras = (regras.colecoes.map(\.palavrasChave) + regras.trilhas.map(\.palavrasChave))
                .map { RegrasEstudo.palavrasChave($0.map(RegrasEstudo.normalizar)) }
            let limites = Array(repeating: regras.collectionLimit, count: regras.colecoes.count) +
                Array(repeating: regras.pathLimit, count: regras.trilhas.count)
            var obrasDoCatalogo = Set<String>()
            for obra in obras {
                if Task.isCancelled { return }
                if obra.recursoJSON == nil && BreviarioStore.urlImportadoExistente(obraID: obra.id) == nil {
                    obrasDoCatalogo.insert(obra.id)
                    continue
                }
                let dados = obra.id == obraAtual ? BreviarioData(itens: itens, indiceRemissivo: indice) :
                    (try? BreviarioStore.carregarDadosDaObra(obra))
                guard let dados else { continue }
                todosItens += dados.itens
                for entrada in dados.indiceRemissivo {
                    for data in entrada.datas { termosPorChave["\(obra.id)_\(data)", default: ""] += " " + entrada.termo }
                }
            }
            // Downloaded works are scored on their FTS index: every page counts, and only the best are loaded.
            var chaves = Set(todosItens.map(\.chavePersistencia))
            var itensCatalogo: [BreviarioItem] = []
            var pontuadosCatalogo = Array(repeating: [RegrasEstudo.ItemPontuado](), count: palavras.count)
            if let catalogo, !obrasDoCatalogo.isEmpty {
                do {
                    let estudo = try catalogo.pontuarEstudo(obraIDs: obrasDoCatalogo, regras: palavras, limites: limites)
                    obrasComFalha += estudo.falhas
                    let paginasPorObra = Dictionary(grouping: estudo.pontuacoes.flatMap { $0 }, by: \.referencia.obraID)
                        .mapValues { Array(Set($0.map(\.referencia.pagina))).sorted() }
                    var itensPorReferencia: [BibliotecaEstudoIndice.Referencia: BreviarioItem] = [:]
                    for (obraID, paginas) in paginasPorObra.sorted(by: { $0.key < $1.key }) {
                        if Task.isCancelled { return }
                        for item in catalogo.carregarItens(obraID: obraID, paginas: paginas) {
                            guard let pagina = item.pagina else { continue }
                            itensPorReferencia[.init(obraID: obraID, pagina: pagina)] = item
                            if chaves.insert(item.chavePersistencia).inserted { itensCatalogo.append(item) }
                        }
                    }
                    // Index scores are kept as they are, so both platforms rank catalog pages identically.
                    pontuadosCatalogo = estudo.pontuacoes.map { pontuacoes in
                        pontuacoes.compactMap { pontuacao in
                            itensPorReferencia[pontuacao.referencia].map {
                                RegrasEstudo.ItemPontuado(item: $0, temas: pontuacao.temas, ocorrencias: pontuacao.ocorrencias)
                            }
                        }
                    }
                } catch {
                    if Task.isCancelled { return }
                    obrasComFalha.append("acervo baixado")
                }
            }
            let historico = todosItens + itensCatalogo + itens.filter { chaves.insert($0.chavePersistencia).inserted }
            let resultado = Self.montarConteudoPremiumCache(itens: todosItens, indice: [], termosPorChave: termosPorChave,
                                                            itensHistorico: historico, pontuadosCatalogo: pontuadosCatalogo)
            let avisoFalhas = obrasComFalha.isEmpty ? nil : "Não foi possível consultar algumas obras nas coleções: " + obrasComFalha.joined(separator: ", ")
            guard Task.isCancelled == false else {
                return
            }

            await MainActor.run {
                guard Task.isCancelled == false else {
                    return
                }
                colecoesTematicasCache = resultado.colecoes
                trilhasDeEstudoCache = resultado.trilhas
                historicoReflexoesCache = resultado.historico
                if let avisoFalhas { mensagemErro = avisoFalhas }
                carregandoColecoes = false
                conteudoPremiumTask = nil
            }
        }
    }

    nonisolated static func montarConteudoPremiumCache(
        itens: [BreviarioItem],
        indice: [IndiceRemissivoEntry],
        termosPorChave: [String: String] = [:],
        itensHistorico: [BreviarioItem]? = nil,
        pontuadosCatalogo: [[RegrasEstudo.ItemPontuado]] = []
    ) -> (colecoes: [ColecaoTematica], trilhas: [TrilhaEstudo], historico: [HistoricoReflexao]) {
        let termosPorData = Dictionary(grouping: indice.flatMap { entrada in
            entrada.datas.map { data in
                (data: data, termo: entrada.termo)
            }
        }, by: \.data)
            .mapValues { pares in
                pares.map(\.termo).joined(separator: " ")
            }

        let textosBusca = itens.reduce(into: [String: String]()) { parcial, item in
            parcial[item.chavePersistencia] = RegrasEstudo.normalizar([
                item.titulo,
                item.texto,
                item.rodape ?? "",
                termosPorChave[item.chavePersistencia] ?? termosPorData[item.data] ?? ""
            ].joined(separator: " "))
        }

        let regras = RegrasEstudo.compartilhadas
        let palavrasPorRegra = (regras.colecoes.map(\.palavrasChave) + regras.trilhas.map(\.palavrasChave))
            .map { RegrasEstudo.palavrasChave($0.map(RegrasEstudo.normalizar)) }
        let todasPalavras = palavrasPorRegra.reduce(into: Set<String>()) { $0.formUnion($1) }
        let contador = RegrasEstudo.ContadorPalavras(palavras: todasPalavras)
        let contagens = textosBusca.mapValues(contador.contar)

        let colecoes = ColecaoTematica.padroes.enumerated().map { indice, colecao in
            let itensColecao = RegrasEstudo.incorporarContagens(pontuadosCatalogo[safe: indice] ?? [], lote: itens, palavras: palavrasPorRegra[indice],
                contagens: contagens, limite: regras.collectionLimit).map(\.item)

            return colecao.comItens(itensColecao)
        }

        let trilhas = regras.trilhas.enumerated().map { indice, regra in
            TrilhaEstudo(id: regra.id, titulo: regra.titulo, subtitulo: regra.subtitulo, objetivo: regra.objetivo,
                         icone: regra.icone, instrucao: regra.instrucao, duracaoSugerida: regra.duracaoSugerida,
                         etapas: regra.etapas, itens: RegrasEstudo.incorporarContagens(
                            pontuadosCatalogo[safe: regras.colecoes.count + indice] ?? [], lote: itens,
                            palavras: palavrasPorRegra[regras.colecoes.count + indice], contagens: contagens,
                            limite: regras.pathLimit).map(\.item))
        }

        let historico = (itensHistorico ?? itens).compactMap { item in
            let texto = ReflexoesService.carregar(data: item.data, obraID: item.obraID).trimmingCharacters(in: .whitespacesAndNewlines)
            return texto.isEmpty ? nil : HistoricoReflexao(item: item, texto: texto)
        }

        return (colecoes, trilhas, historico)
    }

    @ViewBuilder
    var filtroLeituraControle: some View {
        if horizontalSizeClass == .compact {
            Picker("Exibir", selection: $filtroLeitura) {
                ForEach(FiltroLeitura.allCases) { filtro in
                    Label(filtro.titulo, systemImage: filtro.icone)
                        .tag(filtro)
                }
            }
            .pickerStyle(.menu)
        } else {
            Picker("Exibir", selection: $filtroLeitura) {
                ForEach(FiltroLeitura.allCases) { filtro in
                    Label(filtro.titulo, systemImage: filtro.icone)
                        .tag(filtro)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

private extension Array {
    subscript(safe indice: Int) -> Element? {
        indices.contains(indice) ? self[indice] : nil
    }
}
