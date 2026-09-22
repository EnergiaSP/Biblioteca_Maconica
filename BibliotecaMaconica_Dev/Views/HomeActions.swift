import SwiftUI
import UniformTypeIdentifiers
import UIKit

extension HomeView {
func importarPDF(resultado: Result<[URL], Error>) {
        do {
            let urls = try resultado.get()
            guard urls.isEmpty == false else {
                return
            }

            if urls.count > 1 {
                let entradas = try urls.map { url in
                    let obra = try store.criarObraPersonalizada(
                        titulo: tituloObraParaImportacao(url),
                        autor: nil,
                        area: novaObraArea,
                        tipo: novaObraTipo,
                        assuntos: assuntosNovaObra()
                    )
                    return (url: url, obraID: obra.id)
                }

                store.importarPDFsEmLote(entradas)
                itemSelecionadoID = nil
                abrirBreviario()
                mensagemErro = "Importação em lote iniciada: \(urls.count) arquivo(s)."
                criarNovaObraImportacao = false
                limparCamposNovaObra()
                return
            }

            guard let url = urls.first else {
                return
            }

            let obraDestino: BibliotecaObra

            if criarNovaObraImportacao {
                obraDestino = try store.criarObraPersonalizada(
                    titulo: novaObraTitulo,
                    autor: novaObraAutor,
                    area: novaObraArea,
                    tipo: novaObraTipo,
                    assuntos: assuntosNovaObra()
                )
                obraImportacaoID = obraDestino.id
                criarNovaObraImportacao = false
                limparCamposNovaObra()
            } else if let obra = store.obra(id: obraImportacaoID) {
                obraDestino = obra
            } else {
                obraDestino = store.obraSelecionada
                obraImportacaoID = obraDestino.id
            }

            if obraDestino.id != store.obraSelecionada.id {
                store.selecionarObra(id: obraDestino.id)
            }

            store.importarPDF(url: url, obraID: obraDestino.id)
            itemSelecionadoID = nil
            abrirBreviario()
            mensagemErro = "Importação iniciada em \(obraDestino.titulo)."
        } catch {
            mensagemErro = "Nao foi possivel criar a obra ou abrir o PDF selecionado."
        }
    }

    func tituloObraParaImportacao(_ url: URL) -> String {
        url.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " - ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.isEmpty == false }
            .joined(separator: " ")
    }

    func assuntosNovaObra() -> [String] {
        novaObraAssuntos
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
    }

    func limparCamposNovaObra() {
        novaObraTitulo = ""
        novaObraAutor = ""
        novaObraAssuntos = ""
        novaObraArea = .bibliotecaMaconica
        novaObraTipo = .livro
    }

    func gerarPDF(item: BreviarioItem, incluirComentario: Bool) {
        exportandoArquivo = true
        mensagemErro = "Gerando PDF..."
        let comentarioAtual = comentario
        let nomeUsuario = nomeUsuarioPDFPremium

        Task.detached(priority: .userInitiated) {
            do {
                let url = try PDFService.gerarPDF(
                    item: item,
                    comentario: comentarioAtual,
                    nomeUsuario: nomeUsuario,
                    incluirComentario: incluirComentario
                )

                await MainActor.run {
                    pdfURL = url
                    compartilhamento = Compartilhamento(items: [url])
                    mensagemErro = nil
                    exportandoArquivo = false
                }
            } catch {
                await MainActor.run {
                    mensagemErro = "Nao foi possivel gerar o PDF."
                    exportandoArquivo = false
                }
            }
        }
    }

    func exportarMultiplosDias(
        itens: [BreviarioItem],
        incluirComentarios: Bool,
        formato: FormatoExportacaoMultipla
    ) {
        guard itens.isEmpty == false else {
            mensagemErro = "Selecione pelo menos um dia para exportar."
            return
        }

        exportandoArquivo = true
        mensagemErro = "Gerando exportação..."
        let nomeUsuario = nomeUsuarioPDFPremium

        Task.detached(priority: .userInitiated) {
            do {
                let url: URL
                switch formato {
                case .pdf:
                    url = try PDFService.gerarPDF(
                        itens: itens,
                        incluirComentarios: incluirComentarios,
                        nomeUsuario: nomeUsuario
                    )
                case .texto:
                    url = try Self.gerarArquivoTextoExportacao(
                        itens: itens,
                        incluirComentarios: incluirComentarios
                    )
                }

                await MainActor.run {
                    compartilhamento = Compartilhamento(items: [url])
                    mostrandoExportadorMultiplo = false
                    mensagemErro = "\(itens.count) dias exportados em \(formato.titulo)."
                    exportandoArquivo = false
                }
            } catch {
                await MainActor.run {
                    mensagemErro = "Nao foi possivel exportar os dias selecionados."
                    exportandoArquivo = false
                }
            }
        }
    }

    func exportarDestaques(item: BreviarioItem) {
        guard destaques.isEmpty == false else {
            mensagemErro = "Nenhum marcador salvo para exportar."
            return
        }

        exportandoArquivo = true
        mensagemErro = "Gerando PDF dos marcadores..."
        let destaquesAtual = destaques
        let nomeUsuario = nomeUsuarioPDFPremium

        Task.detached(priority: .userInitiated) {
            do {
                let url = try PDFService.gerarPDFDestaques(
                    item: item,
                    destaques: destaquesAtual,
                    nomeUsuario: nomeUsuario
                )

                await MainActor.run {
                    compartilhamento = Compartilhamento(items: [url])
                    mensagemErro = "Marcadores exportados em PDF."
                    exportandoArquivo = false
                }
            } catch {
                await MainActor.run {
                    mensagemErro = "Nao foi possivel exportar os marcadores."
                    exportandoArquivo = false
                }
            }
        }
    }

    func salvarDestaque(texto: String, item: BreviarioItem) {
        let textoLimpo = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard textoLimpo.isEmpty == false else {
            mensagemErro = "Selecione ou informe um trecho antes de salvar."
            return
        }

        DestaquesService.salvar(textoLimpo, para: item.data, obraID: item.obraID)
        destaques = DestaquesService.carregar(data: item.data, obraID: item.obraID)
        novoDestaque = ""
        trechoSelecionadoTexto = ""
        mensagemErro = "Trecho destacado no texto."
    }

    func prepararAnaliseExternaNoChatGPT(item: BreviarioItem) {
        guard analiseIAAtiva else {
            mensagemIA = "Análise por IA desativada nas configurações."
            mensagemErro = mensagemIA
            return
        }

        UIPasteboard.general.string = Self.promptAnaliseExterna(item: item)
        mensagemIA = "Prompt completo copiado. O ChatGPT será aberto; cole, envie e copie a resposta."
        mensagemErro = mensagemIA

        if let url = URL(string: "https://chatgpt.com/") {
            openURL(url)
        }
    }

    func importarAnaliseExternaCopiada(item: BreviarioItem) {
        guard analiseIAAtiva else {
            mensagemIA = "Análise por IA desativada nas configurações."
            mensagemErro = mensagemIA
            return
        }

        guard let texto = UIPasteboard.general.string?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              texto.isEmpty == false else {
            mensagemIA = "Nenhuma resposta copiada encontrada."
            mensagemErro = mensagemIA
            return
        }

        let analise = Self.decodificarAnaliseExterna(texto)
        AnaliseIAService.salvar(analise, para: item.data, obraID: item.obraID)
        analiseIA = analise
        mensagemIA = "Análise externa importada e salva."
        mensagemErro = mensagemIA
    }

    func gerarAnaliseGemini(item: BreviarioItem) {
        guard analiseIAAtiva else {
            mensagemIA = "Análise por IA desativada nas configurações."
            mensagemErro = mensagemIA
            return
        }

        let chave = geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard chave.isEmpty == false else {
            mensagemIA = "Informe a chave gratuita do Gemini para gerar a análise."
            mensagemErro = mensagemIA
            return
        }

        GeminiAPIKeyStore.salvar(chave)

        let data = item.data
        let prompt = Self.promptAnaliseExterna(item: item)
        gerandoAnaliseGemini = true
        mensagemIA = "Gerando análise pelo Gemini..."
        mensagemErro = mensagemIA

        Task {
            do {
                let resposta = try await GeminiAnaliseService.gerarAnalise(prompt: prompt, chaveAPI: chave)
                let analise = Self.decodificarAnaliseExterna(resposta)

                await MainActor.run {
                    AnaliseIAService.salvar(analise, para: data, obraID: item.obraID)
                    salvarAnaliseGeminiNoComentario(analise, item: item)
                    analiseIA = analise
                    mensagemIA = "Análise gerada pelo Gemini e salva no comentário do dia."
                    mensagemErro = mensagemIA
                    gerandoAnaliseGemini = false
                }
            } catch {
                await MainActor.run {
                    mensagemIA = error.localizedDescription
                    mensagemErro = mensagemIA
                    gerandoAnaliseGemini = false
                }
            }
        }
    }

    func salvarAnaliseGeminiNoComentario(_ analise: AnaliseIA, item: BreviarioItem) {
        let comentarioAtual = CommentsService.carregar(data: item.data, obraID: item.obraID)
        let comentarioAtualizado = Self.comentarioComAnaliseGemini(
            comentarioAtual,
            analise: analise,
            item: item
        )

        CommentsService.salvar(comentario: comentarioAtualizado, para: item.data, obraID: item.obraID)

        if itemSelecionadoID == item.id {
            comentario = comentarioAtualizado
        }

        atualizarComentariosCache()
    }

    nonisolated static func comentarioComAnaliseGemini(
        _ comentarioAtual: String,
        analise: AnaliseIA,
        item: BreviarioItem
    ) -> String {
        let comentarioSemAnaliseAnterior = removerBlocoAnaliseGemini(de: comentarioAtual)
        let bloco = blocoComentarioAnaliseGemini(analise: analise, item: item)

        guard comentarioSemAnaliseAnterior.isEmpty == false else {
            return bloco
        }

        return [comentarioSemAnaliseAnterior, bloco].joined(separator: "\n\n")
    }

    nonisolated static func removerBlocoAnaliseGemini(de comentario: String) -> String {
        let marcadorInicioAnaliseGemini = "[INICIO DA ANALISE IA GEMINI]"
        let marcadorFimAnaliseGemini = "[FIM DA ANALISE IA GEMINI]"

        guard let inicio = comentario.range(of: marcadorInicioAnaliseGemini),
              let fim = comentario.range(of: marcadorFimAnaliseGemini, range: inicio.lowerBound..<comentario.endIndex) else {
            return comentario.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var resultado = comentario
        resultado.removeSubrange(inicio.lowerBound..<fim.upperBound)
        return resultado.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated static func blocoComentarioAnaliseGemini(
        analise: AnaliseIA,
        item: BreviarioItem
    ) -> String {
        let marcadorInicioAnaliseGemini = "[INICIO DA ANALISE IA GEMINI]"
        let marcadorFimAnaliseGemini = "[FIM DA ANALISE IA GEMINI]"
        var partes: [String] = [
            marcadorInicioAnaliseGemini,
            "Análise IA Gemini",
            "Data: \(item.referenciaExibicao)",
            "Título: \(item.titulo)"
        ]

        adicionarTopico("Resumo", texto: analise.resumo, em: &partes)
        adicionarTopico("Explicação", texto: analise.explicacao, em: &partes)
        adicionarLista("Ideias principais", itens: analise.ideiasPrincipais, em: &partes)
        adicionarTopico("Reflexão prática", texto: analise.reflexao, em: &partes)
        adicionarLista("Perguntas para meditação", itens: analise.perguntas, em: &partes)
        partes.append(marcadorFimAnaliseGemini)

        return partes.joined(separator: "\n\n")
    }

    nonisolated static func adicionarTopico(
        _ titulo: String,
        texto: String,
        em partes: inout [String]
    ) {
        let textoLimpo = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard textoLimpo.isEmpty == false else {
            return
        }

        partes.append("\(titulo):\n\(textoLimpo)")
    }

    nonisolated static func adicionarLista(
        _ titulo: String,
        itens: [String],
        em partes: inout [String]
    ) {
        let itensLimpos = itens
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }

        guard itensLimpos.isEmpty == false else {
            return
        }

        let lista = itensLimpos.map { "- \($0)" }.joined(separator: "\n")
        partes.append("\(titulo):\n\(lista)")
    }

    nonisolated static func promptAnaliseExterna(item: BreviarioItem) -> String {
        """
        Analise integralmente a leitura abaixo, sem ignorar o final do texto nem as notas de rodape.
        Regra de confiabilidade obrigatoria:
        - Nao invente fatos, autores, referencias, datas, interpretacoes historicas ou doutrinarias.
        - Use como base apenas o texto integral fornecido abaixo e suas notas de rodape.
        - Se a resposta exigir contexto alem do texto fornecido, informe claramente que a base e insuficiente.
        - Quando houver cruzamento futuro com outras fontes, utilize somente obras oficiais importadas no app ou canais comprovadamente oficiais e regulares, como Grandes Lojas, Grandes Orientes, potencias maconicas regulares e documentos institucionais oficiais.
        - Nao utilize blogs, foruns, opinioes anonimas, fontes sem autoria, fontes nao regulares ou material sem comprovacao oficial.
        - Diferencie o que esta literalmente fundamentado no texto do que e apenas uma interpretacao prudente.
        Responda somente em JSON valido, sem markdown, sem ``` e sem texto antes/depois.
        Use exatamente estas chaves:
        {
          "resumo": "texto",
          "explicacao": "texto",
          "ideiasPrincipais": ["item 1", "item 2", "item 3"],
          "reflexao": "texto",
          "perguntas": ["pergunta 1", "pergunta 2"],
          "fontes": ["texto integral fornecido", "notas de rodape fornecidas"],
          "avisoConfiabilidade": "informe aqui se algum ponto nao puder ser confirmado pela base fornecida; use vazio ou null quando tudo estiver sustentado no texto"
        }

        \(item.conteudoIntegralParaIA)
        """
    }

    nonisolated static func decodificarAnaliseExterna(_ texto: String) -> AnaliseIA {
        let textoLimpo = texto
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```JSON", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let jsonTexto: String
        if let inicio = textoLimpo.firstIndex(of: "{"),
           let fim = textoLimpo.lastIndex(of: "}"),
           inicio <= fim {
            jsonTexto = String(textoLimpo[inicio...fim])
        } else {
            jsonTexto = textoLimpo
        }

        if let dados = jsonTexto.data(using: .utf8),
           let payload = try? JSONDecoder().decode(PayloadAnaliseExterna.self, from: dados) {
            return AnaliseIA(
                resumo: payload.resumo,
                explicacao: payload.explicacao,
                ideiasPrincipais: payload.ideiasPrincipais,
                reflexao: payload.reflexao,
                perguntas: payload.perguntas,
                fontes: payload.fontes ?? [],
                avisoConfiabilidade: payload.avisoConfiabilidade,
                geradoEm: Date()
            )
        }

        let linhas = textoLimpo
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
        let resumo = linhas.first ?? "Análise importada externamente."

        return AnaliseIA(
            resumo: resumo,
            explicacao: textoLimpo,
            ideiasPrincipais: [],
            reflexao: "",
            perguntas: [],
            geradoEm: Date()
        )
    }

    struct PayloadAnaliseExterna: Codable {
        let resumo: String
        let explicacao: String
        let ideiasPrincipais: [String]
        let reflexao: String
        let perguntas: [String]
        let fontes: [String]?
        let avisoConfiabilidade: String?
    }

    nonisolated static func gerarArquivoTextoExportacao(
        itens: [BreviarioItem],
        incluirComentarios: Bool
    ) throws -> URL {
        let nomeArquivo = "Breviario-Exportacao-\(Int(Date().timeIntervalSince1970)).txt"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(nomeArquivo)

        let conteudo = itens.map { item in
            var partes = [
                item.cabecalhoDocumental,
                item.referenciaExibicao,
                item.titulo,
                Self.justificarTextoParaCompartilhamento(item.texto, chamadasRodape: item.chamadasRodape)
            ]

            if let rodape = item.rodape?.trimmingCharacters(in: .whitespacesAndNewlines),
               rodape.isEmpty == false {
                let rodapeFormatado = Self.justificarRodapeParaCompartilhamento(
                    rodape,
                    chamadasRodape: item.chamadasRodape
                )
                partes.append("--------------------\n\nNotas de rodapé:\n\n\(rodapeFormatado)")
            }

            if incluirComentarios {
                let comentario = item.comentarioSalvo.trimmingCharacters(in: .whitespacesAndNewlines)
                if comentario.isEmpty == false {
                    partes.append("--------------------\n\nComentário pessoal:\n\n\(Self.justificarTextoParaCompartilhamento(comentario, chamadasRodape: item.chamadasRodape))")
                }
            }

            if let autor = item.autorDocumental { partes.append("Autor: \(autor)") }
            return partes.joined(separator: "\n\n")
        }.joined(separator: "\n\n====================\n\n")

        try conteudo.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
