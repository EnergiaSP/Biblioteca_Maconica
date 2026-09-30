import SwiftUI

/// Study tracks by degree with progress, milestones, the next step and the suggested works.
/// Same content as Android `DegreeTracksScreen`.
struct TrilhasGrauView: View {
    let tema: TemaLeitura
    let configuracao: TrilhasGrau.Configuracao
    let titulos: () -> [String: String]
    let estudar: (String) -> Void
    let abrirObra: (String) -> Void
    @State private var marcadas = TrilhasGrau.marcadas()
    @State private var temasSalvos: [String] = []
    @State private var nomes: [String: String] = [:]
    @State private var abertos: Set<String> = []

    var body: some View {
        let progresso = TrilhasGrau.progresso(configuracao, temasSalvos: temasSalvos, marcadas: marcadas)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(configuracao.rotulo("titulo"))
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(tema.destaque)
                    .accessibilityAddTraits(.isHeader)
                Text(configuracao.rotulo("descricao"))
                    .foregroundStyle(tema.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(Array(zip(configuracao.graus, progresso)), id: \.0.id) { grau, andamento in
                    grauView(grau, andamento)
                }
            }
            .padding()
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            marcadas = TrilhasGrau.marcadas()
            temasSalvos = DossiesSalvosStore().todos().map(\.tema)
            nomes = titulos()
        }
    }

    private func grauView(_ grau: TrilhasGrau.Grau, _ andamento: TrilhasGrau.Progresso) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(grau.nome)
                .font(.title2.weight(.bold))
                .foregroundStyle(tema.textoPrincipal)
                .accessibilityAddTraits(.isHeader)
            Text(grau.descricao)
                .font(.subheadline)
                .foregroundStyle(tema.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
            ProgressView(value: Double(andamento.concluidas.count), total: Double(max(andamento.total, 1)))
                .tint(tema.destaque)
                .accessibilityLabel(grau.nome)
                .accessibilityValue(configuracao.rotulo("progresso", valores(andamento)))
            Text(configuracao.rotulo("progresso", valores(andamento)))
                .font(.callout)
                .foregroundStyle(tema.textoPrincipal)
                .accessibilityIdentifier("trilha.\(grau.id).progresso")
            if !andamento.marco.isEmpty {
                Label(andamento.marco, systemImage: "rosette")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(tema.destaque)
                    .accessibilityIdentifier("trilha.\(grau.id).marco")
            }
            Text(andamento.proxima.flatMap { id in grau.etapas.first { $0.id == id } }
                    .map { configuracao.rotulo("proxima", ["tema": $0.tema]) } ?? configuracao.rotulo("concluida"))
                .font(.callout)
                .foregroundStyle(tema.textoSecundario)
            // The next step is shown; the whole track opens on request.
            let aberto = abertos.contains(grau.id)
            ForEach(grau.etapas.filter { aberto || $0.id == andamento.proxima }) { etapa in
                etapaView(etapa, feita: andamento.concluidas.contains(etapa.id))
            }
            Button {
                if aberto { abertos.remove(grau.id) } else { abertos.insert(grau.id) }
            } label: {
                Text(aberto ? configuracao.rotulo("ocultarEtapas") : configuracao.rotulo("verEtapas", ["n": "\(grau.etapas.count)"]))
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .tint(tema.destaque)
            .accessibilityIdentifier("trilha.\(grau.id).etapas")
            Text(configuracao.rotulo("obras"))
                .font(.headline)
                .foregroundStyle(tema.textoPrincipal)
            if grau.obrasSugeridas.isEmpty {
                Text(configuracao.rotulo("semObras"))
                    .font(.callout)
                    .foregroundStyle(tema.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(grau.obrasSugeridas, id: \.self) { obra in
                    Button { abrirObra(obra) } label: {
                        Text(nomes[obra] ?? obra)
                            .font(.callout)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .tint(tema.destaque)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tema.painel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .contain)
    }

    private func etapaView(_ etapa: TrilhasGrau.Etapa, feita: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(etapa.tema, systemImage: feita ? "checkmark.circle.fill" : "circle")
                .font(.body.weight(.semibold))
                .foregroundStyle(feita ? tema.destaque : tema.textoPrincipal)
                .accessibilityValue(feita ? configuracao.rotulo("estudada") : "")
            Text(etapa.descricao)
                .font(.caption)
                .foregroundStyle(tema.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Button(configuracao.rotulo("estudar")) { estudar(etapa.tema) }
                    .buttonStyle(.bordered)
                    .tint(tema.destaque)
                    .accessibilityLabel("\(configuracao.rotulo("estudar")): \(etapa.tema)")
                    .accessibilityIdentifier("trilha.etapa.\(etapa.id).estudar")
                Button(configuracao.rotulo(marcadas.contains(etapa.id) ? "desmarcar" : "marcar")) {
                    TrilhasGrau.alternar(etapa.id)
                    marcadas = TrilhasGrau.marcadas()
                }
                .buttonStyle(.bordered)
                .tint(tema.textoSecundario)
                .accessibilityLabel("\(configuracao.rotulo(marcadas.contains(etapa.id) ? "desmarcar" : "marcar")): \(etapa.tema)")
                .accessibilityIdentifier("trilha.etapa.\(etapa.id).marcar")
            }
        }
        .padding(.vertical, 4)
    }

    private func valores(_ andamento: TrilhasGrau.Progresso) -> [String: String] {
        ["feitas": "\(andamento.concluidas.count)", "total": "\(andamento.total)", "percentual": "\(andamento.percentual)"]
    }
}
