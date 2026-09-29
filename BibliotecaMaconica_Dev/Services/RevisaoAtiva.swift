import CryptoKit
import Foundation

/// Active review: flashcards and quiz made from a dossier, always with the source. Mirrors
/// `Tools/revisao_referencia.py`; `casos_revisao_v1.json` holds the golden cases both apps reproduce.
enum RevisaoAtiva {
    typealias D = DossieEstudoAnalise

    struct Configuracao: Decodable {
        struct Limites: Decodable {
            let cartoesPorSessao, alternativas, alternativasMinimas: Int
        }
        let schemaVersion: Int
        let limites: Limites
        let intervalos: [Int]
        let rotulos: [String: String]

        static let compartilhada: Configuracao? = {
            guard let url = Bundle.main.url(forResource: "revisao_ativa_v1", withExtension: "json"),
                  let dados = try? Data(contentsOf: url),
                  let configuracao = try? JSONDecoder().decode(Configuracao.self, from: dados),
                  configuracao.schemaVersion == 1 else { return nil }
            return configuracao
        }()

        /// Label with its "{name}" placeholders filled.
        func rotulo(_ chave: String, _ valores: [String: String] = [:]) -> String {
            valores.reduce(rotulos[chave] ?? chave) { $0.replacingOccurrences(of: "{\($1.key)}", with: $1.value) }
        }
    }

    enum Nota: String, CaseIterable { case errei, dificil, acertei }

    struct Cartao: Codable, Equatable, Identifiable {
        let id: String
        let tipo: String
        let frente: String
        let verso: String
        let fonte: String
        let alternativas: [String]
    }

    struct Estado: Codable, Equatable {
        var caixa: Int
        /// yyyy-MM-dd
        var vencimento: String
        var acertos: Int
        var erros: Int
    }

    private static let separador = "\u{1F}"

    static func sha(_ texto: String) -> String {
        SHA256.hash(data: Data(texto.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func tema(_ termo: String) -> String {
        D.nfc(termo).unicodeScalars.split { $0.properties.isWhitespace }.map { D.texto(ArraySlice($0)) }.joined(separator: " ")
    }

    private static func cartao(_ tipo: String, _ frente: String, _ verso: String, _ fonte: String,
                               alternativas: [String] = []) -> Cartao {
        let id = String(sha([tipo, frente, verso, fonte].joined(separator: separador)).prefix(16))
        return Cartao(id: id, tipo: tipo, frente: frente, verso: verso, fonte: fonte, alternativas: alternativas)
    }

    /// The answer and the first associated forms that differ from it ("degrau" and "degraus" count as
    /// the same), in a fixed shuffled order; empty when there are too few.
    static func alternativas(id: String, resposta: String, formas: [String], configuracao: Configuracao) -> [String] {
        var escolhidas = [resposta]
        var vistas = [D.dobrar(resposta)]
        for forma in formas where escolhidas.count < configuracao.limites.alternativas {
            let dobrada = D.dobrar(forma)
            if !vistas.contains(where: { dobrada.hasPrefix($0) || $0.hasPrefix(dobrada) }) {
                vistas.append(dobrada)
                escolhidas.append(forma)
            }
        }
        guard escolhidas.count >= configuracao.limites.alternativasMinimas else { return [] }
        return escolhidas.sorted { sha(id + separador + $0) < sha(id + separador + $1) }
    }

    static func gerar(termo: String, definicoes: [D.Trecho], perguntas: [D.Pergunta], formas: [String],
                      fontes: [D.Fonte], configuracao: Configuracao) -> [Cartao] {
        let porId = Dictionary(fontes.map { ($0.id, $0) }, uniquingKeysWith: { primeira, _ in primeira })
        func citar(_ id: String) -> String {
            guard let fonte = porId[id] else { return id }
            return "\(fonte.tituloObra), \(D.referencia(fonte))"
        }
        let frenteDefinicao = configuracao.rotulo("definicao", ["tema": tema(termo)])
        var cartoes = definicoes.map { cartao("definicao", frenteDefinicao, $0.texto, citar($0.fonte)) }
        for pergunta in perguntas {
            let base = cartao("lacuna", pergunta.pergunta, pergunta.resposta, citar(pergunta.fonte))
            cartoes.append(cartao("lacuna", pergunta.pergunta, pergunta.resposta, citar(pergunta.fonte),
                                  alternativas: alternativas(id: base.id, resposta: pergunta.resposta, formas: formas,
                                                             configuracao: configuracao)))
        }
        return cartoes
    }

    // MARK: - Agenda

    private static let calendario: Calendar = {
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = TimeZone(identifier: "UTC")!
        return calendario
    }()

    private static let formato: DateFormatter = {
        let formato = DateFormatter()
        formato.calendar = calendario
        formato.locale = Locale(identifier: "en_US_POSIX")
        formato.timeZone = calendario.timeZone
        formato.dateFormat = "yyyy-MM-dd"
        return formato
    }()

    static func somarDias(_ dia: String, _ dias: Int) -> String {
        guard let data = formato.date(from: dia), let nova = calendario.date(byAdding: .day, value: dias, to: data) else { return dia }
        return formato.string(from: nova)
    }

    static func novoEstado(hoje: String) -> Estado { Estado(caixa: 0, vencimento: hoje, acertos: 0, erros: 0) }

    /// errei: back to box 0; dificil: same box; acertei: one box up. Due today + interval of the box.
    static func responder(_ estado: Estado, nota: Nota, hoje: String, configuracao: Configuracao) -> Estado {
        let ultima = configuracao.intervalos.count - 1
        let caixa: Int = switch nota {
        case .errei: 0
        case .dificil: estado.caixa
        case .acertei: min(estado.caixa + 1, ultima)
        }
        return Estado(caixa: caixa, vencimento: somarDias(hoje, configuracao.intervalos[caixa]),
                      acertos: estado.acertos + (nota == .acertei ? 1 : 0), erros: estado.erros + (nota == .errei ? 1 : 0))
    }

    /// Ids of the cards due until today: by due date, then creation date, then id; up to the limit.
    static func sessao(_ cartoes: [(id: String, criadoEm: String, vencimento: String)], hoje: String,
                       configuracao: Configuracao) -> [String] {
        cartoes.filter { $0.vencimento <= hoje }
            .sorted { ($0.vencimento, $0.criadoEm, $0.id) < ($1.vencimento, $1.criadoEm, $1.id) }
            .prefix(configuracao.limites.cartoesPorSessao)
            .map(\.id)
    }
}

/// Review cards on this device, with their progress. Same fields and rules as Android `ReviewCardStore`.
struct CartoesRevisaoStore {
    struct Registro: Codable, Equatable, Identifiable {
        let cartao: RevisaoAtiva.Cartao
        let dossieId: String
        let tema: String
        /// yyyy-MM-dd
        let criadoEm: String
        var estado: RevisaoAtiva.Estado
        var id: String { cartao.id }
    }

    private let defaults: UserDefaults
    private static let chave = "cartoesRevisaoV1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func todos() -> [Registro] {
        guard let dados = defaults.data(forKey: Self.chave),
              let lista = try? JSONDecoder().decode([Registro].self, from: dados) else { return [] }
        return lista
    }

    /// Adds the dossier's cards that are not stored yet; stored cards keep their progress.
    @discardableResult
    func adicionar(_ cartoes: [RevisaoAtiva.Cartao], dossieId: String, tema: String, hoje: String) -> Int {
        let atuais = todos()
        let existentes = Set(atuais.map(\.id))
        let novos = cartoes.filter { !existentes.contains($0.id) }.map {
            Registro(cartao: $0, dossieId: dossieId, tema: tema, criadoEm: hoje, estado: RevisaoAtiva.novoEstado(hoje: hoje))
        }
        if !novos.isEmpty { gravar(atuais + novos) }
        return novos.count
    }

    func responder(id: String, nota: RevisaoAtiva.Nota, hoje: String, configuracao: RevisaoAtiva.Configuracao) {
        gravar(todos().map { registro in
            guard registro.id == id else { return registro }
            var novo = registro
            novo.estado = RevisaoAtiva.responder(registro.estado, nota: nota, hoje: hoje, configuracao: configuracao)
            return novo
        })
    }

    /// Cards due until today, in session order.
    func sessao(hoje: String, configuracao: RevisaoAtiva.Configuracao) -> [Registro] {
        let lista = todos()
        let porId = Dictionary(lista.map { ($0.id, $0) }, uniquingKeysWith: { primeiro, _ in primeiro })
        return RevisaoAtiva.sessao(lista.map { ($0.id, $0.criadoEm, $0.estado.vencimento) }, hoje: hoje, configuracao: configuracao)
            .compactMap { porId[$0] }
    }

    /// Replaces every card (a merged notebook already kept the ones that were here).
    func substituir(_ registros: [Registro]) {
        gravar(registros)
    }

    func removerDossie(_ dossieId: String) {
        gravar(todos().filter { $0.dossieId != dossieId })
    }

    private func gravar(_ lista: [Registro]) {
        defaults.set(try? JSONEncoder().encode(lista), forKey: Self.chave)
    }
}
