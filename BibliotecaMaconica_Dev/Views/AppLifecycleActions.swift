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
        if novaAba == 0 {
            fecharCaixasHome()
        }

        if novaAba != 3 {
            leitorVoz.parar()
            mostrandoEditor = false
            mostrandoLeituraTelaCheia = false
        }

        if novaAba == 1 || (novaAba == 4 && telaMais == .colecoes) {
            atualizarConteudoPremiumCache()
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
        } else if itemSelecionadoID != nil {
            limparEstadoLeituraSelecionada()
        }
    }

    func abrirLeitura(_ item: BreviarioItem) {
        if abaSelecionada != 3 {
            aberturaProgramaticaLeitura = true
        }
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
        if aberturaProgramaticaLeitura {
            aberturaProgramaticaLeitura = false
            navigation.showHome()
            limparEstadoLeituraSelecionada()
        } else {
            if caminhoLeitura.isEmpty == false {
                caminhoLeitura.removeAll()
            }
            limparEstadoLeituraSelecionada()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            processandoVoltarLeitura = false
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
        }
    }

    func voltarParaHome() {
        mostrandoLeituraTelaCheia = false
        navigation.showHome()
    }

    func gestoHorizontalParaDireita(_ valor: DragGesture.Value) -> Bool {
        let horizontal = valor.translation.width
        let vertical = valor.translation.height
        return horizontal > 90 && abs(horizontal) > abs(vertical) * 1.35
    }

    func gestoHorizontalParaEsquerda(_ valor: DragGesture.Value) -> Bool {
        let horizontal = valor.translation.width
        let vertical = valor.translation.height
        return horizontal < -90 && abs(horizontal) > abs(vertical) * 1.35
    }

    func mudarMesCalendario(_ valor: Int) {
        calendarioMesExibido = Calendar.current.date(
            byAdding: .month,
            value: valor,
            to: calendarioMesExibido
        ) ?? calendarioMesExibido
        atualizarResumoNavegacaoCache()
    }
}
