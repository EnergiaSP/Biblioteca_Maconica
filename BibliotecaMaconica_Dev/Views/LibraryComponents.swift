import SwiftUI
import UIKit
import ImageIO

struct AsyncOriginalPageImage: View {
    let url: URL
    let tema: TemaLeitura

    @State private var imagem: UIImage?
    @State private var carregamentoConcluido = false

    var body: some View {
        Group {
            if let imagem {
                Image(uiImage: imagem)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(tema.textoSecundario.opacity(0.24), lineWidth: 1)
                    )
                    .transition(.opacity)
            } else if carregamentoConcluido {
                Text("A imagem original desta página não está disponível neste aparelho.")
                    .font(.caption)
                    .foregroundStyle(tema.textoSecundario)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 120)
            }
        }
        .task(id: url) {
            imagem = nil
            carregamentoConcluido = false
            let carregada = await Self.carregarImagemReduzida(url: url)
            guard !Task.isCancelled else { return }
            imagem = carregada
            carregamentoConcluido = true
        }
    }

    private static func carregarImagemReduzida(url: URL) async -> UIImage? {
        await Task.detached(priority: .utility) {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
                return nil
            }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 2048,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true
            ]
            guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                return nil
            }
            return UIImage(cgImage: image)
        }.value
    }
}

struct LeituraListaRow: View {
    let item: BreviarioItem
    let favorito: Bool
    let lido: Bool
    let tema: TemaLeitura
    let tipoObra: BibliotecaObraTipo

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(item.titulo)
                    .font(.headline)
                    .foregroundStyle(tema.textoPrincipal)

                Spacer(minLength: 8)

                if favorito {
                    Image(systemName: "star.fill")
                        .foregroundStyle(tema.destaque)
                        .accessibilityLabel("Favorito")
                }

                if lido {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(tema.sucesso)
                        .accessibilityLabel("Lido")
                }
            }

            HStack(spacing: 8) {
                Text(tipoObra.referenciaSingular)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(tema.textoSobreDestaque)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(tema.fundoDestaque)
                    .clipShape(Capsule())

                Text(item.referenciaExibicao)
                    .font(.caption)
                    .foregroundStyle(tema.textoSecundario)
            }

            Label(item.tempoLeituraEstimado, systemImage: "clock")
                .font(.caption2)
                .foregroundStyle(tema.textoSecundario)

            if let pagina = item.pagina {
                Text("Página \(pagina)")
                    .font(.caption2)
                    .foregroundStyle(tema.textoSecundario)
            }

            Text(item.resumo)
                .font(.caption)
                .foregroundStyle(tema.textoSecundario)
                .lineLimit(2)
        }
    }
}

struct ResultadoBuscaBibliotecaRow: View {
    let resultado: BibliotecaResultadoBusca
    let tema: TemaLeitura

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(resultado.obra.area.titulo)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(tema.textoSobreDestaque)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(tema.fundoDestaque)
                    .clipShape(Capsule())

                Text(resultado.obra.titulo)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(tema.textoSecundario)
                    .lineLimit(1)

                Spacer()
            }

            Text(resultado.item.titulo)
                .font(.headline)
                .foregroundStyle(tema.textoPrincipal)
                .lineLimit(2)

            HStack(spacing: 8) {
                Text(resultado.item.referenciaExibicao)
                if let pagina = resultado.item.pagina {
                    Text("Página \(pagina)")
                }
            }
            .font(.caption)
            .foregroundStyle(tema.textoSecundario)

            Text(resultado.contexto)
                .font(.caption)
                .foregroundStyle(tema.textoSecundario)
                .lineLimit(3)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tema.painel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct DossieEstudoCard: View {
    let dossie: BibliotecaDossieEstudo
    let tema: TemaLeitura
    let abrirResultado: (BibliotecaResultadoBusca) -> Void
    let compartilhar: () -> Void
    let gerarPDF: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "rectangle.stack.badge.person.crop")
                    .font(.title3)
                    .foregroundStyle(tema.destaque)
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 4) {
                    Text(dossie.termo)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(tema.textoPrincipal)

                    Text("\(dossie.resumoEscopo) • \(dossie.resultados.count) referências")
                        .font(.caption)
                        .foregroundStyle(tema.textoSecundario)
                }

                Spacer()
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    botaoAcao("Compartilhar", icone: "square.and.arrow.up", acao: compartilhar)
                    botaoAcao("PDF avançado", icone: "doc.richtext", acao: gerarPDF)
                }

                VStack(spacing: 10) {
                    botaoAcao("Compartilhar por WhatsApp/e-mail", icone: "square.and.arrow.up", acao: compartilhar)
                    botaoAcao("Gerar PDF avançado", icone: "doc.richtext", acao: gerarPDF)
                }
            }

            grupo("Obras envolvidas", icone: "books.vertical") {
                if dossie.obrasEnvolvidas.isEmpty {
                    textoVazio("Nenhuma obra encontrada para este tema.")
                } else {
                    ForEach(dossie.obrasEnvolvidas) { obra in
                        Text("• \(obra.titulo)")
                            .font(.callout)
                            .foregroundStyle(tema.textoPrincipal)
                    }
                }
            }

            if dossie.termosRelacionados.isEmpty == false {
                grupo("Termos relacionados", icone: "tag") {
                    FlowTags(tags: dossie.termosRelacionados, tema: tema)
                }
            }

            grupo("Roteiro de estudo", icone: "list.number") {
                ForEach(Array(dossie.roteiro.enumerated()), id: \.offset) { indice, etapa in
                    Text("\(indice + 1). \(etapa)")
                        .font(.callout)
                        .foregroundStyle(tema.textoPrincipal)
                }
            }

            grupo("Perguntas de fixação", icone: "questionmark.circle") {
                ForEach(dossie.perguntasFixacao, id: \.self) { pergunta in
                    Text("• \(pergunta)")
                        .font(.callout)
                        .foregroundStyle(tema.textoPrincipal)
                }
            }

            grupo("Mapa conceitual", icone: "point.3.connected.trianglepath.dotted") {
                ForEach(dossie.mapaConceitual, id: \.self) { relacao in
                    Text("• \(relacao)")
                        .font(.callout)
                        .foregroundStyle(tema.textoPrincipal)
                }
            }

            grupo("Cruzamentos de estudo", icone: "arrow.triangle.branch") {
                ForEach(dossie.cruzamentos, id: \.self) { cruzamento in
                    Text("• \(cruzamento)")
                        .font(.callout)
                        .foregroundStyle(tema.textoPrincipal)
                }
            }

            grupo("Revisão espaçada", icone: "calendar.badge.clock") {
                ForEach(dossie.revisaoEspacada, id: \.self) { etapa in
                    Text("• \(etapa)")
                        .font(.callout)
                        .foregroundStyle(tema.textoPrincipal)
                }
            }

            grupo("Limites da base", icone: "exclamationmark.shield") {
                ForEach(dossie.limitesDaBase, id: \.self) { limite in
                    Text("• \(limite)")
                        .font(.callout)
                        .foregroundStyle(tema.textoPrincipal)
                }
            }

            grupo("Referências encontradas", icone: "text.magnifyingglass") {
                if dossie.resultados.isEmpty {
                    textoVazio("Refine a busca ou importe novas obras para ampliar o estudo.")
                } else {
                    ForEach(dossie.resultados) { resultado in
                        Button {
                            abrirResultado(resultado)
                        } label: {
                            ResultadoBuscaBibliotecaRow(resultado: resultado, tema: tema)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Text("Gerado apenas com base nas obras disponíveis no app. A IA, quando ativada, deve seguir a mesma regra de fontes oficiais.")
                .font(.caption)
                .foregroundStyle(tema.textoSecundario)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tema.painel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func botaoAcao(_ titulo: String, icone: String, acao: @escaping () -> Void) -> some View {
        Button(action: acao) {
            Label(titulo, systemImage: icone)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(tema.destaque)
    }

    private func grupo<Content: View>(
        _ titulo: String,
        icone: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(titulo, systemImage: icone)
                .font(.headline)
                .foregroundStyle(tema.destaque)

            content()
        }
    }

    private func textoVazio(_ texto: String) -> some View {
        Text(texto)
            .font(.callout)
            .foregroundStyle(tema.textoSecundario)
    }
}

struct FlowTags: View {
    let tags: [String]
    let tema: TemaLeitura

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 8)], spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(tema.textoPrincipal)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(tema.background.opacity(0.32))
                    .clipShape(Capsule())
            }
        }
    }
}

struct IndiceAreaBibliotecaCard: View {
    let area: BibliotecaIndiceArea
    let tema: TemaLeitura
    let abrir: (BibliotecaObra) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: area.area.icone)
                    .font(.headline)
                    .foregroundStyle(tema.destaque)
                    .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(area.area.titulo)
                        .font(.headline)
                        .foregroundStyle(tema.textoPrincipal)

                    Text("\(area.obras.count) obras • \(area.totalItens) itens • \(area.totalIndiceRemissivo) termos")
                        .font(.caption)
                        .foregroundStyle(tema.textoSecundario)
                }

                Spacer()
            }

            VStack(spacing: 0) {
                ForEach(Array(area.obras.enumerated()), id: \.element.id) { indice, obra in
                    if indice > 0 {
                        Divider()
                            .overlay(tema.textoSecundario.opacity(0.14))
                    }

                    Button {
                        abrir(obra.obra)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(obra.obra.titulo)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(tema.textoPrincipal)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(tema.destaque)
                            }

                            Text("\(obra.totalItens) itens disponíveis • \(obra.totalIndiceRemissivo) termos no índice")
                                .font(.caption)
                                .foregroundStyle(tema.textoSecundario)

                            if obra.primeirosTitulos.isEmpty == false {
                                Text(obra.primeirosTitulos.prefix(3).joined(separator: " • "))
                                    .font(.caption2)
                                    .foregroundStyle(tema.textoSecundario.opacity(0.82))
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(tema.background.opacity(0.22))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct IndiceRemissivoGlobalRow: View {
    let entrada: BibliotecaIndiceRemissivoGlobal
    let tema: TemaLeitura
    let abrir: (BibliotecaResultadoBusca) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(entrada.termo)
                    .font(.headline)
                    .foregroundStyle(tema.textoPrincipal)

                Spacer()

                Text("\(entrada.ocorrencias.count)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(tema.textoSobreDestaque)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(tema.fundoDestaque)
                    .clipShape(Capsule())
            }

            ForEach(entrada.ocorrencias) { resultado in
                Button {
                    abrir(resultado)
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(resultado.obra.titulo)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(tema.textoPrincipal)

                            Text("\(resultado.item.referenciaExibicao) • \(resultado.contexto)")
                                .font(.caption2)
                                .foregroundStyle(tema.textoSecundario)
                                .lineLimit(2)
                        }

                        Spacer()

                        Image(systemName: "arrow.up.forward")
                            .font(.caption)
                            .foregroundStyle(tema.destaque)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tema.background.opacity(0.22))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct ColecaoTematicaCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .subheadline) private var larguraReferencia = 102.0
    let colecao: ColecaoTematica
    let tema: TemaLeitura
    let abrir: (BreviarioItem) -> Void
    @State private var expandida = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: colecao.icone)
                    .foregroundStyle(tema.destaque)
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(colecao.titulo)
                        .font(.headline)
                        .foregroundStyle(tema.textoPrincipal)

                    Text("\(colecao.itens.count) leituras")
                        .font(.caption)
                        .foregroundStyle(tema.textoSecundario)
                }
            }

            Text(colecao.subtitulo)
                .font(.caption)
                .foregroundStyle(tema.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)

            Text(colecao.detalhe)
                .font(.caption)
                .foregroundStyle(tema.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)

            if colecao.topicos.isEmpty == false {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(colecao.topicos, id: \.self) { topico in
                            Text(topico)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .fixedSize(horizontal: true, vertical: true)
                                .foregroundStyle(tema == .escuro ? .white : .black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(tema.destaque.opacity(tema == .escuro ? 0.28 : 0.18))
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            ForEach(expandida ? colecao.itens : Array(colecao.itens.prefix(3)), id: \.chavePersistencia) { item in
                Button {
                    abrir(item)
                } label: {
                    let layout = dynamicTypeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
                        : AnyLayout(HStackLayout())
                    layout {
                        Text(item.referenciaExibicao)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(tema.destaque)
                            .frame(width: dynamicTypeSize.isAccessibilitySize ? nil : larguraReferencia, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(alignment: .leading, spacing: 3) {
                            if item.data.hasPrefix("P") && !item.frase.isEmpty {
                                Text(item.frase)
                                    .font(.caption)
                                    .foregroundStyle(tema.textoSecundario)
                            }
                            Text(item.titulo)
                                .font(.subheadline)
                                .foregroundStyle(tema.textoPrincipal)
                        }
                        .fixedSize(horizontal: false, vertical: true)

                        Spacer()
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                    .padding(8)
                    .background(tema.painel)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            if colecao.itens.count > 3 {
                Button { expandida.toggle() } label: {
                    Text(expandida ? "Recolher leituras" : "Ver todas as leituras")
                        .font(.subheadline)
                        .foregroundStyle(tema.textoPrincipal)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(tema.painel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct TrilhaEstudoCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption) private var tamanhoNumero = 24.0
    let trilha: TrilhaEstudo
    let tema: TemaLeitura
    let abrir: (BreviarioItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(trilha.titulo, systemImage: trilha.icone)
                .font(.headline)
                .foregroundStyle(tema.destaque)

            let etiquetas = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                : AnyLayout(HStackLayout(spacing: 8))
            etiquetas {
                TrilhaEtiqueta(texto: trilha.instrucao, icone: "list.bullet.clipboard", tema: tema)
                TrilhaEtiqueta(texto: trilha.duracaoSugerida, icone: "calendar", tema: tema)
            }

            Text(trilha.subtitulo)
                .font(.caption)
                .foregroundStyle(tema.textoSecundario)

            Text(trilha.objetivo)
                .font(.caption)
                .foregroundStyle(tema.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)

            if trilha.etapas.isEmpty == false {
                VStack(alignment: .leading, spacing: 5) {
                        ForEach(Array(trilha.etapas.enumerated()), id: \.offset) { indice, etapa in
                        HStack(alignment: .top, spacing: 7) {
                            Text("\(indice + 1)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(tema.textoSobreDestaque)
                                .frame(width: tamanhoNumero, height: tamanhoNumero)
                                .background(tema.fundoDestaque)
                                .clipShape(Circle())

                            Text(etapa)
                                .font(.caption)
                                .foregroundStyle(tema.textoSecundario)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(10)
                .background(tema.background.opacity(0.22))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(trilha.itens.enumerated()), id: \.element.chavePersistencia) { indice, item in
                        Button {
                            abrir(item)
                        } label: {
                            TrilhaItemCard(indice: indice + 1, item: item, tema: tema)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding()
        .background(tema.painel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct TrilhaEtiqueta: View {
    let texto: String
    let icone: String
    let tema: TemaLeitura

    var body: some View {
        Label(texto, systemImage: icone)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(tema == .escuro ? .white : .black)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(tema.destaque.opacity(tema == .escuro ? 0.24 : 0.16),
                        in: RoundedRectangle(cornerRadius: 8))
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct TrilhaItemCard: View {
    @ScaledMetric(relativeTo: .caption) private var tamanhoNumero = 24.0
    let indice: Int
    let item: BreviarioItem
    let tema: TemaLeitura

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(indice)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(tema.textoSobreDestaque)
                .frame(width: tamanhoNumero, height: tamanhoNumero)
                .background(tema.fundoDestaque)
                .clipShape(Circle())

            Text(item.referenciaExibicao)
                .font(.caption)
                .foregroundStyle(tema.textoSecundario)

            if item.data.hasPrefix("P") && !item.frase.isEmpty {
                Text(item.frase)
                    .font(.caption)
                    .foregroundStyle(tema.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(item.titulo)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(tema.textoPrincipal)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 150, alignment: .topLeading)
        .frame(minHeight: 116, alignment: .topLeading)
        .padding(10)
        .background(tema.painel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
