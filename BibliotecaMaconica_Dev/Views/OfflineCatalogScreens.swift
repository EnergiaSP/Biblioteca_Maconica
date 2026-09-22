import SwiftUI
import UniformTypeIdentifiers
import UIKit

extension HomeView {
var acervoOfflineView: some View {
        ZStack {
            fundo

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Acervo offline")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(destaqueApp)

                        Text("Baixe obras individuais ou todo o acervo para leitura e busca sem depender da internet.")
                            .font(.subheadline)
                            .foregroundStyle(textoSecundarioApp)
                    }

                    Picker("Área", selection: $filtroAcervoOffline) {
                        ForEach(BibliotecaArea.allCases) { area in
                            Text(area.titulo).tag(area)
                        }
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Buscar livro para baixar", systemImage: "magnifyingglass")
                            .font(.headline)
                            .foregroundStyle(textoApp)

                        TextField("Título da obra", text: $buscaAcervoOffline, axis: .vertical)
                            .lineLimit(1...3)
                            .accessibilityLabel("Buscar pelo título da obra")
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .padding(12)
                            .foregroundStyle(textoApp)
                            .background(temaApp.background.opacity(0.55))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(textoSecundarioApp.opacity(0.28), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        if buscaAcervoOffline.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                            Text("\(pacotesOfflineFiltrados.count) obra(s) encontrada(s) nesta área.")
                                .font(.caption)
                                .foregroundStyle(textoSecundarioApp)
                        }
                    }
                    .padding()
                    .background(temaApp.painel)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    let instalados = pacotesOffline.filter(\.instalado).count
                    let total = pacotesOffline.count
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("\(instalados) de \(total) disponíveis offline", systemImage: "internaldrive")
                                .font(.headline)
                                .foregroundStyle(textoApp)

                            Spacer()

                            if instalandoPacotesOffline {
                                ProgressView()
                            }
                        }

                        if progressoAcervoOffline.isEmpty == false {
                            Text(progressoAcervoOffline)
                                .font(.caption)
                                .foregroundStyle(textoSecundarioApp)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Button {
                            instalarTodosPacotesOffline()
                        } label: {
                            Label(instalandoPacotesOffline ? "Baixando..." : "Baixar todas desta área", systemImage: "square.and.arrow.down.on.square")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(instalandoPacotesOffline || pacotesOffline.isEmpty)

                        Button {
                            instalarTodoAcervoOffline()
                        } label: {
                            Label(instalandoPacotesOffline ? "Baixando..." : "Baixar todo o acervo", systemImage: "externaldrive.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(instalandoPacotesOffline)
                    }
                    .padding()
                    .background(temaApp.painel)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    LazyVStack(alignment: .leading, spacing: 10) {
                        if pacotesOfflineFiltrados.isEmpty {
                            ContentUnavailableView(
                                "Nenhuma obra encontrada",
                                systemImage: "magnifyingglass",
                                description: Text("Tente outro trecho do título ou altere a área selecionada.")
                            )
                            .foregroundStyle(textoApp)
                            .frame(maxWidth: .infinity, minHeight: 180)
                        }

                        ForEach(pacotesOfflineFiltrados) { estado in
                            pacoteOfflineRow(estado)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: 980, alignment: .leading)
            }
        }
        .navigationTitle("Acervo offline")
        .onAppear {
            atualizarPacotesOffline()
        }
        .onChange(of: filtroAcervoOffline) { _, _ in
            buscaAcervoOffline = ""
            atualizarPacotesOffline()
        }
    }

    func pacoteOfflineRow(_ estado: BibliotecaPacoteOfflineEstado) -> some View {
        HStack(spacing: 12) {
            Image(systemName: estado.instalado ? "checkmark.circle.fill" : "icloud.and.arrow.down")
                .font(.title3)
                .foregroundStyle(estado.instalado ? .green : destaqueApp)
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 4) {
                Text(estado.titulo)
                    .font(.headline)
                    .foregroundStyle(textoApp)
                    .lineLimit(2)

                Text(estado.detalhe)
                    .font(.caption)
                    .foregroundStyle(textoSecundarioApp)

                if estado.origemDisponivel == false && estado.instalado == false {
                    Text("Pacote ainda não disponível para download nesta instalação.")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            Button {
                if estado.instalado {
                    removerPacoteOffline(estado)
                } else {
                    instalarPacoteOffline(estado)
                }
            } label: {
                Image(systemName: estado.instalado ? "trash" : "arrow.down.circle")
                    .font(.headline)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.bordered)
            .disabled(instalandoPacotesOffline || (estado.origemDisponivel == false && estado.instalado == false))
            .accessibilityLabel(estado.instalado ? "Remover obra offline" : "Baixar obra offline")
        }
        .padding()
        .background(temaApp.painel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    var buscaBibliotecaView: some View {
        ZStack {
            fundo

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Busca estruturada")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(destaqueApp)

                        Text("Pesquise por termo, frase, obra, área ou no acervo completo.")
                            .font(.subheadline)
                            .foregroundStyle(textoSecundarioApp)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        TextField("Buscar", text: $buscaBiblioteca,
                                  prompt: Text("Buscar").foregroundStyle(textoSecundarioApp), axis: .vertical)
                            .lineLimit(1...3)
                            .accessibilityLabel("Palavra, frase ou assunto")
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(12)
                            .foregroundStyle(textoApp)
                            .background(temaApp.background.opacity(0.36))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .onSubmit {
                                executarBuscaBiblioteca()
                            }

                        Picker("Escopo", selection: $escopoBuscaBiblioteca) {
                            ForEach(BibliotecaBuscaEscopo.allCases) { escopo in
                                Text(escopo.titulo).tag(escopo)
                            }
                        }
                        .pickerStyle(.segmented)

                        if escopoBuscaBiblioteca == .obraAtual {
                            Picker("Obra", selection: $obraBuscaBibliotecaID) {
                                Text(store.obraSelecionada.titulo).tag(String?.none)
                                ForEach(store.obras.filter { $0.ativa && $0.id != store.obraSelecionada.id }) { obra in
                                    Text(obra.titulo).tag(Optional(obra.id))
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(destaqueApp)
                        }

                        if escopoBuscaBiblioteca == .area {
                            Picker("Área", selection: $areaBuscaBiblioteca) {
                                ForEach(BibliotecaArea.allCases) { area in
                                    Text(area.titulo).tag(area)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(destaqueApp)
                        }

                        filtrosMetadadosBibliotecaView

                        Button {
                            executarBuscaBiblioteca()
                        } label: {
                            Label(buscandoBiblioteca ? "Buscando..." : "Buscar", systemImage: "magnifyingglass")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AccessibleActionButtonStyle(tema: temaApp))
                        .tint(destaqueApp)
                        .disabled(buscandoBiblioteca || buscaBiblioteca.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        Button {
                            gerarDossieEstudo()
                        } label: {
                            Label(gerandoDossieEstudo ? "Montando dossiê..." : "Gerar dossiê de estudo", systemImage: "rectangle.stack.badge.person.crop")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AccessibleActionButtonStyle(tema: temaApp, prominent: false))
                        .tint(controleNeutroConfiguracoes)
                        .disabled(gerandoDossieEstudo || buscaBiblioteca.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding()
                    .background(temaApp.painel)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Resultados")
                                .font(.headline)
                                .foregroundStyle(textoApp)

                            Spacer()

                            if buscandoBiblioteca {
                                ProgressView()
                                    .tint(destaqueApp)
                            } else {
                                Text("\(resultadosBuscaBiblioteca.count)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(temaApp.textoSobreDestaque)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 5)
                                    .background(temaApp.fundoDestaque)
                                    .clipShape(Capsule())
                            }
                        }

                        if resultadosBuscaBiblioteca.isEmpty && buscandoBiblioteca == false {
                            Text("Informe uma busca para localizar conteúdos nas obras disponíveis.")
                                .font(.callout)
                                .foregroundStyle(textoSecundarioApp)
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(resultadosBuscaBiblioteca) { resultado in
                                    Button {
                                        abrirResultadoBuscaBiblioteca(resultado)
                                    } label: {
                                        ResultadoBuscaBibliotecaRow(resultado: resultado, tema: temaApp)
                                    }
                                    .buttonStyle(.plain)
                                }
                                if buscaBibliotecaTemMais {
                                    Button { executarBuscaBiblioteca(mais: true) } label: {
                                        Label("Carregar mais resultados", systemImage: "plus.magnifyingglass")
                                    }
                                    .disabled(buscandoBiblioteca)
                                    .accessibilityIdentifier("search.loadMore")
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
        .navigationTitle("Busca")
        .onChange(of: escopoBuscaBiblioteca) { _, _ in
            agendarBuscaBiblioteca()
        }
        .onChange(of: areaBuscaBiblioteca) { _, _ in
            agendarBuscaBiblioteca()
        }
        .onChange(of: buscaBiblioteca) { _, _ in
            agendarBuscaBiblioteca()
        }
        .onChange(of: obraBuscaBibliotecaID) { _, _ in
            agendarBuscaBiblioteca()
        }
        .onChange(of: filtroMetadadosBiblioteca) { _, _ in
            invalidarDossieEstudo()
            agendarBuscaBiblioteca()
        }
    }

    var dossieEstudoView: some View {
        ZStack {
            fundo

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Dossiê de estudo")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(destaqueApp)

                        Text("Transforme uma busca em roteiro de estudo, termos relacionados e perguntas de fixação.")
                            .font(.subheadline)
                            .foregroundStyle(textoSecundarioApp)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        TextField("Assunto", text: $buscaBiblioteca,
                                  prompt: Text("Assunto").foregroundStyle(textoSecundarioApp), axis: .vertical)
                            .lineLimit(1...3)
                            .accessibilityLabel("Tema, termo ou frase do dossiê")
                            .accessibilityIdentifier("dossier.topic")
                            .textInputAutocapitalization(.sentences)
                            .autocorrectionDisabled()
                            .padding(12)
                            .foregroundStyle(textoApp)
                            .background(temaApp.background.opacity(0.36))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .onSubmit {
                                gerarDossieEstudo()
                            }

                        Picker("Escopo", selection: $escopoBuscaBiblioteca) {
                            ForEach(BibliotecaBuscaEscopo.allCases) { escopo in
                                Text(escopo.titulo).tag(escopo)
                            }
                        }
                        .pickerStyle(.segmented)

                        if escopoBuscaBiblioteca == .obraAtual {
                            Picker("Obra", selection: $obraBuscaBibliotecaID) {
                                Text(store.obraSelecionada.titulo).tag(String?.none)
                                ForEach(store.obras.filter { $0.ativa && $0.id != store.obraSelecionada.id }) { obra in
                                    Text(obra.titulo).tag(Optional(obra.id))
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(destaqueApp)
                        }

                        if escopoBuscaBiblioteca == .area {
                            Picker("Área", selection: $areaBuscaBiblioteca) {
                                ForEach(BibliotecaArea.allCases) { area in
                                    Text(area.titulo).tag(area)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(destaqueApp)
                        }

                        filtrosMetadadosBibliotecaView

                        Button {
                            gerarDossieEstudo()
                        } label: {
                            Label(gerandoDossieEstudo ? "Montando..." : "Montar dossiê", systemImage: "doc.text.magnifyingglass")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AccessibleActionButtonStyle(tema: temaApp))
                        .tint(destaqueApp)
                        .disabled(gerandoDossieEstudo || buscaBiblioteca.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding()
                    .background(temaApp.painel)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    if gerandoDossieEstudo {
                        ProgressView("Organizando estudo")
                            .tint(destaqueApp)
                            .foregroundStyle(textoSecundarioApp)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(temaApp.painel)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else if let dossieEstudo {
                        DossieEstudoCard(
                            dossie: dossieEstudo,
                            tema: temaApp,
                            abrirResultado: { resultado in
                                abrirResultadoBuscaBiblioteca(resultado)
                            },
                            compartilhar: {
                                compartilharDossieEstudo(dossieEstudo)
                            },
                            gerarPDF: {
                                gerarPDFDossieEstudo(dossieEstudo)
                            }
                        )
                        .accessibilityIdentifier("dossier.results")

                        dossieIAView(dossieEstudo)
                    } else {
                        Text("Informe um tema para montar um roteiro de estudo cruzado pelas obras disponíveis.")
                            .font(.callout)
                            .foregroundStyle(textoSecundarioApp)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(temaApp.painel)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding()
                .frame(maxWidth: 980, alignment: .leading)
            }
        }
        .navigationTitle("Dossiê")
        .onChange(of: buscaBiblioteca) { _, _ in invalidarDossieEstudo() }
        .onChange(of: escopoBuscaBiblioteca) { _, _ in invalidarDossieEstudo() }
        .onChange(of: areaBuscaBiblioteca) { _, _ in invalidarDossieEstudo() }
        .onChange(of: obraBuscaBibliotecaID) { _, _ in invalidarDossieEstudo() }
        .onChange(of: filtroMetadadosBiblioteca) { _, _ in invalidarDossieEstudo() }
        .onAppear {
            carregarChaveGeminiSeNecessario()
        }
    }

    var filtrosMetadadosBibliotecaView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Filtrar por autor")
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("search.author.label")
            TextField("", text: $filtroMetadadosBiblioteca.autor, axis: .vertical)
                .lineLimit(1...3)
                .accessibilityLabel("Filtrar por autor")
                .accessibilityIdentifier("search.author")
                .frame(minHeight: 44)
                .padding(12)
                .background(temaApp.background.opacity(0.36))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(textoSecundarioApp, lineWidth: 1))
            Text("Filtrar por assunto")
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("search.subject.label")
            TextField("", text: $filtroMetadadosBiblioteca.assunto, axis: .vertical)
                .lineLimit(1...3)
                .accessibilityLabel("Filtrar por assunto")
                .accessibilityIdentifier("search.subject")
                .frame(minHeight: 44)
                .padding(12)
                .background(temaApp.background.opacity(0.36))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(textoSecundarioApp, lineWidth: 1))
        }
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .textFieldStyle(.plain)
        .foregroundStyle(textoApp)
    }

    func dossieIAView(_ dossie: BibliotecaDossieEstudo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Análise IA opcional", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(destaqueApp)

                Spacer()

                if gerandoAnaliseDossieIA {
                    ProgressView()
                        .tint(destaqueApp)
                }
            }

            if analiseIAAtiva == false {
                Text("A IA está desativada em Configurações. O dossiê local permanece disponível sem IA.")
                    .font(.callout)
                    .foregroundStyle(textoSecundarioApp)
            } else {
                SecureField("Chave API Gemini", text: $geminiAPIKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(12)
                    .foregroundStyle(textoApp)
                    .background(temaApp.background.opacity(0.36))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Button {
                    gerarAnaliseDossieGemini(dossie)
                } label: {
                    Label(gerandoAnaliseDossieIA ? "Gerando análise..." : "Gerar análise do dossiê", systemImage: "sparkles.rectangle.stack")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(destaqueApp)
                .disabled(gerandoAnaliseDossieIA || geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if analiseDossieIA.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                    JustifiedTextView(
                        texto: analiseDossieIA,
                        font: UIFont.systemFont(ofSize: 16),
                        color: temaApp.textoUIColor,
                        lineSpacing: 7,
                        chamadasRodape: [],
                        destaques: [],
                        corDestaque: UIColor(temaApp.destaque.opacity(0.24)),
                        aoSelecionarTexto: { _ in }
                    )
                    .frame(minHeight: 220)

                    Button {
                        UIPasteboard.general.string = analiseDossieIA
                        mensagemErro = "Análise do dossiê copiada."
                    } label: {
                        Label("Copiar análise", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(controleNeutroConfiguracoes)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(temaApp.painel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
