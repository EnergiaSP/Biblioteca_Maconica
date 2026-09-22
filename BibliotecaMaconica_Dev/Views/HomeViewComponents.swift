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

    func corStatus(destaque: Color) -> Color {
        concluida ? .green : destaque
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

    static func corresponde(texto: String, palavras: [String]) -> Bool {
        palavras.contains { palavra in
            !palavra.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            texto.range(of: palavra, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    static func normalizar(_ texto: String) -> String {
        texto.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "pt_BR"))
    }

    static func selecionar(_ itens: [BreviarioItem], palavras: [String], textos: [String: String], limite: Int) -> [BreviarioItem] {
        incorporar([], lote: itens, palavras: palavras, textos: textos, limite: limite)
    }

    static func incorporar(_ selecionados: [BreviarioItem], lote: [BreviarioItem], palavras: [String], textos: [String: String], limite: Int) -> [BreviarioItem] {
        incorporarNormalizados(selecionados, lote: lote, palavras: palavras.map(normalizar), textos: textos.mapValues(normalizar), limite: limite)
    }

    static func incorporarNormalizados(_ selecionados: [BreviarioItem], lote: [BreviarioItem], palavras: [String], textos: [String: String], limite: Int) -> [BreviarioItem] {
        guard limite > 0 else { return [] }
        let acumulados = selecionados.sorted(by: precede).prefix(limite)
        let fronteira = acumulados.count == limite ? acumulados.last : nil
        let palavras = palavras.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let candidatos = acumulados + lote.filter { item in
            // Later references cannot displace the already selected top results.
            if let fronteira, !precede(item, fronteira) { return false }
            let texto = (textos[item.chavePersistencia] ?? "") as NSString
            return palavras.contains { texto.range(of: $0, options: .literal).location != NSNotFound }
        }
        var chaves = Set<String>()
        return candidatos.filter { chaves.insert($0.chavePersistencia).inserted }
            .sorted(by: precede).prefix(limite).map { $0 }
    }

    private static func precede(_ lhs: BreviarioItem, _ rhs: BreviarioItem) -> Bool {
        if lhs.obraID != rhs.obraID { return lhs.obraID < rhs.obraID }
        if (lhs.pagina ?? 0) != (rhs.pagina ?? 0) { return (lhs.pagina ?? 0) < (rhs.pagina ?? 0) }
        return lhs.data < rhs.data
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

struct DiaCalendarioLeitura: Identifiable {
    let id: String
    let dia: Int?
    let data: String?
    let item: BreviarioItem?
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
