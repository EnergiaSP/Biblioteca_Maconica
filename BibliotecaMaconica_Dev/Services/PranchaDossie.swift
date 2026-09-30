import Foundation

/// Prancha built from a dossier with only the excerpts it already cites, ABNT citations and references,
/// and the side-by-side comparison of authors. Mirrors `Tools/prancha_referencia.py`;
/// `casos_prancha_v1.json` holds the golden cases both apps reproduce.
enum PranchaDossie {
    struct Configuracao: Decodable {
        let schemaVersion: Int
        let semLocal: String
        let semEditora: String
        let semLocalEditora: String
        let semAno: String
        let sufixos: [String]
        let artigos: [String]
        let separadoresAutores: [String]
        let limiteTermosConclusao: Int
        let secoes: [String: String]
        let textos: [String: String]
        let rotulos: [String: String]

        static let compartilhada: Configuracao? = {
            guard let url = Bundle.main.url(forResource: "prancha_v1", withExtension: "json"),
                  let dados = try? Data(contentsOf: url),
                  let configuracao = try? JSONDecoder().decode(Configuracao.self, from: dados),
                  configuracao.schemaVersion == 1 else { return nil }
            return configuracao
        }()

        func texto(_ chave: String, _ valores: [String: String] = [:]) -> String {
            PranchaDossie.preencher(textos[chave] ?? chave, valores)
        }

        func rotulo(_ chave: String) -> String { rotulos[chave] ?? chave }
    }

    /// Bibliographic data of a work (`obras_referencias_v1.json`); empty fields are unknown.
    struct Obra: Codable, Equatable {
        var titulo = ""
        var autor = ""
        var ano = ""
        var editora = ""
        var local = ""
    }

    private struct ArquivoObras: Decodable { let obras: [String: Obra] }

    static let obrasCompartilhadas: [String: Obra] = {
        guard let url = Bundle.main.url(forResource: "obras_referencias_v1", withExtension: "json"),
              let dados = try? Data(contentsOf: url),
              let arquivo = try? JSONDecoder().decode(ArquivoObras.self, from: dados) else { return [:] }
        return arquivo.obras
    }()

    struct Secao: Codable, Equatable {
        let titulo: String
        let paragrafos: [String]
    }

    struct Autor: Codable, Equatable, Identifiable {
        let quem: String
        let obras: [String]
        let trechos: [String]
        var id: String { quem }
    }

    struct Prancha: Codable, Equatable {
        let titulo: String
        let secoes: [Secao]
        let comparacao: [Autor]
        let referencias: [String]
        let texto: String
    }

    static func preencher(_ modelo: String, _ valores: [String: String]) -> String {
        valores.reduce(modelo) { $0.replacingOccurrences(of: "{\($1.key)}", with: $1.value) }
    }

    private static func palavras(_ texto: String) -> [String] {
        texto.split(whereSeparator: { $0.isWhitespace }).map(String.init)
    }

    private static func aparado(_ texto: String) -> String { texto.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// (surname, given names) of each author.
    static func autores(_ nome: String, _ c: Configuracao) -> [(sobrenome: String, prenome: String)] {
        var partes = [aparado(nome)]
        for separador in c.separadoresAutores {
            partes = partes.flatMap { $0.components(separatedBy: separador).map(aparado) }
        }
        return partes.filter { !$0.isEmpty }.map { parte in
            if let virgula = parte.firstIndex(of: ",") {
                return (aparado(String(parte[..<virgula])), aparado(String(parte[parte.index(after: virgula)...])))
            }
            let lista = palavras(parte)
            let tamanho = lista.count >= 3 && c.sufixos.contains(lista[lista.count - 1].lowercased()) ? 2 : 1
            return (lista.suffix(tamanho).joined(separator: " "), lista.dropLast(tamanho).joined(separator: " "))
        }
    }

    static func juntar(_ itens: [String], _ c: Configuracao) -> String {
        guard itens.count > 1 else { return itens.joined() }
        return itens.dropLast().joined(separator: ", ") + (c.textos["ultimoSeparador"] ?? " e ") + itens[itens.count - 1]
    }

    /// Authors in natural order ("Luc Ferry"), joined by commas and " e ".
    static func falado(_ nome: String, _ c: Configuracao) -> String {
        juntar(autores(nome, c).map { aparado("\($0.prenome) \($0.sobrenome)") }, c)
    }

    static func trecho(_ texto: String) -> String {
        var resultado = Substring(texto)
        while let ultimo = resultado.last, " ;,:".contains(ultimo) { resultado = resultado.dropLast() }
        return String(resultado)
    }

    /// Title as the entry of a work without author: first word (and a leading article) in capitals.
    static func entradaTitulo(_ titulo: String, _ c: Configuracao) -> String {
        let lista = palavras(titulo)
        let tamanho = lista.count >= 2 && c.artigos.contains(lista[0].lowercased()) ? 2 : 1
        return (lista.prefix(tamanho).map { $0.uppercased() } + lista.dropFirst(tamanho)).joined(separator: " ")
    }

    static func referencia(_ obra: Obra, _ c: Configuracao) -> String {
        let local = aparado(obra.local), editora = aparado(obra.editora)
        let imprenta = local.isEmpty && editora.isEmpty
            ? c.semLocalEditora
            : "\(local.isEmpty ? c.semLocal : local): \(editora.isEmpty ? c.semEditora : editora)"
        let ano = aparado(obra.ano).isEmpty ? c.semAno : aparado(obra.ano)
        let titulo = aparado(obra.titulo)
        let nomes = autores(obra.autor, c)
        guard !nomes.isEmpty else { return "\(entradaTitulo(titulo, c)). \(imprenta), \(ano)." }
        let entrada = nomes.map { $0.prenome.isEmpty ? $0.sobrenome.uppercased() : "\($0.sobrenome.uppercased()), \($0.prenome)" }
            .joined(separator: "; ")
        return "\(entrada)\(entrada.hasSuffix(".") ? "" : ".") \(titulo). \(imprenta), \(ano)."
    }

    static func citacao(_ obra: Obra, pagina: Int, _ c: Configuracao) -> String {
        let nomes = autores(obra.autor, c)
        let quem: String
        if nomes.isEmpty {
            let lista = palavras(entradaTitulo(aparado(obra.titulo), c))
            let tamanho = lista.count >= 2 && c.artigos.contains(lista[0].lowercased()) ? 2 : 1
            quem = lista.prefix(tamanho).joined(separator: " ") + "..."
        } else {
            quem = nomes.map { $0.sobrenome.uppercased() }.joined(separator: "; ")
        }
        return "(\(quem), \(aparado(obra.ano).isEmpty ? c.semAno : aparado(obra.ano)), p. \(pagina))"
    }

    static func montar(
        termo: String, fontes: [DossieEstudoAnalise.Fonte], definicoes: [DossieEstudoAnalise.Trecho],
        resumo: [DossieEstudoAnalise.Trecho], divergencias: [DossieEstudoAnalise.Trecho],
        termosAssociados: [DossieEstudoAnalise.TermoAssociado], obras: [String: Obra], configuracao c: Configuracao
    ) -> Prancha {
        let porId = Dictionary(fontes.map { ($0.id, $0) }, uniquingKeysWith: { primeira, _ in primeira })
        let tema = palavras(DossieEstudoAnalise.nfc(termo)).joined(separator: " ")
        let citados = (definicoes + resumo + divergencias).filter { porId[$0.fonte] != nil }

        func obra(_ fonte: String) -> Obra {
            let origem = porId[fonte]!
            var dados = obras[origem.obraId] ?? Obra()
            if aparado(dados.titulo).isEmpty { dados.titulo = origem.tituloObra }
            return dados
        }
        func citar(_ item: DossieEstudoAnalise.Trecho) -> String { citacao(obra(item.fonte), pagina: porId[item.fonte]!.pagina, c) }
        func entreAspas(_ item: DossieEstudoAnalise.Trecho) -> String {
            c.texto("trecho", ["trecho": trecho(item.texto), "citacao": citar(item)])
        }

        var unicos: [DossieEstudoAnalise.Trecho] = []
        for item in citados where !unicos.contains(item) { unicos.append(item) }

        // Side by side: every cited excerpt grouped by author (or by work when the author is unknown).
        struct Grupo { var quem: String; var obras: [String]; var trechos: [String]; var resumo: [String]; var varios: Bool }
        var grupos: [String: Grupo] = [:]
        for item in unicos {
            let dados = obra(item.fonte)
            let conhecido = aparado(dados.autor)
            let quem = conhecido.isEmpty ? c.texto("semAutor", ["obra": dados.titulo]) : falado(conhecido, c)
            let chave = DossieEstudoAnalise.dobrar(quem)
            var grupo = grupos[chave] ?? Grupo(quem: quem, obras: [], trechos: [], resumo: [], varios: autores(conhecido, c).count > 1)
            if !grupo.obras.contains(dados.titulo) { grupo.obras.append(dados.titulo) }
            grupo.trechos.append(entreAspas(item))
            if resumo.contains(item) { grupo.resumo.append(entreAspas(item)) }
            grupos[chave] = grupo
        }
        let ordenados = grupos.sorted { a, b in
            a.value.trechos.count != b.value.trechos.count ? a.value.trechos.count > b.value.trechos.count : a.key < b.key
        }.map(\.value)

        var obrasCitadas: [String] = []
        for item in unicos where !obrasCitadas.contains(porId[item.fonte]!.obraId) { obrasCitadas.append(porId[item.fonte]!.obraId) }

        var introducao = [unicos.isEmpty ? c.texto("semTrechos", ["tema": tema])
                                         : c.texto("abertura", ["n": "\(obrasCitadas.count)", "tema": tema])]
        introducao += definicoes.filter { porId[$0.fonte] != nil }.map {
            c.texto("definicao", ["obra": obra($0.fonte).titulo, "trecho": trecho($0.texto), "citacao": citar($0)])
        }
        let desenvolvimento = ordenados.filter { !$0.resumo.isEmpty }.map {
            c.texto($0.varios ? "autoresAfirmam" : "autorAfirma", ["quem": $0.quem, "trechos": $0.resumo.joined(separator: "; ")])
        }
        let pontosDivergentes = divergencias.filter { porId[$0.fonte] != nil }.map {
            c.texto("divergencia", ["obra": obra($0.fonte).titulo, "trecho": trecho($0.texto), "citacao": citar($0)])
        }
        let termos = termosAssociados.prefix(c.limiteTermosConclusao).map(\.forma)
        let conclusao = (termos.isEmpty ? [] : [c.texto("conclusaoTermos", ["tema": tema, "termos": juntar(Array(termos), c)])])
            + [c.texto("conclusaoPendente")]
        let referencias = Set(obrasCitadas.map { obraId in
            referencia(obra(unicos.first { porId[$0.fonte]!.obraId == obraId }!.fonte), c)
        }).sorted { (DossieEstudoAnalise.dobrar($0), $0) < (DossieEstudoAnalise.dobrar($1), $1) }

        var secoes = [Secao(titulo: c.secoes["introducao"] ?? "", paragrafos: introducao),
                      Secao(titulo: c.secoes["desenvolvimento"] ?? "", paragrafos: desenvolvimento)]
        if !pontosDivergentes.isEmpty { secoes.append(Secao(titulo: c.secoes["divergencias"] ?? "", paragrafos: pontosDivergentes)) }
        secoes += [Secao(titulo: c.secoes["conclusao"] ?? "", paragrafos: conclusao),
                   Secao(titulo: c.secoes["referencias"] ?? "", paragrafos: referencias)]
        secoes = secoes.filter { !$0.paragrafos.isEmpty }
        let titulo = c.texto("titulo", ["tema": tema])
        let texto = ([titulo] + secoes.map { $0.titulo + "\n\n" + $0.paragrafos.joined(separator: "\n\n") }).joined(separator: "\n\n") + "\n"
        return Prancha(titulo: titulo, secoes: secoes,
                       comparacao: ordenados.map { Autor(quem: $0.quem, obras: $0.obras, trechos: $0.trechos) },
                       referencias: referencias, texto: texto)
    }
}
