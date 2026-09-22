import SwiftUI
import UniformTypeIdentifiers
import UIKit

extension HomeView {
var detalhe: some View {
        ZStack {

            temaLeitura.background
            .ignoresSafeArea()

            if let item = itemSelecionado {
                GeometryReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {

                            VStack(alignment: .leading, spacing: 10) {
                                Text(item.obraID == ObraID.breviarioSeculoXXI
                                     ? BreviarioImportService.cabecalho : store.obraSelecionada.titulo)
                                    .font(.largeTitle)
                                    .foregroundColor(temaLeitura.destaque)
                                    .bold()

                            if modoLeituraSemDistracoes == false {
                                HStack(alignment: .center, spacing: 12) {
                                    if let autor = item.autor ?? store.obraSelecionada.autor,
                                       !autor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        Text("Autor: \(autor)")
                                            .font(.headline)
                                            .foregroundColor(temaLeitura.textoSecundario)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .layoutPriority(1)
                                    }

                                    Spacer(minLength: 12)

                                    botaoIALeitura()
                                }
                            }

                            Text("\(store.obraSelecionada.tipo.referenciaSingular): \(item.referenciaExibicao)")
                                .foregroundColor(temaLeitura.textoSecundario)

                            if modoLeituraSemDistracoes == false {
                                Label(item.tempoLeituraEstimado, systemImage: "clock")
                                    .font(.caption)
                                    .foregroundColor(temaLeitura.textoSecundario)
                            }

                            if modoLeituraSemDistracoes == false,
                               obraSelecionadaEhDiaria,
                               let pagina = item.pagina {
                                Text("Página \(pagina)")
                                    .font(.caption)
                                    .foregroundColor(temaLeitura.textoSecundario)
                            }

                            if modoLeituraSemDistracoes == false {
                                HStack(spacing: 8) {
                                    if favoritos.contains(item.data) {
                                        marcadorLeitura("Favorito", icone: "star.fill")
                                    }

                                    if leiturasConcluidas.contains(item.data) {
                                        marcadorLeitura("Lido", icone: "checkmark.seal.fill")
                                    }
                                }
                            }

                            controlesLeitura(item)

                            Text(tituloPrincipalLeitura(item))
                                .font(.title)
                                .foregroundColor(temaLeitura.destaque)

                            if leituraContinuaDaObraAtiva {
                                Label(
                                    "Leitura contínua sem quebra visual por páginas",
                                    systemImage: "text.alignleft"
                                )
                                .font(.caption)
                                .foregroundColor(temaLeitura.textoSecundario)
                            }

                            if let frase = item.fraseExibicao, leituraContinuaDaObraAtiva == false {
                                Text(frase)
                                    .font(.headline)
                                    .foregroundColor(temaLeitura.textoPrincipal.opacity(0.9))
                            }
                        }

                        if leituraContinuaDaObraAtiva {
                            leituraContinuaObraView(itemSelecionado: item)
                        } else {
                            textoLeituraView(item)

                            paginaOriginalPDFView(item)

                            rodapeLeituraView(item)
                        }

                            if modoLeituraSemDistracoes == false {
                                VStack(alignment: .leading, spacing: 10) {

                                    Text("Minha reflexão de hoje")
                                        .font(.headline)
                                        .foregroundColor(temaLeitura.destaque)

                                    Text("Registre com suas palavras o principal aprendizado e uma aplicação prática.")
                                        .font(.caption)
                                        .foregroundColor(temaLeitura.textoSecundario)

                                    JustifiedEditableTextView(
                                        texto: $reflexaoPessoal,
                                        font: UIFont.systemFont(ofSize: CGFloat(tamanhoTextoLeitura)),
                                        color: temaLeitura.textoUIColor,
                                        lineSpacing: CGFloat(espacamentoTextoLeitura),
                                        backgroundColor: UIColor(temaLeitura.painel)
                                    )
                                    .frame(maxWidth: .infinity, minHeight: 180)
                                    .padding(8)
                                    .background(temaLeitura.painel)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                    Button {
                                        ReflexoesService.salvar(
                                            reflexaoPessoal,
                                            para: item.data,
                                            obraID: item.obraID
                                        )
                                        atualizarConteudoPremiumCache()
                                        mensagemErro = "Reflexão salva com sucesso."
                                    } label: {
                                        Label("Salvar reflexão", systemImage: "checkmark.circle")
                                    }
                                    .buttonStyle(.borderedProminent)

                                    Divider()

                                    HStack(spacing: 10) {
                                        Text("Comentário")
                                            .font(.headline)
                                            .foregroundColor(temaLeitura.destaque)

                                    Spacer()

                                    Button {
                                        withAnimation(.easeInOut(duration: 0.22)) {
                                            comentarioExpandido.toggle()
                                        }
                                    } label: {
                                        Label(
                                            comentarioExpandido ? "Recolher" : "Expandir",
                                            systemImage: comentarioExpandido
                                                ? "arrow.down.right.and.arrow.up.left"
                                                : "arrow.up.left.and.arrow.down.right"
                                        )
                                        .font(.subheadline)
                                    }
                                    .buttonStyle(.bordered)
                                    .accessibilityLabel(
                                        comentarioExpandido
                                            ? "Recolher campo de comentário"
                                            : "Expandir campo de comentário"
                                    )
                                }

                                JustifiedEditableTextView(
                                    texto: $comentario,
                                    font: UIFont.systemFont(ofSize: CGFloat(tamanhoTextoLeitura)),
                                    color: temaLeitura.textoUIColor,
                                    lineSpacing: CGFloat(espacamentoTextoLeitura),
                                    backgroundColor: UIColor(temaLeitura.painel)
                                )
                                    .frame(maxWidth: .infinity, minHeight: alturaMinimaCampoComentario)
                                    .padding(8)
                                    .background(temaLeitura.painel)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                HStack(spacing: 12) {
                                    Button {
                                    CommentsService.salvar(
                                        comentario: comentario,
                                        para: item.data,
                                        obraID: item.obraID
                                    )
                                    atualizarComentariosCache()
                                    mensagemErro = "Comentário salvo com sucesso."
                                } label: {
                                    Label("Salvar", systemImage: "checkmark.circle")
                                }
                                    .buttonStyle(.borderedProminent)

                                    Button {
                                        mostrandoEditor = true
                                    } label: {
                                        Label("Editar texto", systemImage: "pencil")
                                    }
                                    .buttonStyle(.bordered)
                                }

                                MarcadoresLeituraView(
                                    destaques: destaques,
                                    novoDestaque: $novoDestaque,
                                    trechoSelecionado: trechoSelecionadoTexto,
                                    tema: temaLeitura,
                                    adicionarSelecao: {
                                        salvarDestaque(texto: trechoSelecionadoTexto, item: item)
                                    },
                                    adicionar: {
                                        salvarDestaque(texto: novoDestaque, item: item)
                                    },
                                    remover: { destaque in
                                        DestaquesService.remover(destaque, de: item.data, obraID: item.obraID)
                                        destaques = DestaquesService.carregar(data: item.data, obraID: item.obraID)
                                        mensagemErro = "Marcador removido com sucesso."
                                    },
                                    exportar: {
                                        exportarDestaques(item: item)
                                    }
                                )

                                if let mensagemErro {
                                    Text(mensagemErro)
                                        .font(.caption)
                                        .foregroundColor(.red.opacity(0.9))
                                }
                                }
                            }
                        }
                        .padding()
                        .frame(
                            width: min(max(proxy.size.width, 1), 760),
                            alignment: .leading
                        )
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            } else {
                ContentUnavailableView(
                    store.progressoImportacao ?? (store.importando ? "Importando PDF..." : "Selecione uma leitura"),
                    systemImage: store.importando ? "doc.text.magnifyingglass" : "book",
                    description: Text(store.erro ?? "Escolha uma data ou texto na lista para iniciar a leitura.")
                )
                .foregroundColor(temaLeitura.textoPrincipal)
            }
        }
        .sheet(isPresented: $mostrandoEditor) {
            if let item = itemSelecionado {
                EditarTextoDiarioView(item: item) { edicao in
                    store.salvarEdicao(item: item, edicao: edicao)
                    mostrandoEditor = false
                    mensagemErro = "Texto diário salvo com sucesso."
                } restaurarOriginal: {
                    store.removerEdicao(item: item)
                    mostrandoEditor = false
                    mensagemErro = "Texto original restaurado com sucesso."
                }
            } else {
                ContentUnavailableView("Nenhuma leitura selecionada", systemImage: "book")
            }
        }
        .fullScreenCover(isPresented: $mostrandoLeituraTelaCheia) {
            if let item = itemSelecionado {
                LeituraTelaCheiaView(
                    item: item,
                    itensContinuos: leituraContinuaDaObraAtiva ? itensLeituraContinua(centralizadoEm: item) : [],
                    tamanhoTexto: tamanhoTextoLeitura,
                    espacamentoTexto: espacamentoTextoLeitura,
                    tema: temaLeitura
                ) {
                    mostrandoLeituraTelaCheia = false
                    voltarParaHome()
                }
            } else {
                ContentUnavailableView("Nenhuma leitura selecionada", systemImage: "book")
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 60, coordinateSpace: .local)
                .onEnded { valor in
                    guard itemSelecionadoID != nil else {
                        return
                    }

                    if gestoHorizontalParaDireita(valor) {
                        voltarParaHome()
                    } else if gestoHorizontalParaEsquerda(valor) {
                        avancarDia()
                    }
                }
        )
        .preferredColorScheme(temaLeitura.preferredColorScheme)
        .onReceive(NotificationCenter.default.publisher(for: DestaquesService.alterados).receive(on: RunLoop.main)) { notification in
            guard let item = itemSelecionado,
                  notification.userInfo?["obraID"] as? String == item.obraID,
                  notification.userInfo?["data"] as? String == item.data else { return }
            destaques = DestaquesService.carregar(data: item.data, obraID: item.obraID)
        }
    }

    func tituloPrincipalLeitura(_ item: BreviarioItem) -> String {
        leituraContinuaDaObraAtiva ? store.obraSelecionada.titulo : item.titulo
    }

    static func normalizarBuscaAcervo(_ texto: String) -> String {
        texto
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR"))
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func itensLeituraContinua(centralizadoEm item: BreviarioItem) -> [BreviarioItem] {
        Self.itensLeituraContinua(store.itens, aPartirDe: item)
    }

    static func itensLeituraContinua(_ itens: [BreviarioItem], aPartirDe item: BreviarioItem) -> [BreviarioItem] {
        let itensDaObra = itens
            .filter { $0.obraID == item.obraID }
            .sorted {
                let paginaA = $0.pagina ?? Int.max
                let paginaB = $1.pagina ?? Int.max
                if paginaA == paginaB {
                    return $0.id < $1.id
                }
                return paginaA < paginaB
            }

        guard let inicio = itensDaObra.firstIndex(where: { $0.chavePersistencia == item.chavePersistencia }) else {
            return [item]
        }
        return Array(itensDaObra[inicio...])
    }

    func textoLeituraView(_ item: BreviarioItem) -> some View {
        TextoMarcavelDaPagina(
            item: item,
            tamanhoTexto: tamanhoTextoLeitura,
            espacamentoTexto: espacamentoTextoLeitura,
            tema: temaLeitura,
            aoSelecionarTexto: { trecho in
                // The manual panel belongs to the selected page, not every page in continuous mode.
                guard item.chavePersistencia == itemSelecionado?.chavePersistencia else { return }
                trechoSelecionadoTexto = trecho
                if trecho.isEmpty == false {
                    novoDestaque = trecho
                }
            },
            aoSalvar: {
                mensagemErro = "Marcador salvo: \(item.referenciaExibicao)"
            }
        )
        .id(item.chavePersistencia)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    func rodapeLeituraView(_ item: BreviarioItem) -> some View {
        if let rodape = item.rodape?.trimmingCharacters(in: .whitespacesAndNewlines),
           rodape.isEmpty == false {
            RodapeLeituraView(
                texto: rodape,
                chamadasRodape: item.chamadasRodape,
                tamanhoTexto: max(tamanhoTextoLeitura - 2, 13),
                espacamentoLinhas: espacamentoTextoLeitura + 1,
                tema: temaLeitura
            )
            .padding(.top, 18)
        }
    }

    func leituraContinuaObraView(itemSelecionado: BreviarioItem) -> some View {
        LazyVStack(alignment: .leading, spacing: 18) {
            ForEach(itensLeituraContinua(centralizadoEm: itemSelecionado)) { item in
                VStack(alignment: .leading, spacing: 12) {
                    if modoLeituraSemDistracoes == false,
                       let pagina = item.pagina {
                        Text("p. \(pagina)")
                            .font(.caption2)
                            .fontWeight(item.id == itemSelecionado.id ? .bold : .regular)
                            .foregroundColor(
                                item.id == itemSelecionado.id
                                    ? temaLeitura.destaque
                                    : temaLeitura.textoSecundario.opacity(0.7)
                            )
                            .accessibilityLabel("Página original \(pagina)")
                    }

                    textoLeituraView(item)

                    paginaOriginalPDFView(item)

                    rodapeLeituraView(item)
                }
                .id(item.id)
            }
        }
    }

    @ViewBuilder
    func paginaOriginalPDFView(_ item: BreviarioItem) -> some View {
        PaginaOriginalLeituraView(item: item, tema: temaLeitura)
            .id(item.chavePersistencia)
    }
}
