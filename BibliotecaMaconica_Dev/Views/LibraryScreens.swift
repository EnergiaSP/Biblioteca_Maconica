import SwiftUI
import UniformTypeIdentifiers
import UIKit

extension HomeView {
@ViewBuilder
    var leituraDoDiaContainer: some View {
        Group {
            if let item = itemSelecionado ?? store.itemDoDia {
                detalhe
                    .onAppear {
                        if itemSelecionadoID != item.id {
                            itemSelecionadoID = item.id
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                voltarParaListaLeitura()
                            } label: {
                                Image(systemName: "chevron.left")
                                    .frame(width: 34, height: 34)
                            }
                            .disabled(processandoVoltarLeitura)
                            .accessibilityLabel("Voltar")
                        }

                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                abrirMais(.configuracoes)
                            } label: {
                                Image(systemName: "gearshape")
                                    .frame(width: 34, height: 34)
                            }
                            .accessibilityLabel("Configurações")
                        }
                    }
                    .navigationBarBackButtonHidden(true)
            } else {
                ContentUnavailableView(
                    "Nenhuma leitura disponível",
                    systemImage: "book",
                    description: Text("Importe ou restaure os dados do breviário em Configurações.")
                )
                .foregroundStyle(temaLeitura.textoPrincipal)
                .background(temaLeitura.background.ignoresSafeArea())
            }
        }
    }

    @ViewBuilder
    var breviarioContainer: some View {
        lista
            .navigationDestination(for: Int.self) { id in
                detalhe
                    .onAppear {
                        if itemSelecionadoID != id {
                            itemSelecionadoID = id
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                voltarParaListaLeitura()
                            } label: {
                                Image(systemName: "chevron.left")
                                    .frame(width: 34, height: 34)
                            }
                            .disabled(processandoVoltarLeitura)
                            .accessibilityLabel("Voltar")
                        }

                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                abrirMais(.configuracoes)
                            } label: {
                                Image(systemName: "gearshape")
                                    .frame(width: 34, height: 34)
                            }
                            .accessibilityLabel("Configurações")
                        }
                    }
                    .navigationBarBackButtonHidden(true)
            }
    }

    var lista: some View {
        ZStack {
            fundo

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    obraAtualResumoCard

                    grupoListaLeitura("Filtro") {
                        filtroLeituraControle

                        Label(descricaoContagemItens, systemImage: "number")
                            .font(.caption)
                            .foregroundStyle(textoSecundarioApp)
                    }

                    if obraSelecionadaEhDiaria {
                        grupoListaLeitura("Escolher data") {
                            seletorDataSimplesCard
                        }
                    }

                    grupoListaLeitura(tituloGrupoItens) {
                        if itensVisiveis.isEmpty {
                            ContentUnavailableView(
                                filtroLeitura.titulo,
                                systemImage: filtroLeitura.icone,
                                description: Text("Nenhum texto encontrado para este filtro.")
                            )
                            .foregroundStyle(textoApp)
                            .frame(maxWidth: .infinity, minHeight: 180)
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(itensVisiveis) { item in
                                    Button {
                                        abrirItemBreviario(item)
                                    } label: {
                                        LeituraListaRow(
                                            item: item,
                                            favorito: favoritos.contains(item.data),
                                            lido: leiturasConcluidas.contains(item.data),
                                            tema: temaApp,
                                            tipoObra: store.obraSelecionada.tipo
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding()
                .frame(maxWidth: 980, alignment: .leading)
            }
        }
        .navigationTitle(tituloListaLeitura)
        .foregroundStyle(textoApp)
        .tint(destaqueApp)
        .toolbar {
            Button {
                abrirMais(.configuracoes)
            } label: {
                Label("Configurações", systemImage: "gearshape")
            }
        }
        .searchable(text: $busca, prompt: "Buscar")
    }

    var recursosBreviarioCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recursos dos breviários")
                .font(.headline)
                .foregroundStyle(textoApp)
                .padding(.horizontal, 12)
                .padding(.top, 12)

            VStack(alignment: .leading, spacing: 0) {
                linhaSelecaoHome(
                    titulo: "Favoritos",
                    subtitulo: "\(totalFavoritosBreviarios()) leituras salvas nos breviários",
                    icone: "star.fill",
                    cor: .yellow
                ) {
                    abrirRecursoBreviario(.favoritos)
                }

                divisorSelecaoHome

                linhaSelecaoHome(
                    titulo: "Não lidos",
                    subtitulo: "\(totalPendentesBreviarios()) leituras pendentes nos breviários",
                    icone: "circle",
                    cor: .mint
                ) {
                    abrirRecursoBreviario(.naoLidos)
                }

                divisorSelecaoHome

                linhaSelecaoHome(
                    titulo: "Comentários",
                    subtitulo: "\(totalComentariosBreviarios()) textos anotados nos breviários",
                    icone: "text.bubble",
                    cor: .pink
                ) {
                    abrirRecursoBreviario(.comComentarios)
                }

                divisorSelecaoHome

                linhaSelecaoHome(
                    titulo: "Estatísticas",
                    subtitulo: "\(percentualLeituraBreviarios())% dos breviários concluídos",
                    icone: "chart.bar.xaxis",
                    cor: .blue
                ) {
                    abrirMais(.estatisticas)
                }
            }
            .background(temaApp.background.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    var obraAtualResumoCard: some View {
        let obra = store.obraSelecionada

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: obra.area.icone)
                    .font(.title3)
                    .foregroundStyle(destaqueApp)
                    .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 3) {
                    Text(obra.titulo)
                        .font(.headline)
                        .foregroundStyle(textoApp)

                    Text("\(obra.area.titulo) • \(obra.tipo.titulo)")
                        .font(.caption)
                        .foregroundStyle(textoSecundarioApp)
                }

                Spacer()
            }

            if let autor = obra.autor, autor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                Label(autor, systemImage: "person")
                    .font(.caption)
                    .foregroundStyle(textoSecundarioApp)
            }

            if obra.assuntos.isEmpty == false {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(obra.assuntos.prefix(8), id: \.self) { assunto in
                            Text(assunto)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(temaApp == .escuro ? .white : .black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(destaqueApp.opacity(temaApp == .escuro ? 0.24 : 0.16))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding()
        .background(temaApp.painel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    func grupoListaLeitura<Content: View>(
        _ titulo: String,
        @ViewBuilder conteudo: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(titulo)
                .font(.caption)
                .fontWeight(.semibold)
                .textCase(.uppercase)
                .foregroundStyle(textoSecundarioApp)
                .padding(.horizontal, 2)

            conteudo()
        }
    }

    var seletorDataSimplesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "calendar")
                    .foregroundStyle(destaqueApp)
                    .frame(width: 24)

                DatePicker(
                    "Data",
                    selection: $dataEscolhida,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.compact)
                .environment(\.locale, localePortugues)
                .labelsHidden()

                Spacer(minLength: 8)

                Button {
                    abrirData(dataEscolhida)
                } label: {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title3)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Abrir data selecionada")
            }
        }
        .padding()
        .background(temaApp.painel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    var colecoes: some View {
        ZStack {
            fundo

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Coleções temáticas")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(destaqueApp)

                        Text("Leituras agrupadas por temas do índice remissivo e trilhas de estudo.")
                            .font(.subheadline)
                            .foregroundStyle(textoSecundarioApp)
                    }

                    Text("Temas")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(textoApp)

                    LazyVGrid(
                        columns: dynamicTypeSize.isAccessibilitySize
                            ? [GridItem(.flexible())]
                            : [GridItem(.adaptive(minimum: 230), spacing: 12)],
                        spacing: 12
                    ) {
                        ForEach(colecoesTematicas) { colecao in
                            ColecaoTematicaCard(colecao: colecao, tema: temaApp) { item in
                                abrirItemEstudo(item)
                            }
                        }
                    }

                    Text("Trilhas de estudo")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(textoApp)
                        .padding(.top, 8)

                    if carregandoColecoes {
                        ProgressView("Preparando coleções")
                            .tint(destaqueApp)
                            .foregroundStyle(textoSecundarioApp)
                    }

                    ForEach(trilhasDeEstudo) { trilha in
                        TrilhaEstudoCard(trilha: trilha, tema: temaApp) { item in
                            abrirItemEstudo(item)
                        }
                    }

                    if historicoReflexoes.isEmpty == false {
                        Text("Histórico de reflexões")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(textoApp)
                            .padding(.top, 8)

                        ForEach(historicoReflexoes, id: \.item.chavePersistencia) { registro in
                            Button {
                                abrirItemEstudo(registro.item)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(registro.item.referenciaExibicao)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(destaqueApp)

                                        Text(registro.item.titulo)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(textoApp)
                                            .lineLimit(1)

                                        Spacer()
                                    }

                                    Text(registro.texto)
                                        .font(.caption)
                                        .foregroundStyle(textoSecundarioApp)
                                        .lineLimit(3)
                                }
                                .padding()
                                .background(temaApp.painel)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: 980, alignment: .leading)
            }
        }
        .navigationTitle("Coleções")
    }

    var telaMaisView: some View {
        Group {
            switch telaMais {
            case .menu:
                mais
            case .colecoes:
                colecoes
            case .buscaBiblioteca:
                buscaBibliotecaView
            case .dossieEstudo:
                dossieEstudoView
            case .indicesBiblioteca:
                indicesBibliotecaView
            case .acervoOffline:
                acervoOfflineView
            case .fontesOficiais:
                fontesOficiaisView
            case .solicitarObra:
                solicitarObraView
            case .ia:
                iaLeitura
            case .estatisticas:
                estatisticas
            case .configuracoes:
                configuracoes
            }
        }
        .toolbar {
            if telaMais != .menu {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        telaMais = .menu
                    } label: {
                        Label("Mais", systemImage: "chevron.left")
                    }
                }
            }
        }
    }

    var mais: some View {
        ZStack {
            fundo

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Acesse recursos avançados do app.")
                            .font(.subheadline)
                            .foregroundStyle(textoSecundarioApp)
                    }

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 230), spacing: 12)],
                        spacing: 12
                    ) {
                        acaoHome(
                            titulo: "Índices da Biblioteca",
                            subtitulo: "Obras, áreas e índice remissivo geral",
                            icone: "list.bullet.rectangle",
                            cor: .purple
                        ) {
                            telaMais = .indicesBiblioteca
                        }

                        acaoHome(
                            titulo: "Acervo offline",
                            subtitulo: "Baixar uma obra ou todas as obras",
                            icone: "arrow.down.circle",
                            cor: .blue
                        ) {
                            telaMais = .acervoOffline
                        }

                        acaoHome(
                            titulo: "Fontes oficiais",
                            subtitulo: "Referências confiáveis para IA e estudos",
                            icone: "checkmark.shield",
                            cor: .green
                        ) {
                            telaMais = .fontesOficiais
                        }

                        acaoHome(
                            titulo: "Solicitar obra",
                            subtitulo: "Sugerir novos PDFs e títulos",
                            icone: "doc.badge.plus",
                            cor: .orange
                        ) {
                            telaMais = .solicitarObra
                        }

                        acaoHome(
                            titulo: "IA da leitura",
                            subtitulo: analiseIA == nil ? "Resumo e explicação" : "Análise salva",
                            icone: "sparkles.rectangle.stack",
                            cor: .indigo
                        ) {
                            telaMais = .ia
                        }

                    }
                }
                .padding()
                .frame(maxWidth: 980, alignment: .leading)
            }
        }
        .navigationTitle("Recursos avançados")
    }

    var iaLeitura: some View {
        ZStack {
            fundo

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Resumo e explicação gerados sob demanda, salvos localmente para evitar lentidão.")
                            .font(.subheadline)
                            .foregroundStyle(textoSecundarioApp)
                    }

                    if analiseIAAtiva == false {
                        ContentUnavailableView(
                            "IA opcional desativada",
                            systemImage: "sparkles.slash",
                            description: Text("Ative a análise por IA em Configurações somente quando quiser gerar estudos assistidos.")
                        )
                        .foregroundStyle(textoApp)
                        .padding()
                        .background(temaApp.painel)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else if let item = itemSelecionado ?? store.itemDoDia {
                        IAResumoView(
                            item: item,
                            analise: analiseIA,
                            mensagem: mensagemIA,
                            tema: temaApp,
                            geminiAPIKey: $geminiAPIKey,
                            gerandoGemini: gerandoAnaliseGemini,
                            gerarGemini: {
                                gerarAnaliseGemini(item: item)
                            },
                            prepararExterno: {
                                prepararAnaliseExternaNoChatGPT(item: item)
                            },
                            importarExterno: {
                                importarAnaliseExternaCopiada(item: item)
                            },
                            abrirLeitura: {
                                abrirLeitura(item)
                            }
                        )
                    } else {
                        ContentUnavailableView(
                            "Nenhuma leitura selecionada",
                            systemImage: "sparkles.rectangle.stack",
                            description: Text("Abra uma leitura diária para gerar a análise por IA.")
                        )
                    }
                }
                .padding()
                .frame(maxWidth: 860, alignment: .leading)
            }
        }
        .navigationTitle("IA da leitura")
        .onAppear {
            carregarChaveGeminiSeNecessario()
        }
    }
}
