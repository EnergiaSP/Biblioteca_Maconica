import SwiftUI
import UIKit

/// The prancha of a dossier: how each author treats the topic, side by side, and the text with ABNT
/// citations and references, ready to share or copy. Same content as Android `PranchaScreen`.
struct PranchaView: View {
    let prancha: PranchaDossie.Prancha
    let configuracao: PranchaDossie.Configuracao
    let tema: TemaLeitura
    @Environment(\.dismiss) private var dismiss
    @State private var copiada = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(configuracao.rotulo("aviso"))
                        .font(.subheadline)
                        .foregroundStyle(tema.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("prancha.aviso")

                    if !prancha.comparacao.isEmpty {
                        Text(configuracao.rotulo("comparacao"))
                            .font(.headline)
                            .foregroundStyle(tema.textoPrincipal)
                        ScrollView(.horizontal) {
                            HStack(alignment: .top, spacing: 12) {
                                ForEach(prancha.comparacao) { autor in
                                    autorView(autor)
                                }
                            }
                        }
                        .accessibilityIdentifier("prancha.comparacao")
                    }

                    HStack(spacing: 12) {
                        ShareLink(item: prancha.texto) {
                            Label(configuracao.rotulo("compartilhar"), systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AccessibleActionButtonStyle(tema: tema))
                        .accessibilityIdentifier("prancha.compartilhar")
                        Button {
                            UIPasteboard.general.string = prancha.texto
                            copiada = true
                        } label: {
                            Label(configuracao.rotulo(copiada ? "copiada" : "copiar"), systemImage: copiada ? "checkmark" : "doc.on.doc")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AccessibleActionButtonStyle(tema: tema, prominent: false))
                        .accessibilityIdentifier("prancha.copiar")
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text(prancha.titulo)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(tema.destaque)
                            .accessibilityAddTraits(.isHeader)
                        ForEach(prancha.secoes, id: \.titulo) { secao in
                            Text(secao.titulo)
                                .font(.headline)
                                .foregroundStyle(tema.textoPrincipal)
                                .accessibilityAddTraits(.isHeader)
                            ForEach(Array(secao.paragrafos.enumerated()), id: \.offset) { _, paragrafo in
                                Text(paragrafo)
                                    .foregroundStyle(tema.textoPrincipal)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .textSelection(.enabled)
                            }
                        }
                        Text(configuracao.rotulo("referenciasIncompletas"))
                            .font(.caption)
                            .foregroundStyle(tema.textoSecundario)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(tema.painel)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityIdentifier("prancha.texto")
                }
                .padding()
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(tema.background.ignoresSafeArea())
            .navigationTitle(configuracao.rotulo("tituloTela"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
    }

    private func autorView(_ autor: PranchaDossie.Autor) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(autor.quem)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tema.destaque)
            Text(autor.obras.joined(separator: "; "))
                .font(.caption)
                .foregroundStyle(tema.textoSecundario)
            ForEach(Array(autor.trechos.enumerated()), id: \.offset) { _, trecho in
                Text(trecho)
                    .font(.callout)
                    .foregroundStyle(tema.textoPrincipal)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(width: 280, alignment: .topLeading)
        .background(tema.painel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("prancha.autor")
    }
}
