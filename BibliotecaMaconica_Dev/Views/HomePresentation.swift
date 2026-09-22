import SwiftUI
import UniformTypeIdentifiers
import UIKit

extension HomeView {
func avisoGlobal(_ mensagem: String) -> some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: iconeAvisoGlobal(mensagem))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(.white.opacity(0.18))
                    .clipShape(Circle())

                Text(mensagem)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(corFundoAvisoGlobal(mensagem))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.white.opacity(0.42), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.34), radius: 18, x: 0, y: 8)
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Spacer()
        }
        .animation(.easeInOut(duration: 0.18), value: mensagem)
        .allowsHitTesting(false)
    }

    func iconeAvisoGlobal(_ mensagem: String) -> String {
        if mensagem.localizedCaseInsensitiveContains("gerando") {
            return "clock"
        }

        if mensagem.localizedCaseInsensitiveContains("não")
            || mensagem.localizedCaseInsensitiveContains("nao")
            || mensagem.localizedCaseInsensitiveContains("nenhum")
            || mensagem.localizedCaseInsensitiveContains("selecione") {
            return "exclamationmark.triangle"
        }

        return "checkmark.circle.fill"
    }

    func corAvisoGlobal(_ mensagem: String) -> Color {
        if mensagem.localizedCaseInsensitiveContains("gerando") {
            return temaApp.destaque
        }

        if mensagem.localizedCaseInsensitiveContains("não")
            || mensagem.localizedCaseInsensitiveContains("nao")
            || mensagem.localizedCaseInsensitiveContains("nenhum")
            || mensagem.localizedCaseInsensitiveContains("selecione") {
            return .orange
        }

        return .green
    }

    func corFundoAvisoGlobal(_ mensagem: String) -> Color {
        if mensagem.localizedCaseInsensitiveContains("gerando") {
            return Color(red: 0.20, green: 0.23, blue: 0.30)
        }

        if mensagem.localizedCaseInsensitiveContains("não")
            || mensagem.localizedCaseInsensitiveContains("nao")
            || mensagem.localizedCaseInsensitiveContains("nenhum")
            || mensagem.localizedCaseInsensitiveContains("selecione") {
            return Color(red: 0.72, green: 0.38, blue: 0.05)
        }

        return Color(red: 0.08, green: 0.42, blue: 0.24)
    }

    func agendarOcultacaoMensagem(_ mensagem: String?) {
        mensagemErroTask?.cancel()

        guard let mensagem, mensagem.isEmpty == false else {
            return
        }

        guard mensagem.localizedCaseInsensitiveContains("gerando") == false else {
            return
        }

        mensagemErroTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_800_000_000)
            guard Task.isCancelled == false, mensagemErro == mensagem else {
                return
            }

            withAnimation(.easeInOut(duration: 0.2)) {
                mensagemErro = nil
            }
        }
    }

    var paginaInicial: some View {
        GeometryReader { viewport in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(alignment: .center, spacing: 12) {
                        Text("Biblioteca Maçônica")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(destaqueApp)
                            .fixedSize(horizontal: false, vertical: true)
                            .onTapGesture(count: 8) {
                                abrirGeradorAtivacaoProtegido()
                            }

                        Spacer()

                        Button {
                            abrirMais(.configuracoes)
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.title3)
                                .foregroundStyle(textoApp)
                                .frame(width: 38, height: 38)
                                .background(temaApp.painel)
                                .clipShape(Circle())
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Configurações")
                    }
                    .padding(.top, 10)

                    if leiturasDiariasBreviariosCache.isEmpty == false {
                        leiturasDiariasBreviariosCard
                    }

                    buscaHomeCard

                    bibliotecaHomeCard

                    if leiturasRecentesBreviariosCache.isEmpty == false {
                        leiturasRecentesBreviariosCard
                    }
                }
                .padding()
                .frame(maxWidth: 980, alignment: .leading)
            }
            .modifier(HomeScrollEdgeVisibility())
            .frame(width: viewport.size.width, height: viewport.size.height)
            .clipped()
        }
        .background(fundo)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            fecharCaixasHome()
        }
        .sheet(isPresented: $mostrandoNotificacao) {
            ConfigurarNotificacaoView(
                ativa: $notificacaoDiariaAtiva,
                hora: $notificacaoDiariaHora,
                minuto: $notificacaoDiariaMinuto,
                obras: store.obras.filter { $0.ativa && $0.tipo == .breviarioDiario },
                obrasSelecionadas: Binding(
                    get: { obrasNotificacaoIDs },
                    set: { salvarObrasNotificacao($0) }
                ),
                carregarItens: { ids in
                    await store.itensDisponiveisParaNotificacao(obraIDs: ids)
                }
            ) { mensagem in
                mensagemErro = mensagem
            }
        }
        .sheet(isPresented: $mostrandoGeradorAtivacao) {
            ActivationAdminProtectedGeneratorView()
        }
    }

    func abrirGeradorAtivacaoProtegido() {
        mostrandoGeradorAtivacao = true
    }

    func selecionarObra(_ obra: BibliotecaObra) {
        guard obra.id != store.obraSelecionada.id else {
            return
        }

        leitorVoz.parar()
        itemSelecionadoID = nil
        caminhoLeitura.removeAll()
        busca = ""
        buscaIndice = ""
        filtroLeitura = .todos
        comentario = ""
        analiseIA = nil
        mensagemIA = nil
        destaques = []
        novoDestaque = ""
        trechoSelecionadoTexto = ""
        pdfURL = nil
        mensagemErro = nil
        obraImportacaoID = obra.id
        store.selecionarObra(id: obra.id)
    }

    func abrirObra(_ obra: BibliotecaObra) {
        selecionarObra(obra)
        filtroLeitura = .todos
        abrirBreviario()
    }

    func abrirRecursoBreviario(_ filtro: FiltroLeitura) {
        if store.obraSelecionada.tipo != .breviarioDiario,
           let primeiroBreviario = store.obras.first(where: { $0.ativa && $0.tipo == .breviarioDiario }) {
            selecionarObra(primeiroBreviario)
        }

        filtroLeitura = filtro
        abrirBreviario()
    }

    var obrasBreviarioAtivas: [BibliotecaObra] {
        store.obras.filter { $0.ativa && $0.tipo == .breviarioDiario }
    }

    func totalItensBreviarios() -> Int {
        obrasBreviarioAtivas.reduce(0) { total, obra in
            if let totalCatalogado = store.totalItensPorObra[obra.id], totalCatalogado > 0 {
                return total + totalCatalogado
            }

            return total + ((try? BreviarioStore.carregarItensParaResumo(obra: obra).count) ?? 0)
        }
    }

    func totalLidasBreviarios() -> Int {
        obrasBreviarioAtivas.reduce(0) { total, obra in
            total + ReadingProgressService.concluidos(obraID: obra.id).count
        }
    }

    func totalFavoritosBreviarios() -> Int {
        obrasBreviarioAtivas.reduce(0) { total, obra in
            total + ReadingProgressService.favoritos(obraID: obra.id).count
        }
    }

    func totalComentariosBreviarios() -> Int {
        obrasBreviarioAtivas.reduce(0) { total, obra in
            guard let itens = try? BreviarioStore.carregarItensParaResumo(obra: obra) else {
                return total
            }

            return total + CommentsService.datasComComentario(
                datas: itens.map(\.data),
                obraID: obra.id
            ).count
        }
    }

    func totalPendentesBreviarios() -> Int {
        max(totalItensBreviarios() - totalLidasBreviarios(), 0)
    }

    func percentualLeituraBreviarios() -> Int {
        let total = totalItensBreviarios()
        guard total > 0 else {
            return 0
        }

        return Int((min(Double(totalLidasBreviarios()) / Double(total), 1) * 100).rounded())
    }

    func fecharCaixasHome() {
        areaHomeExpandida = nil
        expansaoHomeLiberada = false
    }

    var fundo: some View {
        temaApp.background
        .ignoresSafeArea()
    }

    var leiturasDiariasBreviariosCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(leiturasDiariasBreviariosCache) { leitura in
                destaqueDoDia(leitura)
            }
        }
    }

    func destaqueDoDia(_ leitura: LeituraDiariaBreviario) -> some View {
        Button {
            guard let item = leitura.item else {
                mensagemErro = "Leitura diária ainda não importada para este breviário."
                return
            }

            if let obra = store.obra(id: leitura.obra.id) {
                selecionarObra(obra)
            }
            abrirLeitura(item)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    Label(leitura.obra.titulo, systemImage: "calendar.badge.clock")
                        .font(.subheadline)
                        .foregroundStyle(textoSecundarioApp)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()

                    Label(leitura.item?.data ?? "Pendente", systemImage: "sun.max")
                        .font(.footnote)
                        .foregroundStyle(textoSecundarioApp)
                        .fixedSize()
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if leitura.concluida {
                        Image(systemName: leitura.iconeStatus)
                            .font(.title3)
                            .foregroundStyle(temaApp.sucesso)
                    }

                    Text(leitura.tituloExibicao)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(leitura.concluida ? temaApp.sucesso : destaqueApp)
                }

                if leitura.concluida == false, let resumo = leitura.item?.resumo {
                    Text(resumo)
                        .font(.body)
                        .foregroundStyle(textoApp)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(temaApp.painel)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Abrir leitura diária de \(leitura.obra.titulo)")
        .accessibilityValue("\(leitura.item?.data ?? "Pendente"). \(leitura.tituloExibicao)")
    }

    var bibliotecaHomeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(BibliotecaArea.allCases.enumerated()), id: \.element.id) { indice, area in
                areaBibliotecaHome(area)
            }
        }
    }

    private var homeCardLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 12))
    }

    var buscaHomeCard: some View {
        Button {
            abrirMais(.buscaBiblioteca)
        } label: {
            homeCardLayout {
                Image(systemName: "magnifyingglass")
                    .font(.headline)
                    .foregroundStyle(destaqueApp)
                    .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Buscar na biblioteca")
                        .font(.headline)
                        .foregroundStyle(textoApp)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Palavras, frases, obras, áreas e assuntos")
                        .font(.footnote)
                        .foregroundStyle(textoSecundarioApp)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(textoSecundarioApp)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(temaApp.painel)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Buscar na biblioteca")
        .accessibilityHint("Pesquisar por palavras, frases, obras, áreas e assuntos")
    }

    func areaBibliotecaHome(_ area: BibliotecaArea) -> some View {
        let obras = store.obras(na: area)
        let total = store.totalItens(area: area)
        let expandida = expansaoHomeLiberada && areaHomeExpandida == area

        return VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    expansaoHomeLiberada = true
                    areaHomeExpandida = expandida ? nil : area
                }
            } label: {
                homeCardLayout {
                    Image(systemName: area.icone)
                        .font(.title3)
                        .foregroundStyle(destaqueApp)
                        .frame(width: 34, height: 34)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(area.titulo)
                            .font(.headline)
                            .foregroundStyle(textoApp)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(expandida ? "\(obras.count) obras cadastradas • \(total) itens disponíveis" : "Toque para expandir")
                            .font(.footnote)
                            .foregroundStyle(textoSecundarioApp)
                            .fixedSize(horizontal: false, vertical: true)

                        if expandida, store.obraSelecionada.area == area {
                            Text("Área ativa")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(temaApp == .escuro ? .white : .black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(destaqueApp.opacity(temaApp == .escuro ? 0.28 : 0.18))
                                .clipShape(Capsule())
                        }
                    }

                    Spacer()

                    Image(systemName: expandida ? "chevron.up.circle.fill" : "chevron.down.circle")
                        .font(.title3)
                        .foregroundStyle(expandida ? destaqueApp : textoSecundarioApp)
                }
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(expandida ? "Recolher \(area.titulo)" : "Expandir \(area.titulo)")
            .accessibilityValue(expandida ? "Expandida. \(obras.count) obras, \(total) itens" : "Recolhida")

            if expandida {
                Text(area.subtitulo)
                    .font(.caption)
                    .foregroundStyle(textoSecundarioApp)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(obras.enumerated()), id: \.element.id) { indice, obra in
                        if indice > 0 {
                            Divider()
                                .overlay(textoSecundarioApp.opacity(0.14))
                        }

                        linhaObraBiblioteca(obra)
                    }
                }
                .background(temaApp.background.opacity(0.22))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .transition(.opacity.combined(with: .move(edge: .top)))

                if area == .breviarios {
                    recursosBreviarioCard
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding()
        .background(temaApp.painel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    func linhaObraBiblioteca(_ obra: BibliotecaObra) -> some View {
        Button {
            abrirObra(obra)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: obra.id == store.obraSelecionada.id ? "checkmark.circle.fill" : "book.closed")
                    .font(.headline)
                    .foregroundStyle(obra.id == store.obraSelecionada.id ? destaqueApp : textoSecundarioApp)
                    .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 3) {
                    Text(obra.titulo)
                        .font(.headline)
                        .foregroundStyle(textoApp)

                    Text(obra.descricao)
                        .font(.caption)
                        .foregroundStyle(textoSecundarioApp)
                        .lineLimit(2)

                    if obra.assuntos.isEmpty == false {
                        Text(obra.assuntos.prefix(4).joined(separator: " • "))
                            .font(.caption2)
                            .foregroundStyle(textoSecundarioApp.opacity(0.84))
                            .lineLimit(1)
                    }
                }

                Spacer()

                Text("\(store.totalItensPorObra[obra.id] ?? 0)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(obra.id == store.obraSelecionada.id ? .black : textoSecundarioApp)
                    .frame(minWidth: 28, minHeight: 24)
                    .background(obra.id == store.obraSelecionada.id ? destaqueApp : textoSecundarioApp.opacity(0.12))
                    .clipShape(Capsule())
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Abrir \(obra.titulo)")
    }

    func acaoHome(
        titulo: String,
        subtitulo: String,
        icone: String,
        cor: Color,
        acao: @escaping () -> Void
    ) -> some View {
        Button(action: acao) {
            HStack(spacing: 12) {
                Image(systemName: icone)
                    .font(.title2)
                    .foregroundStyle(cor)
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 4) {
                    Text(titulo)
                        .font(.headline)
                        .foregroundStyle(textoApp)

                    Text(subtitulo)
                        .font(.caption)
                        .foregroundStyle(textoSecundarioApp)
                }

                Spacer()
            }
            .padding()
            .frame(minHeight: 84)
            .background(temaApp.painel)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    var telaAberturaCarregamento: some View {
        TelaAberturaCarregamentoView()
        .transition(.opacity.animation(.easeInOut(duration: 0.35)))
        .zIndex(10)
    }

    var divisorSelecaoHome: some View {
        Divider()
            .overlay(textoSecundarioApp.opacity(0.18))
            .padding(.leading, 58)
    }

    func linhaSelecaoHome(
        titulo: String,
        subtitulo: String,
        icone: String,
        cor: Color,
        acao: @escaping () -> Void
    ) -> some View {
        Button(action: acao) {
            HStack(spacing: 12) {
                Image(systemName: icone)
                    .font(.headline)
                    .foregroundStyle(cor)
                    .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 3) {
                    Text(titulo)
                        .font(.headline)
                        .foregroundStyle(textoApp)

                    Text(subtitulo)
                        .font(.caption)
                        .foregroundStyle(textoSecundarioApp)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(textoSecundarioApp)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    func estatistica(_ titulo: String, _ valor: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(valor)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(textoApp)

            Text(titulo)
                .font(.caption)
                .foregroundStyle(textoSecundarioApp)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(temaApp.painel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct HomeScrollEdgeVisibility: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.scrollEdgeEffectHidden(true, for: .all)
        } else {
            content
        }
    }
}
