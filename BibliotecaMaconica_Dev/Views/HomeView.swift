import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct HomeView: View {

    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.openURL) var openURL
    @Environment(\.scenePhase) var scenePhase
    @StateObject var store = BreviarioStore()
    @StateObject var leitorVoz = LeituraVozService()
    @StateObject var navigation = AppNavigationController()
    @ObservedObject private var notificationRouter = NotificationReadingRouter.shared
    @AppStorage("notificacaoDiariaAtiva") var notificacaoDiariaAtiva = false
    @AppStorage("notificacaoDiariaHora") var notificacaoDiariaHora = 8
    @AppStorage("notificacaoDiariaMinuto") var notificacaoDiariaMinuto = 0
    @AppStorage("vozLeituraGenero") var vozLeituraGenero = VozLeituraGenero.feminina.rawValue
    @AppStorage("velocidadeLeitura") var velocidadeLeitura = 0.9
    @AppStorage("tamanhoTextoLeitura") var tamanhoTextoLeitura = 17.0
    @AppStorage("espacamentoTextoLeitura") var espacamentoTextoLeitura = 8.0
    @AppStorage("temaApp") var temaAppRaw = TemaLeitura.escuro.rawValue
    @AppStorage("temaLeitura") var temaLeituraRaw = TemaLeitura.escuro.rawValue
    @AppStorage("modoLeituraSemDistracoes") var modoLeituraSemDistracoes = false
    @AppStorage("modoLeituraLivrosContinuo") var modoLeituraLivrosContinuo = true
    @AppStorage("nomeUsuarioPDFPremium") var nomeUsuarioPDFPremium = ""
    @AppStorage("analiseIAAtiva") var analiseIAAtiva = false
    @AppStorage("obrasNotificacaoIDs") var obrasNotificacaoIDsRaw = ""
    @State var busca = ""
    @State var buscaIndice = ""
    @State var buscaBiblioteca = ""
    @State var escopoBuscaBiblioteca = BibliotecaBuscaEscopo.appTodo
    @State var areaBuscaBiblioteca = BibliotecaArea.breviarios
    @State var resultadosBuscaBiblioteca: [BibliotecaResultadoBusca] = []
    @State var buscaBibliotecaTemMais = false
    @State var obraBuscaBibliotecaID: String?
    @State var filtroMetadadosBiblioteca = BibliotecaFiltroMetadados()
    @State var buscandoBiblioteca = false
    @State var dossieEstudo: BibliotecaDossieEstudo?
    @State var gerandoDossieEstudo = false
    @State var analiseDossieIA = ""
    @State var gerandoAnaliseDossieIA = false
    @State var indiceBiblioteca: [BibliotecaIndiceArea] = []
    @State var obraIndicePaginas: BibliotecaObra?
    @State var indiceRemissivoBiblioteca: [BibliotecaIndiceRemissivoGlobal] = []
    @State var carregandoIndiceBiblioteca = false
    @State var chaveIndiceBibliotecaCache = ""
    @State var escopoIndiceBiblioteca = BibliotecaBuscaEscopo.appTodo
    @State var obraIndiceRemissivoID: String?
    @State var areaIndiceBiblioteca = BibliotecaArea.breviarios
    @State var filtroAcervoOffline = BibliotecaArea.bibliotecaMaconica
    @State var buscaAcervoOffline = ""
    @State var pacotesOffline: [BibliotecaPacoteOfflineEstado] = []
    @State var instalandoPacotesOffline = false
    @State var progressoAcervoOffline = ""
    @State var obraImportacaoID = ObraID.breviarioSeculoXXI
    @State var criarNovaObraImportacao = false
    @State var novaObraTitulo = ""
    @State var novaObraAutor = ""
    @State var novaObraAssuntos = ""
    @State var novaObraArea = BibliotecaArea.bibliotecaMaconica
    @State var novaObraTipo = BibliotecaObraTipo.livro
    @State var solicitacaoArea = BibliotecaArea.bibliotecaMaconica
    @State var solicitacaoTitulo = ""
    @State var solicitacaoAutor = ""
    @State var solicitacaoObservacao = ""
    @State var solicitacoesObras: [SolicitacaoInclusaoObra] = []
    @State var fonteTitulo = ""
    @State var fonteOrigem = ""
    @State var fonteURL = ""
    @State var fonteObservacao = ""
    @State var dataEscolhida = Date()
    @State var calendarioMesExibido = Date()
    @State var itemSelecionadoID: Int?
    @State var comentario = ""
    @State var reflexaoPessoal = ""
    @State var comentarioExpandido = false
    @State var analiseIA: AnaliseIA?
    @State var mensagemIA: String?
    @State var geminiAPIKey = ""
    @State var gerandoAnaliseGemini = false
    @State var novoDestaque = ""
    @State var trechoSelecionadoTexto = ""
    @State var destaques: [DestaqueLeitura] = []
    @State var pdfURL: URL?
    @State var compartilhamento: Compartilhamento?
    @State var mensagemErro: String?
    @State var mensagemErroTask: Task<Void, Never>?
    @State var mostrandoImportador = false
    @State var mostrandoEditor = false
    @State var mostrandoNotificacao = false
    @State var mostrandoExportadorMultiplo = false
    @State var mostrandoLeituraTelaCheia = false
    @State var favoritos: Set<String> = []
    @State var leiturasConcluidas: Set<String> = []
    @State var leiturasRecentes: [String] = []
    @State var filtroLeitura = FiltroLeitura.todos
    @State var colecoesTematicasCache: [ColecaoTematica] = []
    @State var trilhasDeEstudoCache: [TrilhaEstudo] = []
    @State var historicoReflexoesCache: [HistoricoReflexao] = []
    @State var datasComComentarioCache: Set<String> = []
    @State var resumosComentarioCache: [String: String] = [:]
    @State var itensVisiveisCache: [BreviarioItem] = []
    @State var itensRecentesCache: [BreviarioItem] = []
    @State var leiturasDiariasBreviariosCache: [LeituraDiariaBreviario] = []
    @State var leiturasRecentesBreviariosCache: [LeituraRecenteBreviario] = []
    @State var itensFavoritosCache: [BreviarioItem] = []
    @State var itensComComentarioCache: [BreviarioItem] = []
    @State var itensSemanaAtualCache: [BreviarioItem] = []
    @State var itensMesAtualCache: [BreviarioItem] = []
    @State var totalLidasSemanaAtualCache = 0
    @State var totalLidasMesAtualCache = 0
    @State var diasCalendarioMesAtualCache: [DiaCalendarioLeitura] = []
    @State var nomeMesAtualCache = ""
    @State var dataHojeBreviarioCache = ""
    @State var sequenciaAtualCache = 0
    @State var exportandoArquivo = false
    @State var buscaTask: Task<Void, Never>?
    @State var buscaBibliotecaTask: Task<Void, Never>?
    @State var recentesBreviariosTask: Task<Void, Never>?
    @State var conteudoPremiumTask: Task<Void, Never>?
    @State var comentariosTask: Task<Void, Never>?
    @State var telaAberturaTask: Task<Void, Never>?
    @State var carregandoColecoes = false
    @State var appInicializado = false
    @State var processandoVoltarLeitura = false
    @State var aberturaProgramaticaLeitura = false
    @State var urlBreviarioPendente: URL?
    @State var cachesIniciaisAgendados = false
    @State var manterTelaAbertura = true
    @State var mostrandoGeradorAtivacao = false
    @State var areaHomeExpandida: BibliotecaArea?
    @State var expansaoHomeLiberada = false
    @State var secoesConfiguracoesAbertas: Set<ConfiguracaoSecao> = [.aparencia, .leitura]

    let localePortugues = Locale(identifier: "pt_BR")

    var abaSelecionada: Int {
        get { navigation.selectedTab }
        nonmutating set { navigation.selectedTab = newValue }
    }

    var telaMais: TelaMais {
        get { navigation.moreScreen }
        nonmutating set { navigation.moreScreen = newValue }
    }

    var caminhoLeitura: [Int] {
        get { navigation.readingPath }
        nonmutating set { navigation.readingPath = newValue }
    }

    var abaSelecionadaBinding: Binding<Int> {
        Binding(get: { navigation.selectedTab }, set: { navigation.selectedTab = $0 })
    }

    var caminhoLeituraBinding: Binding<[Int]> {
        Binding(get: { navigation.readingPath }, set: { navigation.readingPath = $0 })
    }
    static let formatadorDiaMesCompartilhado: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "dd/MM"
        return formatter
    }()
    static let formatadorMesAnoCompartilhado: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()

    var itemSelecionado: BreviarioItem? {
        guard let itemSelecionadoID else {
            return nil
        }

        return store.item(id: itemSelecionadoID)
    }

    var temaLeitura: TemaLeitura {
        TemaLeitura(rawValue: temaNormalizado(temaLeituraRaw)) ?? .escuro
    }

    var temaApp: TemaLeitura {
        TemaLeitura(rawValue: temaNormalizado(temaAppRaw)) ?? .escuro
    }

    var obrasNotificacaoIDs: Set<String> {
        let ids = obrasNotificacaoIDsRaw
            .split(separator: ",")
            .map(String.init)
            .filter { $0.isEmpty == false }

        if ids.isEmpty {
            return Set(store.obras.filter { $0.tipo == .breviarioDiario }.map(\.id))
        }

        return Set(ids)
    }

    var textoApp: Color {
        temaApp.textoPrincipal
    }

    var textoSecundarioApp: Color {
        temaApp.textoSecundario
    }

    var destaqueApp: Color {
        temaApp.destaque
    }

    var controleNeutroConfiguracoes: Color {
        switch temaApp {
        case .escuro:
            .white
        case .claro, .sepia:
            .black
        }
    }

    var temaSelecionadoConfiguracao: TemaLeitura {
        TemaLeitura(rawValue: temaAppRaw) ?? .escuro
    }

    var vozSelecionadaConfiguracao: VozLeituraGenero {
        VozLeituraGenero(rawValue: vozLeituraGenero) ?? .feminina
    }

    var temaUnificadoBinding: Binding<String> {
        Binding(
            get: { temaAppRaw },
            set: { novoTema in
                aplicarTemaUnificado(novoTema)
            }
        )
    }

    func temaNormalizado(_ rawValue: String) -> String {
        rawValue == "noturno" ? TemaLeitura.escuro.rawValue : rawValue
    }

    func aplicarTemaUnificado(_ rawValue: String) {
        let tema = temaNormalizado(rawValue)

        if temaAppRaw != tema {
            temaAppRaw = tema
        }

        if temaLeituraRaw != tema {
            temaLeituraRaw = tema
        }
    }

    func normalizarTemasSelecionados() {
        aplicarTemaUnificado(temaAppRaw)
    }

    func carregarChaveGeminiSeNecessario() {
        guard geminiAPIKey.isEmpty else {
            return
        }

        geminiAPIKey = GeminiAPIKeyStore.carregar()
    }

    var comentarioAtualTrimmed: String {
        comentario.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var alturaMinimaCampoComentario: CGFloat {
        if comentarioExpandido {
            horizontalSizeClass == .regular ? 760 : 620
        } else {
            280
        }
    }

    var itensRecentes: [BreviarioItem] {
        itensRecentesCache
    }

    var itensFavoritos: [BreviarioItem] {
        itensFavoritosCache
    }

    var itensComComentario: [BreviarioItem] {
        itensComComentarioCache
    }

    var historicoReflexoes: [HistoricoReflexao] {
        historicoReflexoesCache
    }

    var colecoesTematicas: [ColecaoTematica] {
        colecoesTematicasCache
    }

    var trilhasDeEstudo: [TrilhaEstudo] {
        trilhasDeEstudoCache
    }

    var totalLeituras: Int {
        store.itens.count
    }

    var totalLidas: Int {
        leiturasConcluidas.count
    }

    var progressoLeitura: Double {
        ReadingMetricsController.progress(completed: totalLidas, total: totalLeituras)
    }

    var percentualLeitura: Int {
        ReadingMetricsController.percentage(completed: totalLidas, total: totalLeituras)
    }

    var itensSemanaAtual: [BreviarioItem] {
        itensSemanaAtualCache
    }

    var totalLidasSemanaAtual: Int {
        totalLidasSemanaAtualCache
    }

    var progressoSemanaAtual: Double {
        ReadingMetricsController.progress(completed: totalLidasSemanaAtual, total: itensSemanaAtual.count)
    }

    var percentualSemanaAtual: Int {
        ReadingMetricsController.percentage(completed: totalLidasSemanaAtual, total: itensSemanaAtual.count)
    }

    var itensMesAtual: [BreviarioItem] {
        itensMesAtualCache
    }

    var totalLidasMesAtual: Int {
        totalLidasMesAtualCache
    }

    var progressoMesAtual: Double {
        ReadingMetricsController.progress(completed: totalLidasMesAtual, total: itensMesAtual.count)
    }

    var percentualMesAtual: Int {
        ReadingMetricsController.percentage(completed: totalLidasMesAtual, total: itensMesAtual.count)
    }

    var nomeMesAtual: String {
        nomeMesAtualCache
    }

    var diasSemanaCalendario: [String] {
        ["Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sab"]
    }

    var dataHojeBreviario: String {
        dataHojeBreviarioCache
    }

    var tituloListaLeitura: String {
        switch filtroLeitura {
        case .favoritos:
            "Favorito"
        case .naoLidos:
            "Não Lido"
        case .comComentarios:
            "Comentário"
        default:
            store.obraSelecionada.tipo == .breviarioDiario ? "Breviário" : store.obraSelecionada.titulo
        }
    }

    var obraSelecionadaEhDiaria: Bool {
        store.obraSelecionada.tipo == .breviarioDiario
    }

    var leituraContinuaDaObraAtiva: Bool {
        modoLeituraLivrosContinuo && obraSelecionadaEhDiaria == false
    }

    var pacotesOfflineFiltrados: [BibliotecaPacoteOfflineEstado] {
        let termo = buscaAcervoOffline.trimmingCharacters(in: .whitespacesAndNewlines)
        guard termo.isEmpty == false else {
            return pacotesOffline
        }

        let termoNormalizado = Self.normalizarBuscaAcervo(termo)
        return pacotesOffline.filter {
            Self.normalizarBuscaAcervo($0.titulo).contains(termoNormalizado)
        }
    }

    var tituloGrupoItens: String {
        store.obraSelecionada.tipo.tituloLista
    }

    var descricaoContagemItens: String {
        let unidade = obraSelecionadaEhDiaria ? "textos encontrados" : "\(store.obraSelecionada.tipo.tituloLista.lowercased()) encontrados"
        return "\(itensVisiveis.count) \(unidade)"
    }

    var diasCalendarioMesAtual: [DiaCalendarioLeitura] {
        diasCalendarioMesAtualCache
    }

    func montarDiasCalendarioMesAtual() -> [DiaCalendarioLeitura] {
        let calendario = Calendar.current
        let componentes = calendario.dateComponents([.year, .month], from: calendarioMesExibido)

        guard let primeiroDia = calendario.date(from: componentes),
              let intervaloDias = calendario.range(of: .day, in: .month, for: primeiroDia) else {
            return []
        }

        let mesAtual = calendario.component(.month, from: primeiroDia)
        let deslocamentoInicial = calendario.component(.weekday, from: primeiroDia) - 1
        var dias: [DiaCalendarioLeitura] = (0..<deslocamentoInicial).map { indice in
            DiaCalendarioLeitura(id: "vazio-\(indice)", dia: nil, data: nil, item: nil)
        }

        dias.append(contentsOf: intervaloDias.map { dia in
            let data = String(format: "%02d/%02d", dia, mesAtual)
            return DiaCalendarioLeitura(
                id: data,
                dia: dia,
                data: data,
                item: store.item(data: data)
            )
        })

        return dias
    }

    func montarItensSemanaAtual() -> [BreviarioItem] {
        let calendario = Calendar.current
        let hoje = Date()
        let inicioSemana = calendario.dateInterval(of: .weekOfYear, for: hoje)?.start ?? hoje

        let datasSemana = (0..<7).compactMap { offset in
            calendario.date(byAdding: .day, value: offset, to: inicioSemana)
        }.map { Self.formatadorDiaMesCompartilhado.string(from: $0) }

        return datasSemana.compactMap { store.item(data: $0) }
    }

    func montarItensMesAtual() -> [BreviarioItem] {
        let mesAtual = Calendar.current.component(.month, from: Date())
        return store.itens.filter { mesDaData($0.data) == mesAtual }
    }

    func montarNomeMesAtual() -> String {
        Self.formatadorMesAnoCompartilhado.string(from: calendarioMesExibido).capitalized
    }

    var sequenciaAtual: Int {
        sequenciaAtualCache
    }

    var itensVisiveis: [BreviarioItem] {
        itensVisiveisCache
    }

    var body: some View {
        ZStack {
            TabView(selection: abaSelecionadaBinding) {
                NavigationStack {
                    paginaInicial
                }
                .tabItem {
                    Label("Início", systemImage: "house")
                }
                .accessibilityIdentifier("tab.inicio")
                .tag(0)

                NavigationStack {
                    colecoes
                }
                .tabItem {
                    Label("Coleções", systemImage: "square.grid.2x2")
                }
                .accessibilityIdentifier("tab.colecoes")
                .tag(1)

                NavigationStack {
                    dossieEstudoView
                }
                .tabItem {
                    Label("Dossiê", systemImage: "rectangle.stack.badge.person.crop")
                }
                .accessibilityIdentifier("tab.dossie")
                .tag(2)

                NavigationStack(path: caminhoLeituraBinding) {
                    breviarioContainer
                }
                .id(navigation.readingStackID)
                .tabItem {
                    Label("Acervo", systemImage: "books.vertical")
                }
                .accessibilityIdentifier("tab.acervo")
                .tag(3)

                NavigationStack {
                    telaMaisView
                }
                .tabItem {
                    Label("Mais", systemImage: "ellipsis.circle")
                }
                .accessibilityIdentifier("tab.mais")
                .tag(4)
            }

            if manterTelaAbertura {
                telaAberturaCarregamento
            }

            if let mensagemErro {
                avisoGlobal(mensagemErro)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(20)
            }
        }
        .preferredColorScheme(temaApp.preferredColorScheme)
        .environment(\.locale, localePortugues)
        .simultaneousGesture(
            DragGesture(minimumDistance: 60, coordinateSpace: .local)
                .onEnded { valor in
                    guard gestoHorizontalParaDireita(valor) else {
                        return
                    }

                    voltarParaHome()
                }
        )
        .onAppear {
            normalizarTemasSelecionados()
            if appInicializado == false {
                appInicializado = true
                fecharCaixasHome()
                if itemSelecionadoID == nil {
                    itemSelecionadoID = store.itemDoDia?.id
                }
                prepararCachesIniciais()
                iniciarTelaAberturaTemporizada()
            }
            let itemInicial = itemSelecionado ?? store.itemDoDia
            comentario = itemInicial?.comentarioSalvo ?? ""
            if let item = itemInicial {
                reflexaoPessoal = ReflexoesService.carregar(data: item.data, obraID: item.obraID)
                analiseIA = AnaliseIAService.carregar(data: item.data, obraID: item.obraID)
                destaques = DestaquesService.carregar(data: item.data, obraID: item.obraID)
            }
        }
        .onChange(of: abaSelecionada) { _, novaAba in
            aoMudarAba(novaAba)
        }
        .onChange(of: caminhoLeitura) { _, novoCaminho in
            aoMudarCaminhoLeitura(novoCaminho)
        }
        .onChange(of: busca) { _, _ in
            agendarAtualizacaoBusca()
        }
        .onChange(of: filtroLeitura) { _, _ in
            atualizarItensVisiveisCache()
        }
        .onChange(of: temaAppRaw) { _, novoTema in
            aplicarTemaUnificado(novoTema)
        }
        .onChange(of: temaLeituraRaw) { _, novoTema in
            aplicarTemaUnificado(novoTema)
        }
        .onChange(of: mensagemErro) { _, novaMensagem in
            agendarOcultacaoMensagem(novaMensagem)
        }
        .onChange(of: itemSelecionadoID) { _, _ in
            leitorVoz.parar()
            guard let item = itemSelecionado else {
                comentario = ""
                reflexaoPessoal = ""
                analiseIA = nil
                mensagemIA = nil
                destaques = []
                novoDestaque = ""
                trechoSelecionadoTexto = ""
                pdfURL = nil
                mensagemErro = nil
                mostrandoEditor = false
                mostrandoLeituraTelaCheia = false
                return
            }

            comentario = item.comentarioSalvo
            reflexaoPessoal = ReflexoesService.carregar(data: item.data, obraID: item.obraID)
            analiseIA = AnaliseIAService.carregar(data: item.data, obraID: item.obraID)
            mensagemIA = nil
            destaques = DestaquesService.carregar(data: item.data, obraID: item.obraID)
            novoDestaque = ""
            trechoSelecionadoTexto = ""
            pdfURL = nil
            mensagemErro = nil
            mostrandoEditor = false
            registrarLeituraAberta(item)
        }
        .onChange(of: scenePhase) { _, novaFase in
            if novaFase == .active, abaSelecionada == 0 {
                fecharCaixasHome()
            }
        }
        .onReceive(store.$itens) { _ in
            chaveIndiceBibliotecaCache = ""
            prepararEstadoAposCarregamento()
            atualizarProgressoLeitura()
            atualizarItensVisiveisCache()
            agendarAtualizacaoComentariosCache()
            processarURLBreviarioPendenteSePossivel()
        }
        .onChange(of: store.carregando) { _, carregando in
            // @Published emits items before indexes and loading state are updated.
            guard !carregando else { return }
            prepararEstadoAposCarregamento()
            processarURLBreviarioPendenteSePossivel()
        }
        .onChange(of: notificationRouter.pendingURL, initial: true) { _, url in
            guard let url else { return }
            abrirURLBreviario(url)
            notificationRouter.consume(url)
        }
        .onReceive(NotificationCenter.default.publisher(for: .progressoLeituraSincronizado)) { _ in
            atualizarProgressoLeitura()
            atualizarItensVisiveisCache()
            atualizarRecentesBreviariosCache()
            agendarAtualizacaoComentariosCache()
        }
        .fileImporter(
            isPresented: $mostrandoImportador,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: true
        ) { resultado in
            importarPDF(resultado: resultado)
        }
        .sheet(item: $compartilhamento) { compartilhamento in
            ActivityShareView(items: compartilhamento.items)
        }
        .sheet(isPresented: $mostrandoExportadorMultiplo) {
            ExportacaoMultiplaView(itens: store.itens, tema: temaApp) { itensSelecionados, incluirComentarios, formato in
                exportarMultiplosDias(
                    itens: itensSelecionados,
                    incluirComentarios: incluirComentarios,
                    formato: formato
                )
            }
        }
        .onOpenURL { url in
            abrirURLBreviario(url)
        }
        .onDisappear {
            cancelarTarefasDaTela()
        }
    }
}
