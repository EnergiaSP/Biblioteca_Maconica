import SwiftUI
import UniformTypeIdentifiers
import UIKit

extension HomeView {
/// Builds the dossier for the current fields; a saved one keeps its review dates.
func gerarDossieEstudo(salvo: DossieSalvo? = nil) {
        let termo = buscaBiblioteca.trimmingCharacters(in: .whitespacesAndNewlines)
        guard termo.isEmpty == false else {
            mensagemErro = "Informe um tema para montar o dossiê."
            return
        }

        buscaBibliotecaTask?.cancel()
        buscandoBiblioteca = false
        buscaBibliotecaTemMais = false
        gerandoDossieEstudo = true
        let escopo = escopoBuscaBiblioteca
        let area = areaBuscaBiblioteca
        let obraID = obraBuscaBibliotecaID
        let filtro = filtroMetadadosBiblioteca
        let dataBase = salvo?.dataCriacao ?? Date()
        dossieEstudo = nil
        analiseDossieIA = ""
        chaveDossieEmCurso = chaveDossieAtual()
        dossieSalvoID = salvo?.id

        buscaBibliotecaTask = Task { @MainActor in
            do {
                let dossie = try await store.montarDossieEstudo(
                    termo: termo,
                    escopo: escopo,
                    area: escopo == .area ? area : nil,
                    obraID: obraID,
                    filtro: filtro,
                    dataBase: dataBase
                )

                guard Task.isCancelled == false else { return }

                dossieEstudo = dossie
                resultadosBuscaBiblioteca = dossie?.resultados ?? []
                analiseDossieIA = ""
                gerandoDossieEstudo = false
                buscaBibliotecaTask = nil
                telaMais = .dossieEstudo
                mensagemErro = dossie?.resultados.isEmpty == true
                    ? "Dossiê criado sem ocorrências; refine o tema ou importe novas obras."
                    : "Dossiê de estudo criado."
            } catch {
                guard !Task.isCancelled else { return }
                gerandoDossieEstudo = false
                buscaBibliotecaTask = nil
                dossieEstudo = nil
                mensagemErro = "Não foi possível concluir o dossiê. \(error.localizedDescription)"
            }
        }
    }

    func abrirResultadoBuscaBiblioteca(_ resultado: BibliotecaResultadoBusca) {
        selecionarObra(resultado.obra)
        abrirLeitura(resultado.item)
    }

    func compartilharDossieEstudo(_ dossie: BibliotecaDossieEstudo) {
        compartilhamento = Compartilhamento(items: [PDFService.textoDossieEstudo(dossie, analise: analiseDossieIA)])
        mensagemErro = "Dossiê pronto para WhatsApp/e-mail."
    }

    func gerarPDFDossieEstudo(_ dossie: BibliotecaDossieEstudo) {
        guard !exportandoArquivo else { return }
        exportandoArquivo = true
        mensagemErro = "Gerando PDF avançado do dossiê..."
        let nomeUsuario = nomeUsuarioPDFPremium
        let analise = analiseDossieIA

        Task.detached(priority: .userInitiated) {
            do {
                let url = try PDFService.gerarPDFDossieEstudo(dossie, nomeUsuario: nomeUsuario, analise: analise)

                await MainActor.run {
                    compartilhamento = Compartilhamento(items: [url])
                    mensagemErro = "PDF avançado do dossiê gerado."
                    exportandoArquivo = false
                }
            } catch {
                await MainActor.run {
                    mensagemErro = "Nao foi possivel gerar o PDF do dossiê."
                    exportandoArquivo = false
                }
            }
        }
    }

    nonisolated static func textoDossieEstudo(_ dossie: BibliotecaDossieEstudo) -> String {
        "Dossiê de estudo\n\n" + PDFService.textoDossieEstudo(dossie)
    }

    /// Same key as a saved dossier, so reopening one does not count as a change of question.
    func chaveDossieAtual() -> String {
        DossieSalvo.chave(
            tema: buscaBiblioteca,
            area: escopoBuscaBiblioteca == .area ? areaBuscaBiblioteca.rawValue : nil,
            obraId: escopoBuscaBiblioteca == .obraAtual ? (obraBuscaBibliotecaID ?? store.obraSelecionada.id) : nil,
            autor: filtroMetadadosBiblioteca.autor,
            assunto: filtroMetadadosBiblioteca.assunto
        )
    }

    func abrirDossieSalvo(_ salvo: DossieSalvo) {
        buscaBiblioteca = salvo.tema
        filtroMetadadosBiblioteca = BibliotecaFiltroMetadados(autor: salvo.autor, assunto: salvo.assunto)
        if let obraId = salvo.obraId {
            escopoBuscaBiblioteca = .obraAtual
            obraBuscaBibliotecaID = obraId == store.obraSelecionada.id ? nil : obraId
        } else if let area = salvo.area.flatMap(BibliotecaArea.init(rawValue:)) {
            escopoBuscaBiblioteca = .area
            areaBuscaBiblioteca = area
        } else {
            escopoBuscaBiblioteca = .appTodo
        }
        navigation.selectedTab = AppNavigationController.Tab.dossie.rawValue
        gerarDossieEstudo(salvo: salvo)
    }

    func abrirDossieSalvo(id: String) {
        dossiesSalvos = DossiesSalvosStore().todos()
        guard let salvo = dossiesSalvos.first(where: { $0.id == id }) else {
            mensagemErro = "Este dossiê salvo foi excluído."
            return
        }
        abrirDossieSalvo(salvo)
    }

    func salvarDossieEstudo() {
        let store = DossiesSalvosStore()
        let salvo = store.buscar(chave: chaveDossieAtual()) ?? DossieSalvo(
            id: UUID().uuidString,
            tema: buscaBiblioteca.trimmingCharacters(in: .whitespacesAndNewlines),
            area: escopoBuscaBiblioteca == .area ? areaBuscaBiblioteca.rawValue : nil,
            obraId: escopoBuscaBiblioteca == .obraAtual ? (obraBuscaBibliotecaID ?? self.store.obraSelecionada.id) : nil,
            autor: filtroMetadadosBiblioteca.autor.trimmingCharacters(in: .whitespacesAndNewlines),
            assunto: filtroMetadadosBiblioteca.assunto.trimmingCharacters(in: .whitespacesAndNewlines),
            criadoEm: DossieSalvo.data(Date())
        )
        store.salvar(salvo)
        NotificationService.agendarRevisoesDossie(salvo)
        dossiesSalvos = store.todos()
        dossieSalvoID = salvo.id
        mensagemErro = "Dossiê salvo. Você será lembrado de cada revisão."
    }

    func alternarRevisaoDossie(_ salvo: DossieSalvo, dias: Int) {
        let atualizado = salvo.alternando(dias)
        let store = DossiesSalvosStore()
        store.salvar(atualizado)
        NotificationService.agendarRevisoesDossie(atualizado)
        dossiesSalvos = store.todos()
    }

    func excluirDossieSalvo(_ salvo: DossieSalvo) {
        NotificationService.cancelarRevisoesDossie(salvo)
        let store = DossiesSalvosStore()
        store.remover(id: salvo.id)
        if dossieSalvoID == salvo.id { dossieSalvoID = nil }
        dossiesSalvos = store.todos()
        mensagemErro = "Dossiê \"\(salvo.tema)\" excluído."
    }

    func invalidarDossieEstudo() {
        // Fields changed by reopening a saved dossier still ask the same question.
        guard chaveDossieAtual() != chaveDossieEmCurso else { return }
        chaveDossieEmCurso = nil
        dossieSalvoID = nil
        buscaBibliotecaTask?.cancel()
        buscaBibliotecaTask = nil
        gerandoDossieEstudo = false
        dossieEstudo = nil
        analiseDossieIA = ""
    }

    func gerarAnaliseDossieGemini(_ dossie: BibliotecaDossieEstudo) {
        guard !gerandoAnaliseDossieIA else { return }
        guard !dossie.resultados.isEmpty else {
            mensagemErro = "Não há base documental suficiente para analisar este dossiê."
            return
        }
        guard analiseIAAtiva else {
            mensagemErro = "Análise por IA desativada nas configurações."
            return
        }

        let chave = geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard chave.isEmpty == false else {
            mensagemErro = "Informe a chave gratuita do Gemini para gerar a análise."
            return
        }

        GeminiAPIKeyStore.salvar(chave)
        guard let configuracao = InterpretacaoAssistida.Configuracao.compartilhada,
              let estudo = DossieEstudoAnalise.Configuracao.compartilhada else {
            mensagemErro = "Regras da interpretação assistida indisponíveis."
            return
        }
        gerandoAnaliseDossieIA = true
        mensagemErro = "Gerando interpretação assistida..."
        let prompt = Self.promptAnaliseDossie(dossie, fontesOficiais: store.fontesOficiais)
        let fontes = BreviarioStore.fontesDossie(dossie.resultados)

        Task {
            do {
                let resposta = try await GeminiAnaliseService.gerarTexto(prompt: prompt, chaveAPI: chave)
                // Only sentences citing the dossier excerpts are kept; the rest is removed, not shown.
                let resultado = InterpretacaoAssistida.filtrar(
                    resposta: Self.normalizarRespostaTextualIA(resposta), fontes: fontes, configuracao: configuracao)
                let exibicao = InterpretacaoAssistida.exibicao(resultado, fontes: fontes, configuracao: configuracao, estudo: estudo)

                await MainActor.run {
                    guard dossieEstudo?.id == dossie.id,
                          dossieEstudo?.resultados.map(\.id) == dossie.resultados.map(\.id) else {
                        gerandoAnaliseDossieIA = false
                        return
                    }
                    analiseDossieIA = exibicao
                    mensagemErro = exibicao.isEmpty ? configuracao.rotulos.semFontes : "Interpretação assistida gerada."
                    gerandoAnaliseDossieIA = false
                }
            } catch {
                await MainActor.run {
                    mensagemErro = error.localizedDescription
                    gerandoAnaliseDossieIA = false
                }
            }
        }
    }

    /// Same prompt as Android: the rules of `ia_assistida_v1.json` and only the excerpts shown in the dossier.
    nonisolated static func promptAnaliseDossie(
        _ dossie: BibliotecaDossieEstudo,
        fontesOficiais: [FonteOficialMaconica]
    ) -> String {
        guard let configuracao = InterpretacaoAssistida.Configuracao.compartilhada,
              let estudo = DossieEstudoAnalise.Configuracao.compartilhada else { return "" }
        return InterpretacaoAssistida.prompt(
            termo: dossie.termo,
            fontes: BreviarioStore.fontesDossie(dossie.resultados),
            oficiais: fontesOficiais.map { .init(titulo: $0.titulo, origem: $0.origem, url: $0.url, observacao: $0.observacao) },
            configuracao: configuracao,
            estudo: estudo
        )
    }

    nonisolated static func normalizarRespostaTextualIA(_ texto: String) -> String {
        texto
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```JSON", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
