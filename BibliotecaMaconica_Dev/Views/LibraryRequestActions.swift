import SwiftUI
import UniformTypeIdentifiers
import UIKit

extension HomeView {
func carregarIndicesBiblioteca() {
        let obraID = obraIndiceRemissivoID ?? store.obraSelecionada.id
        let catalogo = store.obras.map { "\($0.id):\($0.ativa):\(store.totalItensPorObra[$0.id] ?? 0)" }.joined(separator: "|")
        let chaveCache = "\(escopoIndiceBiblioteca.rawValue)-\(areaIndiceBiblioteca.rawValue)-\(obraID)-\(catalogo)-\(store.itens.count)-\(store.indiceRemissivo.count)"
        guard chaveCache != chaveIndiceBibliotecaCache || indiceBiblioteca.isEmpty else {
            return
        }

        chaveIndiceBibliotecaCache = chaveCache
        carregandoIndiceBiblioteca = true
        let escopo = escopoIndiceBiblioteca
        let area = areaIndiceBiblioteca

        Task { @MainActor in
            async let indice = store.montarIndiceBiblioteca()
            async let remissivo = store.montarIndiceRemissivoGlobal(
                escopo: escopo,
                area: escopo == .area ? area : nil,
                obraID: obraID
            )

            let novosResultados = await (indice, remissivo)
            guard chaveIndiceBibliotecaCache == chaveCache else { return }
            indiceBiblioteca = novosResultados.0
            indiceRemissivoBiblioteca = novosResultados.1
            carregandoIndiceBiblioteca = false
        }
    }

    func salvarSolicitacaoObra() {
        guard solicitacaoTitulo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            mensagemErro = "Informe o título da obra."
            return
        }

        let solicitacao = solicitacaoAtual()
        do {
            try store.salvarSolicitacaoInclusao(solicitacao)
            carregarSolicitacoesObras()
            mensagemErro = "Solicitação de obra salva."
        } catch {
            mensagemErro = "Nao foi possivel salvar a solicitação."
        }
    }

    func carregarSolicitacoesObras() {
        solicitacoesObras = ((try? store.carregarSolicitacoesInclusao()) ?? [])
            .sorted { $0.dataCriacao > $1.dataCriacao }
    }

    func compartilharSolicitacaoObra() {
        guard solicitacaoTitulo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            mensagemErro = "Informe o título da obra antes de compartilhar."
            return
        }

        let texto = textoSolicitacaoObra(solicitacaoAtual())
        compartilhamento = Compartilhamento(items: [texto])
        mensagemErro = "Solicitação pronta para WhatsApp/e-mail."
    }

    func solicitacaoAtual() -> SolicitacaoInclusaoObra {
        SolicitacaoInclusaoObra(
            area: solicitacaoArea,
            titulo: solicitacaoTitulo.trimmingCharacters(in: .whitespacesAndNewlines),
            autor: solicitacaoAutor.trimmingCharacters(in: .whitespacesAndNewlines),
            observacao: solicitacaoObservacao.trimmingCharacters(in: .whitespacesAndNewlines),
            dataCriacao: Date()
        )
    }

    func textoSolicitacaoObra(_ solicitacao: SolicitacaoInclusaoObra) -> String {
        [
            "Solicitação de inclusão de obra",
            "Área: \(solicitacao.area.titulo)",
            "Título: \(solicitacao.titulo)",
            solicitacao.autor.isEmpty ? nil : "Autor/origem: \(solicitacao.autor)",
            solicitacao.observacao.isEmpty ? nil : "Observações: \(solicitacao.observacao)"
        ]
        .compactMap { $0 }
        .joined(separator: "\n\n")
    }

    func calcularSequenciaAtual(leiturasConcluidas: Set<String>) -> Int {
        let calendario = Calendar.current

        var sequencia = 0
        for offset in 0..<366 {
            guard let data = calendario.date(byAdding: .day, value: -offset, to: Date()) else {
                break
            }

            if leiturasConcluidas.contains(Self.formatadorDiaMesCompartilhado.string(from: data)) {
                sequencia += 1
            } else {
                break
            }
        }

        return sequencia
    }

    func alternarFavorito(_ item: BreviarioItem) {
        let estavaFavorito = favoritos.contains(item.data)
        ReadingProgressService.alternarFavorito(item.data, obraID: item.obraID)
        atualizarProgressoLeitura()
        atualizarItensVisiveisCache()
        mensagemErro = estavaFavorito ? "Favorito removido." : "Leitura adicionada aos favoritos."
    }

    func alternarConcluido(_ item: BreviarioItem) {
        let estavaConcluido = leiturasConcluidas.contains(item.data)
        ReadingProgressService.alternarConcluido(item.data, obraID: item.obraID)
        atualizarProgressoLeitura()
        atualizarItensVisiveisCache()
        mensagemErro = estavaConcluido ? "Leitura marcada como não lida." : "Leitura marcada como lida."
    }

    func registrarLeituraAberta(_ item: BreviarioItem) {
        ReadingProgressService.registrarRecente(item.data, obraID: item.obraID)
        leiturasRecentes = ReadingProgressService.recentes(obraID: item.obraID)
        itensRecentesCache = leiturasRecentes.compactMap { store.item(data: $0) }
        atualizarRecentesBreviariosCache()
    }

    func possuiComentario(_ item: BreviarioItem) -> Bool {
        datasComComentarioCache.contains(item.data)
    }

    func resumoComentario(_ item: BreviarioItem) -> String {
        resumosComentarioCache[item.data] ?? ""
    }

    func mesDaData(_ data: String) -> Int? {
        let partes = data.split(separator: "/").compactMap { Int($0) }
        guard partes.count == 2 else {
            return nil
        }

        return partes[1]
    }

    func reagendarNotificacaoSeNecessario() {
        guard notificacaoDiariaAtiva, store.itens.isEmpty == false else {
            return
        }

        NotificationService.agendarNotificacaoDiaria(
            hora: notificacaoDiariaHora,
            minuto: notificacaoDiariaMinuto,
            itens: store.itens
        ) { _ in }
    }
}
