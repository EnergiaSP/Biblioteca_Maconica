import SwiftUI
import UniformTypeIdentifiers
import UIKit

extension HomeView {
var configuracoes: some View {
        Form {
            grupoConfiguracao(.aparencia) {
                seletorTemaConfiguracao

                Button {
                    aplicarTemaUnificado(TemaLeitura.escuro.rawValue)
                    mensagemErro = "Configuração salva: tema padrão restaurado."
                } label: {
                    Label("Restaurar tema padrão", systemImage: "paintpalette")
                }
            }

            grupoConfiguracao(.leitura) {
                HStack(spacing: 12) {
                    Text("Tamanho")
                    Slider(value: $tamanhoTextoLeitura, in: 15...23, step: 1)
                        .accessibilityLabel("Tamanho da fonte")
                        .accessibilityValue("\(Int(tamanhoTextoLeitura)) pontos")
                    Text("\(Int(tamanhoTextoLeitura))")
                        .foregroundStyle(textoSecundarioApp)
                        .frame(width: 32, alignment: .trailing)
                }

                HStack(spacing: 12) {
                    Text("Espaçamento")
                    Slider(value: $espacamentoTextoLeitura, in: 6...14, step: 1)
                        .accessibilityLabel("Espaçamento entre linhas")
                        .accessibilityValue("\(Int(espacamentoTextoLeitura)) pontos")
                    Text("\(Int(espacamentoTextoLeitura))")
                        .foregroundStyle(textoSecundarioApp)
                        .frame(width: 32, alignment: .trailing)
                }

                Toggle("Modo leitura sem distrações", isOn: $modoLeituraSemDistracoes)

                Button {
                    tamanhoTextoLeitura = 17
                    espacamentoTextoLeitura = 8
                    modoLeituraSemDistracoes = false
                    mensagemErro = "Configuração salva: leitura padrão restaurada."
                } label: {
                    Label("Restaurar leitura padrão", systemImage: "arrow.counterclockwise")
                }
            }

            grupoConfiguracao(.pdf) {
                TextField("Nome para capa personalizada", text: $nomeUsuarioPDFPremium)
                    .textInputAutocapitalization(.words)

                Text("Este nome aparece na capa das exportações premium.")
                    .font(.caption)
                    .foregroundStyle(textoSecundarioApp)
            }

            grupoConfiguracao(.ia) {
                Toggle("Permitir análise por IA", isOn: $analiseIAAtiva)

                Text("A IA é opcional. Quando ativada, deve usar apenas obras oficiais do app e fontes institucionais comprovadamente oficiais, sem inventar respostas.")
                    .font(.caption)
                    .foregroundStyle(textoSecundarioApp)
            }

            grupoConfiguracao(.voz) {
                seletorVozConfiguracao

                HStack(spacing: 12) {
                    Image(systemName: "tortoise")
                        .foregroundStyle(textoSecundarioApp)

                    Slider(value: $velocidadeLeitura, in: 0.75...1.2, step: 0.05)
                        .accessibilityLabel("Velocidade da voz")
                        .accessibilityValue("\(Int((velocidadeLeitura * 100).rounded())) por cento")

                    Image(systemName: "hare")
                        .foregroundStyle(textoSecundarioApp)

                    Text("\(Int((velocidadeLeitura * 100).rounded()))%")
                        .foregroundStyle(textoSecundarioApp)
                        .frame(width: 44, alignment: .trailing)
                }

                if let item = itemSelecionado {
                    HStack {
                        Button {
                            leitorVoz.alternarLeitura(
                                item,
                                genero: VozLeituraGenero(rawValue: vozLeituraGenero) ?? .feminina,
                                velocidade: velocidadeLeitura
                            )
                        } label: {
                            Label(
                                leitorVoz.estaLendo ? "Parar leitura" : "Ouvir texto selecionado",
                                systemImage: leitorVoz.estaLendo ? "stop.circle" : "speaker.wave.2"
                            )
                        }
                        .buttonStyle(.bordered)
                        .tint(controleNeutroConfiguracoes)

                        Button {
                            leitorVoz.alternarPausa()
                        } label: {
                            Label(
                                leitorVoz.estaPausado ? "Continuar" : "Pausar",
                                systemImage: leitorVoz.estaPausado ? "play.circle" : "pause.circle"
                            )
                        }
                        .buttonStyle(.bordered)
                        .tint(controleNeutroConfiguracoes)
                        .disabled(leitorVoz.estaLendo == false)
                    }
                } else {
                    Text("Selecione um texto diário para habilitar a leitura em voz alta.")
                        .font(.caption)
                        .foregroundStyle(textoSecundarioApp)
                }
            }

            grupoConfiguracao(.notificacoes) {
                Toggle("Ativar notificação", isOn: $notificacaoDiariaAtiva)

                Stepper(
                    String(format: "Hora: %02d", notificacaoDiariaHora),
                    value: $notificacaoDiariaHora,
                    in: 0...23
                )

                Stepper(
                    String(format: "Minuto: %02d", notificacaoDiariaMinuto),
                    value: $notificacaoDiariaMinuto,
                    in: 0...59
                )

                Button {
                    salvarConfiguracaoNotificacao()
                } label: {
                    Label("Salvar notificação", systemImage: "bell.badge")
                }
                .buttonStyle(.bordered)
                .tint(controleNeutroConfiguracoes)

                Button {
                    testarNotificacao()
                } label: {
                    Label("Enviar teste em 5 segundos", systemImage: "bell.and.waves.left.and.right")
                }
                .tint(controleNeutroConfiguracoes)
                .disabled(store.itemDoDia == nil)

                Button("Cancelar notificação", role: .destructive) {
                    notificacaoDiariaAtiva = false
                    NotificationService.cancelarNotificacaoDiaria()
                    mensagemErro = "Configuração salva: notificação diária cancelada."
                }
            }

            grupoConfiguracao(.dados) {
                Toggle("Criar nova obra ao importar", isOn: $criarNovaObraImportacao)

                if criarNovaObraImportacao {
                    Picker("Área", selection: $novaObraArea) {
                        ForEach(BibliotecaArea.allCases) { area in
                            Text(area.titulo).tag(area)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(controleNeutroConfiguracoes)

                    Picker("Tipo", selection: $novaObraTipo) {
                        ForEach(BibliotecaObraTipo.allCases) { tipo in
                            Text(tipo.titulo).tag(tipo)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(controleNeutroConfiguracoes)

                    TextField("Título da nova obra", text: $novaObraTitulo)
                        .textInputAutocapitalization(.words)

                    TextField("Autor ou origem", text: $novaObraAutor)
                        .textInputAutocapitalization(.words)

                    TextField("Assuntos separados por vírgula", text: $novaObraAssuntos)
                        .textInputAutocapitalization(.sentences)

                } else {
                    Picker("Destino da importação", selection: $obraImportacaoID) {
                        ForEach(store.obras.filter(\.ativa)) { obra in
                            Text("\(obra.area.titulo) - \(obra.titulo)")
                                .tag(obra.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(controleNeutroConfiguracoes)
                }

                Button {
                    mostrandoImportador = true
                } label: {
                    Label(criarNovaObraImportacao ? "Criar obra e importar PDF OCR" : "Importar PDF OCR", systemImage: "doc.badge.plus")
                }

                Button {
                    mostrandoExportadorMultiplo = true
                } label: {
                    Label("Exportar múltiplos dias", systemImage: "square.and.arrow.up.on.square")
                }

                Button("Restaurar dados do app") {
                    store.restaurarDadosEmbutidos()
                    itemSelecionadoID = store.itemDoDia?.id
                    comentario = store.itemDoDia?.comentarioSalvo ?? ""
                    mensagemErro = "Configuração salva: dados restaurados."
                }
            }

            if let mensagemErro {
                Section {
                    Text(mensagemErro)
                        .font(.caption)
                        .foregroundStyle(textoSecundarioApp)
                }
                .listRowBackground(temaApp.painel)
            }
        }
        .navigationTitle("Configurações")
        .scrollContentBackground(.hidden)
        .background(fundo)
        .foregroundStyle(textoApp)
        .tint(destaqueApp)
    }

    func grupoConfiguracao<Content: View>(
        _ secao: ConfiguracaoSecao,
        @ViewBuilder conteudo: @escaping () -> Content
    ) -> some View {
        Section {
            DisclosureGroup(
                isExpanded: bindingSecaoConfiguracao(secao)
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    conteudo()
                }
                // Controls share one Form row; avoid automatic row-wide button actions.
                .buttonStyle(.borderless)
                .padding(.top, 8)
            } label: {
                Label(secao.titulo, systemImage: secao.icone)
                    .font(.headline)
                    .foregroundStyle(textoApp)
            }
        }
        .listRowBackground(temaApp.painel)
    }

    func bindingSecaoConfiguracao(_ secao: ConfiguracaoSecao) -> Binding<Bool> {
        Binding {
            secoesConfiguracoesAbertas.contains(secao)
        } set: { aberta in
            withAnimation(.easeInOut(duration: 0.18)) {
                if aberta {
                    secoesConfiguracoesAbertas.insert(secao)
                } else {
                    secoesConfiguracoesAbertas.remove(secao)
                }
            }
        }
    }

    var seletorTemaConfiguracao: some View {
        Menu {
            ForEach(TemaLeitura.allCases) { tema in
                Button {
                    aplicarTemaUnificado(tema.rawValue)
                } label: {
                    Label(tema.titulo, systemImage: tema.icone)
                }
            }
        } label: {
            HStack(spacing: 12) {
                Text("Tema")
                    .foregroundStyle(controleNeutroConfiguracoes)

                Spacer()

                Label(temaSelecionadoConfiguracao.titulo, systemImage: temaSelecionadoConfiguracao.icone)
                    .foregroundStyle(controleNeutroConfiguracoes)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(controleNeutroConfiguracoes.opacity(0.75))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .tint(controleNeutroConfiguracoes)
        .foregroundStyle(controleNeutroConfiguracoes)
    }

    var seletorVozConfiguracao: some View {
        Menu {
            ForEach(VozLeituraGenero.allCases) { genero in
                Button {
                    vozLeituraGenero = genero.rawValue
                } label: {
                    Label(genero.titulo, systemImage: genero.icone)
                }
            }
        } label: {
            HStack(spacing: 12) {
                Text("Voz")
                    .foregroundStyle(controleNeutroConfiguracoes)

                Spacer()

                Label(vozSelecionadaConfiguracao.titulo, systemImage: vozSelecionadaConfiguracao.icone)
                    .foregroundStyle(controleNeutroConfiguracoes)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(controleNeutroConfiguracoes.opacity(0.75))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .tint(controleNeutroConfiguracoes)
        .foregroundStyle(controleNeutroConfiguracoes)
    }

    func controlesLeitura(_ item: BreviarioItem) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                botoesControleLeitura(item)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 40, maximum: 42), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                botoesControleLeitura(item)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    func botoesControleLeitura(_ item: BreviarioItem) -> some View {
        botaoIcone("Dia anterior", icone: "chevron.left") {
            retrocederDia()
        }

        botaoIcone("Próximo dia", icone: "chevron.right") {
            avancarDia()
        }

        botaoIcone(
            favoritos.contains(item.data) ? "Remover favorito" : "Favoritar",
            icone: favoritos.contains(item.data) ? "star.fill" : "star"
        ) {
            alternarFavorito(item)
        }

        botaoIcone(
            leiturasConcluidas.contains(item.data) ? "Marcar como não lido" : "Marcar como lido",
            icone: leiturasConcluidas.contains(item.data) ? "checkmark.seal.fill" : "checkmark.seal"
        ) {
            alternarConcluido(item)
        }

        botaoIcone("Tela cheia", icone: "arrow.up.left.and.arrow.down.right") {
            mostrandoLeituraTelaCheia = true
        }

        if obraSelecionadaEhDiaria == false {
            botaoIcone(
                modoLeituraLivrosContinuo ? "Ver página original" : "Ver como livro",
                icone: modoLeituraLivrosContinuo ? "doc.text" : "text.book.closed"
            ) {
                modoLeituraLivrosContinuo.toggle()
                mensagemErro = modoLeituraLivrosContinuo
                    ? "Modo livro ativado."
                    : "Visualização por página ativada."
            }
        }

        menuCompartilharLeitura(item)
    }

    func botaoIALeitura() -> some View {
        Button {
            abrirMais(.ia)
        } label: {
            Text("IA")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel("IA da leitura")
    }

    func menuCompartilharLeitura(_ item: BreviarioItem) -> some View {
        Menu {
            Button {
                compartilharWhatsApp(item, incluirComentario: false)
            } label: {
                Label("WhatsApp", systemImage: "message")
            }

            Button {
                compartilharWhatsApp(item, incluirComentario: true)
            } label: {
                Label("WhatsApp com comentário", systemImage: "message.badge")
            }
            .disabled(comentarioAtualTrimmed.isEmpty)

            Button {
                gerarPDF(item: item, incluirComentario: false)
            } label: {
                Label("PDF leitura completa", systemImage: "doc.richtext")
            }

            Button {
                gerarPDF(item: item, incluirComentario: true)
            } label: {
                Label("PDF com comentário", systemImage: "doc.badge.plus")
            }
            .disabled(comentarioAtualTrimmed.isEmpty)

            Button {
                copiarTexto(item, incluirComentario: false)
            } label: {
                Label("Copiar texto", systemImage: "doc.on.doc")
            }

            Button {
                copiarTexto(item, incluirComentario: true)
            } label: {
                Label("Copiar com comentário", systemImage: "doc.on.clipboard")
            }
            .disabled(comentarioAtualTrimmed.isEmpty)
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.headline)
                .frame(width: 38, height: 38)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(temaLeitura.textoPrincipal)
        .background(temaLeitura.painel)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(temaLeitura.textoSecundario.opacity(0.34), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityLabel("Compartilhar")
    }

    func botaoIcone(
        _ acessibilidade: String,
        icone: String,
        acao: @escaping () -> Void
    ) -> some View {
        Button(action: acao) {
            Image(systemName: icone)
                .font(.headline)
                .frame(width: 38, height: 38)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(temaLeitura.textoPrincipal)
        .background(temaLeitura.painel)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(temaLeitura.textoSecundario.opacity(0.34), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityLabel(acessibilidade)
    }
}
