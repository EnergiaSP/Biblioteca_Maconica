import SwiftUI
import UniformTypeIdentifiers
import UIKit

extension HomeView {
var indicesBibliotecaView: some View {
        ZStack {
            fundo

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Índices da Biblioteca")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(destaqueApp)

                        Text("Consulte o acervo por área, obra e índice remissivo geral.")
                            .font(.subheadline)
                            .foregroundStyle(textoSecundarioApp)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Índice por área e obra")
                                .font(.headline)
                                .foregroundStyle(textoApp)

                            Spacer()

                            if carregandoIndiceBiblioteca {
                                ProgressView()
                                    .tint(destaqueApp)
                            }
                        }

                        if indiceBiblioteca.isEmpty && carregandoIndiceBiblioteca == false {
                            Text("As obras importadas aparecerão aqui automaticamente.")
                                .font(.callout)
                                .foregroundStyle(textoSecundarioApp)
                        } else {
                            ForEach(indiceBiblioteca) { area in
                                IndiceAreaBibliotecaCard(area: area, tema: temaApp) { obra in
                                    obraIndicePaginas = obra
                                }
                            }
                        }
                    }
                    .padding()
                    .background(temaApp.painel)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Índice remissivo geral")
                                .font(.headline)
                                .foregroundStyle(textoApp)

                            Spacer()

                            Text("\(indiceRemissivoBiblioteca.count)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(temaApp.textoSobreDestaque)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(temaApp.fundoDestaque)
                                .clipShape(Capsule())
                        }

                        Picker("Escopo", selection: $escopoIndiceBiblioteca) {
                            ForEach(BibliotecaBuscaEscopo.allCases) { escopo in
                                Text(escopo.titulo).tag(escopo)
                            }
                        }
                        .pickerStyle(.segmented)

                        if escopoIndiceBiblioteca == .obraAtual {
                            Picker("Obra", selection: $obraIndiceRemissivoID) {
                                Text("Obra atual: \(store.obraSelecionada.titulo)").tag(String?.none)
                                ForEach(store.obras.filter(\.ativa)) { obra in
                                    Text(obra.titulo).tag(Optional(obra.id))
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(destaqueApp)
                            .accessibilityIdentifier("index.work")
                        }

                        if escopoIndiceBiblioteca == .area {
                            Picker("Área", selection: $areaIndiceBiblioteca) {
                                ForEach(BibliotecaArea.allCases) { area in
                                    Text(area.titulo).tag(area)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(destaqueApp)
                        }

                        if indiceRemissivoBiblioteca.isEmpty && carregandoIndiceBiblioteca == false {
                            Text("O índice remissivo geral será formado pelas obras que possuem índice importado.")
                                .font(.callout)
                                .foregroundStyle(textoSecundarioApp)
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(indiceRemissivoBiblioteca) { entrada in
                                    IndiceRemissivoGlobalRow(entrada: entrada, tema: temaApp) { resultado in
                                        abrirResultadoBuscaBiblioteca(resultado)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .background(temaApp.painel)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding()
                .frame(maxWidth: 980, alignment: .leading)
            }
        }
        .navigationTitle("Índices")
        .sheet(item: $obraIndicePaginas) { obra in
            IndicePaginasObraView(obra: obra, tema: temaApp) { item in
                obraIndicePaginas = nil
                abrirResultadoBuscaBiblioteca(BibliotecaResultadoBusca(obra: obra, item: item, contexto: ""))
            }
        }
        .onAppear {
            carregarIndicesBiblioteca()
        }
        .onChange(of: escopoIndiceBiblioteca) { _, _ in
            carregarIndicesBiblioteca()
        }
        .onChange(of: areaIndiceBiblioteca) { _, _ in
            carregarIndicesBiblioteca()
        }
        .onChange(of: obraIndiceRemissivoID) { _, _ in
            carregarIndicesBiblioteca()
        }
    }

    var fontesOficiaisView: some View {
        ZStack {
            fundo

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Fontes oficiais")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(destaqueApp)

                        Text("Cadastre referências institucionais confiáveis para orientar estudos e análises por IA.")
                            .font(.subheadline)
                            .foregroundStyle(textoSecundarioApp)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        campoSolicitacao("Título da fonte", texto: $fonteTitulo)
                        campoSolicitacao("Origem institucional", texto: $fonteOrigem)
                        campoSolicitacao("URL oficial", texto: $fonteURL)

                        TextEditor(text: $fonteObservacao)
                            .frame(minHeight: 110)
                            .padding(8)
                            .foregroundStyle(textoApp)
                            .scrollContentBackground(.hidden)
                            .background(temaApp.background.opacity(0.36))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        botaoSolicitacao("Salvar fonte oficial", icone: "checkmark.shield") {
                            salvarFonteOficial()
                        }
                    }
                    .padding()
                    .background(temaApp.painel)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    LazyVStack(spacing: 10) {
                        ForEach(store.fontesOficiais) { fonte in
                            FonteOficialCard(
                                fonte: fonte,
                                tema: temaApp,
                                abrir: {
                                    abrirURLFonte(fonte)
                                },
                                remover: {
                                    removerFonteOficial(fonte)
                                }
                            )
                        }
                    }
                }
                .padding()
                .frame(maxWidth: 980, alignment: .leading)
            }
        }
        .navigationTitle("Fontes oficiais")
    }

    var solicitarObraView: some View {
        ZStack {
            fundo

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Solicitar obra")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(destaqueApp)

                        Text("Registre uma sugestão de obra para inclusão futura na biblioteca.")
                            .font(.subheadline)
                            .foregroundStyle(textoSecundarioApp)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Picker("Área", selection: $solicitacaoArea) {
                            ForEach(BibliotecaArea.allCases) { area in
                                Text(area.titulo).tag(area)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(destaqueApp)

                        campoSolicitacao("Título da obra", texto: $solicitacaoTitulo)
                        campoSolicitacao("Autor ou origem", texto: $solicitacaoAutor)

                        TextEditor(text: $solicitacaoObservacao)
                            .frame(minHeight: 150)
                            .padding(8)
                            .foregroundStyle(textoApp)
                            .scrollContentBackground(.hidden)
                            .background(temaApp.background.opacity(0.36))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 10) {
                                botaoSolicitacao("Salvar", icone: "checkmark.circle") {
                                    salvarSolicitacaoObra()
                                }

                                botaoSolicitacao("Compartilhar", icone: "square.and.arrow.up") {
                                    compartilharSolicitacaoObra()
                                }
                            }

                            VStack(spacing: 10) {
                                botaoSolicitacao("Salvar", icone: "checkmark.circle") {
                                    salvarSolicitacaoObra()
                                }

                                botaoSolicitacao("Compartilhar por WhatsApp/e-mail", icone: "square.and.arrow.up") {
                                    compartilharSolicitacaoObra()
                                }
                            }
                        }
                    }
                    .padding()
                    .background(temaApp.painel)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    if solicitacoesObras.isEmpty == false {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Histórico de solicitações")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(textoApp)

                            ForEach(Array(solicitacoesObras.enumerated()), id: \.offset) { _, solicitacao in
                                SolicitacaoObraCard(solicitacao: solicitacao, tema: temaApp)
                            }
                        }
                    }
                }
                .padding()
                .frame(maxWidth: 980, alignment: .leading)
            }
        }
        .navigationTitle("Solicitar obra")
        .onAppear {
            carregarSolicitacoesObras()
        }
    }

    func campoSolicitacao(_ placeholder: String, texto: Binding<String>) -> some View {
        TextField(placeholder, text: texto)
            .textInputAutocapitalization(.words)
            .padding(12)
            .foregroundStyle(textoApp)
            .background(temaApp.background.opacity(0.36))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    func botaoSolicitacao(
        _ titulo: String,
        icone: String,
        acao: @escaping () -> Void
    ) -> some View {
        Button(action: acao) {
            Label(titulo, systemImage: icone)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(destaqueApp)
    }

    var estatisticas: some View {
        ZStack {
            fundo

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Acompanhe o progresso das leituras, favoritos e comentários.")
                            .font(.subheadline)
                            .foregroundStyle(textoSecundarioApp)
                    }

                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: 130), spacing: 10)
                        ],
                        spacing: 10
                    ) {
                        estatistica("Leituras", "\(totalItensBreviarios())")
                        estatistica("Lidas", "\(totalLidasBreviarios())")
                        estatistica("Pendentes", "\(totalPendentesBreviarios())")
                        estatistica("Favoritos", "\(totalFavoritosBreviarios())")
                        estatistica("Notas", "\(totalComentariosBreviarios())")
                        estatistica("Sequência", "\(sequenciaAtual)")
                    }

                    painelProgressoSemanal

                    painelProgressoMensal

                    painelProgressoAnual

                    if itensFavoritos.isEmpty == false {
                        favoritosCard
                    }

                    if itensComComentario.isEmpty == false {
                        notasPessoaisCard
                    }
                }
                .padding()
                .frame(maxWidth: 980, alignment: .leading)
            }
        }
        .navigationTitle("Estatísticas")
    }
}

struct IndicePaginasObraView: View {
    let obra: BibliotecaObra
    let tema: TemaLeitura
    let abrir: (BreviarioItem) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var entradas: [BreviarioItem] = []
    @State private var filtro = ""
    @State private var limite = 50
    @State private var carregando = true
    @State private var erro: String?

    private var filtradas: [BreviarioItem] {
        guard !filtro.isEmpty else { return entradas }
        return entradas.filter { "\($0.referenciaExibicao) \($0.titulo)".localizedStandardContains(filtro) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    Text(obra.titulo).font(.headline)
                    if carregando { ProgressView() }
                    if let erro { Text(erro) }
                    ForEach(Array(filtradas.prefix(limite))) { item in
                        Button { abrir(item) } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(item.referenciaExibicao).font(.caption)
                                    Text(item.titulo).multilineTextAlignment(.leading)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .frame(minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                    if filtradas.count > limite {
                        Button("Carregar mais páginas") { limite += 50 }
                    }
                }
                .padding()
            }
            .background(tema.background)
            .foregroundStyle(tema.textoPrincipal)
            .navigationTitle("Índice de páginas")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $filtro, prompt: "Página ou título")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fechar") { dismiss() } } }
            .onChange(of: filtro) { _, _ in limite = 50 }
            .task {
                let obraAtual = obra
                let resultado = await Task.detached(priority: .userInitiated) {
                    Result { try BreviarioStore.carregarIndicePaginas(obra: obraAtual) }
                }.value
                guard !Task.isCancelled else { return }
                switch resultado {
                case .success(let itens): entradas = itens
                case .failure: erro = "Índice indisponível. Confira se a obra está baixada."
                }
                carregando = false
            }
        }
    }
}
