import SwiftUI
import UIKit

struct IAResumoView: View {
    let item: BreviarioItem
    let analise: AnaliseIA?
    let mensagem: String?
    let tema: TemaLeitura
    @Binding var geminiAPIKey: String
    let gerandoGemini: Bool
    let gerarGemini: () -> Void
    let prepararExterno: () -> Void
    let importarExterno: () -> Void
    let abrirLeitura: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(tema.destaque)
                    .frame(width: 34)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.referenciaExibicao)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(tema.destaque)

                    Text(item.titulo)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(tema.textoPrincipal)

                    Text(item.resumo)
                        .font(.caption)
                        .foregroundStyle(tema.textoSecundario)
                        .lineLimit(3)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Gemini API gratuita", systemImage: "sparkles")
                        .font(.headline)
                        .foregroundStyle(tema.textoPrincipal)

                    SecureField("Chave API Gemini", text: $geminiAPIKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.callout)
                        .foregroundStyle(tema.textoPrincipal)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 11)
                        .background(tema.background.opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(tema.destaque.opacity(0.35), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Text("A chave fica salva neste aparelho e a análise é gravada localmente após a geração.")
                        .font(.caption)
                        .foregroundStyle(tema.textoSecundario)

                    Button {
                        gerarGemini()
                    } label: {
                        HStack(spacing: 12) {
                            if gerandoGemini {
                                ProgressView()
                                    .tint(corTextoBotaoPrincipal)
                            } else {
                                Image(systemName: "wand.and.stars")
                                    .font(.title3)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(gerandoGemini ? "Gerando análise..." : "Gerar com Gemini")
                                    .font(.headline)

                                Text("Usa o texto integral e as notas de rodapé")
                                    .font(.caption)
                                    .fontWeight(.regular)
                                    .opacity(0.86)
                            }

                            Spacer()
                        }
                        .foregroundStyle(corTextoBotaoPrincipal)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(tema.destaque)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .disabled(gerandoGemini || geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(gerandoGemini || geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.62 : 1)
                }
                .padding()
                .background(tema.background.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Button {
                    prepararExterno()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.up.forward.app.fill")
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Abrir ChatGPT")
                                .font(.headline)

                            Text("Prepara o texto completo da leitura")
                                .font(.caption)
                                .fontWeight(.regular)
                                .opacity(0.86)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(corTextoBotaoPrincipal)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(tema.destaque)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        botaoSecundarioIA("Importar resposta", icone: "doc.on.clipboard") {
                            importarExterno()
                        }

                        botaoSecundarioIA("Abrir leitura", icone: "book") {
                            abrirLeitura()
                        }
                    }

                    VStack(spacing: 10) {
                        botaoSecundarioIA("Importar resposta", icone: "doc.on.clipboard") {
                            importarExterno()
                        }

                        botaoSecundarioIA("Abrir leitura", icone: "book") {
                            abrirLeitura()
                        }
                    }
                }
            }

            if let mensagem, mensagem.isEmpty == false {
                Label(mensagem, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(tema.textoSecundario)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(tema.painel.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if let analise {
                GrupoAnaliseIA(titulo: "Resumo", texto: analise.resumo, icone: "text.alignleft", tema: tema)
                GrupoAnaliseIA(titulo: "Explicação", texto: analise.explicacao, icone: "lightbulb", tema: tema)

                if analise.ideiasPrincipais.isEmpty == false {
                    GrupoListaAnaliseIA(titulo: "Ideias principais", itens: analise.ideiasPrincipais, icone: "list.bullet", tema: tema)
                }

                GrupoAnaliseIA(titulo: "Reflexão prática", texto: analise.reflexao, icone: "person.text.rectangle", tema: tema)

                if analise.perguntas.isEmpty == false {
                    GrupoListaAnaliseIA(titulo: "Perguntas para meditação", itens: analise.perguntas, icone: "questionmark.circle", tema: tema)
                }

                if analise.fontes.isEmpty == false {
                    GrupoListaAnaliseIA(titulo: "Base consultada", itens: analise.fontes, icone: "checkmark.shield", tema: tema)
                }

                if let aviso = analise.avisoConfiabilidade,
                   aviso.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                    GrupoAnaliseIA(titulo: "Confiabilidade", texto: aviso, icone: "exclamationmark.shield", tema: tema)
                }
            } else {
                Text("Nenhuma análise salva para esta leitura.")
                    .font(.callout)
                    .foregroundStyle(tema.textoSecundario)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(tema.painel)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(tema.painel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var corTextoBotaoPrincipal: Color {
        switch tema {
        case .escuro:
            .black
        case .claro, .sepia:
            .white
        }
    }

    private func botaoSecundarioIA(
        _ titulo: String,
        icone: String,
        acao: @escaping () -> Void
    ) -> some View {
        Button(action: acao) {
            HStack(spacing: 8) {
                Image(systemName: icone)
                    .font(.subheadline)
                    .frame(width: 18)

                Text(titulo)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 0)
            }
            .foregroundStyle(tema.textoPrincipal)
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(tema.background.opacity(0.42))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(tema.destaque.opacity(0.36), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(titulo)
    }
}

struct GrupoAnaliseIA: View {
    let titulo: String
    let texto: String
    let icone: String
    let tema: TemaLeitura

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(titulo, systemImage: icone)
                .font(.headline)
                .foregroundStyle(tema.destaque)

            Text(texto.isEmpty ? "Sem conteúdo retornado." : texto)
                .font(.body)
                .foregroundStyle(tema.textoPrincipal)
                .textSelection(.enabled)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tema.painel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct GrupoListaAnaliseIA: View {
    let titulo: String
    let itens: [String]
    let icone: String
    let tema: TemaLeitura

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(titulo, systemImage: icone)
                .font(.headline)
                .foregroundStyle(tema.destaque)

            ForEach(Array(itens.enumerated()), id: \.offset) { indice, item in
                Text("\(indice + 1). \(item)")
                    .font(.body)
                    .foregroundStyle(tema.textoPrincipal)
                    .textSelection(.enabled)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tema.painel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct MarcadoresLeituraView: View {
    let destaques: [DestaqueLeitura]
    @Binding var novoDestaque: String
    let trechoSelecionado: String
    let tema: TemaLeitura
    let adicionarSelecao: () -> Void
    let adicionar: () -> Void
    let remover: (DestaqueLeitura) -> Void
    let exportar: () -> Void

    private var possuiSelecao: Bool {
        trechoSelecionado.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Marcadores", systemImage: "highlighter")
                    .font(.headline)
                    .foregroundStyle(tema.destaque)

                Spacer()

                Button {
                    exportar()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .disabled(destaques.isEmpty)
                .accessibilityLabel("Exportar marcadores")
            }

            Text("Selecione um trecho diretamente no texto para salvar e destacar na leitura.")
                .font(.caption)
                .foregroundStyle(tema.textoSecundario)

            if possuiSelecao {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Trecho selecionado")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(tema.destaque)

                    Text(trechoSelecionado)
                        .font(.caption)
                        .foregroundStyle(tema.textoPrincipal)
                        .lineLimit(4)

                    Button {
                        adicionarSelecao()
                    } label: {
                        Label("Destacar seleção", systemImage: "highlighter")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(10)
                .background(tema.destaque.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(tema.destaque.opacity(0.46), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            TextEditor(text: $novoDestaque)
                .frame(minHeight: 78)
                .scrollContentBackground(.hidden)
                .foregroundColor(tema.textoPrincipal)
                .padding(8)
                .background(tema.painel)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Button {
                adicionar()
            } label: {
                Label("Salvar marcador manual", systemImage: "plus.circle")
            }
            .buttonStyle(.bordered)
            .disabled(novoDestaque.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            ForEach(destaques) { destaque in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "quote.opening")
                        .foregroundStyle(tema.destaque)

                    Text(destaque.texto)
                        .font(.callout)
                        .foregroundStyle(tema.textoPrincipal)

                    Spacer()

                    Button(role: .destructive) {
                        remover(destaque)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }
                .padding(10)
                .background(tema.painel)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(tema.painel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct RodapeLeituraView: View {
    let texto: String
    let chamadasRodape: Set<String>
    let tamanhoTexto: Double
    let espacamentoLinhas: Double
    let tema: TemaLeitura

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(tema.destaque.opacity(0.92))
                .frame(height: 3)

            HStack(spacing: 8) {
                Image(systemName: "text.append")
                    .font(.caption)

                Text("RODAPÉ / NOTAS DA OBRA")
                    .font(.caption)
                    .fontWeight(.bold)
            }
            .foregroundColor(tema == .claro ? .white : .black)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tema.destaque.opacity(0.92))

            JustifiedTextView(
                texto: TextoLeituraFormatter.rodapeComNotasEmLinhas(texto, chamadasRodape: chamadasRodape),
                font: UIFont.systemFont(ofSize: CGFloat(tamanhoTexto)),
                color: tema.textoSecundarioUIColor,
                lineSpacing: CGFloat(espacamentoLinhas)
            )
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(tema.painel)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(tema.destaque.opacity(0.7), lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct PaginaOriginalLeituraView: View {
    let item: BreviarioItem
    let tema: TemaLeitura
    @State private var expandida = false

    var body: some View {
        if let midia = item.paginaMidia, let url = midia.urlArquivo {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) { expandida.toggle() }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .foregroundStyle(tema.destaque)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Página original do PDF")
                                .font(.headline)
                                .foregroundStyle(tema.textoPrincipal)
                            Text("Página \(midia.pagina)")
                                .font(.caption)
                                .foregroundStyle(tema.textoSecundario)
                        }
                        Spacer()
                        Image(systemName: expandida ? "chevron.up.circle.fill" : "chevron.down.circle")
                            .foregroundStyle(expandida ? tema.destaque : tema.textoSecundario)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(expandida ? "Ocultar página original do PDF" : "Mostrar página original do PDF")
                .accessibilityValue("Página \(midia.pagina)")
                if expandida { AsyncOriginalPageImage(url: url, tema: tema) }
            }
            .padding()
            .background(tema.painel)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct TextoMarcavelDaPagina: View {
    let item: BreviarioItem
    let tamanhoTexto: Double
    let espacamentoTexto: Double
    let tema: TemaLeitura
    var aoSelecionarTexto: ((String) -> Void)?
    let aoSalvar: () -> Void
    @State private var destaques: [DestaqueLeitura] = []

    var body: some View {
        JustifiedTextView(
            texto: TextoLeituraFormatter.comParagrafosVisiveis(item.texto),
            font: UIFont.systemFont(ofSize: CGFloat(tamanhoTexto)),
            color: tema.textoUIColor,
            lineSpacing: CGFloat(espacamentoTexto),
            chamadasRodape: item.chamadasRodape,
            destaques: destaques.map(\.texto),
            corDestaque: UIColor(tema.destaque.opacity(0.32)),
            aoSelecionarTexto: aoSelecionarTexto,
            aoDestacarTexto: { trecho in
                DestaquesService.salvar(trecho, para: item.data, obraID: item.obraID)
                aoSalvar()
            }
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: item.chavePersistencia) { atualizar() }
        .onReceive(NotificationCenter.default.publisher(for: DestaquesService.alterados).receive(on: RunLoop.main)) { notification in
            guard notification.userInfo?["obraID"] as? String == item.obraID,
                  notification.userInfo?["data"] as? String == item.data else { return }
            atualizar()
        }
    }

    private func atualizar() {
        destaques = DestaquesService.carregar(data: item.data, obraID: item.obraID)
    }
}

struct LeituraTelaCheiaView: View {
    let item: BreviarioItem
    let itensContinuos: [BreviarioItem]
    let tamanhoTexto: Double
    let espacamentoTexto: Double
    let tema: TemaLeitura
    let voltarHome: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var confirmacaoMarcador: String?
    @State private var salvamentoMarcador = 0

    var body: some View {
        ZStack {
            tema.background
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.data)
                                .font(.caption)
                                .foregroundStyle(tema.textoSecundario)

                            Text(item.titulo)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundStyle(tema.destaque)
                        }

                        Spacer()

                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.headline)
                                .frame(width: 36, height: 36)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Fechar tela cheia")
                    }

                    if let frase = item.fraseExibicao {
                        Text(frase)
                            .font(.headline)
                            .foregroundStyle(tema.textoPrincipal.opacity(0.9))
                    }

                    if itensContinuos.isEmpty {
                        textoTelaCheia(item)
                        PaginaOriginalLeituraView(item: item, tema: tema)
                        rodapeTelaCheia(item)
                    } else {
                        LazyVStack(alignment: .leading, spacing: 18) {
                            ForEach(itensContinuos) { itemContinuo in
                                VStack(alignment: .leading, spacing: 12) {
                                    if let pagina = itemContinuo.pagina {
                                        Text("p. \(pagina)")
                                            .font(.caption2)
                                            .foregroundStyle(tema.textoSecundario.opacity(0.7))
                                    }

                                    textoTelaCheia(itemContinuo)
                                    PaginaOriginalLeituraView(item: itemContinuo, tema: tema)
                                    rodapeTelaCheia(itemContinuo)
                                }
                            }
                        }
                    }
                }
                .padding()
                .frame(maxWidth: 760, alignment: .leading)
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 60, coordinateSpace: .local)
                .onEnded { valor in
                    let horizontal = valor.translation.width
                    let vertical = valor.translation.height
                    guard horizontal > 90,
                          abs(horizontal) > abs(vertical) * 1.35 else {
                        return
                    }

                    dismiss()
                    voltarHome()
                }
        )
        .preferredColorScheme(tema.preferredColorScheme)
        .overlay(alignment: .top) {
            if let confirmacaoMarcador {
                Label(confirmacaoMarcador, systemImage: "checkmark.circle.fill")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(Color(red: 0.08, green: 0.35, blue: 0.20), in: RoundedRectangle(cornerRadius: 8))
                    .padding()
                    .accessibilityIdentifier("reading.highlight.saved")
                    .allowsHitTesting(false)
            }
        }
        .task(id: salvamentoMarcador) {
            guard salvamentoMarcador > 0 else { return }
            try? await Task.sleep(for: .seconds(2.8))
            guard !Task.isCancelled else { return }
            confirmacaoMarcador = nil
        }
    }

    private func textoTelaCheia(_ item: BreviarioItem) -> some View {
        TextoMarcavelDaPagina(item: item, tamanhoTexto: tamanhoTexto,
                             espacamentoTexto: espacamentoTexto, tema: tema, aoSalvar: {
                                 confirmacaoMarcador = "Marcador salvo: \(item.referenciaExibicao)"
                                 salvamentoMarcador += 1
                             })
            .id(item.chavePersistencia)
    }

    @ViewBuilder
    private func rodapeTelaCheia(_ item: BreviarioItem) -> some View {
        if let rodape = item.rodape?.trimmingCharacters(in: .whitespacesAndNewlines),
           rodape.isEmpty == false {
            RodapeLeituraView(
                texto: rodape,
                chamadasRodape: item.chamadasRodape,
                tamanhoTexto: max(tamanhoTexto - 2, 13),
                espacamentoLinhas: espacamentoTexto + 1,
                tema: tema
            )
        }
    }
}
