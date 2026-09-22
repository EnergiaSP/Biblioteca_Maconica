import SwiftUI
import UniformTypeIdentifiers
import UIKit

extension HomeView {
func salvarConfiguracaoNotificacao() {
        if notificacaoDiariaAtiva {
            Task { @MainActor in
                let itensNotificacao = await store.itensDisponiveisParaNotificacao(obraIDs: obrasNotificacaoIDs)
                NotificationService.agendarNotificacaoDiaria(
                    hora: notificacaoDiariaHora,
                    minuto: notificacaoDiariaMinuto,
                    itens: itensNotificacao
                ) { sucesso in
                    Task { @MainActor in
                        mensagemErro = sucesso
                            ? "Configuração salva: notificação diária ativada."
                            : "Não foi possível salvar a notificação."
                    }
                }
            }
        } else {
            NotificationService.cancelarNotificacaoDiaria()
            mensagemErro = "Configuração salva: notificação diária desativada."
        }
    }

    func salvarObrasNotificacao(_ ids: Set<String>) {
        obrasNotificacaoIDsRaw = ids.sorted().joined(separator: ",")
        if notificacaoDiariaAtiva {
            salvarConfiguracaoNotificacao()
        }
    }

    func salvarFonteOficial() {
        let titulo = fonteTitulo.trimmingCharacters(in: .whitespacesAndNewlines)
        let origem = fonteOrigem.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = fonteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let observacao = fonteObservacao.trimmingCharacters(in: .whitespacesAndNewlines)

        guard titulo.isEmpty == false, origem.isEmpty == false else {
            mensagemErro = "Informe o título e a origem da fonte oficial."
            return
        }

        do {
            try store.salvarFonteOficial(
                FonteOficialMaconica(
                    titulo: titulo,
                    origem: origem,
                    url: url,
                    observacao: observacao
                )
            )
            fonteTitulo = ""
            fonteOrigem = ""
            fonteURL = ""
            fonteObservacao = ""
            mensagemErro = "Fonte oficial salva."
        } catch {
            mensagemErro = "Nao foi possivel salvar a fonte oficial."
        }
    }

    func removerFonteOficial(_ fonte: FonteOficialMaconica) {
        do {
            try store.removerFonteOficial(fonte)
            mensagemErro = "Fonte oficial removida."
        } catch {
            mensagemErro = "Nao foi possivel remover a fonte oficial."
        }
    }

    func abrirURLFonte(_ fonte: FonteOficialMaconica) {
        guard let url = URL(string: fonte.url), fonte.url.isEmpty == false else {
            mensagemErro = "Esta fonte não possui URL oficial cadastrada."
            return
        }

        openURL(url)
    }

    func testarNotificacao() {
        guard let item = store.itemDoDia else {
            mensagemErro = "Nenhum texto disponível para teste."
            return
        }

        NotificationService.agendarTeste(item: item) { sucesso in
            Task { @MainActor in
                mensagemErro = sucesso
                    ? "Teste agendado: a notificação será enviada em 5 segundos."
                    : "Não foi possível enviar o teste."
            }
        }
    }

    func atualizarProgressoLeitura() {
        favoritos = ReadingProgressService.favoritos(obraID: store.obraSelecionada.id)
        leiturasConcluidas = ReadingProgressService.concluidos(obraID: store.obraSelecionada.id)
        leiturasRecentes = ReadingProgressService.recentes(obraID: store.obraSelecionada.id)
        sequenciaAtualCache = calcularSequenciaAtual(leiturasConcluidas: leiturasConcluidas)
        atualizarResumoNavegacaoCache()
        atualizarRecentesBreviariosCache()
    }

    func atualizarComentariosCache() {
        agendarAtualizacaoComentariosCache(atraso: 0)
    }

    func agendarAtualizacaoComentariosCache() {
        agendarAtualizacaoComentariosCache(atraso: 450_000_000)
    }

    func agendarAtualizacaoComentariosCache(atraso: UInt64) {
        comentariosTask?.cancel()
        let datas = store.itens.map(\.data)
        let obraID = store.obraSelecionada.id

        comentariosTask = Task { @MainActor in
            if atraso > 0 {
                try? await Task.sleep(nanoseconds: atraso)
            }

            let resultado = await Task.detached(priority: .utility) {
                Self.montarComentariosCache(datas: datas, obraID: obraID)
            }.value

            guard Task.isCancelled == false else {
                return
            }

            aplicarComentariosCache(resultado)
            comentariosTask = nil
        }
    }

    nonisolated static func montarComentariosCache(
        datas: [String],
        obraID: String
    ) -> (datasComComentario: Set<String>, resumos: [String: String]) {
        let datasComComentario = CommentsService.datasComComentario(datas: datas, obraID: obraID)
        let resumos = datasComComentario.reduce(into: [String: String]()) { parcial, data in
            let resumo = CommentsService.carregar(data: data, obraID: obraID)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\n", with: " ")

            if resumo.isEmpty == false {
                parcial[data] = resumo
            }
        }

        return (datasComComentario, resumos)
    }

    func aplicarComentariosCache(
        _ resultado: (datasComComentario: Set<String>, resumos: [String: String])
    ) {
        datasComComentarioCache = resultado.datasComComentario
        resumosComentarioCache = resultado.resumos
        atualizarResumoNavegacaoCache()
        atualizarItensVisiveisCache()
    }

    func atualizarResumoNavegacaoCache() {
        itensRecentesCache = leiturasRecentes.compactMap { store.item(data: $0) }
        itensFavoritosCache = store.itens.filter { favoritos.contains($0.data) }
        itensComComentarioCache = store.itens.filter { datasComComentarioCache.contains($0.data) }
        itensSemanaAtualCache = montarItensSemanaAtual()
        itensMesAtualCache = montarItensMesAtual()
        totalLidasSemanaAtualCache = itensSemanaAtualCache.reduce(0) { parcial, item in
            parcial + (leiturasConcluidas.contains(item.data) ? 1 : 0)
        }
        totalLidasMesAtualCache = itensMesAtualCache.reduce(0) { parcial, item in
            parcial + (leiturasConcluidas.contains(item.data) ? 1 : 0)
        }
        diasCalendarioMesAtualCache = montarDiasCalendarioMesAtual()
        nomeMesAtualCache = montarNomeMesAtual()
        dataHojeBreviarioCache = Self.formatadorDiaMesCompartilhado.string(from: Date())
    }

    func atualizarRecentesBreviariosCache() {
        recentesBreviariosTask?.cancel()
        let obras = store.obras.filter { $0.ativa }
        let obrasBreviario = obras.filter { $0.tipo == .breviarioDiario }
        let hoje = Self.formatadorDiaMesCompartilhado.string(from: Date())

        recentesBreviariosTask = Task { @MainActor in
            let resultado = await Task.detached(priority: .utility) {
                let leiturasDiarias = obrasBreviario.compactMap { obra -> LeituraDiariaBreviario? in
                    let concluidas = ReadingProgressService.concluidos(obraID: obra.id)
                    let itens = (try? BreviarioStore.carregarItensParaResumo(obra: obra)) ?? []
                    let item = itens.first(where: { $0.data == hoje }) ?? itens.first

                    return LeituraDiariaBreviario(
                        obra: obra,
                        item: item,
                        concluida: item.map { concluidas.contains($0.data) } ?? false
                    )
                }

                let catalogo = try? BibliotecaRAGCatalogService()
                let recentes = obras.flatMap { obra -> [LeituraRecenteBreviario] in
                    let recentesObra = Array(ReadingProgressService.recentes(obraID: obra.id).prefix(3))
                    guard recentesObra.isEmpty == false,
                          let itens = try? BreviarioStore.carregarItensRecentesParaResumo(
                            obra: obra, referencias: recentesObra, catalogo: catalogo
                          ) else {
                        return []
                    }

                    let itensPorData = Dictionary(uniqueKeysWithValues: itens.map { ($0.data, $0) })
                    return recentesObra.compactMap { data in
                        guard let item = itensPorData[data] else {
                            return nil
                        }

                        return LeituraRecenteBreviario(obra: obra, item: item)
                    }
                }

                return (leiturasDiarias, recentes)
            }.value

            guard Task.isCancelled == false else {
                return
            }

            leiturasDiariasBreviariosCache = resultado.0
            leiturasRecentesBreviariosCache = resultado.1
            recentesBreviariosTask = nil
        }
    }

    func atualizarItensVisiveisCache() {
        let itens = store.itensFiltrados(busca: busca)

        switch filtroLeitura {
        case .todos:
            itensVisiveisCache = itens
        case .favoritos:
            itensVisiveisCache = itens.filter { favoritos.contains($0.data) }
        case .lidos:
            itensVisiveisCache = itens.filter { leiturasConcluidas.contains($0.data) }
        case .naoLidos:
            itensVisiveisCache = itens.filter { leiturasConcluidas.contains($0.data) == false }
        case .comComentarios:
            itensVisiveisCache = itens.filter { datasComComentarioCache.contains($0.data) }
        }
    }

    func agendarAtualizacaoBusca() {
        buscaTask?.cancel()
        buscaTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard Task.isCancelled == false else {
                return
            }

            atualizarItensVisiveisCache()
        }
    }

    func agendarBuscaBiblioteca() {
        buscaBibliotecaTask?.cancel()
        gerandoDossieEstudo = false
        resultadosBuscaBiblioteca = []
        buscaBibliotecaTemMais = false
        buscandoBiblioteca = false
        buscaBibliotecaTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard Task.isCancelled == false else {
                return
            }

            executarBuscaBiblioteca()
        }
    }

    func executarBuscaBiblioteca(mais: Bool = false) {
        if mais && (buscandoBiblioteca || !buscaBibliotecaTemMais) { return }
        buscaBibliotecaTask?.cancel()
        gerandoDossieEstudo = false
        let termo = buscaBiblioteca.trimmingCharacters(in: .whitespacesAndNewlines)
        guard termo.isEmpty == false else {
            resultadosBuscaBiblioteca = []
            buscaBibliotecaTemMais = false
            buscandoBiblioteca = false
            return
        }

        let inicio = mais ? resultadosBuscaBiblioteca.count : 0
        if !mais { resultadosBuscaBiblioteca = [] }
        buscandoBiblioteca = true
        let escopo = escopoBuscaBiblioteca
        let area = areaBuscaBiblioteca
        let obraID = obraBuscaBibliotecaID
        let filtro = filtroMetadadosBiblioteca

        buscaBibliotecaTask = Task { @MainActor in
            do {
                let resultados = try await store.buscarBiblioteca(
                    termo: termo,
                    escopo: escopo,
                    area: escopo == .area ? area : nil,
                    limite: 51,
                    offset: inicio,
                    obraID: obraID,
                    filtro: filtro
                )

                guard Task.isCancelled == false else { return }

                resultadosBuscaBiblioteca += resultados.prefix(50)
                buscaBibliotecaTemMais = resultados.count > 50
                buscandoBiblioteca = false
                buscaBibliotecaTask = nil
            } catch {
                guard !Task.isCancelled else { return }
                buscandoBiblioteca = false
                buscaBibliotecaTemMais = false
                buscaBibliotecaTask = nil
                mensagemErro = "Não foi possível concluir a busca. \(error.localizedDescription)"
            }
        }
    }
}
