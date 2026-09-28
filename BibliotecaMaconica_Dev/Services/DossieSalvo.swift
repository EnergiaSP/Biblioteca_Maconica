import Foundation

/// A saved dossier keeps the question, not the answer: reopening rebuilds it from the installed
/// collection, so it never shows outdated text. Reviews are dated from the day it was saved.
/// Same fields and rules as Android `SavedDossier`.
struct DossieSalvo: Codable, Identifiable, Equatable {
    enum Situacao: String { case feita, atrasada, hoje, proxima }

    struct Revisao: Equatable {
        let dias: Int
        let tarefa: String
        let data: Date
        let situacao: Situacao
    }

    let id: String
    let tema: String
    let area: String?
    let obraId: String?
    let autor: String
    let assunto: String
    /// yyyy-MM-dd
    let criadoEm: String
    var revisoesConcluidas: [Int] = []

    /// Identifies the same study (topic and scope), ignoring case and surrounding spaces.
    var chave: String { Self.chave(tema: tema, area: area, obraId: obraId, autor: autor, assunto: assunto) }

    var dataCriacao: Date { Self.formato.date(from: criadoEm) ?? Date() }

    func revisoes(passos: [DossieEstudoAnalise.Configuracao.Revisao], hoje: Date) -> [Revisao] {
        let calendario = Self.calendario
        let inicioHoje = calendario.startOfDay(for: hoje)
        return passos.map { passo in
            let data = calendario.date(byAdding: .day, value: passo.dias, to: dataCriacao) ?? dataCriacao
            let situacao: Situacao = if revisoesConcluidas.contains(passo.dias) {
                .feita
            } else if data < inicioHoje {
                .atrasada
            } else if calendario.isDate(data, inSameDayAs: inicioHoje) {
                .hoje
            } else {
                .proxima
            }
            return Revisao(dias: passo.dias, tarefa: passo.tarefa, data: data, situacao: situacao)
        }
    }

    func proximaRevisao(passos: [DossieEstudoAnalise.Configuracao.Revisao], hoje: Date) -> Revisao? {
        revisoes(passos: passos, hoje: hoje).first { $0.situacao != .feita }
    }

    func alternando(_ dias: Int) -> DossieSalvo {
        var copia = self
        copia.revisoesConcluidas = revisoesConcluidas.contains(dias)
            ? revisoesConcluidas.filter { $0 != dias }
            : (revisoesConcluidas + [dias]).sorted()
        return copia
    }

    static func chave(tema: String, area: String?, obraId: String?, autor: String, assunto: String) -> String {
        [tema, area ?? "", obraId ?? "", autor, assunto]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .joined(separator: "|")
    }

    static func data(_ date: Date) -> String { formato.string(from: date) }

    static let calendario: Calendar = {
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = .current
        return calendario
    }()

    private static let formato: DateFormatter = {
        let formato = DateFormatter()
        formato.calendar = calendario
        formato.locale = Locale(identifier: "en_US_POSIX")
        formato.timeZone = .current
        formato.dateFormat = "yyyy-MM-dd"
        return formato
    }()
}

/// Saved dossiers on this device, most recent first.
struct DossiesSalvosStore {
    private let defaults: UserDefaults
    private static let chave = "dossiesSalvosV1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func todos() -> [DossieSalvo] {
        guard let dados = defaults.data(forKey: Self.chave),
              let lista = try? JSONDecoder().decode([DossieSalvo].self, from: dados) else { return [] }
        return lista.sorted {
            $0.criadoEm != $1.criadoEm ? $0.criadoEm > $1.criadoEm : $0.tema.lowercased() < $1.tema.lowercased()
        }
    }

    func buscar(id: String) -> DossieSalvo? { todos().first { $0.id == id } }

    func buscar(chave: String) -> DossieSalvo? { todos().first { $0.chave == chave } }

    /// Replaces the dossier with the same id, or the same study saved before.
    func salvar(_ dossie: DossieSalvo) {
        gravar(todos().filter { $0.id != dossie.id && $0.chave != dossie.chave } + [dossie])
    }

    func remover(id: String) {
        gravar(todos().filter { $0.id != id })
    }

    private func gravar(_ lista: [DossieSalvo]) {
        defaults.set(try? JSONEncoder().encode(lista), forKey: Self.chave)
    }
}
