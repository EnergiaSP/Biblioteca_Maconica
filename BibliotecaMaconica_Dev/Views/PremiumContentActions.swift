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
            let todasPalavras = palavras.reduce(into: Set<String>()) { $0.formUnion($1) }
            let limites = Array(repeating: regras.collectionLimit, count: regras.colecoes.count) +
                Array(repeating: regras.pathLimit, count: regras.trilhas.count)
            var selecionados = Array(repeating: [RegrasEstudo.ItemPontuado](), count: palavras.count)
            for obra in obras {
                if Task.isCancelled { return }
                if obra.recursoJSON == nil && BreviarioStore.urlImportadoExistente(obraID: obra.id) == nil {
                    do {
                        try catalogo?.percorrerItens(obraID: obra.id) { lote in
                            if Task.isCancelled { return false }
                            let contagens = Dictionary(uniqueKeysWithValues: lote.map {
                                ($0.chavePersistencia, RegrasEstudo.contarPalavras(
                                    RegrasEstudo.normalizar([$0.titulo, $0.texto, $0.rodape ?? ""].joined(separator: " ")),
                                    palavras: todasPalavras))
                            })
                            for i in palavras.indices {
                                selecionados[i] = RegrasEstudo.incorporarContagens(selecionados[i], lote: lote,
                                    palavras: palavras[i], contagens: contagens, limite: limites[i])
                            }
                            return true
                        }
                    } catch { obrasComFalha.append(obra.titulo) }
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
            var chaves = Set(todosItens.map(\.chavePersistencia))
            todosItens += selecionados.flatMap { $0 }.map(\.item).filter { chaves.insert($0.chavePersistencia).inserted }
            let historico = todosItens + itens.filter { chaves.insert($0.chavePersistencia).inserted }
            let resultado = Self.montarConteudoPremiumCache(itens: todosItens, indice: [], termosPorChave: termosPorChave, itensHistorico: historico)
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
        itensHistorico: [BreviarioItem]? = nil
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
        let contagens = textosBusca.mapValues { RegrasEstudo.contarPalavras($0, palavras: todasPalavras) }

        let colecoes = ColecaoTematica.padroes.enumerated().map { indice, colecao in
            let itensColecao = RegrasEstudo.incorporarContagens([], lote: itens, palavras: palavrasPorRegra[indice],
                contagens: contagens, limite: regras.collectionLimit).map(\.item)

            return colecao.comItens(itensColecao)
        }

        let trilhas = regras.trilhas.enumerated().map { indice, regra in
            TrilhaEstudo(id: regra.id, titulo: regra.titulo, subtitulo: regra.subtitulo, objetivo: regra.objetivo,
                         icone: regra.icone, instrucao: regra.instrucao, duracaoSugerida: regra.duracaoSugerida,
                         etapas: regra.etapas, itens: RegrasEstudo.incorporarContagens([], lote: itens,
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
