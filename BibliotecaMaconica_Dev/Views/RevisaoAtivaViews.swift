import SwiftUI

extension HomeView {
    func atualizarRevisaoAtiva() {
        guard let configuracao = RevisaoAtiva.Configuracao.compartilhada else { return }
        let store = CartoesRevisaoStore()
        totalCartoesRevisao = store.todos().count
        cartoesParaHoje = store.sessao(hoje: DossieSalvo.data(Date()), configuracao: configuracao).count
    }

    /// Entry of the Dossier screen: cards due today, as on Android.
    var revisaoAtivaResumo: some View {
        let configuracao = RevisaoAtiva.Configuracao.compartilhada
        return VStack(alignment: .leading, spacing: 8) {
            Label(configuracao?.rotulo("titulo") ?? "Revisão ativa", systemImage: "rectangle.on.rectangle.angled")
                .font(.headline)
                .foregroundStyle(textoApp)
            Text(totalCartoesRevisao == 0
                 ? configuracao?.rotulo("semCartoes") ?? ""
                 : configuracao?.rotulo("paraHoje", ["n": "\(cartoesParaHoje)"]) ?? "")
                .font(.subheadline)
                .foregroundStyle(textoSecundarioApp)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("review.summary")
            if cartoesParaHoje > 0 {
                Button("Revisar agora") { mostrandoRevisaoAtiva = true }
                    .buttonStyle(AccessibleActionButtonStyle(tema: temaApp))
                    .accessibilityIdentifier("review.start")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(temaApp.painel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onAppear { atualizarRevisaoAtiva() }
        .sheet(isPresented: $mostrandoRevisaoAtiva, onDismiss: { atualizarRevisaoAtiva() }) {
            RevisaoAtivaSessaoView(tema: temaApp)
        }
    }
}

/// Review session: front, then the answer with its source and the grade; cloze cards can be answered
/// as multiple choice. Same steps and labels as Android `ActiveReviewSession`.
struct RevisaoAtivaSessaoView: View {
    let tema: TemaLeitura
    @Environment(\.dismiss) private var fechar
    @State private var fila: [CartoesRevisaoStore.Registro] = []
    @State private var indice = 0
    @State private var mostrandoResposta = false
    @State private var modoQuiz = false
    @State private var escolhida: String?
    @State private var carregada = false
    private let configuracao = RevisaoAtiva.Configuracao.compartilhada

    private func rotulo(_ chave: String, _ valores: [String: String] = [:]) -> String {
        configuracao?.rotulo(chave, valores) ?? chave
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if indice < fila.count {
                        cartaoAtual(fila[indice])
                    } else if carregada {
                        Text(rotulo("concluida"))
                            .font(.headline)
                            .foregroundStyle(tema.textoPrincipal)
                            .accessibilityIdentifier("review.done")
                    }
                }
                .padding()
                .frame(maxWidth: 760, alignment: .leading)
            }
            .background(tema.background)
            .navigationTitle(rotulo("titulo"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { fechar() }
                }
            }
        }
        .task {
            guard !carregada, let configuracao else { return }
            fila = CartoesRevisaoStore().sessao(hoje: DossieSalvo.data(Date()), configuracao: configuracao)
            carregada = true
        }
    }

    @ViewBuilder
    private func cartaoAtual(_ registro: CartoesRevisaoStore.Registro) -> some View {
        let cartao = registro.cartao
        Text("\(indice + 1) de \(fila.count) • \(registro.tema)")
            .font(.caption)
            .foregroundStyle(tema.textoSecundario)
        if cartao.tipo == "lacuna" {
            Text(rotulo("lacuna"))
                .font(.subheadline)
                .foregroundStyle(tema.textoSecundario)
        }
        Text(cartao.frente)
            .font(.title3)
            .foregroundStyle(tema.textoPrincipal)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("review.front")
        if !cartao.alternativas.isEmpty && !mostrandoResposta {
            Toggle(rotulo("quiz"), isOn: $modoQuiz)
                .tint(tema.destaque)
                .foregroundStyle(tema.textoPrincipal)
                .accessibilityIdentifier("review.quiz")
        }
        if modoQuiz && !cartao.alternativas.isEmpty {
            ForEach(cartao.alternativas, id: \.self) { alternativa in
                Button {
                    guard escolhida == nil else { return }
                    escolhida = alternativa
                    mostrandoResposta = true
                } label: {
                    Text(alternativa)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(AccessibleActionButtonStyle(tema: tema, prominent: escolhida == alternativa))
                .disabled(escolhida != nil && escolhida != alternativa)
            }
        } else if !mostrandoResposta {
            Button(rotulo("mostrarResposta")) { mostrandoResposta = true }
                .buttonStyle(AccessibleActionButtonStyle(tema: tema))
                .accessibilityIdentifier("review.show")
        }
        if mostrandoResposta {
            resposta(cartao)
        }
    }

    @ViewBuilder
    private func resposta(_ cartao: RevisaoAtiva.Cartao) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let escolhida {
                Text(escolhida == cartao.verso ? rotulo("certa") : rotulo("errada", ["resposta": cartao.verso]))
                    .font(.headline)
                    .foregroundStyle(tema.textoPrincipal)
            } else {
                Text(cartao.verso)
                    .font(.body)
                    .foregroundStyle(tema.textoPrincipal)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("review.back")
            }
            Text(cartao.fonte)
                .font(.caption)
                .foregroundStyle(tema.textoSecundario)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tema.painel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        if let escolhida {
            Button("Próximo") { responder(escolhida == cartao.verso ? .acertei : .errei) }
                .buttonStyle(AccessibleActionButtonStyle(tema: tema))
                .accessibilityIdentifier("review.next")
        } else {
            // Side by side when they fit; one below the other at large text sizes.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { botoesNota }
                VStack(alignment: .leading, spacing: 8) { botoesNota }
            }
        }
    }

    private var botoesNota: some View {
        ForEach(RevisaoAtiva.Nota.allCases, id: \.self) { nota in
            Button(rotulo(nota.rawValue)) { responder(nota) }
                .buttonStyle(AccessibleActionButtonStyle(tema: tema, prominent: nota == .acertei))
                .accessibilityIdentifier("review.grade.\(nota.rawValue)")
        }
    }

    private func responder(_ nota: RevisaoAtiva.Nota) {
        guard let configuracao, indice < fila.count else { return }
        CartoesRevisaoStore().responder(id: fila[indice].id, nota: nota, hoje: DossieSalvo.data(Date()), configuracao: configuracao)
        indice += 1
        mostrandoResposta = false
        escolhida = nil
        modoQuiz = false
    }
}
