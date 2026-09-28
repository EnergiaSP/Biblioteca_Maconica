import SwiftUI

/// Sections of the AI-free dossier analysis: every line is extracted from the sources and cites one.
struct DossieAnaliseSecoes: View {
    let exibicao: DossieEstudoAnalise.Exibicao
    let tema: TemaLeitura

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            secao("Definição", icone: "character.book.closed", exibicao.definicoes,
                  vazio: "Nenhum dicionário do acervo define o tema.")
            secao("Resumo com fontes", icone: "text.quote", exibicao.resumo,
                  vazio: "Nenhuma frase das fontes trata diretamente do tema.")
                .accessibilityIdentifier("dossier.summary")
            if !exibicao.divergencias.isEmpty {
                secao("Pontos a comparar", icone: "arrow.left.arrow.right", exibicao.divergencias, vazio: "")
            }
            secao("Métricas", icone: "chart.bar", exibicao.metricas, vazio: "")
            if !exibicao.obrasCentrais.isEmpty {
                secao("Obras centrais", icone: "star", exibicao.obrasCentrais, vazio: "")
            }
            if !exibicao.capitulosDedicados.isEmpty {
                secao("Capítulos dedicados ao tema", icone: "bookmark", exibicao.capitulosDedicados, vazio: "")
            }
        }
    }

    private func secao(_ titulo: String, icone: String, _ linhas: [String], vazio: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(titulo, systemImage: icone)
                .font(.headline)
                .foregroundStyle(tema.destaque)
            if linhas.isEmpty {
                Text(vazio)
                    .font(.callout)
                    .foregroundStyle(tema.textoSecundario)
            } else {
                ForEach(Array(linhas.enumerated()), id: \.offset) { _, linha in
                    Text("• \(linha)")
                        .font(.callout)
                        .foregroundStyle(tema.textoPrincipal)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
