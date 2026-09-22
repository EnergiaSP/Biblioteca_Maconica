import SwiftUI
import UniformTypeIdentifiers
import UIKit

extension HomeView {
var leiturasRecentesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Recentes", systemImage: "clock.arrow.circlepath")
                    .font(.headline)
                    .foregroundStyle(textoApp)

                Spacer()
            }

            ForEach(itensRecentes.prefix(3)) { item in
                Button {
                    abrirLeitura(item)
                } label: {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.titulo)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(textoApp)
                                .lineLimit(1)

                            Text(item.data)
                                .font(.caption)
                                .foregroundStyle(textoSecundarioApp)

                            Label(item.tempoLeituraEstimado, systemImage: "clock")
                                .font(.caption2)
                                .foregroundStyle(textoSecundarioApp)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(destaqueApp)
                    }
                    .padding(10)
                    .background(temaApp.painel)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(item.titulo)
                .accessibilityValue("\(item.data). \(item.tempoLeituraEstimado)")
                .accessibilityHint("Abrir leitura recente")
            }
        }
        .padding()
        .background(temaApp.painel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    var leiturasRecentesBreviariosCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Últimas leituras", systemImage: "checkmark.circle")
                    .font(.headline)
                    .foregroundStyle(textoApp)

                Spacer()
            }

            ForEach(leiturasRecentesBreviariosCache) { recente in
                Button {
                    if let obra = store.obra(id: recente.obra.id) {
                        selecionarObra(obra)
                    }
                    abrirLeitura(recente.item)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "book.closed")
                            .font(.subheadline)
                            .foregroundStyle(destaqueApp)
                            .frame(width: 22)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(recente.obra.titulo)
                                .font(.footnote)
                                .foregroundStyle(textoSecundarioApp)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(recente.item.titulo)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(textoApp)
                                .fixedSize(horizontal: false, vertical: true)

                            Text("\(recente.item.data) • \(recente.item.tempoLeituraEstimado)")
                                .font(.footnote)
                                .foregroundStyle(textoSecundarioApp)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(destaqueApp)
                    }
                    .padding(10)
                    .background(temaApp.background.opacity(0.24))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(recente.obra.titulo). \(recente.item.titulo)")
                .accessibilityValue("\(recente.item.data). \(recente.item.tempoLeituraEstimado)")
                .accessibilityHint("Abrir leitura recente")
            }
        }
        .padding()
        .background(temaApp.painel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }


    var favoritosCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Favoritos", systemImage: "star.fill")
                    .font(.headline)
                    .foregroundStyle(textoApp)

                Spacer()

                Button {
                    filtroLeitura = .favoritos
                    abrirBreviario()
                } label: {
                    Label("Ver todos", systemImage: "arrow.right.circle")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.bordered)
                .tint(destaqueApp)
                .accessibilityLabel("Ver todos os favoritos")
            }

            ForEach(itensFavoritos.prefix(3)) { item in
                Button {
                    abrirLeitura(item)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(destaqueApp)
                            .frame(width: 18)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.titulo)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(textoApp)
                                .lineLimit(1)

                            Text(item.data)
                                .font(.caption)
                                .foregroundStyle(textoSecundarioApp)

                            Label(item.tempoLeituraEstimado, systemImage: "clock")
                                .font(.caption2)
                                .foregroundStyle(textoSecundarioApp)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(destaqueApp)
                    }
                    .padding(10)
                    .background(temaApp.painel)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(temaApp.painel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    var notasPessoaisCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Notas pessoais", systemImage: "note.text")
                    .font(.headline)
                    .foregroundStyle(textoApp)

                Spacer()

                Button {
                    filtroLeitura = .comComentarios
                    abrirBreviario()
                } label: {
                    Label("Ver todas", systemImage: "arrow.right.circle")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.bordered)
                .tint(destaqueApp)
                .accessibilityLabel("Ver todas as notas pessoais")
            }

            ForEach(itensComComentario.prefix(3)) { item in
                Button {
                    abrirLeitura(item)
                } label: {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 8) {
                            Text(item.data)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(destaqueApp)

                            Text(item.titulo)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(textoApp)
                                .lineLimit(1)

                            Spacer()

                            Label(item.tempoLeituraEstimado, systemImage: "clock")
                                .font(.caption2)
                                .foregroundStyle(textoSecundarioApp)

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(destaqueApp)
                        }

                        Text(resumoComentario(item))
                            .font(.caption)
                            .foregroundStyle(textoSecundarioApp)
                            .lineLimit(2)
                    }
                    .padding(10)
                    .background(temaApp.painel)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(temaApp.painel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    func marcadorLeitura(_ texto: String, icone: String) -> some View {
        Label(texto, systemImage: icone)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.black)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(destaqueApp.opacity(0.92))
            .clipShape(Capsule())
    }
}
