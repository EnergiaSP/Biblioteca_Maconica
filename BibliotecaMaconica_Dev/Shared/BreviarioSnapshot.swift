import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

struct BreviarioSnapshot: Codable, Identifiable {
    let id: Int
    let data: String
    let titulo: String
    let frase: String
    let texto: String
    let autor: String
    let obraID: String
    var rodape: String? = nil

    var dataPorExtenso: String {
        Self.dataPorExtenso(data)
    }

    var resumo: String {
        let base = frase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? texto : frase
        return Self.resumo(base, limite: 150)
    }

    var trecho: String {
        Self.resumo(texto, limite: 320)
    }

    var deepLink: URL? {
        URL(string: "breviario://leitura?obra=\(obraID)&data=\(data.replacingOccurrences(of: "/", with: "-"))")
    }

    static let vazio = BreviarioSnapshot(
        id: 0,
        data: "--/--",
        titulo: "Breviário Maçônico",
        frase: "Importe ou abra o app para carregar a leitura do dia.",
        texto: "Importe ou abra o app para carregar a leitura do dia.",
        autor: "Kennyo Ismail",
        obraID: "breviario_seculo_xxi"
    )

    private static func resumo(_ texto: String, limite: Int) -> String {
        let textoLimpo = texto
            .components(separatedBy: CharacterSet.whitespacesAndNewlines)
            .filter { $0.isEmpty == false }
            .joined(separator: " ")

        guard textoLimpo.count > limite else {
            return textoLimpo
        }

        let indice = textoLimpo.index(textoLimpo.startIndex, offsetBy: limite)
        let prefixo = textoLimpo[..<indice]
        if let ultimoEspaco = prefixo.lastIndex(where: { $0.isWhitespace }) {
            return "\(textoLimpo[..<ultimoEspaco])..."
        }

        return "\(prefixo)..."
    }

    private static func dataPorExtenso(_ data: String) -> String {
        let partes = data.split(separator: "/").compactMap { Int($0) }
        guard partes.count == 2, (1...31).contains(partes[0]), (1...12).contains(partes[1]) else {
            return data
        }

        let meses = [
            "janeiro", "fevereiro", "março", "abril", "maio", "junho",
            "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"
        ]

        return String(format: "%02d de %@", partes[0], meses[partes[1] - 1])
    }
}

enum BreviarioSnapshotProvider {

    static let appGroupID = "group.com.renatocamargo.BreviarioMaconicoSeculoXXIPrivado"
    private static let chaveSnapshotAtual = "biblioteca.snapshot.atual"

    static func salvarSnapshotAtual(_ snapshot: BreviarioSnapshot) {
        guard let dados = try? JSONEncoder().encode(snapshot) else {
            return
        }

        UserDefaults(suiteName: appGroupID)?.set(dados, forKey: chaveSnapshotAtual)
#if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: "BreviarioWidget")
#endif
    }

    static func snapshotCompartilhadoAtual() -> BreviarioSnapshot? {
        guard let dados = UserDefaults(suiteName: appGroupID)?.data(forKey: chaveSnapshotAtual) else {
            return nil
        }

        return try? JSONDecoder().decode(BreviarioSnapshot.self, from: dados)
    }

    static func leituraDoDia(bundle: Bundle = .main, data: Date = Date()) -> BreviarioSnapshot {
        leiturasDoDia(bundle: bundle, data: data).first ?? .vazio
    }

    static func leiturasDoDia(bundle: Bundle = .main, data: Date = Date()) -> [BreviarioSnapshot] {
        let dataHoje = formatter.string(from: data)
        let compartilhado = snapshotCompartilhadoAtual().flatMap {
            $0.data == dataHoje ? $0 : nil
        }

        let leituras = recursosEmbutidos.compactMap { recurso -> BreviarioSnapshot? in
            guard let url = bundle.url(forResource: recurso.nome, withExtension: "json"),
                  let dados = try? Data(contentsOf: url),
                  let breviario = decodificar(dados: dados),
                  let item = breviario.itens.first(where: { $0.data == dataHoje }) ?? breviario.itens.first else {
                return nil
            }

            let obraID = item.obraID ?? recurso.obraID
            if let compartilhado, compartilhado.obraID == obraID {
                return compartilhado
            }
            return snapshot(item: item, obraID: obraID, autorPadrao: recurso.autor)
        }

        if leituras.isEmpty, let compartilhado {
            return [compartilhado]
        }
        return leituras
    }

    // A notification may be opened on another day. Never substitute today's reading.
    static func leitura(data: String, obraID: String, bundle: Bundle = .main) -> BreviarioSnapshot? {
        if let atual = snapshotCompartilhadoAtual(), atual.data == data, atual.obraID == obraID {
            return atual
        }
        let recurso = recursosEmbutidos.first(where: { $0.obraID == obraID })
        guard let recurso,
              let url = bundle.url(forResource: recurso.nome, withExtension: "json"),
              let dados = try? Data(contentsOf: url),
              let acervo = decodificar(dados: dados),
              let item = acervo.itens.first(where: {
                  $0.data == data && ($0.obraID ?? "breviario_seculo_xxi") == obraID
              }) else { return nil }
        return snapshot(item: item, obraID: obraID, autorPadrao: recurso.autor)
    }

    private static func snapshot(item: SnapshotItem, obraID: String, autorPadrao: String) -> BreviarioSnapshot {
        BreviarioSnapshot(
            id: item.id, data: item.data, titulo: item.titulo,
            frase: fraseExibicao(frase: item.frase, texto: item.texto) ?? "",
            texto: item.texto, autor: item.autor ?? autorPadrao, obraID: obraID, rodape: item.rodape
        )
    }

    private static func decodificar(dados: Data) -> SnapshotData? {
        let decoder = JSONDecoder()

        if let dadosCompletos = try? decoder.decode(SnapshotData.self, from: dados) {
            return dadosCompletos
        }

        if let itens = try? decoder.decode([SnapshotItem].self, from: dados) {
            return SnapshotData(itens: itens)
        }

        return nil
    }

    private struct SnapshotData: Codable {
        let itens: [SnapshotItem]
    }

    private struct SnapshotItem: Codable {
        let id: Int
        let data: String
        let titulo: String
        let frase: String
        let texto: String
        let autor: String?
        let obraID: String?
        let rodape: String?
    }

    private static func fraseExibicao(frase: String, texto: String) -> String? {
        let fraseLimpa = frase.trimmingCharacters(in: .whitespacesAndNewlines)
        let textoLimpo = texto.trimmingCharacters(in: .whitespacesAndNewlines)

        guard fraseLimpa.isEmpty == false else {
            return nil
        }

        if normalizarParaExibicao(fraseLimpa) == normalizarParaExibicao(textoLimpo) {
            return nil
        }

        if textoLimpo.hasPrefix(fraseLimpa), fraseLimpa.count > 320 {
            return nil
        }

        return fraseLimpa
    }

    private static func normalizarParaExibicao(_ texto: String) -> String {
        texto
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .components(separatedBy: CharacterSet.whitespacesAndNewlines)
            .filter { $0.isEmpty == false }
            .joined(separator: " ")
    }

    private static let recursosEmbutidos = [
        (nome: "breviario", obraID: "breviario_seculo_xxi", autor: "Kennyo Ismail"),
        (nome: "breviario_rizzardo", obraID: "breviario_rizzardo_da_camino", autor: "Rizzardo da Camino")
    ]

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "dd/MM"
        return formatter
    }()
}
