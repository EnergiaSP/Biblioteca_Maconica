import Foundation

/// Search variants: spelling groups and the optional singular and plural. Mirrors
/// `Tools/variantes_referencia.py`; `casos_variantes_v1.json` holds the golden cases both apps reproduce.
enum VariantesBusca {
    struct Flexao: Decodable {
        let final: String
        let formas: [String]
    }

    struct Configuracao: Decodable {
        let schemaVersion: Int
        let minimoLetras: Int
        let maximoPorPalavra: Int
        let semFlexao: [String]
        let grupos: [[String]]
        let singularPlural: [Flexao]
        let rotulos: [String: String]

        static let compartilhada: Configuracao? = {
            guard let url = Bundle.main.url(forResource: "variantes_busca_v1", withExtension: "json"),
                  let dados = try? Data(contentsOf: url),
                  let configuracao = try? JSONDecoder().decode(Configuracao.self, from: dados),
                  configuracao.schemaVersion == 1 else { return nil }
            return configuracao
        }()

        func rotulo(_ chave: String) -> String { rotulos[chave] ?? chave }
    }

    /// Each word of a group maps to the other words of the group, in the group's order.
    static func grafias(_ c: Configuracao) -> [String: [String]] {
        var resultado: [String: [String]] = [:]
        for grupo in c.grupos {
            for palavra in grupo {
                var atual = resultado[palavra] ?? []
                for outra in grupo where outra != palavra && !atual.contains(outra) { atual.append(outra) }
                resultado[palavra] = atual
            }
        }
        return resultado
    }

    static func flexoes(_ palavra: String, _ c: Configuracao) -> [String] {
        guard palavra.count >= c.minimoLetras, !c.semFlexao.contains(palavra),
              let regra = c.singularPlural.first(where: { palavra.hasSuffix($0.final) }) else { return [] }
        let raiz = String(palavra.dropLast(regra.final.count))
        return regra.formas.map { raiz + $0 }
    }

    /// Alternatives of each searched word (already normalized), as passed to the index query.
    static func expandir(_ palavras: [String], singularPlural: Bool, _ c: Configuracao) -> [String: [String]] {
        let grupos = grafias(c)
        var resultado: [String: [String]] = [:]
        for palavra in palavras {
            var opcoes = grupos[palavra] ?? []
            if singularPlural {
                for base in [palavra] + opcoes { opcoes += flexoes(base, c) }
            }
            var unicas: [String] = []
            for opcao in opcoes where opcao != palavra && !unicas.contains(opcao) { unicas.append(opcao) }
            if !unicas.isEmpty { resultado[palavra] = Array(unicas.prefix(c.maximoPorPalavra)) }
        }
        return resultado
    }

    /// Variants of every word of a library search, words and quoted phrases alike.
    static func paraBusca(_ termo: String, singularPlural: Bool) -> [String: [String]] {
        guard let c = Configuracao.compartilhada else { return [:] }
        let palavras = BibliotecaSQLiteService.termosBusca(termo)
            .flatMap { RegrasEstudo.normalizar($0).split(separator: " ").map(String.init) }
        return expandir(palavras, singularPlural: singularPlural, c)
    }

    static let chaveSingularPlural = "buscaSingularPlural"

}
