import SwiftUI
import UniformTypeIdentifiers
import UIKit

extension HomeView {
func prepararCachesIniciais() {
        guard cachesIniciaisAgendados == false else {
            return
        }

        cachesIniciaisAgendados = true
        atualizarProgressoLeitura()
        atualizarResumoNavegacaoCache()
        atualizarItensVisiveisCache()

        comentariosTask?.cancel()
        let datas = store.itens.map(\.data)
        let obraID = store.obraSelecionada.id
        comentariosTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            let resultado = await Task.detached(priority: .utility) {
                Self.montarComentariosCache(datas: datas, obraID: obraID)
            }.value

            guard Task.isCancelled == false else {
                return
            }

            aplicarComentariosCache(resultado)

            if let item = store.itemDoDia {
                registrarLeituraAberta(item)
            }

            reagendarNotificacaoSeNecessario()
            comentariosTask = nil
        }
        // Packages left out of the catalog (works removed as copies of others) do not keep taking space.
        Task.detached(priority: .background) {
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            _ = try? BibliotecaOfflinePackageService().removerPacotesForaDoCatalogo()
            BibliotecaNotasSearch.prepararPacotesInstalados()
        }
    }

    func prepararEstadoAposCarregamento() {
        guard appInicializado, store.itens.isEmpty == false else {
            return
        }

        if itemSelecionadoID == nil, let item = store.itemDoDia {
            itemSelecionadoID = item.id
        }
    }

    func iniciarTelaAberturaTemporizada() {
        telaAberturaTask?.cancel()
        if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
            manterTelaAbertura = false
            return
        }
        manterTelaAbertura = true

        telaAberturaTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard Task.isCancelled == false else {
                return
            }

            withAnimation(.easeInOut(duration: 0.35)) {
                manterTelaAbertura = false
            }
            telaAberturaTask = nil
        }
    }

    func cancelarTarefasDaTela() {
        buscaTask?.cancel()
        conteudoPremiumTask?.cancel()
        comentariosTask?.cancel()
        mensagemErroTask?.cancel()
        telaAberturaTask?.cancel()
        buscaTask = nil
        conteudoPremiumTask = nil
        comentariosTask = nil
        mensagemErroTask = nil
        telaAberturaTask = nil
    }

    func aoMudarAba(_ novaAba: Int) {
        salvarRascunhosLeitura()

        if novaAba != AppNavigationController.Tab.acervo.rawValue {
            // Leaving the reading by hand means Back should stay inside the Acervo tab later.
            navigation.forgetReadingOrigin()
        }

        if novaAba == 0 {
            fecharCaixasHome()
        }

        if novaAba != 3 {
            leitorVoz.parar()
            mostrandoEditor = false
            mostrandoLeituraTelaCheia = false
        }

        if novaAba == 1 || (novaAba == 4 && telaMais == .colecoes) {
            atualizarConteudoPremiumCache(apenasSeMudou: true)
        }
    }

    func aoMudarCaminhoLeitura(_ novoCaminho: [Int]) {
        guard abaSelecionada == 3 else {
            return
        }

        if let id = novoCaminho.last {
            if itemSelecionadoID != id {
                itemSelecionadoID = id
            }
        } else {
            if itemSelecionadoID != nil {
                limparEstadoLeituraSelecionada()
            }
            // Covers the edge-swipe pop, which empties the path without going through the Back button.
            navigation.closeReading()
        }
    }

    func abrirLeitura(_ item: BreviarioItem) {
        itemSelecionadoID = item.id
        navigation.showReading(itemID: item.id)
        processandoVoltarLeitura = false
        mensagemErro = nil
    }

    func abrirBreviario() {
        navigation.showLibrary()
        mensagemErro = nil
    }

    func abrirItemBreviario(_ item: BreviarioItem) {
        itemSelecionadoID = item.id
        filtroLeitura = .todos
        abaSelecionada = 3
        if caminhoLeitura.last != item.id {
            caminhoLeitura = [item.id]
        }
        processandoVoltarLeitura = false
        mensagemErro = nil
    }

    func voltarParaListaLeitura() {
        guard processandoVoltarLeitura == false else {
            return
        }

        processandoVoltarLeitura = true
        limparEstadoLeituraSelecionada()
        // Returns to the Dossiê, Coleções, Busca or Início screen that opened the reading, if any.
        navigation.closeReading()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            processandoVoltarLeitura = false
        }
    }

    /// Binds the reading editors to `item`, saving unsaved text of the previous reading first.
    /// Keeping the editors tied to one reading prevents text from being saved onto another page.
    func sincronizarEstadoLeitura(com item: BreviarioItem?, registrar: Bool = true) {
        guard item?.chavePersistencia != itemEstadoLeitura?.chavePersistencia else {
            return
        }

        salvarRascunhosLeitura()
        itemEstadoLeitura = item
        novoDestaque = ""
        trechoSelecionadoTexto = ""

        guard let item else {
            comentario = ""
            reflexaoPessoal = ""
            analiseIA = nil
            destaques = []
            return
        }

        comentario = item.comentarioSalvo
        reflexaoPessoal = ReflexoesService.carregar(data: item.data, obraID: item.obraID)
        analiseIA = AnaliseIAService.carregar(data: item.data, obraID: item.obraID)
        destaques = DestaquesService.carregar(data: item.data, obraID: item.obraID)
        if registrar {
            registrarLeituraAberta(item)
        }
    }

    /// Persists the comment and reflection typed for the loaded reading when they differ from what is saved.
    func salvarRascunhosLeitura() {
        guard let item = itemEstadoLeitura else {
            return
        }

        if comentario != CommentsService.carregar(data: item.data, obraID: item.obraID) {
            CommentsService.salvar(comentario: comentario, para: item.data, obraID: item.obraID)
            atualizarComentariosCache()
        }

        if reflexaoPessoal != ReflexoesService.carregar(data: item.data, obraID: item.obraID) {
            ReflexoesService.salvar(reflexaoPessoal, para: item.data, obraID: item.obraID)
            atualizarConteudoPremiumCache()
        }
    }

    func limparEstadoLeituraSelecionada() {
        leitorVoz.parar()
        mostrandoEditor = false
        mostrandoLeituraTelaCheia = false
        itemSelecionadoID = nil
        mensagemErro = nil
    }

    func abrirMais(_ tela: TelaMais = .menu) {
        navigation.showMore(tela)
    }

    func atualizarPacotesOffline() {
        let area = filtroAcervoOffline
        Task.detached(priority: .utility) {
            let estados = (try? BibliotecaOfflinePackageService().estados(area: area)) ?? []
            await MainActor.run {
                pacotesOffline = estados
            }
        }
    }

    func instalarPacoteOffline(_ estado: BibliotecaPacoteOfflineEstado) {
        instalandoPacotesOffline = true
        progressoAcervoOffline = "Baixando \(estado.titulo)..."

        Task.detached(priority: .utility) {
            do {
                try await BibliotecaOfflinePackageService().instalarPacote(estado.pacote)
                await MainActor.run {
                    instalandoPacotesOffline = false
                    progressoAcervoOffline = "\(estado.titulo) disponível offline."
                    atualizarPacotesOffline()
                    mensagemErro = "Obra baixada para uso offline."
                }
                // The new package's footnote search cache is built now, not by the first search.
                BibliotecaNotasSearch.prepararPacotesInstalados()
            } catch {
                await MainActor.run {
                    instalandoPacotesOffline = false
                    progressoAcervoOffline = "Não foi possível baixar \(estado.titulo)."
                    mensagemErro = "Não foi possível baixar a obra."
                }
            }
        }
    }

    func removerPacoteOffline(_ estado: BibliotecaPacoteOfflineEstado) {
        instalandoPacotesOffline = true
        progressoAcervoOffline = "Removendo \(estado.titulo)..."

        Task.detached(priority: .utility) {
            do {
                try BibliotecaOfflinePackageService().removerPacote(estado.pacote)
                await MainActor.run {
                    instalandoPacotesOffline = false
                    progressoAcervoOffline = "\(estado.titulo) removido do offline."
                    atualizarPacotesOffline()
                    mensagemErro = "Obra removida do acervo offline."
                }
            } catch {
                await MainActor.run {
                    instalandoPacotesOffline = false
                    progressoAcervoOffline = "Não foi possível remover \(estado.titulo)."
                    mensagemErro = "Não foi possível remover a obra."
                }
            }
        }
    }

    func instalarTodosPacotesOffline() {
        let area = filtroAcervoOffline
        instalandoPacotesOffline = true
        progressoAcervoOffline = "Preparando download das obras..."

        Task.detached(priority: .utility) {
            do {
                try await BibliotecaOfflinePackageService().instalarTodos(area: area) { concluido, total, titulo in
                    Task { @MainActor in
                        progressoAcervoOffline = "Baixando \(concluido) de \(total): \(titulo)"
                    }
                }

                await MainActor.run {
                    instalandoPacotesOffline = false
                    progressoAcervoOffline = "Todas as obras desta área estão disponíveis offline."
                    atualizarPacotesOffline()
                    mensagemErro = "Download offline concluído."
                }
            } catch {
                await MainActor.run {
                    instalandoPacotesOffline = false
                    progressoAcervoOffline = "O download foi interrompido antes de concluir."
                    atualizarPacotesOffline()
                    mensagemErro = "Não foi possível baixar todas as obras."
                }
            }
            BibliotecaNotasSearch.prepararPacotesInstalados()
        }
    }

    func instalarTodoAcervoOffline() {
        instalandoPacotesOffline = true
        progressoAcervoOffline = "Preparando download de todo o acervo..."

        Task.detached(priority: .utility) {
            do {
                try await BibliotecaOfflinePackageService().instalarTodos(area: nil) { concluido, total, titulo in
                    Task { @MainActor in
                        progressoAcervoOffline = "Baixando \(concluido) de \(total): \(titulo)"
                    }
                }

                await MainActor.run {
                    instalandoPacotesOffline = false
                    progressoAcervoOffline = "Todo o acervo está disponível offline."
                    atualizarPacotesOffline()
                    mensagemErro = "Download de todo o acervo concluído."
                }
            } catch {
                await MainActor.run {
                    instalandoPacotesOffline = false
                    progressoAcervoOffline = "O download geral foi interrompido antes de concluir."
                    atualizarPacotesOffline()
                    mensagemErro = "Não foi possível baixar todo o acervo."
                }
            }
            BibliotecaNotasSearch.prepararPacotesInstalados()
        }
    }

}
