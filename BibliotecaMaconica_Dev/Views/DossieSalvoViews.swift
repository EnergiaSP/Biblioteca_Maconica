import SwiftUI

/// Texts shared with Android (`DossierSavedUi.kt`), so both apps describe saved dossiers alike.
enum DossieSalvoTextos {
    private static let formato: DateFormatter = {
        let formato = DateFormatter()
        formato.locale = Locale(identifier: "pt_BR")
        formato.calendar = DossieSalvo.calendario
        formato.dateFormat = "dd/MM/yyyy"
        return formato
    }()

    static func data(_ data: Date) -> String { formato.string(from: data) }

    static func situacao(_ situacao: DossieSalvo.Situacao) -> String {
        switch situacao {
        case .feita: "Feita"
        case .atrasada: "Atrasada"
        case .hoje: "Hoje"
        case .proxima: "Próxima"
        }
    }

    static func progresso(_ salvo: DossieSalvo, passos: [DossieEstudoAnalise.Configuracao.Revisao], hoje: Date) -> String {
        guard let proxima = salvo.proximaRevisao(passos: passos, hoje: hoje) else {
            return "Todas as revisões concluídas."
        }
        switch proxima.situacao {
        case .atrasada: return "Revisão atrasada desde \(data(proxima.data)): \(proxima.tarefa)"
        case .hoje: return "Revisão de hoje: \(proxima.tarefa)"
        default: return "Próxima revisão em \(data(proxima.data)): \(proxima.tarefa)"
        }
    }

    static func escopo(_ salvo: DossieSalvo) -> String {
        let area = salvo.area.flatMap(BibliotecaArea.init(rawValue:))?.titulo ?? "Toda a biblioteca"
        let filtros = [("Autor", salvo.autor), ("Assunto", salvo.assunto)].compactMap { rotulo, valor -> String? in
            let limpo = valor.trimmingCharacters(in: .whitespacesAndNewlines)
            return limpo.isEmpty ? nil : "\(rotulo): \(limpo)"
        }.joined(separator: " • ")
        return [area, salvo.obraId == nil ? "" : "Obra selecionada", filtros].filter { !$0.isEmpty }.joined(separator: " • ")
    }

    static func notaLembrete(_ salvo: DossieSalvo, lembrete: DossieEstudoAnalise.Configuracao.Lembrete) -> String {
        "Salvo em \(data(salvo.dataCriacao)). Lembrete às \(String(format: "%02d:%02d", lembrete.hora, lembrete.minuto)) no dia de cada revisão pendente."
    }
}

struct DossiesSalvosCard: View {
    let salvos: [DossieSalvo]
    let passos: [DossieEstudoAnalise.Configuracao.Revisao]
    let tema: TemaLeitura
    let habilitado: Bool
    let abrir: (DossieSalvo) -> Void
    let excluir: (DossieSalvo) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dossiês salvos")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(tema.textoPrincipal)
            Text("Ao abrir, o dossiê é refeito com o acervo instalado.")
                .font(.caption)
                .foregroundStyle(tema.textoSecundario)

            ForEach(salvos) { salvo in
                VStack(alignment: .leading, spacing: 4) {
                    Text(salvo.tema)
                        .font(.headline)
                        .foregroundStyle(tema.textoPrincipal)
                    Text(DossieSalvoTextos.escopo(salvo))
                        .font(.caption)
                        .foregroundStyle(tema.destaque)
                    Text(DossieSalvoTextos.progresso(salvo, passos: passos, hoje: Date()))
                        .font(.caption)
                        .foregroundStyle(tema.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 10) {
                        Button("Abrir") { abrir(salvo) }
                            .buttonStyle(.borderedProminent)
                            .tint(tema.destaque)
                            .accessibilityIdentifier("dossier.saved.open")
                        Button("Excluir", role: .destructive) { excluir(salvo) }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("dossier.saved.delete")
                    }
                    .disabled(!habilitado)
                }
                .accessibilityElement(children: .contain)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tema.painel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dossier.saved")
    }
}

struct RevisoesDossieCard: View {
    let salvo: DossieSalvo
    let passos: [DossieEstudoAnalise.Configuracao.Revisao]
    let lembrete: DossieEstudoAnalise.Configuracao.Lembrete
    let tema: TemaLeitura
    let alternar: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Revisões deste dossiê")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(tema.textoPrincipal)
            Text(DossieSalvoTextos.notaLembrete(salvo, lembrete: lembrete))
                .font(.caption)
                .foregroundStyle(tema.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(salvo.revisoes(passos: passos, hoje: Date()), id: \.dias) { revisao in
                Button {
                    alternar(revisao.dias)
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: revisao.situacao == .feita ? "checkmark.square.fill" : "square")
                            .font(.title3)
                            .foregroundStyle(tema.destaque)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(DossieSalvoTextos.data(revisao.data)) • \(DossieSalvoTextos.situacao(revisao.situacao))")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(revisao.situacao == .atrasada ? tema.destaque : tema.textoPrincipal)
                            Text(revisao.tarefa)
                                .font(.subheadline)
                                .foregroundStyle(tema.textoSecundario)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("dossier.review.\(revisao.dias)")
                .accessibilityValue(revisao.situacao == .feita ? "Feita" : "Pendente")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tema.painel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dossier.reviews")
    }
}

/// The topic in the center and its associated terms around it, clockwise from the top, as on
/// Android. Everything drawn comes from the analysis of the sources.
struct MapaDossieView: View {
    static let quantidadeTermos = 8

    let termo: String
    let termos: [DossieEstudoAnalise.TermoAssociado]
    let tema: TemaLeitura

    var body: some View {
        let exibidos = Array(termos.prefix(Self.quantidadeTermos))
        VStack(alignment: .leading, spacing: 8) {
            Text("Mapa do tema")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(tema.textoPrincipal)
            Text("Termos que mais aparecem perto do tema nas fontes; o número é de ocorrências.")
                .font(.caption)
                .foregroundStyle(tema.textoSecundario)

            Canvas { contexto, tamanho in
                let centro = CGPoint(x: tamanho.width / 2, y: tamanho.height / 2)
                let raio = min(tamanho.width, tamanho.height) * 0.36
                let pontos = exibidos.indices.map { indice -> CGPoint in
                    let angulo = (-90 + 360 * Double(indice) / Double(exibidos.count)) * .pi / 180
                    return CGPoint(x: centro.x + raio * cos(angulo), y: centro.y + raio * sin(angulo))
                }
                for ponto in pontos {
                    var linha = Path()
                    linha.move(to: centro)
                    linha.addLine(to: ponto)
                    contexto.stroke(linha, with: .color(tema.textoSecundario.opacity(0.6)), lineWidth: 2)
                }
                let circulo = Path(ellipseIn: CGRect(x: centro.x - 34, y: centro.y - 34, width: 68, height: 68))
                contexto.fill(circulo, with: .color(tema.destaque))
                contexto.draw(
                    Text(termo).font(.caption).fontWeight(.bold).foregroundStyle(tema.textoSobreDestaque),
                    in: CGRect(x: centro.x - 32, y: centro.y - 26, width: 64, height: 52)
                )
                for (termoAssociado, ponto) in zip(exibidos, pontos) {
                    contexto.fill(Path(ellipseIn: CGRect(x: ponto.x - 6, y: ponto.y - 6, width: 12, height: 12)), with: .color(tema.destaque))
                    let largura = tamanho.width * 0.3
                    let abaixo = ponto.y >= centro.y
                    let rotulo = CGRect(
                        x: min(max(ponto.x - largura / 2, 0), tamanho.width - largura),
                        y: abaixo ? ponto.y + 8 : ponto.y - 8 - 32,
                        width: largura,
                        height: 32
                    )
                    contexto.draw(
                        Text("\(termoAssociado.forma) (\(termoAssociado.ocorrencias))").font(.caption).foregroundStyle(tema.textoPrincipal),
                        in: rotulo
                    )
                }
            }
            .frame(height: 320)
            .accessibilityElement()
            .accessibilityLabel("Mapa: \(termo) ligado a " + exibidos.map { "\($0.forma) (\($0.ocorrencias))" }.joined(separator: ", "))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tema.painel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dossier.map")
    }
}
