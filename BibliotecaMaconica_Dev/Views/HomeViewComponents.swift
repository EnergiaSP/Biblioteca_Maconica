import SwiftUI
import UIKit

struct Compartilhamento: Identifiable {
    let id = UUID()
    let items: [Any]
}

struct LeituraRecenteBreviario: Identifiable {
    let obra: BibliotecaObra
    let item: BreviarioItem

    var id: String {
        "\(obra.id)-\(item.data)"
    }
}

struct LeituraDiariaBreviario: Identifiable {
    let obra: BibliotecaObra
    let item: BreviarioItem?
    let concluida: Bool

    var id: String {
        "\(obra.id)-diaria-\(item?.data ?? "sem-conteudo")"
    }

    var tituloExibicao: String {
        if concluida {
            return "Leitura diária Concluida"
        }

        return item?.titulo ?? "Leitura diária não importada"
    }

    var iconeStatus: String {
        if concluida {
            return "checkmark.seal.fill"
        }

        return item == nil ? "exclamationmark.circle" : "arrow.right"
    }

}

struct TelaAberturaCarregamentoView: View {
    @State private var animando = false
    @State private var brilho = false

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 26) {
                iconeAnimado

                VStack(spacing: 5) {
                    Text("Biblioteca Maçônica")
                        .font(.system(size: 29, weight: .semibold, design: .serif))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, Color(red: 0.95, green: 0.78, blue: 0.34)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Text("Estudos maçônicos")
                        .font(.system(size: 17, weight: .medium, design: .default))
                        .foregroundStyle(.white.opacity(0.78))
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
                .opacity(animando ? 1 : 0.72)
                .offset(y: animando ? 0 : 8)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                animando = true
            }

            brilho = false
            withAnimation(.linear(duration: 1.35).delay(0.25).repeatForever(autoreverses: false)) {
                brilho = true
            }
        }
    }

    private var iconeAnimado: some View {
        imagemIconeApp
            .frame(width: 164, height: 164)
            .clipShape(RoundedRectangle(cornerRadius: 36))
            .overlay {
                GeometryReader { proxy in
                    let largura = proxy.size.width
                    let altura = proxy.size.height

                    Rectangle()
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: .white.opacity(0.16), location: 0.42),
                                    .init(color: .white.opacity(0.78), location: 0.5),
                                    .init(color: Color(red: 0.95, green: 0.78, blue: 0.34).opacity(0.28), location: 0.58),
                                    .init(color: .clear, location: 1)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: largura * 0.34, height: altura * 1.7)
                        .rotationEffect(.degrees(24))
                        .offset(x: brilho ? largura * 1.28 : -largura * 0.62, y: -altura * 0.28)
                        .blendMode(.screen)
                }
                .clipShape(RoundedRectangle(cornerRadius: 36))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 36)
                    .stroke(.white.opacity(animando ? 0.20 : 0.08), lineWidth: 1)
            }
            .shadow(color: Color(red: 0.95, green: 0.72, blue: 0.28).opacity(animando ? 0.34 : 0.16), radius: animando ? 28 : 16, x: 0, y: 12)
            .scaleEffect(animando ? 1.03 : 0.98)
            .opacity(animando ? 1 : 0.88)
    }

    private var imagemIconeApp: some View {
        Group {
            if let imagem = UIImage(named: "AppLaunchIcon") {
                Image(uiImage: imagem)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 74, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
            }
        }
    }
}

struct ColecaoTematica: Identifiable {
    let id: String
    let titulo: String
    let subtitulo: String
    let detalhe: String
    let icone: String
    let palavrasChave: [String]
    let topicos: [String]
    let itens: [BreviarioItem]

    func comItens(_ itens: [BreviarioItem]) -> ColecaoTematica {
        ColecaoTematica(
            id: id,
            titulo: titulo,
            subtitulo: subtitulo,
            detalhe: detalhe,
            icone: icone,
            palavrasChave: palavrasChave,
            topicos: topicos,
            itens: Array(itens.prefix(RegrasEstudo.compartilhadas.collectionLimit))
        )
    }

    static let padroes: [ColecaoTematica] = RegrasEstudo.compartilhadas.colecoes.map {
        ColecaoTematica(id: $0.id, titulo: $0.titulo, subtitulo: $0.subtitulo, detalhe: $0.detalhe,
                       icone: $0.icone, palavrasChave: $0.palavrasChave, topicos: $0.topicos, itens: [])
    }
}

struct TrilhaEstudo: Identifiable {
    let id: String
    let titulo: String
    let subtitulo: String
    let objetivo: String
    let icone: String
    let instrucao: String
    let duracaoSugerida: String
    let etapas: [String]
    let itens: [BreviarioItem]

    init(
        id: String,
        titulo: String,
        subtitulo: String,
        objetivo: String,
        icone: String,
        instrucao: String = "Estudo geral",
        duracaoSugerida: String = "7 a 14 dias",
        etapas: [String] = [],
        itens: [BreviarioItem]
    ) {
        self.id = id
        self.titulo = titulo
        self.subtitulo = subtitulo
        self.objetivo = objetivo
        self.icone = icone
        self.instrucao = instrucao
        self.duracaoSugerida = duracaoSugerida
        self.etapas = etapas
        self.itens = itens
    }
}

struct RegrasEstudo: Decodable {
    let schemaVersion: Int
    let collectionLimit: Int
    let pathLimit: Int
    let colecoes: [Colecao]
    let trilhas: [Trilha]

    /// A page belongs to a theme when a keyword appears as whole words: "lei" does not match "leitura".
    static func corresponde(texto: String, palavras: [String]) -> Bool {
        !contarPalavras(normalizar(texto), palavras: palavrasChave(palavras.map(normalizar))).isEmpty
    }

    /// Folds case and accents and keeps only words, padded with spaces so keywords match whole words.
    static func normalizar(_ texto: String) -> String {
        let dobrado = texto
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "pt_BR"))
            .lowercased()
        var saida = String.UnicodeScalarView()
        saida.append(" ")
        var terminouEmEspaco = true
        for caractere in dobrado.unicodeScalars {
            if alfanumericos.contains(caractere) {
                saida.append(caractere)
                terminouEmEspaco = false
            } else if !terminouEmEspaco {
                saida.append(" ")
                terminouEmEspaco = true
            }
        }
        if !terminouEmEspaco { saida.append(" ") }
        return String(saida)
    }

    private static let alfanumericos = CharacterSet.alphanumerics

    /// Relevance of a page for a theme: distinct keywords found first, then total occurrences.
    struct ItemPontuado {
        let item: BreviarioItem
        let temas: Int
        let ocorrencias: Int
    }

    static func selecionar(_ itens: [BreviarioItem], palavras: [String], textos: [String: String], limite: Int) -> [BreviarioItem] {
        incorporar([], lote: itens, palavras: palavras, textos: textos, limite: limite)
    }

    static func incorporar(_ selecionados: [BreviarioItem], lote: [BreviarioItem], palavras: [String], textos: [String: String], limite: Int) -> [BreviarioItem] {
        let palavrasNormalizadas = palavras.map(normalizar)
        let textosNormalizados = textos.mapValues(normalizar)
        let anteriores = incorporarNormalizados([], lote: selecionados, palavras: palavrasNormalizadas,
                                                textos: textosNormalizados, limite: Int.max)
        return incorporarNormalizados(anteriores, lote: lote, palavras: palavrasNormalizadas,
                                      textos: textosNormalizados, limite: limite).map(\.item)
    }

    static func incorporarNormalizados(_ selecionados: [ItemPontuado], lote: [BreviarioItem], palavras: [String], textos: [String: String], limite: Int) -> [ItemPontuado] {
        let chaves = palavrasChave(palavras)
        let contador = ContadorPalavras(palavras: chaves)
        let contagens = textos.mapValues(contador.contar)
        return incorporarContagens(selecionados, lote: lote, palavras: chaves, contagens: contagens, limite: limite)
    }

    /// Keeps the `limite` most relevant pages. The result does not depend on batch size or order,
    /// so the catalog can be streamed in batches without holding every page in memory.
    /// `contagens` comes from `contarPalavras` over all rules' keywords, so each page is read once.
    static func incorporarContagens(_ selecionados: [ItemPontuado], lote: [BreviarioItem], palavras: Set<String>, contagens: [String: [String: Int]], limite: Int) -> [ItemPontuado] {
        guard limite > 0 else { return [] }
        let candidatos = selecionados + lote.compactMap { item in
            pontuar(item, palavras: palavras, contagens: contagens[item.chavePersistencia] ?? [:])
        }
        var vistas = Set<String>()
        return candidatos.sorted(by: precede).filter { vistas.insert($0.item.chavePersistencia).inserted }
            .prefix(limite).map { $0 }
    }

    /// Normalized keywords without padding, ignoring blanks and repetitions.
    static func palavrasChave(_ palavras: [String]) -> Set<String> {
        Set(palavras.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
    }

    /// Counts, in a single pass over a normalized page, the occurrences of each keyword, including phrases.
    static func contarPalavras(_ texto: String, palavras: Set<String>) -> [String: Int] {
        ContadorPalavras(palavras: palavras).contar(texto)
    }

    /// Keyword lookup built once and reused across many texts.
    struct ContadorPalavras {
        private let simples: Set<Substring>
        private let expressoes: [[Substring]]
        private let iniciosExpressoes: Set<Substring>

        init(palavras: Set<String>) {
            simples = Set(palavras.filter { !$0.contains(" ") }.map { Substring($0) })
            expressoes = palavras.filter { $0.contains(" ") }.map { $0.split(separator: " ") }
            iniciosExpressoes = Set(expressoes.compactMap(\.first))
        }

        func contar(_ texto: String) -> [String: Int] {
            let tokens = texto.split(separator: " ")
            var contagens: [String: Int] = [:]
            for (indice, token) in tokens.enumerated() {
                if simples.contains(token) {
                    contagens[String(token), default: 0] += 1
                }
                guard iniciosExpressoes.contains(token) else { continue }
                for expressao in expressoes where expressao.first == token && indice + expressao.count <= tokens.count {
                    if tokens[indice..<(indice + expressao.count)].elementsEqual(expressao) {
                        contagens[expressao.joined(separator: " "), default: 0] += 1
                    }
                }
            }
            return contagens
        }
    }

    private static func pontuar(_ item: BreviarioItem, palavras: Set<String>, contagens: [String: Int]) -> ItemPontuado? {
        var temas = 0
        var ocorrencias = 0
        for palavra in palavras {
            if let quantidade = contagens[palavra], quantidade > 0 {
                temas += 1
                ocorrencias += quantidade
            }
        }
        return temas == 0 ? nil : ItemPontuado(item: item, temas: temas, ocorrencias: ocorrencias)
    }

    private static func precede(_ lhs: ItemPontuado, _ rhs: ItemPontuado) -> Bool {
        if lhs.temas != rhs.temas { return lhs.temas > rhs.temas }
        if lhs.ocorrencias != rhs.ocorrencias { return lhs.ocorrencias > rhs.ocorrencias }
        if lhs.item.obraID != rhs.item.obraID { return lhs.item.obraID < rhs.item.obraID }
        if (lhs.item.pagina ?? 0) != (rhs.item.pagina ?? 0) { return (lhs.item.pagina ?? 0) < (rhs.item.pagina ?? 0) }
        return lhs.item.data < rhs.item.data
    }

    struct Colecao: Decodable {
        let id, titulo, subtitulo, detalhe, icone: String
        let palavrasChave, topicos: [String]
    }
    struct Trilha: Decodable {
        let id, titulo, subtitulo, objetivo, icone, instrucao, duracaoSugerida: String
        let etapas, palavrasChave: [String]
    }
    static let compartilhadas: RegrasEstudo = {
        guard let url = Bundle.main.url(forResource: "regras_estudo_v1", withExtension: "json"),
              let dados = try? Data(contentsOf: url),
              let regras = try? JSONDecoder().decode(RegrasEstudo.self, from: dados), regras.schemaVersion == 1 else {
            return RegrasEstudo(schemaVersion: 0, collectionLimit: 24, pathLimit: 18, colecoes: [], trilhas: [])
        }
        return regras
    }()
}

struct HistoricoReflexao: Identifiable {
    var id: String {
        item.chavePersistencia
    }

    let item: BreviarioItem
    let texto: String
}

enum FiltroLeitura: String, CaseIterable, Identifiable {
    case todos
    case favoritos
    case lidos
    case naoLidos
    case comComentarios

    var id: String {
        rawValue
    }

    var titulo: String {
        switch self {
        case .todos:
            "Todos"
        case .favoritos:
            "Favoritos"
        case .lidos:
            "Lidos"
        case .naoLidos:
            "Não lidos"
        case .comComentarios:
            "Comentários"
        }
    }

    var icone: String {
        switch self {
        case .todos:
            "list.bullet"
        case .favoritos:
            "star.fill"
        case .lidos:
            "checkmark.seal.fill"
        case .naoLidos:
            "circle"
        case .comComentarios:
            "text.bubble"
        }
    }
}

struct ActivityShareView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
    }
}
