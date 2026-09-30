import Foundation

/// Study tracks by degree (Aprendiz, Companheiro, Mestre): each step is a topic studied in the
/// Dossiê. Mirrors `Tools/trilhas_referencia.py`; `casos_trilhas_v1.json` holds the golden cases.
enum TrilhasGrau {
    struct Etapa: Decodable, Identifiable, Equatable {
        let id: String
        let tema: String
        let descricao: String
    }

    struct Grau: Decodable, Identifiable {
        let id: String
        let nome: String
        let descricao: String
        let etapas: [Etapa]
        let obrasSugeridas: [String]
    }

    struct Marco: Decodable {
        let percentual: Int
        let rotulo: String
    }

    struct Configuracao: Decodable {
        let schemaVersion: Int
        let marcos: [Marco]
        let rotulos: [String: String]
        let graus: [Grau]

        static let compartilhada: Configuracao? = {
            guard let url = Bundle.main.url(forResource: "trilhas_grau_v1", withExtension: "json"),
                  let dados = try? Data(contentsOf: url),
                  let configuracao = try? JSONDecoder().decode(Configuracao.self, from: dados),
                  configuracao.schemaVersion == 1 else { return nil }
            return configuracao
        }()

        func rotulo(_ chave: String, _ valores: [String: String] = [:]) -> String {
            valores.reduce(rotulos[chave] ?? chave) { $0.replacingOccurrences(of: "{\($1.key)}", with: $1.value) }
        }
    }

    struct Progresso: Decodable, Equatable {
        let grau: String
        let concluidas: [String]
        let total: Int
        let percentual: Int
        let marco: String
        let proxima: String?
    }

    /// Case, accents and spaces ignored, as the saved dossier topic is compared with the step topic.
    static func chaveEstudo(_ tema: String) -> String {
        DossieEstudoAnalise.dobrar(tema).split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    static func progresso(_ configuracao: Configuracao, temasSalvos: [String], marcadas: Set<String>) -> [Progresso] {
        let salvos = Set(temasSalvos.map(chaveEstudo))
        return configuracao.graus.map { grau in
            let feitas = grau.etapas.filter { marcadas.contains($0.id) || salvos.contains(chaveEstudo($0.tema)) }.map(\.id)
            let total = grau.etapas.count
            var marco = ""
            for item in configuracao.marcos where feitas.count >= max(1, (total * item.percentual + 99) / 100) {
                marco = item.rotulo
            }
            return Progresso(grau: grau.id, concluidas: feitas, total: total,
                             percentual: total == 0 ? 0 : feitas.count * 100 / total, marco: marco,
                             proxima: grau.etapas.first { !feitas.contains($0.id) }?.id)
        }
    }

    // MARK: - Etapas marcadas neste aparelho

    private static let chaveMarcadas = "trilhasGrauMarcadas"

    static func marcadas(_ defaults: UserDefaults = .standard) -> Set<String> {
        Set(defaults.stringArray(forKey: chaveMarcadas) ?? [])
    }

    static func alternar(_ etapa: String, _ defaults: UserDefaults = .standard) {
        var atual = marcadas(defaults)
        if atual.contains(etapa) { atual.remove(etapa) } else { atual.insert(etapa) }
        defaults.set(atual.sorted(), forKey: chaveMarcadas)
    }
}
